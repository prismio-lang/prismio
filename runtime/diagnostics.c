// Source-level diagnostics: the file registry, span rendering and error
// accounting behind every message the compiler prints.
//
// Compiler-only (backend.lib). A compiled Prismio program never reports a
// diagnostic, so none of this belongs in runtime.lib.
//
// Why this lives in C rather than in Prismio: rendering a diagnostic needs the
// *original source text* of whichever file the node came from, long after the
// parser has thrown the text away and `resolve_imports` has flattened every
// module into one AST. A registry keyed by an integer id is the smallest thing
// that survives both. Prismio also has no varargs, so the frontend composes the
// message with str_concat and hands over a finished string.
//
// Output goes to stderr, unconditionally and without colour. stderr because a
// diagnostic is not program output; without colour because the compiler cannot
// know whether the receiving console decodes ANSI (Windows consoles do not
// enable VT processing for a plain console application by default), and a
// half-decoded escape is worse than none.

// stdio/stdlib/string arrive through this; including them again here would only
// let the two lists drift.
#include "prismio_platform.h"

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

static void diag_emit_json(const char* severity, int file, int line, int col,
                           int len, const char* message) {
    fputs("{\"kind\":\"diagnostic\",\"schemaVersion\":1,\"severity\":", stderr);
    diag_json_string(severity);
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
static void diag_render_span(int file, int line, int col, int len) {
    if (file < 0 || file >= g_file_count || line <= 0) return;

    const char* path = g_files[file].path;
    const char* text = g_files[file].content;
    const char* start = diag_line_start(text, line);

    if (col < 1) col = 1;

    if (!start) {
        // No snippet available, but the location itself is still worth having.
        fprintf(stderr, " --> %s:%d:%d\n", path, line, col);
        return;
    }

    int line_len = diag_line_length(start);
    int gutter = diag_digits(line);

    diag_spaces(gutter);
    fprintf(stderr, "--> %s:%d:%d\n", path, line, col);

    diag_spaces(gutter + 1);
    fprintf(stderr, "|\n");

    fprintf(stderr, "%d | %.*s\n", line, line_len, start);

    diag_spaces(gutter + 1);
    fprintf(stderr, "| ");

    // Pad with the source's own whitespace so a tab-indented line keeps the
    // caret under the right character instead of drifting by seven columns.
    int pad = col - 1;
    if (pad > line_len) pad = line_len;
    for (int i = 0; i < pad; i++) fputc(start[i] == '\t' ? '\t' : ' ', stderr);

    int carets = len > 0 ? len : 1;
    if (pad + carets > line_len) carets = line_len - pad;
    if (carets < 1) carets = 1;
    for (int i = 0; i < carets; i++) fputc('^', stderr);
    fputc('\n', stderr);
}

static void diag_emit(const char* severity, int file, int line, int col, int len, const char* message) {
    if (g_json_mode) {
        diag_emit_json(severity, file, line, col, len, message);
        fflush(stderr);
        return;
    }

    fprintf(stderr, "%s: %s\n", severity, message ? message : "");
    diag_render_span(file, line, col, len);
    fflush(stderr);
}

void diag_error_at(int file, int line, int col, int len, const char* message) {
    g_finished = 0;
    g_error_count++;

    if (g_error_count > DIAG_ERROR_LIMIT) {
        if (g_json_mode) {
            diag_emit_json("error", -1, 0, 0, 0,
                           "too many errors; stopping after 25");
            diag_emit_json_summary();
            exit(1);
        }
        fprintf(stderr, "error: too many errors; stopping after %d\n", DIAG_ERROR_LIMIT);
        fflush(stderr);
        exit(1);
    }

    diag_emit("error", file, line, col, len, message);
}

void diag_error(const char* message) {
    diag_error_at(-1, 0, 0, 0, message);
}

void diag_warning_at(int file, int line, int col, int len, const char* message) {
    g_finished = 0;
    g_warning_count++;
    diag_emit("warning", file, line, col, len, message);
}

// Unlocated, the counterpart of diag_error above and reached the same way -- a
// file of -1. LAYOUT 3.2's W2 is what needed it: a workload that fails to build
// or times out has to warn, and the thing that went wrong is a build step rather
// than a span of source, so there is no honest place to point a caret.
void diag_warning(const char* message) {
    diag_warning_at(-1, 0, 0, 0, message);
}

// A secondary span belonging to the diagnostic just reported -- "the first
// declaration is here", "the loop starts here". Indented so it reads as
// subordinate rather than as a second, unrelated error.
void diag_note_at(int file, int line, int col, int len, const char* message) {
    if (g_json_mode) {
        diag_emit("note", file, line, col, len, message);
        return;
    }

    fprintf(stderr, "  note: %s\n", message ? message : "");
    diag_render_span(file, line, col, len);
    fflush(stderr);
}

void diag_note(const char* message) {
    if (g_json_mode) {
        diag_emit("note", -1, 0, 0, 0, message);
        return;
    }

    fprintf(stderr, "  note: %s\n", message ? message : "");
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

    if (g_error_count == 1) {
        fprintf(stderr, "error: aborting due to 1 previous error\n");
    } else {
        fprintf(stderr, "error: aborting due to %d previous errors\n", g_error_count);
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
