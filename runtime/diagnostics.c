// Source-level diagnostics: the file registry, span rendering and error
// accounting behind every message the compiler prints.
//
// Compiler-only (backend.lib). A compiled Prismio program never reports a
// diagnostic, so none of this belongs in installed runtime bitcode.
//
// Why this lives in C rather than in Prismio: rendering a diagnostic needs the
// *original source text* of whichever file the node came from, long after the
// parser has thrown the text away and `resolve_imports` has flattened every
// module into one AST. A registry keyed by an integer id is the smallest thing
// that survives both. Prismio also has no varargs, so the frontend composes the
// message with str_concat and hands over a finished string.
//
// Output goes to stderr, because a diagnostic is not program output. It is
// styled only when stderr is a terminal that decodes ANSI -- see
// diag_tty_styled below -- and otherwise is the plain text it always was, byte
// for byte: the test suite, an IDE and every script that greps a build log
// match on that text, and none of them is a terminal.

// stdio/stdlib/string arrive through this; including them again here would only
// let the two lists drift.
#include "prismio_platform.h"

#include <time.h>

#define DIAG_MAX_FILES 256

// Past this many errors the compiler stops rather than continuing to recover.
// Beyond roughly this point the output is cascade, not information, and every
// further recovery step is another chance to walk a half-built AST.
#define DIAG_ERROR_LIMIT 25

// `module` is the *logical* import path this file was reached by -- `std.string`
// for a file the installed layout stores at `stdlib/string.psm`. It is recorded
// rather than derived because the two disagree: `resolveImportPath` flattens the
// package on install, so a qualifier computed from `path` would read `std.string`
// in a checkout and `stdlib.string` from an installed toolchain, and every
// qualified call would resolve here and fail there.
typedef struct {
    char* path;
    char* content;
    char* module;
} DiagFile;

static DiagFile g_files[DIAG_MAX_FILES];
static int g_file_count = 0;
static int g_error_count = 0;
static int g_warning_count = 0;
static int g_json_mode = 0;
static int g_finished = 0;

void diag_set_json_mode(int on) {
    g_json_mode = on != 0;
}

// Terminal presentation
//
// Colour, the live progress line and the result lines (`Built`, `Checked`).
// Each is decided per stream, because `prismio build | tee log` has a terminal
// on stderr and a pipe on stdout, and the pipe must get the plain text.
//
// The detection is prismio_rt_color_supported's (program_support.c) -- the one
// std.term programs use -- repeated rather than called, because this file is
// the compiler backend and that one is program runtime. On Windows it switches
// VT processing on, which is what the old "never colour" rule was waiting for.
// FORCE_COLOR / CLICOLOR_FORCE override a pipe, for CI logs that render ANSI.

static int g_styled[3] = {-1, -1, -1};   // by fd; -1 until first asked
static double g_clock_start = -1.0;
static char g_progress_subject[256];
static int g_progress_shown = 0;

static int diag_env_set(const char* name) {
    const char* v = getenv(name);
    return v && v[0] && !(v[0] == '0' && v[1] == '\0');
}

static int diag_is_terminal(int fd) {
#ifdef _WIN32
    return _isatty(fd) ? 1 : 0;
#else
    return isatty(fd) ? 1 : 0;
#endif
}

static int diag_detect_color(int fd) {
    if (diag_env_set("NO_COLOR")) return 0;
    if (diag_env_set("FORCE_COLOR") || diag_env_set("CLICOLOR_FORCE")) return 1;
    const char* term = getenv("TERM");
    if (term && strcmp(term, "dumb") == 0) return 0;
#ifdef _WIN32
    if (!_isatty(fd)) return 0;
    HANDLE handle = GetStdHandle(fd == 2 ? STD_ERROR_HANDLE : STD_OUTPUT_HANDLE);
    DWORD mode = 0;
    if (handle == INVALID_HANDLE_VALUE || !GetConsoleMode(handle, &mode)) return 0;
    if (mode & ENABLE_VIRTUAL_TERMINAL_PROCESSING) return 1;
    return SetConsoleMode(handle, mode | ENABLE_VIRTUAL_TERMINAL_PROCESSING) ? 1 : 0;
#else
    return isatty(fd) ? 1 : 0;
#endif
}

