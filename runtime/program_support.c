// Program support -- the runtime half of the former driver.c.
//
// Everything here is callable by a compiled Prismio program and belongs in
// its own installed runtime bitcode module. It must not depend on llc, clang, or
// anything else to do with *producing* a program; that all lives in build_driver.c.

#include "prismio_platform.h"
#include "prismio_runtime.h"

// M4.3's common conversion/access failure path. Defined outside
// lang_runtime.c so its curated bounds-check body does not grow private Clang
// `.cold` dependencies that cannot be linked from the extracted module.
__attribute__((noreturn)) void data_view_fail(const char* message) {
    fprintf(stderr, "runtime error: invalid DataView conversion: %s\n", message);
    exit(1);
}

__attribute__((noreturn)) void data_view_access_fail(int reason) {
    if (reason == 1) data_view_fail("view is not ready for access");
    data_view_fail("element index out of range");
}

int file_exists(const char* path) {
    FILE* file = fopen(path, "r");
    if (file) {
        fclose(file);
        return 1;
    }
    return 0;
}

// `file_exists` above opens the path, which is not a directory test: fopen on a
// directory succeeds on some platforms and fails on others, so it answers a
// different question than this one asks.
//
// Exported rather than static because a package manager has to tell "this path
// dependency names a real directory" from "it does not", and the only other way
// to ask was to call make_directory -- which answers by *creating* it, so a
// mistyped path would silently succeed.
int directory_exists(const char* path) {
    if (!path || !path[0]) return 0;
#ifdef _WIN32
    DWORD attrs = GetFileAttributesA(path);
    if (attrs == INVALID_FILE_ATTRIBUTES) return 0;
    return (attrs & FILE_ATTRIBUTE_DIRECTORY) ? 1 : 0;
#else
    struct stat st;
    if (stat(path, &st) != 0) return 0;
    return S_ISDIR(st.st_mode) ? 1 : 0;
#endif
}

// Creates `path` and every missing parent, and answers 0 for "it exists now".
//
// A separate entry point rather than a flag on write_file, because a package
// manager needs the directory before it has anything to put in it -- and because
// build_driver.c's ensure_directory_exists, which does the same walk, is static
// to that file and is compiler infrastructure rather than part of the surface a
// program can call.
//
// An existing directory is success: PRISMIO_MKDIR fails with EEXIST and that is
// the outcome the caller asked for. Only the final component is reported on, so
// a parent that already exists never fails the call.
int make_directory(const char* path) {
    if (!path || !path[0]) return 1;

    size_t n = strlen(path);
    char* work = (char*)malloc(n + 1);   // internal temporary; never handed to Prismio
    if (!work) return 1;
    memcpy(work, path, n + 1);

    size_t start = 0;
#ifdef _WIN32
    // "C:\..." -- do not try to create the drive itself.
    if (n > 2 && work[1] == ':') start = 3;
#endif
    if (work[0] == '/' || work[0] == '\\') start = 1;

    for (size_t i = start; work[i] != '\0'; i++) {
        if (work[i] == '/' || work[i] == '\\') {
            char saved = work[i];
            work[i] = '\0';
            if (work[0]) PRISMIO_MKDIR(work);
            work[i] = saved;
        }
    }
    PRISMIO_MKDIR(work);
    free(work);

    return directory_exists(path) ? 0 : 1;
}

// Writes `content` over `path`, creating it if absent. 0 on success.
//
// Text mode is deliberate on Windows: a lockfile is read back by people and by
// `read_file`, and "wb" here against a text-mode read elsewhere is how a file
// grows a \r nobody asked for.
int write_file(const char* path, const char* content) {
    if (!path || !path[0]) return 1;
    if (!content) content = "";

    FILE* file = fopen(path, "w");
    if (!file) return 1;

    size_t n = strlen(content);
    size_t written = n ? fwrite(content, 1, n, file) : 0;
    int closed = fclose(file);

    return (written == n && closed == 0) ? 0 : 1;
}

// Returns an empty string on failure, never NULL. Prismio has no null String, so
// every caller checks the result with str_equals(content, "") -- and handing them a
// NULL turned "file not found" into strcmp(NULL, "") and an access violation. That
// made `prismio build missing.psm`, and any `import` naming a file that is not
// there, crash silently instead of reporting the error the code already had ready.
char* read_file(const char* path) {
    FILE* file = fopen(path, "rb");
    if (!file) {
        char* empty = (char*)rt_base_alloc(1);
        empty[0] = '\0';
        return empty;
    }

    fseek(file, 0, SEEK_END);
    long size = ftell(file);
    fseek(file, 0, SEEK_SET);

    char* buffer = (char*)rt_base_alloc(size + 1);
    if (!buffer) {
        fclose(file);
        char* empty = (char*)rt_base_alloc(1);
        empty[0] = '\0';
        return empty;
    }

    size_t read = fread(buffer, 1, size, file);
    buffer[read] = '\0';

    fclose(file);
    return buffer;
}

int delete_file(const char* path) {
    if (!path || path[0] == '\0') return 0;
    return remove(path) == 0 ? 0 : 1;
}

char* get_directory(const char* path) {
    const char* last_slash = strrchr(path, '/');
    const char* last_backslash = strrchr(path, '\\');

    const char* separator = last_slash > last_backslash ? last_slash : last_backslash;

    if (!separator) {
        char* result = (char*)rt_base_alloc(2);
        strcpy(result, ".");
        return result;
    }

    int len = separator - path;
    char* result = (char*)rt_base_alloc(len + 1);
    strncpy(result, path, len);
    result[len] = '\0';

    return result;
}

// Separators in the result are normalised to the host's, including any the
// caller had already embedded in `filename`. That matters for module paths: a
// dotted import (`import ir.expr`) becomes "ir/expr.psm" in the frontend, which
// knows nothing about the host, and the joined path is then what every
// diagnostic about that module prints. Both separators open a file on Windows,
// so this is about how the path reads, not whether it resolves.
char* join_path(const char* directory, const char* filename) {
    int len = (int)strlen(directory) + 1 + (int)strlen(filename) + 1;
    char* result = (char*)rt_base_alloc(len);
    sprintf(result, "%s%c%s", directory, PRISMIO_PATH_SEP, filename);

    for (char* c = result; *c; c++) {
        if (*c == '/' || *c == '\\') *c = PRISMIO_PATH_SEP;
    }
    return result;
}

// The OS owns the working directory; exposing it as an allocated String keeps
// manifest discovery in native Prismio while limiting this runtime seam to the
// one capability the language cannot implement itself.
char* current_directory(void) {
#ifdef _WIN32
    char* path = _getcwd(NULL, 0);
#else
    char* path = getcwd(NULL, 0);
#endif
    // Copied out of the C library's allocation rather than returned directly.
    // getcwd(NULL, 0) allocates with the system malloc, which the verify ledger
    // does not track, so handing that pointer to Prismio meant the release
    // codegen emits for it reported as a pointer that was never live. The copy
    // costs one small allocation on a path that runs once.
    if (path) {
        char* owned = (char*)rt_base_alloc(strlen(path) + 1);
        strcpy(owned, path);
        free(path);
        return owned;
    }

    char* fallback = (char*)rt_base_alloc(2);
    strcpy(fallback, ".");
    return fallback;
}

