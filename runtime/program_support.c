// Program support -- the runtime half of the former driver.c.
//
// Everything here is callable by a compiled Prismio program and belongs in
// runtime.lib / runtime.a. It must not depend on llc, clang, or anything else to
// do with *producing* a program; that all lives in build_driver.c (backend.lib).

#include "prismio_platform.h"
#include "prismio_runtime.h"

// Defined by generated code, not by this file: generate_module() in src/ir.psm
// emits them as module-level globals and generate_function() stores main's real
// argc/argv into them in the entry prologue. Reading them here is what makes
// cli_arg()/cli_arg_count() behave the same on Windows, Linux and macOS -- the
// previous version read the Windows-only CRT globals __argc/__argv and returned
// nothing at all anywhere else.
extern int prismio_argc;
extern char** prismio_argv;

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

// Records `filename` as a module name, minus its .psm suffix; ignores anything
// else. The suffix is re-checked here rather than trusted to the Win32 search
// pattern, which also matches 8.3 short names and would let through a file whose
// real extension is longer.
static void append_module_name(char*** names, int* count, int* capacity,
                               const char* filename) {
    size_t len = strlen(filename);
    if (len <= 4 || strcmp(filename + len - 4, ".psm") != 0) return;

    if (*count == *capacity) {
        *capacity = *capacity ? *capacity * 2 : 16;
        *names = (char**)realloc(*names, (size_t)*capacity * sizeof(char*));
        if (!*names) {
            fprintf(stderr, "prismio: out of memory listing modules\n");
            exit(1);
        }
    }

    char* stem = (char*)malloc(len - 3);
    memcpy(stem, filename, len - 4);
    stem[len - 4] = '\0';
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
    snprintf(pattern, sizeof(pattern), "%s%c*.psm", directory, PRISMIO_PATH_SEP);

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

int cli_arg_count(void) {
    return prismio_argc;
}

char* cli_arg(int index) {
    if (index < 0 || index >= prismio_argc || prismio_argv == NULL) {
        return "";
    }
    return prismio_argv[index];
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
    prismio_task_invoke((PrismioTask*)arg);
    return 0;
}
#else
static void* prismio_task_entry(void* arg) {
    prismio_task_invoke((PrismioTask*)arg);
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