// Whether fd 1 or 2 gets styled output. JSON mode is a machine reading stderr,
// so it is never styled whatever the stream is.
int diag_tty_styled(int fd) {
    if (fd != 1 && fd != 2) return 0;
    if (g_json_mode) return 0;
    if (g_styled[fd] < 0) g_styled[fd] = diag_detect_color(fd);
    return g_styled[fd];
}

// An SGR sequence, or "" when the stream is plain -- so a format string can
// carry its styling unconditionally and still print plain text to a pipe.
static const char* sgr(int fd, const char* code) {
    return diag_tty_styled(fd) ? code : "";
}

#define SGR_RESET  "\033[0m"
#define SGR_BOLD   "\033[1m"
#define SGR_DIM    "\033[2m"
#define SGR_RED    "\033[1;31m"
#define SGR_GREEN  "\033[1;32m"
#define SGR_YELLOW "\033[1;33m"
#define SGR_BLUE   "\033[1;34m"
#define SGR_MAGENTA "\033[1;35m"
#define SGR_CYAN   "\033[1;36m"

static const char* diag_severity_style(const char* severity) {
    if (strcmp(severity, "error") == 0) return SGR_RED;
    if (strcmp(severity, "warning") == 0) return SGR_YELLOW;
    return SGR_CYAN;
}

static double diag_now_ms(void) {
#ifdef _WIN32
    LARGE_INTEGER freq, now;
    QueryPerformanceFrequency(&freq);
    QueryPerformanceCounter(&now);
    return (double)now.QuadPart * 1000.0 / (double)freq.QuadPart;
#else
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec * 1000.0 + (double)ts.tv_nsec / 1.0e6;
#endif
}

// Erases the progress line, if one is showing. Everything that writes to the
// terminal while a compile is running calls this first -- a diagnostic, a
// result line, a failed tool's output, the program `run` starts -- or it would
// be printed onto the end of "Compiling main.psm (generating IR)".
void diag_progress_clear(void) {
    if (!g_progress_shown) return;
    fputs("\r\033[2K", stderr);
    fflush(stderr);
    g_progress_shown = 0;
}

// Starts the clock the result line reports, and names what is being compiled.
// Nothing is printed until the first phase.
void diag_progress_begin(const char* subject) {
    g_clock_start = diag_now_ms();
    snprintf(g_progress_subject, sizeof(g_progress_subject), "%s", subject ? subject : "");
}

// The phase now running, as one line rewritten in place on stderr:
//
//      Compiling main.psm (checking types)
//
// A real terminal only -- FORCE_COLOR colours a CI log, but a line rewritten
// with `\r` is noise in any log it lands in, and the result line says
// everything it would have. ASCII, because a Windows console that decodes VT
// sequences may still not be on a UTF-8 code page.
void diag_progress(const char* phase) {
    if (!diag_tty_styled(2) || !diag_is_terminal(2) || g_progress_subject[0] == '\0') return;
    fprintf(stderr, "\r\033[2K" SGR_CYAN "%12s" SGR_RESET " %s " SGR_DIM "(%s)" SGR_RESET,
            "Compiling", g_progress_subject, phase ? phase : "");
    fflush(stderr);
    g_progress_shown = 1;
}

// Seconds since diag_progress_begin, formatted for a result line, or "" when no
// clock was started.
static void diag_elapsed(char* out, size_t size) {
    out[0] = '\0';
    if (g_clock_start < 0) return;
    double ms = diag_now_ms() - g_clock_start;
    if (ms < 1000.0) snprintf(out, size, "%.0fms", ms);
    else snprintf(out, size, "%.2fs", ms / 1000.0);
}