static int compare_names(const void* a, const void* b) {
    return strcmp(*(const char* const*)a, *(const char* const*)b);
}

// Records source (.psm) and compiled-library (.plib) modules by stem; ignores
// everything else. A directory containing both forms still names the module
// once, which keeps package imports deterministic during toolchain development.
static void append_module_name(char*** names, int* count, int* capacity,
                               const char* filename) {
    size_t len = strlen(filename);
    if (len <= 4 || (strcmp(filename + len - 4, ".psm") != 0
                    && strcmp(filename + len - 5, ".plib") != 0)) return;

    size_t suffix = strcmp(filename + len - 4, ".psm") == 0 ? 4 : 5;
    size_t stem_len = len - suffix;
    for (int i = 0; i < *count; i++) {
        if (strlen((*names)[i]) == stem_len
            && strncmp((*names)[i], filename, stem_len) == 0) return;
    }

    if (*count == *capacity) {
        *capacity = *capacity ? *capacity * 2 : 16;
        *names = (char**)realloc(*names, (size_t)*capacity * sizeof(char*));
        if (!*names) {
            fprintf(stderr, "prismio: out of memory listing modules\n");
            exit(1);
        }
    }

    char* stem = (char*)malloc(stem_len + 1);
    memcpy(stem, filename, stem_len);
    stem[stem_len] = '\0';
    (*names)[(*count)++] = stem;
}

// The module names in `directory`, newline-separated, without the .psm suffix.
// Empty string when the directory does not exist or holds no modules -- the
// frontend reports that, because only it knows which `import` asked.
//
// **Sorted, and that is load-bearing.** This backs `import pkg.*`, so the order
// here becomes the order those modules are merged into the AST, which becomes
// the order their functions are emitted into the IR. Readdir order is a
// filesystem artefact that differs between machines and between a fresh checkout
// and a rebuilt one; taking it raw would mean two hosts building byte-different
// compilers from identical sources, breaking the fixpoint check and the seed.
char* list_modules(const char* directory) {
    char** names = NULL;
    int count = 0;
    int capacity = 0;

#ifdef _WIN32
    char pattern[1024];
    snprintf(pattern, sizeof(pattern), "%s%c*.*", directory, PRISMIO_PATH_SEP);

    WIN32_FIND_DATAA entry;
    HANDLE search = FindFirstFileA(pattern, &entry);
    if (search != INVALID_HANDLE_VALUE) {
        do {
            if (entry.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) continue;
            append_module_name(&names, &count, &capacity, entry.cFileName);
        } while (FindNextFileA(search, &entry));
        FindClose(search);
    }
#else
    DIR* dir = opendir(directory);
    if (dir) {
        struct dirent* entry;
        while ((entry = readdir(dir)) != NULL) {
            append_module_name(&names, &count, &capacity, entry->d_name);
        }
        closedir(dir);
    }
#endif

    if (count > 1) qsort(names, count, sizeof(char*), compare_names);

    size_t total = 1;
    for (int i = 0; i < count; i++) total += strlen(names[i]) + 1;

    char* result = (char*)rt_base_alloc(total);
    result[0] = '\0';
    for (int i = 0; i < count; i++) {
        if (i > 0) strcat(result, "\n");
        strcat(result, names[i]);
        free(names[i]);
    }
    free(names);
    return result;
}

char* prismio_executable_directory(void) {
#ifdef _WIN32
    char exe_path[1024];
    DWORD len = GetModuleFileNameA(NULL, exe_path, sizeof(exe_path));
    if (len > 0 && len < sizeof(exe_path)) {
        return get_directory(exe_path);
    }

    if (__argc > 0 && __argv[0] && __argv[0][0] != '\0') {
        return get_directory(__argv[0]);
    }
#elif defined(__APPLE__)
    // macOS has no /proc, so the Linux branch below silently fails there.
    char raw_path[1024];
    uint32_t size = sizeof(raw_path);
    if (_NSGetExecutablePath(raw_path, &size) == 0) {
        char resolved_path[1024];
        if (realpath(raw_path, resolved_path) != NULL) {
            return get_directory(resolved_path);
        }
        return get_directory(raw_path);
    }
#else
    char exe_path[1024];
    ssize_t len = readlink("/proc/self/exe", exe_path, sizeof(exe_path) - 1);
    if (len > 0) {
        exe_path[len] = '\0';
        return get_directory(exe_path);
    }
#endif
    return NULL;
}

char* executable_directory(void) {
    char* directory = prismio_executable_directory();
    if (directory) {
        return directory;
    }

    char* fallback = (char*)rt_base_alloc(2);
    strcpy(fallback, ".");
    return fallback;
}

char* command_quote_arg(const char* arg) {
    int len = strlen(arg);
    char* result = (char*)rt_base_alloc((len * 2) + 3);
    int out = 0;
    result[out++] = '"';
    for (int i = 0; i < len; i++) {
        if (arg[i] == '"') {
            result[out++] = '\\';
        }
        result[out++] = arg[i];
    }
    result[out++] = '"';
    result[out] = '\0';
    return result;
}

// Which host is running this compiler, not which target it is building for --
// `ir_target_triple` answers the other question. A project command that runs a
// script needs the first: the interpreter on PATH is a property of the machine,
// and on Windows it is `python` where every other platform has `python3`.
int host_is_windows(void) {
#ifdef _WIN32
    return 1;
#else
    return 0;
#endif
}

int execute_command(const char* command) {
#ifdef _WIN32
    int command_len = (int)strlen(command) + 16;
    char* wrapped = (char*)malloc(command_len);
    snprintf(wrapped, command_len, "cmd /S /C \"%s\"", command);
    int result = system(wrapped);
    free(wrapped);
    return result == 0 ? 0 : 1;
#else
    return system(command) == 0 ? 0 : 1;
#endif
}

// Subprocesses: an argument vector rather than a shell line.
//
// `execute_command` above hands a string to `system`, which is why `quoteArg`
// has to exist and why nothing can read a child's output. What follows is the
// capability `std.process` wraps as `Process`: an argv the shell never sees,
// each of the three streams inherited, piped or discarded, and a handle the
// caller can wait on or kill.
//
// **The vector is accumulated across calls, because a `List<T>` does not cross
// the FFI boundary.** Nothing in the tree passes or returns one; `list_modules`
// joins with newlines and `std.fs` splits, which is wrong for argv because an
// argument may contain any byte. So this is the shape `ir_call_begin` /
// `ir_call_arg` / the call already has in `src/ir/bridge.psm`, for the same
// reason and with the same limitation: **one spawn may be under construction at
// a time in a process.** Two threads building one concurrently interleave into
// one vector. Prismio's concurrency is isolation-based and this is documented in
// `std/process.psm`, but it is a real constraint and not an oversight.
//
// `proc_spawn_arg` copies. The boundary already made a NUL-terminated copy for a
// view (`ir_call_arg_cstr`) and frees it when the call returns, so a pointer
// kept here would dangle by the time the spawn happens.

#ifdef _WIN32
#include <fcntl.h>
#include <io.h>
#else
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <spawn.h>
#include <sys/wait.h>
#include <time.h>
extern char** environ;
#endif