// A result line on stdout: what was produced, and how long it took.
//
//   plain  `<plain><subject>` -- "Built ./hello", "Wrote LLVM IR: out.ll". The
//          exact text these lines always had; the suite and scripts match it.
//          Nothing at all when `plain` is empty: a quiet success stays quiet.
//   styled `       Built ./hello  (optimized, 0.84s)`, the verb right-aligned
//          in bold green, cargo's shape.
void diag_result(const char* plain, const char* verb, const char* subject,
                 const char* detail) {
    diag_progress_clear();
    if (!subject) subject = "";
    if (!diag_tty_styled(1)) {
        if (plain && plain[0]) {
            fprintf(stdout, "%s%s\n", plain, subject);
            fflush(stdout);
        }
        return;
    }
    char elapsed[32];
    diag_elapsed(elapsed, sizeof(elapsed));
    int has_detail = detail && detail[0];
    fprintf(stdout, SGR_GREEN "%12s" SGR_RESET " %s", verb ? verb : "", subject);
    if (has_detail || elapsed[0]) {
        fprintf(stdout, SGR_DIM "  (%s%s%s)" SGR_RESET, has_detail ? detail : "",
                has_detail && elapsed[0] ? ", " : "", elapsed);
    }
    fputc('\n', stdout);
    fflush(stdout);
}

// A status line with no plain form -- `Running ./hello` before a program's own
// output. Styled terminals only; piped, the program's output stands alone.
void diag_status(const char* verb, const char* subject) {
    diag_progress_clear();
    if (!diag_tty_styled(1)) return;
    fprintf(stdout, SGR_GREEN "%12s" SGR_RESET " %s\n", verb ? verb : "",
            subject ? subject : "");
    fflush(stdout);
}

// One line of text on stdout in a style, or plain. `style` names a role rather
// than a colour so the palette stays in this file: "ok", "fail", "warn",
// "alert", "heading", "command", "dim", "accent".
void diag_styled(const char* style, const char* text) {
    const char* code = "";
    if (style) {
        if (strcmp(style, "ok") == 0) code = SGR_GREEN;
        else if (strcmp(style, "fail") == 0) code = SGR_RED;
        else if (strcmp(style, "warn") == 0) code = SGR_YELLOW;
        else if (strcmp(style, "alert") == 0) code = SGR_MAGENTA;
        else if (strcmp(style, "heading") == 0) code = SGR_BOLD;
        else if (strcmp(style, "command") == 0) code = SGR_CYAN;
        else if (strcmp(style, "dim") == 0) code = SGR_DIM;
        else if (strcmp(style, "accent") == 0) code = SGR_BLUE;
    }
    diag_progress_clear();
    fprintf(stdout, "%s%s%s", sgr(1, code), text ? text : "", code[0] ? sgr(1, SGR_RESET) : "");
    fflush(stdout);
}

// The same on stderr, for the launcher's banner and anything else that is
// commentary on a build rather than its result.
void diag_styled_err(const char* style, const char* text) {
    const char* code = "";
    if (style) {
        if (strcmp(style, "dim") == 0) code = SGR_DIM;
        else if (strcmp(style, "accent") == 0) code = SGR_BLUE;
        else if (strcmp(style, "ok") == 0) code = SGR_GREEN;
    }
    diag_progress_clear();
    fprintf(stderr, "%s%s%s", sgr(2, code), text ? text : "", code[0] ? sgr(2, SGR_RESET) : "");
    fflush(stderr);
}