// One spelling in three places -- here, `std/process.psm`, and the fixture.
// C_CODE_STYLE's rule about a constant that crosses a seam: the int is never
// re-derived, so a mode added to one list and not the others still builds.
#define PRISMIO_STDIO_INHERIT 0
#define PRISMIO_STDIO_PIPE    1
#define PRISMIO_STDIO_DISCARD 2

// What a spawn answers, written through a pointer the caller owns -- the shape
// `clock_gettime(clk, stamp)` uses.
//
// **Every field is 64-bit and that is deliberate.** It removes any question of
// padding between this declaration and `std/process.psm`'s, and the handle needs
// the width regardless: a Prismio `Int` is `i32` and a Windows `HANDLE` is a
// pointer.
typedef struct {
    int64_t handle;
    int64_t stdin_fd;
    int64_t stdout_fd;
    int64_t stderr_fd;
    int64_t error;
} PrismioSpawnOut;

static char*  g_spawn_program = NULL;
static char** g_spawn_argv = NULL;
static int    g_spawn_argc = 0;
static int    g_spawn_cap = 0;

static void spawn_builder_reset(void) {
    for (int i = 0; i < g_spawn_argc; i++) free(g_spawn_argv[i]);
    free(g_spawn_argv);
    free(g_spawn_program);
    g_spawn_program = NULL;
    g_spawn_argv = NULL;
    g_spawn_argc = 0;
    g_spawn_cap = 0;
}

// Plain `malloc` throughout the builder, not `rt_base_alloc`: none of it is
// returned to Prismio and this runtime frees all of it itself, which is the
// converse half of the allocator invariant.
static char* spawn_dup(const char* text) {
    size_t n = strlen(text) + 1;
    char* copy = (char*)malloc(n);
    if (copy) memcpy(copy, text, n);
    return copy;
}

void proc_spawn_begin(const char* program) {
    spawn_builder_reset();
    g_spawn_program = spawn_dup(program ? program : "");
}

void proc_spawn_arg(const char* argument) {
    if (!argument) return;
    if (g_spawn_argc == g_spawn_cap) {
        int grown = g_spawn_cap ? g_spawn_cap * 2 : 8;
        char** bigger = (char**)realloc(g_spawn_argv, (size_t)grown * sizeof(char*));
        if (!bigger) return;
        g_spawn_argv = bigger;
        g_spawn_cap = grown;
    }
    char* copy = spawn_dup(argument);
    if (!copy) return;
    g_spawn_argv[g_spawn_argc++] = copy;
}

// argv as `execvp` wants it: the program at 0, the accumulated arguments after
// it, NULL-terminated. Freed by the caller; the elements are the builder's and
// are not.
static char** spawn_vector(void) {
    char** vector = (char**)malloc((size_t)(g_spawn_argc + 2) * sizeof(char*));
    if (!vector) return NULL;
    vector[0] = g_spawn_program ? g_spawn_program : (char*)"";
    for (int i = 0; i < g_spawn_argc; i++) vector[i + 1] = g_spawn_argv[i];
    vector[g_spawn_argc + 1] = NULL;
    return vector;
}

#ifndef _WIN32

// One stream's plumbing. `child` is the descriptor the child should see as
// `target`; `parent` is the end this process keeps, or -1 when there is none.
//
// Returns 0, or the errno that stopped it.
static int spawn_stream(int mode, int target, int writable,
                        posix_spawn_file_actions_t* actions,
                        int* child_end, int* parent_end) {
    *child_end = -1;
    *parent_end = -1;
    if (mode == PRISMIO_STDIO_INHERIT) return 0;

    if (mode == PRISMIO_STDIO_DISCARD) {
        int null_fd = open("/dev/null", writable ? O_WRONLY : O_RDONLY);
        if (null_fd < 0) return errno;
        *child_end = null_fd;
        return posix_spawn_file_actions_adddup2(actions, null_fd, target);
    }

    int ends[2];
    if (pipe(ends) != 0) return errno;
    // A pipe the child writes hands the child `ends[1]` and keeps `ends[0]`;
    // one the child reads is the other way round.
    *child_end = writable ? ends[1] : ends[0];
    *parent_end = writable ? ends[0] : ends[1];
    // **The parent's end must not reach any child**, this one included. A spawned
    // process inherits every descriptor not marked close-on-exec, so without this
    // the child holds its own copy of the write end of its stdin, and
    // `stdin.close()` in the parent never delivers EOF: a child reading to the end
    // of its input hangs, and so does the parent reading its output. The same copy
    // leaks into every later child for as long as this one runs. `pipe2` would
    // set it atomically, and macOS does not have it.
    if (fcntl(*parent_end, F_SETFD, FD_CLOEXEC) != 0) {
        int failure = errno;
        close(ends[0]);
        close(ends[1]);
        *child_end = -1;
        *parent_end = -1;
        return failure;
    }
    return posix_spawn_file_actions_adddup2(actions, *child_end, target);
}

int proc_spawn_run(int stdin_mode, int stdout_mode, int stderr_mode,
                   PrismioSpawnOut* out) {
    if (!out) return -1;
    out->handle = -1;
    out->stdin_fd = -1;
    out->stdout_fd = -1;
    out->stderr_fd = -1;
    out->error = 0;

    posix_spawn_file_actions_t actions;
    if (posix_spawn_file_actions_init(&actions) != 0) {
        out->error = errno;
        spawn_builder_reset();
        return -1;
    }

    int child_in = -1, child_out = -1, child_err = -1;
    int parent_in = -1, parent_out = -1, parent_err = -1;
    int failure = spawn_stream(stdin_mode, 0, 0, &actions, &child_in, &parent_in);
    if (!failure) failure = spawn_stream(stdout_mode, 1, 1, &actions, &child_out, &parent_out);
    if (!failure) failure = spawn_stream(stderr_mode, 2, 1, &actions, &child_err, &parent_err);

    pid_t child = -1;
    if (!failure) {
        char** vector = spawn_vector();
        if (!vector) {
            failure = ENOMEM;
        } else {
            failure = posix_spawnp(&child, vector[0], &actions, NULL, vector, environ);
            free(vector);
        }
    }

    posix_spawn_file_actions_destroy(&actions);

    // **The child's ends close here, in every outcome.** A parent holding the
    // write end of the child's stdout pipe never sees EOF on it, so a `readAll`
    // that looks correct hangs forever.
    if (child_in >= 0) close(child_in);
    if (child_out >= 0) close(child_out);
    if (child_err >= 0) close(child_err);

    if (failure) {
        if (parent_in >= 0) close(parent_in);
        if (parent_out >= 0) close(parent_out);
        if (parent_err >= 0) close(parent_err);
        out->error = failure;
        spawn_builder_reset();
        return -1;
    }

    out->handle = (int64_t)child;
    out->stdin_fd = parent_in;
    out->stdout_fd = parent_out;
    out->stderr_fd = parent_err;
    spawn_builder_reset();
    return 0;
}

int proc_wait(int64_t handle) {
    int status = 0;
    pid_t waited;
    do {
        waited = waitpid((pid_t)handle, &status, 0);
    } while (waited < 0 && errno == EINTR);
    if (waited < 0) return -1;
    if (WIFEXITED(status)) return WEXITSTATUS(status);
    if (WIFSIGNALED(status)) return 128 + WTERMSIG(status);
    return -1;
}

int proc_kill(int64_t handle) {
    return kill((pid_t)handle, SIGKILL) == 0 ? 0 : -1;
}

int proc_exec(void) {
    char** vector = spawn_vector();
    if (!vector) return -1;
    execvp(vector[0], vector);
    // Only reached when the exec failed; the vector's elements belong to the
    // builder, so only the vector itself is this function's to free.
    free(vector);
    return -1;
}

int proc_write(int fd, const char* bytes, int length) {
    if (fd < 0 || !bytes || length < 0) return -1;
    int written = 0;
    while (written < length) {
        ssize_t n = write(fd, bytes + written, (size_t)(length - written));
        if (n < 0) {
            if (errno == EINTR) continue;
            return -1;
        }
        if (n == 0) break;
        written += (int)n;
    }
    return written;
}

int proc_close(int fd) {
    if (fd < 0) return -1;
    return close(fd) == 0 ? 0 : -1;
}

#else

// The Win32 half. Same five entry points, same meanings, three differences that
// reach the caller and are documented in `std/process.psm` rather than hidden:
// there is no real `exec`, a killed child's status is the code
// `TerminateProcess` was given, and the handle is a `HANDLE` rather than a pid.
//
// **Descriptors, not handles, cross into Prismio.** `_open_osfhandle` wraps the
// parent's pipe end in a CRT `int`, so `Stream` is one type on both platforms and
// `proc_read_all` is one function.

// One argument, quoted the way `CommandLineToArgvW` unquotes.
//
// Not `command_quote_arg`: that one escapes a quote and nothing else, which is
// right for `cmd /C` and wrong here. A backslash is literal *except* in the run
// immediately before a quote, where each one must be doubled -- so `a\` passed
// through the simple quoter becomes `"a\"` and swallows the closing quote.
static void spawn_quote_into(char* out, int* at, const char* argument) {
    out[(*at)++] = '"';
    for (int i = 0; argument[i] != '\0'; ) {
        int slashes = 0;
        while (argument[i] == '\\') { slashes++; i++; }
        if (argument[i] == '\0') {
            for (int s = 0; s < slashes * 2; s++) out[(*at)++] = '\\';
            break;
        }
        if (argument[i] == '"') {
            for (int s = 0; s < slashes * 2 + 1; s++) out[(*at)++] = '\\';
        } else {
            for (int s = 0; s < slashes; s++) out[(*at)++] = '\\';
        }
        out[(*at)++] = argument[i++];
    }
    out[(*at)++] = '"';
}

// The whole command line. Every argument can at worst double and gain two
// quotes, so `2n + 3` per element bounds it.
static char* spawn_command_line(void) {
    size_t bound = 1;
    const char* program = g_spawn_program ? g_spawn_program : "";
    bound += strlen(program) * 2 + 3;
    for (int i = 0; i < g_spawn_argc; i++) bound += strlen(g_spawn_argv[i]) * 2 + 4;

    char* line = (char*)malloc(bound);
    if (!line) return NULL;
    int at = 0;
    spawn_quote_into(line, &at, program);
    for (int i = 0; i < g_spawn_argc; i++) {
        line[at++] = ' ';
        spawn_quote_into(line, &at, g_spawn_argv[i]);
    }
    line[at] = '\0';
    return line;
}

static int spawn_stream_win(int mode, DWORD standard, int writable,
                            HANDLE* child_end, HANDLE* parent_end) {
    *child_end = INVALID_HANDLE_VALUE;
    *parent_end = INVALID_HANDLE_VALUE;

    SECURITY_ATTRIBUTES inheritable;
    inheritable.nLength = sizeof(inheritable);
    inheritable.lpSecurityDescriptor = NULL;
    inheritable.bInheritHandle = TRUE;

    if (mode == PRISMIO_STDIO_INHERIT) {
        *child_end = GetStdHandle(standard);
        return 0;
    }
    if (mode == PRISMIO_STDIO_DISCARD) {
        HANDLE null_handle = CreateFileA("NUL", writable ? GENERIC_WRITE : GENERIC_READ,
                                         FILE_SHARE_READ | FILE_SHARE_WRITE, &inheritable,
                                         OPEN_EXISTING, 0, NULL);
        if (null_handle == INVALID_HANDLE_VALUE) return (int)GetLastError();
        *child_end = null_handle;
        return 0;
    }

    HANDLE read_end, write_end;
    if (!CreatePipe(&read_end, &write_end, &inheritable, 0)) return (int)GetLastError();
    // Only the child's end may be inherited. Without this the parent's end is
    // duplicated into the child too, and the read never sees EOF.
    HANDLE keep = writable ? read_end : write_end;
    HANDLE give = writable ? write_end : read_end;
    if (!SetHandleInformation(keep, HANDLE_FLAG_INHERIT, 0)) {
        CloseHandle(read_end);
        CloseHandle(write_end);
        return (int)GetLastError();
    }
    *child_end = give;
    *parent_end = keep;
    return 0;
}

static int64_t spawn_descriptor(HANDLE handle, int writable) {
    if (handle == INVALID_HANDLE_VALUE) return -1;
    int fd = _open_osfhandle((intptr_t)handle, writable ? 0 : _O_RDONLY);
    if (fd < 0) { CloseHandle(handle); return -1; }
    return (int64_t)fd;
}

int proc_spawn_run(int stdin_mode, int stdout_mode, int stderr_mode,
                   PrismioSpawnOut* out) {
    if (!out) return -1;
    out->handle = -1;
    out->stdin_fd = -1;
    out->stdout_fd = -1;
    out->stderr_fd = -1;
    out->error = 0;

    HANDLE child_in, child_out, child_err;
    HANDLE parent_in, parent_out, parent_err;
    int failure = spawn_stream_win(stdin_mode, STD_INPUT_HANDLE, 0, &child_in, &parent_in);
    if (!failure) failure = spawn_stream_win(stdout_mode, STD_OUTPUT_HANDLE, 1, &child_out, &parent_out);
    if (!failure) failure = spawn_stream_win(stderr_mode, STD_ERROR_HANDLE, 1, &child_err, &parent_err);

    char* line = NULL;
    PROCESS_INFORMATION info;
    memset(&info, 0, sizeof(info));
    if (!failure) {
        line = spawn_command_line();
        if (!line) failure = (int)ERROR_NOT_ENOUGH_MEMORY;
    }
    if (!failure) {
        STARTUPINFOA start;
        memset(&start, 0, sizeof(start));
        start.cb = sizeof(start);
        start.dwFlags = STARTF_USESTDHANDLES;
        start.hStdInput = child_in;
        start.hStdOutput = child_out;
        start.hStdError = child_err;
        if (!CreateProcessA(NULL, line, NULL, NULL, TRUE, 0, NULL, NULL, &start, &info)) {
            failure = (int)GetLastError();
        }
    }
    free(line);

    // The child's ends close here in every outcome, for the reason the POSIX
    // half gives: a parent still holding the write end never sees EOF.
    if (stdin_mode != PRISMIO_STDIO_INHERIT && child_in != INVALID_HANDLE_VALUE) CloseHandle(child_in);
    if (stdout_mode != PRISMIO_STDIO_INHERIT && child_out != INVALID_HANDLE_VALUE) CloseHandle(child_out);
    if (stderr_mode != PRISMIO_STDIO_INHERIT && child_err != INVALID_HANDLE_VALUE) CloseHandle(child_err);

    if (failure) {
        if (parent_in != INVALID_HANDLE_VALUE) CloseHandle(parent_in);
        if (parent_out != INVALID_HANDLE_VALUE) CloseHandle(parent_out);
        if (parent_err != INVALID_HANDLE_VALUE) CloseHandle(parent_err);
        out->error = failure;
        spawn_builder_reset();
        return -1;
    }

    CloseHandle(info.hThread);
    out->handle = (int64_t)(intptr_t)info.hProcess;
    out->stdin_fd = spawn_descriptor(parent_in, 1);
    out->stdout_fd = spawn_descriptor(parent_out, 0);
    out->stderr_fd = spawn_descriptor(parent_err, 0);
    spawn_builder_reset();
    return 0;
}