// Help text, styled line by line when stdout is a terminal: a line that starts
// in column 0 is a heading, and `prismio <command>` at the start of an indented
// line is the command. Anything else passes through, and piped it is all
// passed through unchanged.
void diag_print_help(const char* text) {
    if (!text) return;
    if (!diag_tty_styled(1)) {
        fputs(text, stdout);
        fputc('\n', stdout);
        fflush(stdout);
        return;
    }
    const char* p = text;
    while (*p) {
        const char* end = strchr(p, '\n');
        int len = end ? (int)(end - p) : (int)strlen(p);
        if (len > 0 && p[0] != ' ') {
            fprintf(stdout, SGR_BOLD "%.*s" SGR_RESET, len, p);
        } else {
            int indent = 0;
            while (indent < len && p[indent] == ' ') indent++;
            const char* word = p + indent;
            if (len - indent > 8 && strncmp(word, "prismio ", 8) == 0) {
                // `prismio` plus the command word after it.
                int cmd = 8;
                while (indent + cmd < len && word[cmd] != ' ') cmd++;
                fprintf(stdout, "%.*s" SGR_CYAN "%.*s" SGR_RESET "%.*s", indent, p, cmd, word,
                        len - indent - cmd, word + cmd);
            } else if (len - indent > 1 && word[0] == '-') {
                // A flag paragraph: the flag in bold, its explanation as is.
                int flag = 0;
                while (indent + flag < len && word[flag] != ' ') flag++;
                fprintf(stdout, "%.*s" SGR_BOLD "%.*s" SGR_RESET "%.*s", indent, p, flag, word,
                        len - indent - flag, word + flag);
            } else {
                fprintf(stdout, "%.*s", len, p);
            }
        }
        fputc('\n', stdout);
        if (!end) break;
        p = end + 1;
    }
    // println's newline after the text's own, as the plain path prints it.
    size_t n = strlen(text);
    if (n > 0 && text[n - 1] == '\n') fputc('\n', stdout);
    fflush(stdout);
}

static char* diag_strdup(const char* s) {
    if (!s) s = "";
    size_t n = strlen(s) + 1;
    char* out = (char*)malloc(n);
    if (!out) return NULL;
    memcpy(out, s, n);
    return out;
}

// Registers a source file and returns the id to stamp onto every token and AST
// node produced from it. The content is copied: the caller's buffer belongs to
// the frontend, which is free to reuse or release it once parsing is done.
//
// Re-registering a path returns the existing id instead of a second entry, so
// the diamond-shaped import graph in src/ does not consume four slots for
// utils.psm.
int diag_add_file(const char* path, const char* content) {
    if (!path) path = "<unknown>";

    for (int i = 0; i < g_file_count; i++) {
        if (strcmp(g_files[i].path, path) == 0) return i;
    }

    if (g_file_count >= DIAG_MAX_FILES) return -1;

    char* p = diag_strdup(path);
    char* c = diag_strdup(content);
    if (!p || !c) {
        free(p);
        free(c);
        return -1;
    }

    g_files[g_file_count].path = p;
    g_files[g_file_count].content = c;
    return g_file_count++;
}

const char* diag_file_path(int file) {
    if (file < 0 || file >= g_file_count) return "<unknown>";
    return g_files[file].path;
}

// One line of a registered file, without its indentation or line ending: what a
// failed `assert` with no message of its own prints, captured while the source is
// still in hand. Returned in a buffer that the next call overwrites -- the one
// caller copies it into an LLVM constant at once -- and "" for a line that does
// not exist, since a program must still build without it.
const char* diag_source_line(int file, int line) {
    static char buf[256];
    buf[0] = '\0';
    if (file < 0 || file >= g_file_count || line < 1) return buf;
    const char* p = g_files[file].content;
    for (int at = 1; at < line && *p; p++) {
        if (*p == '\n') at++;
    }
    while (*p == ' ' || *p == '\t') p++;
    size_t n = 0;
    while (p[n] && p[n] != '\n' && p[n] != '\r' && n + 1 < sizeof buf) n++;
    while (n > 0 && (p[n - 1] == ' ' || p[n - 1] == '\t')) n--;
    memcpy(buf, p, n);
    buf[n] = '\0';
    return buf;
}

// The logical module path for a file, recorded by the merge as it resolves each
// import. Set at most once per file: `diag_add_file` dedupes by path, so a module
// reached twice through a diamond keeps the spelling it was first reached by,
// which is the same rule the merge already applies to the declarations themselves.
//
// Internal storage, freed by nothing -- the getter is declared `alias` on the
// Prismio side, exactly as `diag_file_path` is, so plain malloc is right here and
// `rt_base_alloc` would record an allocation no release ever pairs with.
void diag_set_file_module(int file, const char* module) {
    if (file < 0 || file >= g_file_count) return;
    if (g_files[file].module) return;
    g_files[file].module = diag_strdup(module);
}