int proc_wait(int64_t handle) {
    HANDLE process = (HANDLE)(intptr_t)handle;
    if (WaitForSingleObject(process, INFINITE) != WAIT_OBJECT_0) return -1;
    DWORD status = 0;
    if (!GetExitCodeProcess(process, &status)) { CloseHandle(process); return -1; }
    CloseHandle(process);
    return (int)status;
}

int proc_kill(int64_t handle) {
    return TerminateProcess((HANDLE)(intptr_t)handle, 1) ? 0 : -1;
}

// **Windows has no `execvp`.** `_execvp` spawns a new process and exits this
// one, so a parent waiting on the original sees it finish and the pid changes.
// That difference is observable and is documented rather than papered over.
int proc_exec(void) {
    char** vector = spawn_vector();
    if (!vector) return -1;
    _execvp(vector[0], (const char* const*)vector);
    free(vector);
    return -1;
}

int proc_write(int fd, const char* bytes, int length) {
    if (fd < 0 || !bytes || length < 0) return -1;
    int written = 0;
    while (written < length) {
        int n = _write(fd, bytes + written, (unsigned int)(length - written));
        if (n < 0) return -1;
        if (n == 0) break;
        written += n;
    }
    return written;
}

int proc_close(int fd) {
    if (fd < 0) return -1;
    return _close(fd) == 0 ? 0 : -1;
}

#endif

// The environment, and this process's id -- what `process.env`, `setEnv`,
// `removeEnv` and `pid` read.
//
// Presence and value are two calls because the value crosses as an owned String,
// and an owned String has no null: `proc_env_get` answers "" for an unset name,
// and std.process asks `proc_env_has` first to tell that from an empty value.
//
// The C library's environment is process-global and not thread-safe on any
// platform: a `setEnv` racing a read on another task is undefined, as it is in C.
int proc_env_has(const char* name) {
    return (name && *name && getenv(name) != NULL) ? 1 : 0;
}

// `rt_base_alloc` on every path, the empty one included: a literal return would
// make the whole function's result unowned (see `proc_read_all` below).
char* proc_env_get(const char* name) {
    const char* value = (name && *name) ? getenv(name) : NULL;
    if (!value) value = "";
    size_t length = strlen(value);
    char* out = (char*)rt_base_alloc(length + 1);
    if (!out) return NULL;
    memcpy(out, value, length + 1);
    return out;
}

// 1 on success. A name that is empty or contains `=` is refused, as setenv
// refuses it, on Windows too, where `_putenv_s` would read `A=B` as a name.
int proc_env_set(const char* name, const char* value) {
    if (!name || !*name || strchr(name, '=') || !value) return 0;
#ifdef _WIN32
    return _putenv_s(name, value) == 0 ? 1 : 0;
#else
    return setenv(name, value, 1) == 0 ? 1 : 0;
#endif
}

// 1 when the name is unset afterwards, whether or not it was set before.
// Windows spells removal as setting the empty value.
int proc_env_remove(const char* name) {
    if (!name || !*name || strchr(name, '=')) return 0;
#ifdef _WIN32
    return _putenv_s(name, "") == 0 ? 1 : 0;
#else
    return unsetenv(name) == 0 ? 1 : 0;
#endif
}

int proc_pid(void) {
#ifdef _WIN32
    return (int)_getpid();
#else
    return (int)getpid();
#endif
}

// Everything the child wrote, as a String the caller owns.
//
// `rt_base_alloc`, because this crosses back into Prismio and codegen emits a
// release for it. **Never a literal on any path**, including the empty and the
// error one: a static return contributes no allocation site and makes the whole
// function's result unowned, so the paths that did allocate leak.
char* proc_read_all(int fd) {
    size_t capacity = 4096;
    size_t filled = 0;
    char* buffer = (char*)rt_base_alloc(capacity);
    if (!buffer) return NULL;

    if (fd >= 0) {
        for (;;) {
            if (filled + 1 >= capacity) {
                size_t grown = capacity * 2;
                char* bigger = (char*)rt_base_realloc(buffer, grown);
                if (!bigger) { rt_free(buffer); return NULL; }
                buffer = bigger;
                capacity = grown;
            }
#ifdef _WIN32
            int n = _read(fd, buffer + filled, (unsigned int)(capacity - filled - 1));
#else
            ssize_t n = read(fd, buffer + filled, capacity - filled - 1);
            if (n < 0 && errno == EINTR) continue;
#endif
            if (n <= 0) break;
            filled += (size_t)n;
        }
    }
    buffer[filled] = '\0';
    return buffer;
}

// This process's standard input, read through one buffer for the whole process:
// what `stdin.readLine`, `stdin.lines` and `stdin.readAll` in std/io.psm read.
//
// **One `read` per buffer, not per line.** A line reader that asked the kernel
// for each line would make a filter slower than `cat`; this one finds the line
// in memory with `memchr` and copies it out, and goes back to the descriptor
// only when the buffer holds no complete line. The buffer grows to fit a line
// longer than it, so a line is never split.
//
// A pending line is `[io_stdin_start, io_stdin_line_end)`, found by
// `io_stdin_has_line` and handed out by `io_stdin_take_line`. Two calls because
// the iterator protocol asks "is there another?" and "give it to me" separately,
// and because an owned String has no null to mean end of input.
//
// The buffer is internal and freed by nothing, so it is plain `malloc`: only the
// line copies cross into Prismio, and those come from `rt_base_alloc`.
//
// **One reader.** The state is process-global and unlocked, as C's `stdin` is
// under `getc_unlocked`: two tasks reading lines concurrently is undefined.
// Reading descriptor 0 directly (`Stream { descriptor: 0 }`) bypasses the buffer
// and skips whatever it already holds.
#define IO_STDIN_CHUNK 65536

static char*  io_stdin_buffer;
static size_t io_stdin_capacity;
static size_t io_stdin_start;
static size_t io_stdin_end;
static size_t io_stdin_line_end;
static size_t io_stdin_next;
static int    io_stdin_pending;
static int    io_stdin_eof;

// Moves the unread bytes to the front, makes room for at least one chunk, and
// reads once. Answers the bytes read; 0 once input has ended, and on an error or
// a failed allocation, which a reader can do nothing with but stop.
static size_t io_stdin_fill(void) {
    if (io_stdin_eof) return 0;
    size_t unread = io_stdin_end - io_stdin_start;
    if (io_stdin_start > 0) {
        memmove(io_stdin_buffer, io_stdin_buffer + io_stdin_start, unread);
        io_stdin_start = 0;
        io_stdin_end = unread;
    }
    if (io_stdin_capacity - io_stdin_end < IO_STDIN_CHUNK) {
        size_t grown = io_stdin_capacity ? io_stdin_capacity * 2 : IO_STDIN_CHUNK;
        while (grown - io_stdin_end < IO_STDIN_CHUNK) grown *= 2;
        char* bigger = (char*)realloc(io_stdin_buffer, grown);
        if (!bigger) { io_stdin_eof = 1; return 0; }
        io_stdin_buffer = bigger;
        io_stdin_capacity = grown;
    }
    for (;;) {
#ifdef _WIN32
        int n = _read(0, io_stdin_buffer + io_stdin_end,
                      (unsigned int)(io_stdin_capacity - io_stdin_end));
#else
        ssize_t n = read(0, io_stdin_buffer + io_stdin_end,
                         io_stdin_capacity - io_stdin_end);
        if (n < 0 && errno == EINTR) continue;
#endif
        if (n <= 0) { io_stdin_eof = 1; return 0; }
        io_stdin_end += (size_t)n;
        return (size_t)n;
    }
}

// 1 when a line is pending, reading as much as it takes to find one; 0 at the
// end of input. A last line without a terminator is still a line, and an empty
// input has none. The terminator is `\n` or `\r\n`, and is not part of the line.
int io_stdin_has_line(void) {
    if (io_stdin_pending) return 1;
    size_t scanned = 0;
    for (;;) {
        char* data = io_stdin_buffer + io_stdin_start;
        char* newline = io_stdin_end > io_stdin_start + scanned
            ? (char*)memchr(data + scanned, '\n', io_stdin_end - io_stdin_start - scanned)
            : NULL;
        if (newline) {
            io_stdin_line_end = (size_t)(newline - io_stdin_buffer);
            io_stdin_next = io_stdin_line_end + 1;
            if (io_stdin_line_end > io_stdin_start &&
                io_stdin_buffer[io_stdin_line_end - 1] == '\r') {
                io_stdin_line_end--;
            }
            io_stdin_pending = 1;
            return 1;
        }
        scanned = io_stdin_end - io_stdin_start;
        if (io_stdin_fill() == 0) break;
    }
    if (io_stdin_end == io_stdin_start) return 0;
    io_stdin_line_end = io_stdin_end;
    io_stdin_next = io_stdin_end;
    io_stdin_pending = 1;
    return 1;
}

// The pending line as a String the caller owns, found first if need be, and ""
// at the end of input -- allocated like any other line, so every path's result
// is owned.
char* io_stdin_take_line(void) {
    size_t length = 0;
    if (io_stdin_has_line()) length = io_stdin_line_end - io_stdin_start;
    char* out = (char*)rt_base_alloc(length + 1);
    if (!out) return NULL;
    if (length > 0) memcpy(out, io_stdin_buffer + io_stdin_start, length);
    out[length] = '\0';
    if (io_stdin_pending) {
        io_stdin_start = io_stdin_next;
        io_stdin_pending = 0;
    }
    return out;
}

// Everything not yet handed out, to the end of input. A line found by
// `io_stdin_has_line` and not yet taken is part of it.
char* io_stdin_read_all(void) {
    io_stdin_pending = 0;
    while (io_stdin_fill() > 0) {}
    size_t length = io_stdin_end - io_stdin_start;
    char* out = (char*)rt_base_alloc(length + 1);
    if (!out) return NULL;
    if (length > 0) memcpy(out, io_stdin_buffer + io_stdin_start, length);
    out[length] = '\0';
    io_stdin_start = io_stdin_end;
    return out;
}

// The clocks and the sleep behind std/time.psm. Nanoseconds as `int64_t`
// everywhere: 292 years either side of the origin, and a Prismio `Int` is 32
// bits, so nothing narrower holds a timestamp.
//
// **Monotonic is the clock to measure with.** It never steps backwards when the
// wall clock is set, and its origin is unspecified (boot, on Linux) -- which is
// why std.time hands out an `Instant` to subtract rather than a number to read.
//
// Windows has no `clock_gettime`. `QueryPerformanceCounter` counts at a
// frequency fixed at boot, and the conversion splits the count into whole
// seconds and a remainder so `count * 1e9` cannot overflow at a 10 MHz
// frequency after 29 years of uptime. The wall clock is a FILETIME: 100 ns
// ticks since 1601.
int64_t time_monotonic_nanos(void) {
#ifdef _WIN32
    static LARGE_INTEGER frequency;
    if (frequency.QuadPart == 0) QueryPerformanceFrequency(&frequency);
    LARGE_INTEGER count;
    QueryPerformanceCounter(&count);
    int64_t seconds = count.QuadPart / frequency.QuadPart;
    int64_t rest = count.QuadPart % frequency.QuadPart;
    return seconds * 1000000000LL + rest * 1000000000LL / frequency.QuadPart;
#else
    struct timespec now;
    clock_gettime(CLOCK_MONOTONIC, &now);
    return (int64_t)now.tv_sec * 1000000000LL + (int64_t)now.tv_nsec;
#endif
}

int64_t time_unix_nanos(void) {
#ifdef _WIN32
    FILETIME now;
    GetSystemTimePreciseAsFileTime(&now);
    int64_t ticks = ((int64_t)now.dwHighDateTime << 32) | (int64_t)now.dwLowDateTime;
    return (ticks - 116444736000000000LL) * 100;
#else
    struct timespec now;
    clock_gettime(CLOCK_REALTIME, &now);
    return (int64_t)now.tv_sec * 1000000000LL + (int64_t)now.tv_nsec;
#endif
}

// Sleeps at least `nanos`, and returns at once for zero or less. A signal that
// interrupts `nanosleep` resumes it for what is left, so a program with a
// signal handler still sleeps as long as it asked. `Sleep` takes milliseconds,
// rounded up so a short sleep is not a zero one.
void time_sleep_nanos(int64_t nanos) {
    if (nanos <= 0) return;
#ifdef _WIN32
    int64_t millis = (nanos + 999999) / 1000000;
    while (millis > 0) {
        DWORD step = millis > 0x7fffffffLL ? 0x7fffffffUL : (DWORD)millis;
        Sleep(step);
        millis -= (int64_t)step;
    }
#else
    struct timespec want = { (time_t)(nanos / 1000000000LL), (long)(nanos % 1000000000LL) };
    struct timespec left;
    while (nanosleep(&want, &left) != 0 && errno == EINTR) want = left;
#endif
}