// "" rather than "<unknown>" for an unrecorded file: the caller treats an empty
// qualifier as "this file has no module name", which is the honest answer for the
// entry file, and "<unknown>" would be a qualifier a program could accidentally match.
const char* diag_file_module(int file) {
    if (file < 0 || file >= g_file_count) return "";
    if (!g_files[file].module) return "";
    return g_files[file].module;
}

// How many ids diag_add_file has handed out.
//
// Exists because "<unknown>" is a usable answer for a diagnostic and a wrong one
// for debug info: an out-of-range id would become a DIFile named "<unknown>" and
// a debugger would go looking for a file by that name. The DWARF emitter asks
// this first and emits no location at all for an id outside the registry.
int diag_file_count(void) { return g_file_count; }

// Start of the 1-based `line` within `text`, or NULL if the file has fewer
// lines than that -- which happens whenever a span is stale or synthesised, and
// must degrade to "no snippet" rather than reading past the buffer.
static const char* diag_line_start(const char* text, int line) {
    if (!text || line <= 0) return NULL;

    const char* p = text;
    int current = 1;
    while (current < line && *p) {
        if (*p == '\n') current++;
        p++;
    }
    return (current == line) ? p : NULL;
}

static int diag_line_length(const char* start) {
    const char* end = start;
    while (*end && *end != '\n') end++;
    int len = (int)(end - start);
    // A CRLF file would otherwise put a stray carriage return in the middle of
    // the rendered snippet, pushing the caret line back to column zero.
    if (len > 0 && start[len - 1] == '\r') len--;
    return len;
}

static int diag_digits(int value) {
    int n = 1;
    while (value >= 10) {
        value /= 10;
        n++;
    }
    return n;
}

static void diag_spaces(int n) {
    for (int i = 0; i < n; i++) fputc(' ', stderr);
}

// JSON Lines is used instead of one enclosing array so an IDE can consume each
// diagnostic as soon as the compiler reports it. Strings are written directly:
// diagnostics are already complete UTF-8 messages, and allocating an escaped
// copy here would make error reporting itself another failure path.
static void diag_json_string(const char* text) {
    if (!text) text = "";

    fputc('"', stderr);
    for (const unsigned char* p = (const unsigned char*)text; *p; p++) {
        switch (*p) {
            case '"': fputs("\\\"", stderr); break;
            case '\\': fputs("\\\\", stderr); break;
            case '\b': fputs("\\b", stderr); break;
            case '\f': fputs("\\f", stderr); break;
            case '\n': fputs("\\n", stderr); break;
            case '\r': fputs("\\r", stderr); break;
            case '\t': fputs("\\t", stderr); break;
            default:
                if (*p < 0x20) {
                    fprintf(stderr, "\\u%04x", (unsigned int)*p);
                } else {
                    fputc(*p, stderr);
                }
                break;
        }
    }
    fputc('"', stderr);
}

static void diag_emit_json(const char* severity, const char* code, int file,
                           int line, int col, int len, const char* message) {
    fputs("{\"kind\":\"diagnostic\",\"schemaVersion\":1,\"severity\":", stderr);
    diag_json_string(severity);
    fputs(",\"code\":", stderr);
    if (code) {
        diag_json_string(code);
    } else {
        fputs("null", stderr);
    }
    fputs(",\"file\":", stderr);
    if (file >= 0 && file < g_file_count) {
        diag_json_string(g_files[file].path);
    } else {
        fputs("null", stderr);
    }
    fprintf(stderr, ",\"line\":%d,\"column\":%d,\"length\":%d,\"message\":",
            line, col, len);
    diag_json_string(message);
    fputs("}\n", stderr);
}

static void diag_emit_json_summary(void) {
    fprintf(stderr,
            "{\"kind\":\"summary\",\"schemaVersion\":1,\"errors\":%d,\"warnings\":%d}\n",
            g_error_count, g_warning_count);
    fflush(stderr);
}