//
// REQUIREMENTS 15, and the shape is fixed by SPEC 11 item 10: *isolation*
// concurrency, no shared mutable heap, no atomic counts on the common path.
// Everything here exists to make that sentence enforceable rather than
// aspirational -- and to give AIF's `T` domain (INFERENCE 2.3) something to
// attach to, which it has never had.
//
// Two primitives, and the split between them is the whole design:
//
//   * A **task** takes ownership of its arguments. `spawn f(x)` moves `x` in;
//     the move checker makes the parent's binding dead, so no second owning
//     reference exists and INFERENCE's T-SPAWN-MOVE lands the value at
//     `Transferred` rather than `CrossThread`. Transferred is the tier
//     isolation exists to produce: the spawn is itself a synchronisation edge,
//     so a release/acquire pair there is sufficient and the *count stays
//     non-atomic*. That is the sentence SPEC 11 item 10 is protecting.
//   * A **channel** carries messages between tasks. The message is moved, not
//     shared -- send hands the pointer over and the sender must not keep it.
//     The channel is the one object both tasks hold at once, which is exactly
//     why it is a runtime object with its own lock rather than a Prismio heap
//     value: nothing the solver tiers is shared, so nothing the solver tiers
//     needs an atomic count.
//
// The arity ceiling is three, and it is a real ceiling rather than a variadic
// call through a mistyped pointer. Calling a one-argument function through a
// three-argument function pointer happens to work on every ABI anyone ships and
// is still undefined; the switch below costs four lines and is defined.

// The threading primitives moved to prismio_runtime.h when `--verify`'s ledger
// became the second user; see the note there.

// A task's result comes back through `join`, so the runtime has to call the
// spawned function through a pointer of its *real* type. Twelve typedefs --
// three return kinds by four arities -- rather than one signature and a cast.
//
// The cast would work on every ABI anyone ships and is still undefined, and
// with return values it stops being merely formal: an i32-returning function
// called through a pointer declared to return void* leaves the upper half of
// the register undefined on exactly the 64-bit targets this compiles for.
#define PRISMIO_RK_INT  0
#define PRISMIO_RK_PTR  1
#define PRISMIO_RK_VOID 2

typedef int   (*PrismioFnI0)(void);
typedef int   (*PrismioFnI1)(void*);
typedef int   (*PrismioFnI2)(void*, void*);
typedef int   (*PrismioFnI3)(void*, void*, void*);
typedef void* (*PrismioFnP0)(void);
typedef void* (*PrismioFnP1)(void*);
typedef void* (*PrismioFnP2)(void*, void*);
typedef void* (*PrismioFnP3)(void*, void*, void*);
typedef void  (*PrismioFnV0)(void);
typedef void  (*PrismioFnV1)(void*);
typedef void  (*PrismioFnV2)(void*, void*);
typedef void  (*PrismioFnV3)(void*, void*, void*);

typedef struct {
    PRISMIO_THREAD_T thread;
    void* fn;
    int rkind;
    int nargs;
    void* a[3];
    int result_i;
    void* result_p;
    int joined;
    int started;
} PrismioTask;

static void prismio_task_invoke(PrismioTask* t) {
    void** a = t->a;
    if (t->rkind == PRISMIO_RK_PTR) {
        switch (t->nargs) {
            case 0:  t->result_p = ((PrismioFnP0)t->fn)(); return;
            case 1:  t->result_p = ((PrismioFnP1)t->fn)(a[0]); return;
            case 2:  t->result_p = ((PrismioFnP2)t->fn)(a[0], a[1]); return;
            default: t->result_p = ((PrismioFnP3)t->fn)(a[0], a[1], a[2]); return;
        }
    }
    if (t->rkind == PRISMIO_RK_VOID) {
        switch (t->nargs) {
            case 0:  ((PrismioFnV0)t->fn)(); return;
            case 1:  ((PrismioFnV1)t->fn)(a[0]); return;
            case 2:  ((PrismioFnV2)t->fn)(a[0], a[1]); return;
            default: ((PrismioFnV3)t->fn)(a[0], a[1], a[2]); return;
        }
    }
    switch (t->nargs) {
        case 0:  t->result_i = ((PrismioFnI0)t->fn)(); return;
        case 1:  t->result_i = ((PrismioFnI1)t->fn)(a[0]); return;
        case 2:  t->result_i = ((PrismioFnI2)t->fn)(a[0], a[1]); return;
        default: t->result_i = ((PrismioFnI3)t->fn)(a[0], a[1], a[2]); return;
    }
}

#ifdef _WIN32
static DWORD WINAPI prismio_task_entry(LPVOID arg) {
    prismio_memory_thread_enter();
    prismio_task_invoke((PrismioTask*)arg);
    prismio_memory_thread_cleanup();
    return 0;
}
#else
static void* prismio_task_entry(void* arg) {
    prismio_memory_thread_enter();
    prismio_task_invoke((PrismioTask*)arg);
    prismio_memory_thread_cleanup();
    return NULL;
}
#endif

// Emitted by generate_expression for a SPAWN_EXPR. Returns an opaque handle;
// the language types it `Task<R>`, where R is what `join` yields.
//
// A task that cannot be started runs **inline** rather than failing. SPEC 1's
// invariant is about inference, but the same principle applies with more force
// here: a program that silently does not run its work is worse than one that
// runs it on the calling thread. The result is identical either way, because
// isolation means the task shares nothing with its parent -- which is the one
// property that makes a serial fallback observationally equivalent.
void* prismio_task_spawn(void* fn, int rkind, int nargs, void* a0, void* a1, void* a2) {
    PrismioTask* t = (PrismioTask*)calloc(1, sizeof(PrismioTask));
    if (!t) return NULL;
    t->fn = fn;
    t->rkind = rkind;
    t->nargs = (nargs < 0) ? 0 : (nargs > 3 ? 3 : nargs);
    t->a[0] = a0;
    t->a[1] = a1;
    t->a[2] = a2;

    // Publish the switch before the OS can run the new thread. Programs that
    // never spawn retain the direct process-local arena fast path.
    prismio_memory_threads_enable();

#ifdef _WIN32
    t->thread = CreateThread(NULL, 0, prismio_task_entry, t, 0, NULL);
    t->started = (t->thread != NULL);
#else
    t->started = (pthread_create(&t->thread, NULL, prismio_task_entry, t) == 0);
#endif

    if (!t->started) {
        prismio_task_invoke(t);
    }
    return t;
}

// The wait itself, shared by the three typed accessors below. Split out because
// joining twice must not wait on a dead thread: the language does not stop a
// program from doing it -- a handle is copyable -- so the runtime has to.
static PrismioTask* prismio_task_await(void* handle) {
    PrismioTask* t = (PrismioTask*)handle;
    if (!t) return NULL;
    if (!t->joined) {
        if (t->started) {
#ifdef _WIN32
            WaitForSingleObject(t->thread, INFINITE);
            CloseHandle(t->thread);
#else
            pthread_join(t->thread, NULL);
#endif
        }
        t->joined = 1;
    }
    return t;
}

// Three accessors rather than one returning a word the caller reinterprets.
// Which one is emitted is decided by the callee's declared return type, which
// the compiler knows statically -- so the type the task produced and the type
// read back out are the same by construction rather than by convention.
int prismio_task_join(void* handle) {
    PrismioTask* t = prismio_task_await(handle);
    return t ? t->result_i : 0;
}

void* prismio_task_join_p(void* handle) {
    PrismioTask* t = prismio_task_await(handle);
    return t ? t->result_p : NULL;
}

void prismio_task_join_v(void* handle) {
    prismio_task_await(handle);
}

// The join is the synchronisation edge, so the handle is dead the moment it
// returns and the caller has nothing left to free by hand.
void prismio_task_release(void* handle) {
    if (handle) free(handle);
}

typedef struct {
    PRISMIO_MUTEX_T lock;
    PRISMIO_COND_T not_empty;
    PRISMIO_COND_T not_full;
    void** slots;
    int cap, head, len;
    int closed;
} PrismioChan;

void* chan_new(int capacity) {
    if (capacity < 1) capacity = 1;
    PrismioChan* c = (PrismioChan*)calloc(1, sizeof(PrismioChan));
    if (!c) return NULL;
    c->slots = (void**)calloc((size_t)capacity, sizeof(void*));
    if (!c->slots) { free(c); return NULL; }
    c->cap = capacity;
    PRISMIO_MUTEX_INIT(&c->lock);
    PRISMIO_COND_INIT(&c->not_empty);
    PRISMIO_COND_INIT(&c->not_full);
    return c;
}

// Blocks while the channel is full. Sending on a closed channel drops the
// message and reports 0; the alternative is aborting the program, and a closed
// channel is a race the receiver won rather than a defect in the sender.
int chan_send(void* handle, void* msg) {
    PrismioChan* c = (PrismioChan*)handle;
    if (!c) return 0;
    PRISMIO_MUTEX_LOCK(&c->lock);
    while (c->len == c->cap && !c->closed) {
        PRISMIO_COND_WAIT(&c->not_full, &c->lock);
    }
    if (c->closed) {
        PRISMIO_MUTEX_UNLOCK(&c->lock);
        return 0;
    }
    c->slots[(c->head + c->len) % c->cap] = msg;
    c->len++;
    PRISMIO_COND_SIGNAL(&c->not_empty);
    PRISMIO_MUTEX_UNLOCK(&c->lock);
    return 1;
}

// Blocks until a message arrives. Returns NULL once the channel is closed and
// drained, which is how a receiving loop terminates without a sentinel value.
void* chan_recv(void* handle) {
    PrismioChan* c = (PrismioChan*)handle;
    if (!c) return NULL;
    PRISMIO_MUTEX_LOCK(&c->lock);
    while (c->len == 0 && !c->closed) {
        PRISMIO_COND_WAIT(&c->not_empty, &c->lock);
    }
    if (c->len == 0) {
        PRISMIO_MUTEX_UNLOCK(&c->lock);
        return NULL;
    }
    void* msg = c->slots[c->head];
    c->head = (c->head + 1) % c->cap;
    c->len--;
    PRISMIO_COND_SIGNAL(&c->not_full);
    PRISMIO_MUTEX_UNLOCK(&c->lock);
    return msg;
}

// Wakes every blocked party. Both waits above re-test `closed`, so a broadcast
// is enough and no waiter can be left holding the old predicate.
void chan_close(void* handle) {
    PrismioChan* c = (PrismioChan*)handle;
    if (!c) return;
    PRISMIO_MUTEX_LOCK(&c->lock);
    c->closed = 1;
    PRISMIO_COND_BROADCAST(&c->not_empty);
    PRISMIO_COND_BROADCAST(&c->not_full);
    PRISMIO_MUTEX_UNLOCK(&c->lock);
}

// SPEC 11 item 10, and this function exists *because* of its second sentence:
// "creating a second owning reference SHALL be a syntactically identifiable
// event." A channel is the one object two tasks are supposed to hold at once,
// and every handle the language can name is affine -- so without an explicit
// duplication there is no way to get one into a task and keep one in the
// parent, and `spawn producer(c)` simply moves the channel away.
//
// So the duplication is spelled out loud. `chan_share` is the event, it is
// visible at the call site, and it is what AIF's aliasing module sees when it
// decides the endpoint is `Shared` rather than `Unique` -- which is what puts
// anything reachable from it at CrossThread, and therefore on an atomic count.
// The alternative, making channel handles quietly copyable, would have bought
// the same programs and lost the only place the analysis could have noticed.
//
// The pointer is returned as-is rather than reference-counted. The contract is
// the one the corpus already follows and the one the join edge makes checkable:
// the creator closes, joins every task it shared with, then frees. A count here
// would have to be atomic, which is the tax this whole design exists to avoid
// paying on anything but the shared object itself.
void* chan_share(void* handle) {
    return handle;
}

int chan_len(void* handle) {
    PrismioChan* c = (PrismioChan*)handle;
    if (!c) return 0;
    PRISMIO_MUTEX_LOCK(&c->lock);
    int n = c->len;
    PRISMIO_MUTEX_UNLOCK(&c->lock);
    return n;
}

// Freeing a channel someone is still blocked on is a program defect this cannot
// detect. Every caller in the corpus closes, joins, then frees -- the join is
// what makes the free safe, and it is the same edge that makes the counts
// non-atomic.
void chan_free(void* handle) {
    PrismioChan* c = (PrismioChan*)handle;
    if (!c) return;
    PRISMIO_MUTEX_DESTROY(&c->lock);
    PRISMIO_COND_DESTROY(&c->not_empty);
    PRISMIO_COND_DESTROY(&c->not_full);
    free(c->slots);
    free(c);
}

// std.term's `colorEnabled`: whether text written to descriptor `fd` (1 or 2)
// should carry ANSI styling. No, when NO_COLOR is set to anything
// (no-color.org), when TERM is `dumb`, and when the descriptor is not a
// terminal -- a pipe or a file would keep the escape bytes as text.
//
// On Windows a console is a terminal but may not interpret the sequences:
// conhost does so only once ENABLE_VIRTUAL_TERMINAL_PROCESSING is on. Asking is
// the moment to turn it on, so a program that checks before styling gets colour
// in a legacy console too, and one where the mode cannot be set gets a no.
#if defined(_WIN32) && !defined(ENABLE_VIRTUAL_TERMINAL_PROCESSING)
#define ENABLE_VIRTUAL_TERMINAL_PROCESSING 0x0004
#endif

int prismio_rt_color_supported(int fd) {
    const char* no_color = getenv("NO_COLOR");
    if (no_color && no_color[0]) return 0;
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

// The seed's three answers
//
// bootstrap/prismio-seed.ll carries no triple, so it can be compiled on any
// host, and three things libc spells per platform cannot be written into it:
// errno's accessor (`__error`, `__errno_location`, `_errno`), the console write
// (`write`, `_write`, with different word sizes) and EAGAIN (35 on Darwin, 11
// elsewhere). A compiler emitting the seed (PRISMIO_SEED_IR, set by
// tools/refresh_seed.*) calls these instead; see errno_location_symbol in
// llvm-api-backend.c. Nothing else calls them, and a program's own build names
// libc directly, so they cost an ordinary program nothing.
#include <errno.h>

int* rt_seed_errno_location(void) { return &errno; }

int rt_seed_errno_again(void) { return EAGAIN; }

int rt_seed_console_write(int fd, const char* bytes, int count) {
#ifdef _WIN32
    return _write(fd, bytes, (unsigned int)count);
#else
    return (int)write(fd, bytes, (size_t)count);
#endif
}