// The snippet block, in the rustc shape:
//
//      --> src/foo.psm:12:5
//       |
//    12 |     x = 6
//       |     ^
//
// `gutter` is the width of the line number, so the vertical bars line up no
// matter how long the file is.
//
// `accent` colours the carets: the severity's colour, so an error's underline is
// red and a note's is cyan. The frame -- arrow, bars, line number -- is blue, as
// rustc draws it.
static void diag_render_span(int file, int line, int col, int len, const char* accent) {
    if (file < 0 || file >= g_file_count || line <= 0) return;
    const char* frame = sgr(2, SGR_BLUE);
    const char* mark = sgr(2, accent);
    const char* reset = sgr(2, SGR_RESET);

    const char* path = g_files[file].path;
    const char* text = g_files[file].content;
    const char* start = diag_line_start(text, line);

    if (col < 1) col = 1;

    if (!start) {
        // No snippet available, but the location itself is still worth having.
        fprintf(stderr, " %s-->%s %s:%d:%d\n", frame, reset, path, line, col);
        return;
    }

    int line_len = diag_line_length(start);
    int gutter = diag_digits(line);

    diag_spaces(gutter);
    fprintf(stderr, "%s-->%s %s:%d:%d\n", frame, reset, path, line, col);

    diag_spaces(gutter + 1);
    fprintf(stderr, "%s|%s\n", frame, reset);

    fprintf(stderr, "%s%d |%s %.*s\n", frame, line, reset, line_len, start);

    diag_spaces(gutter + 1);
    fprintf(stderr, "%s|%s ", frame, reset);

    // Pad with the source's own whitespace so a tab-indented line keeps the
    // caret under the right character instead of drifting by seven columns.
    int pad = col - 1;
    if (pad > line_len) pad = line_len;
    for (int i = 0; i < pad; i++) fputc(start[i] == '\t' ? '\t' : ' ', stderr);

    int carets = len > 0 ? len : 1;
    if (pad + carets > line_len) carets = line_len - pad;
    if (carets < 1) carets = 1;
    fputs(mark, stderr);
    for (int i = 0; i < carets; i++) fputc('^', stderr);
    fputs(reset, stderr);
    fputc('\n', stderr);
}

static void diag_emit(const char* severity, const char* code, int file,
                      int line, int col, int len, const char* message) {
    if (g_json_mode) {
        diag_emit_json(severity, code, file, line, col, len, message);
        fflush(stderr);
        return;
    }

    // `error[P4001]` in the severity's colour, the message in bold -- rustc's
    // shape, and the plain text is unchanged when stderr is not a terminal.
    diag_progress_clear();
    const char* head = sgr(2, diag_severity_style(severity));
    const char* bold = sgr(2, SGR_BOLD);
    const char* reset = sgr(2, SGR_RESET);
    if (code) {
        fprintf(stderr, "%s%s[%s]%s%s: %s%s\n", head, severity, code, reset, bold,
                message ? message : "", reset);
    } else {
        fprintf(stderr, "%s%s%s%s: %s%s\n", head, severity, reset, bold,
                message ? message : "", reset);
    }
    diag_render_span(file, line, col, len, diag_severity_style(severity));
    fflush(stderr);
}

void diag_error_at_code(const char* code, int file, int line, int col, int len,
                        const char* message) {
    g_finished = 0;
    g_error_count++;

    if (g_error_count > DIAG_ERROR_LIMIT) {
        if (g_json_mode) {
            diag_emit_json("error", "P0001", -1, 0, 0, 0,
                           "too many errors; stopping after 25");
            diag_emit_json_summary();
            exit(1);
        }
        diag_progress_clear();
        fprintf(stderr, "%serror[P0001]%s%s: too many errors; stopping after %d%s\n",
                sgr(2, SGR_RED), sgr(2, SGR_RESET), sgr(2, SGR_BOLD), DIAG_ERROR_LIMIT,
                sgr(2, SGR_RESET));
        fflush(stderr);
        exit(1);
    }

    diag_emit("error", code, file, line, col, len, message);
}

void diag_error_code(const char* code, const char* message) {
    diag_error_at_code(code, -1, 0, 0, 0, message);
}

void diag_warning_at_code(const char* code, int file, int line, int col, int len,
                          const char* message) {
    g_finished = 0;
    g_warning_count++;
    diag_emit("warning", code, file, line, col, len, message);
}

// Unlocated, the counterpart of diag_error above and reached the same way -- a
// file of -1. LAYOUT 3.2's W2 is what needed it: a workload that fails to build
// or times out has to warn, and the thing that went wrong is a build step rather
// than a span of source, so there is no honest place to point a caret.
void diag_warning_code(const char* code, const char* message) {
    diag_warning_at_code(code, -1, 0, 0, 0, message);
}

// Compatibility entry points for seed compilers and external users of the C
// runtime. New frontend call sites use the coded forms above; P0000 makes any
// remaining legacy caller visible without dropping the machine-readable field.
void diag_error_at(int file, int line, int col, int len, const char* message) {
    diag_error_at_code("P0000", file, line, col, len, message);
}

void diag_error(const char* message) {
    diag_error_code("P0000", message);
}

void diag_warning_at(int file, int line, int col, int len, const char* message) {
    diag_warning_at_code("P0000", file, line, col, len, message);
}

void diag_warning(const char* message) {
    diag_warning_code("P0000", message);
}

// A secondary span belonging to the diagnostic just reported -- "the first
// declaration is here", "the loop starts here". Indented so it reads as
// subordinate rather than as a second, unrelated error.
void diag_note_at(int file, int line, int col, int len, const char* message) {
    if (g_json_mode) {
        diag_emit("note", NULL, file, line, col, len, message);
        return;
    }

    diag_progress_clear();
    fprintf(stderr, "  %snote%s: %s\n", sgr(2, SGR_CYAN), sgr(2, SGR_RESET), message ? message : "");
    diag_render_span(file, line, col, len, SGR_CYAN);
    fflush(stderr);
}

void diag_note(const char* message) {
    if (g_json_mode) {
        diag_emit("note", NULL, -1, 0, 0, 0, message);
        return;
    }

    diag_progress_clear();
    fprintf(stderr, "  %snote%s: %s\n", sgr(2, SGR_CYAN), sgr(2, SGR_RESET), message ? message : "");
    fflush(stderr);
}

int diag_error_count(void) {
    return g_error_count;
}

int diag_warning_count(void) {
    return g_warning_count;
}

// The closing line, printed once when compilation gives up. Its wording is the
// contract the negative tests match on: a test passes because the compiler
// *rejected* the program, which a crash or a linker failure must not be able to
// impersonate.
void diag_finish(void) {
    if (g_finished) return;
    g_finished = 1;

    if (g_json_mode) {
        diag_emit_json_summary();
        return;
    }

    if (g_error_count <= 0) return;

    diag_progress_clear();
    const char* head = sgr(2, SGR_RED);
    const char* bold = sgr(2, SGR_BOLD);
    const char* reset = sgr(2, SGR_RESET);
    if (g_error_count == 1) {
        fprintf(stderr, "%serror%s%s: aborting due to 1 previous error%s\n", head, reset, bold, reset);
    } else {
        fprintf(stderr, "%serror%s%s: aborting due to %d previous errors%s\n", head, reset, bold,
                g_error_count, reset);
    }
    fflush(stderr);
}

void diag_reset(void) {
    for (int i = 0; i < g_file_count; i++) {
        free(g_files[i].path);
        free(g_files[i].content);
        free(g_files[i].module);
        g_files[i].path = NULL;
        g_files[i].content = NULL;
        // Cleared with the rest: diag_set_file_module refuses to overwrite a
        // recorded name, so a stale one surviving a reset would silently give
        // every file in the next compile the previous compile's qualifier.
        g_files[i].module = NULL;
    }
    g_file_count = 0;
    g_error_count = 0;
    g_warning_count = 0;
    g_finished = 0;
}
