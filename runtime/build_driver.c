// Build orchestration -- the compiler half of the former driver.c.
//
// Everything here exists to *produce* an executable: locating the toolchain
// sources, naming temporary files, and driving llc and clang. A compiled Prismio
// program never calls any of it, so this translation unit is linked into the
// compiler alongside llvm-api-backend.c, and never into runtime bitcode.
//
// It does depend on the runtime half (prismio_runtime.h) for plain file and path
// helpers. That direction is deliberate and one-way: backend -> runtime.

// `nftw` and `FTW_DEPTH`/`FTW_PHYS`/`FTW_DP` are X/Open, which glibc hides under
// its default feature set -- CI's Linux bootstrap failed here with the names
// undeclared. `_DEFAULT_SOURCE` keeps everything the file already relied on, and
// has to be said again because defining `_XOPEN_SOURCE` alone turns it off. Both
// precede the first system header, which prismio_platform.h includes. macOS and
// Windows declare what they have without either.
#ifdef __linux__
#define _DEFAULT_SOURCE 1
#define _XOPEN_SOURCE 700
#endif

#include "prismio_platform.h"
#include "prismio_runtime.h"
#include <time.h>

// The terminal's progress line, owned by diagnostics.c. A build step reports
// the phase it starts, and anything that writes to the terminal clears the
// line first -- a failed tool's log, or the program `run` hands the terminal to.
void diag_progress(const char* phase);
void diag_progress_clear(void);
#include <errno.h>
#ifndef _WIN32
#include <ftw.h>
#include <sys/wait.h>
#endif

// Generated code stores the process arguments here before it enters Prismio
// `main`. Forwarding uses the original vector directly, so quoting cannot change
// an argument and the hosted command keeps the caller's exact CLI contract.
extern int prismio_argc;
extern char** prismio_argv;

// The runtime's sources: what an installed runtime's bitcode is built from, and
// so what `runtime-hash` hashes to tell whether lib/ matches a checkout.
//
// Only the runtime. The compiler's backend used to be listed here too, so that a
// "bootstrap" build mode could compile a compiler from a table every shipped
// compiler carried. A compiler is now an ordinary UMS target that names its own
// C sources (the checkout's build.ums, `native { ... }`), and nothing in this
// binary knows which files make one.
typedef struct {
    const char* name;
} PrismioToolchainFile;

// From llvm-api-backend.c: the target the frontend selected. Read rather than
// copied, so this file and the backend cannot disagree about what is being
// built. See the "Targets" section there.
const char* ir_target_triple(void);
int ir_target_is_explicit(void);

// M1.1's two LLVM operations. They live in llvm-api-backend.c because that is
// where the C API dependency lives; this file drives clang and does not link
// LLVM itself.
int ir_curate_module(const char* runtime_ir, const char* const* names, int count,
                     const char* out_path);
int ir_link_modules(const char* dest_ir, const char* src_ir, const char* out_path);
int ir_link_library_modules(const char* dest_ir,
                            const char* const* src_irs,
                            const int* link_modes, int module_count,
                            const char* out_path);
// IR to an object, in process: 0 on success, 1 on failure, -1 when this
// backend was built without the LLVM headers and cannot (the caller then asks
// clang). See the note above it in llvm-api-backend.c.
int ir_emit_object(const char* ir_path, const char* obj_path, const char* triple,
                   int opt_level, int internalize, int* extra_objects);
// Keep the next merged module in memory for ir_emit_object instead of writing
// it (0 turns that off), and dispose of one nothing took.
void ir_hold_merged_module(int on);
void ir_release_held_module(void);
// Where ir_emit_object put partition `partition` of a parallel emission.
void ir_partition_object_path(const char* obj_path, int partition, char* out, size_t size);
const char* ir_host_macos_version(void);

static const PrismioToolchainFile prismio_toolchain_files[] = {
    { "prismio_platform.h" },
    { "prismio_runtime.h" },
    { "lang_runtime.c" },
    { "program_support.c" },
};

#define PRISMIO_TOOLCHAIN_FILE_COUNT \
    ((int)(sizeof(prismio_toolchain_files) / sizeof(prismio_toolchain_files[0])))

static const char* path_file_name(const char* path) {
    const char* last_slash = strrchr(path, '/');
    const char* last_backslash = strrchr(path, '\\');
    const char* separator = last_slash > last_backslash ? last_slash : last_backslash;
    return separator ? separator + 1 : path;
}

static char* path_without_extension(const char* path) {
    const char* filename = path_file_name(path);
    const char* dot = strrchr(filename, '.');
    int len = dot ? (int)(dot - path) : (int)strlen(path);
    char* result = (char*)malloc(len + 1);
    strncpy(result, path, len);
    result[len] = '\0';
    return result;
}

char* compiler_default_exe_path(const char* source_path) {
    char* stem = path_without_extension(source_path);
#ifdef _WIN32
    char* result = (char*)malloc(strlen(stem) + 5);
    sprintf(result, "%s.exe", stem);
#else
    char* result = (char*)malloc(strlen(stem) + 1);
    sprintf(result, "%s", stem);
#endif
    free(stem);
    return result;
}

// Builds "<dir><sep>.prismio-<stem>-<suffix>", or the same without the directory
// prefix when the path has none. Shared by the temporary .ll, .obj and unpacked
// source directory names, which previously repeated this logic three times.
static char* compiler_temp_path(const char* base_path, const char* suffix) {
    char* directory = get_directory(base_path);
    const char* filename = path_file_name(base_path);
    const char* dot = strrchr(filename, '.');
    int stem_len = dot ? (int)(dot - filename) : (int)strlen(filename);

    int has_directory = strcmp(directory, ".") != 0;
    int result_len = (has_directory ? (int)strlen(directory) + 1 : 0) +
                     (int)strlen(".prismio-") + stem_len + 1 +
                     (int)strlen(suffix) + 1;
    char* result = (char*)malloc(result_len);

    if (has_directory) {
        sprintf(result, "%s%c.prismio-%.*s-%s", directory, PRISMIO_PATH_SEP,
                stem_len, filename, suffix);
    } else {
        sprintf(result, ".prismio-%.*s-%s", stem_len, filename, suffix);
    }

    free(directory);
    return result;
}

// LAYOUT 3.2. The workload runner needs three temporaries beside the source --
// driver IR, driver executable, and the profile itself -- and they follow the
// same ".prismio-<stem>-<suffix>" convention as every other build temporary so a
// failed build leaves recognisable litter rather than anonymous files.
//
// Unlike compiler_temp_ir_path this does *not* stamp the pid into the name. The
// profile is the one build temporary a user may want to keep and check in
// (LAYOUT 2.2: "checked in beside the manifest"), and a pid in the name would
// make that impossible to predict.
char* compiler_temp_path_for(const char* source_path, const char* suffix) {
    return compiler_temp_path(source_path, suffix);
}

// The same name with the pid in it, for a temporary that must not be shared
// between concurrent builds of one source.
//
// RESULTS-layout §7: the three paths the workload runner used were the only ones
// here without a pid, so two compiles of the same program shared one
// profile.txt. A build that read another process's profile chose a different
// field order, and -- unlike a profile that fails to load -- neither fell back
// nor warned. It made the IR differential, which is this project's definition of
// a safe change, report a false difference under any concurrent load.
//
// LAYOUT §2.2's predictable path is kept: the profile is *published* to it after
// the run (compiler_publish_file), so the artifact a user may check in beside
// the manifest still appears at the name it always had. What changed is that
// nothing reads it.
char* compiler_temp_private_path(const char* source_path, const char* suffix) {
    char stamped[128];
    snprintf(stamped, sizeof(stamped), "%d-%s", PRISMIO_GETPID(), suffix);
    return compiler_temp_path(source_path, stamped);
}

static int write_text_file(const char* path, const char* content);

// Copies `from` onto `to` through a pid-qualified temporary beside it, so a
// concurrent reader of `to` sees either the old file or the new one and never a
// half-written one. Returns 0 on success.
int compiler_publish_file(const char* from, const char* to) {
    char* text = read_file(from);
    if (!text) return 1;

    size_t len = strlen(to) + 32;
    char* tmp = (char*)malloc(len);
    snprintf(tmp, len, "%s.%d.tmp", to, PRISMIO_GETPID());

    int result = write_text_file(tmp, text);
    if (result == 0 && fs_rename(tmp, to) != 0) {
        // Same filesystem by construction -- the temporary is a sibling -- so a
        // failure here is a permission or a disk problem, not EXDEV. Publishing
        // is best-effort either way: the build has its own copy.
        delete_file(tmp);
        result = 1;
    }

    free(tmp);
    free(text);
    return result;
}

char* compiler_temp_ir_path(const char* source_path) {
    char suffix[32];
    snprintf(suffix, sizeof(suffix), "%d.ll", PRISMIO_GETPID());
    return compiler_temp_path(source_path, suffix);
}

static char* compiler_temp_obj_path(const char* exe_file, const char* role) {
    char suffix[96];
    snprintf(suffix, sizeof(suffix), "%s-%d.obj", role, PRISMIO_GETPID());
    return compiler_temp_path(exe_file, suffix);
}

static int ensure_directory_exists(const char* directory) {
    if (!directory || directory[0] == '\0' || strcmp(directory, ".") == 0) {
        return 0;
    }

    char* path = (char*)malloc(strlen(directory) + 1);
    strcpy(path, directory);

    int start = 0;
#ifdef _WIN32
    if (strlen(path) > 2 && path[1] == ':') {
        start = 3;
    }
#endif

    for (int i = start; path[i] != '\0'; i++) {
        if (path[i] == '/' || path[i] == '\\') {
            char saved = path[i];
            path[i] = '\0';
            if (strlen(path) > 0) {
                PRISMIO_MKDIR(path);
            }
            path[i] = saved;
        }
    }

    PRISMIO_MKDIR(path);
    free(path);
    return 0;
}

int compiler_prepare_output_path(const char* output_path) {
    char* directory = get_directory(output_path);
    int result = ensure_directory_exists(directory);
    free(directory);
    return result;
}

static int accept_if_exists(char* out, int out_size, const char* candidate) {
    if (!file_exists(candidate)) {
        return 0;
    }
    strncpy(out, candidate, out_size - 1);
    out[out_size - 1] = '\0';
    return 1;
}

// The checkout a project build names, when it has one: the root of the
// `build.ums` whose target links `component("prismio.backend")`. Set by the UMS
// driver before it builds that target, so the sources come from the project
// being built -- not from whatever `runtime/` the working directory, or one or
// two directories above it, happens to hold.
static char g_toolchain_root[1024] = "";

void compiler_set_toolchain_root(const char* root) {
    snprintf(g_toolchain_root, sizeof(g_toolchain_root), "%s", root ? root : "");
}

// Looks for <subdir>/<filename> in a Prismio checkout: first under the project
// root a UMS build named, then relative to the compiler executable (so an
// installed toolchain works from any working directory) and then relative to the
// current directory (so a single-file in-repo build works). `subdir` is
// "runtime" for every bootstrap path and "std" for the project-local toolchain
// build, which needs the standard library sources from the same checkout and by
// the same search -- a second search order would be a second answer to "which
// checkout is this".
static int find_toolchain_entry(char* out, int out_size, const char* subdir,
                                const char* filename) {
    char candidate[1024];

    if (g_toolchain_root[0]) {
        snprintf(candidate, sizeof(candidate), "%s%c%s%c%s", g_toolchain_root,
                 PRISMIO_PATH_SEP, subdir, PRISMIO_PATH_SEP, filename);
        if (accept_if_exists(out, out_size, candidate)) return 1;
    }

    char* compiler_dir = prismio_executable_directory();
    if (compiler_dir) {
        snprintf(candidate, sizeof(candidate), "%s%c..%c%s%c%s",
                 compiler_dir, PRISMIO_PATH_SEP, PRISMIO_PATH_SEP, subdir,
                 PRISMIO_PATH_SEP, filename);
        if (accept_if_exists(out, out_size, candidate)) {
            free(compiler_dir);
            return 1;
        }

        snprintf(candidate, sizeof(candidate), "%s%c%s%c%s",
                 compiler_dir, PRISMIO_PATH_SEP, subdir, PRISMIO_PATH_SEP, filename);
        if (accept_if_exists(out, out_size, candidate)) {
            free(compiler_dir);
            return 1;
        }

        free(compiler_dir);
    }

    static const char* prefixes[] = { "", "..", "../..", NULL };
    for (int i = 0; prefixes[i] != NULL; i++) {
        if (prefixes[i][0]) {
            snprintf(candidate, sizeof(candidate), "%s%c%s%c%s", prefixes[i],
                     PRISMIO_PATH_SEP, subdir, PRISMIO_PATH_SEP, filename);
        } else {
            snprintf(candidate, sizeof(candidate), "%s%c%s", subdir,
                     PRISMIO_PATH_SEP, filename);
        }
        if (accept_if_exists(out, out_size, candidate)) {
            return 1;
        }
    }

    return 0;
}

static int find_toolchain_source(char* out, int out_size, const char* filename) {
    return find_toolchain_entry(out, out_size, "runtime", filename);
}

// Locating the LLVM C API
// The backend is built on it, so a build that includes the backend needs LLVM's
// headers to compile and its C API library to link. The two places to look are
// the same two the bootstrap scripts read, in the same order and with the same
// names: PRISMIO_LLVM_DIR overrides, otherwise third_party/llvm-paths.json,
// which tools/setup_llvm.py writes. A third answer would be a third thing to
// keep in step.

// The value of a top-level "key": "value" pair. Not a JSON parser and does not
// pretend to be one: this reads a file this toolchain generated, whose shape is
// fixed by setup_llvm.py. The one escape a Windows path actually produces --
// a doubled backslash -- is undone; anything else is copied through, and a file
// that does not match returns 0 rather than a wrong answer.
static int json_string_field(const char* text, const char* key, char* out, int out_size) {
    char pattern[64];
    snprintf(pattern, sizeof(pattern), "\"%s\"", key);

    const char* at = strstr(text, pattern);
    if (!at) return 0;
    at = strchr(at + strlen(pattern), ':');
    if (!at) return 0;
    at = strchr(at, '"');
    if (!at) return 0;
    at++;

    int n = 0;
    while (*at && *at != '"' && n < out_size - 1) {
        if (at[0] == '\\' && (at[1] == '\\' || at[1] == '/')) at++;
        out[n++] = *at++;
    }
    if (*at != '"') return 0; // ran off the end: an incomplete value is not a value
    out[n] = '\0';
    return n > 0;
}

// The `-l` *name* is not a constant, which is why it is an output here rather
// than a literal at the link site. Homebrew and the Windows package ship
// `libLLVM-C.dylib` / `LLVM-C.lib`; apt.llvm.org's llvm-N-dev ships `libLLVM.so`
// and no LLVM-C at all, so `-lLLVM-C` fails to link on Ubuntu. setup_llvm.py
// already records the library it validated -- `link_out` is that name reduced to
// what `-l` wants: a leading `lib` dropped, then everything from the first dot.
//
// `link_out` may be NULL for callers that only want the directories.
static void llvm_link_name(const char* file_name, char* out, int out_size) {
    const char* p = file_name;
    if (strncmp(p, "lib", 3) == 0) p += 3;
    int n = 0;
    while (p[n] && p[n] != '.' && n < out_size - 1) { out[n] = p[n]; n++; }
    out[n] = '\0';
    if (n == 0) snprintf(out, out_size, "LLVM-C");
}

// `rsp_out`, when non-NULL, receives the response file setup_llvm.py writes for
// the pinned toolchain -- the static archives and the system libraries they
// need -- or "" for an install adopted with --llvm-dir, which is linked by
// `-L <lib> -l<link>` as before.
static int find_llvm_paths_ex(char* include_out, int include_size, char* lib_out, int lib_size,
                              char* link_out, int link_size, char* rsp_out, int rsp_size) {
    if (link_out && link_size > 0) snprintf(link_out, link_size, "LLVM-C");
    if (rsp_out && rsp_size > 0) rsp_out[0] = '\0';
    const char* root = getenv("PRISMIO_LLVM_DIR");
    if (root && root[0]) {
        snprintf(include_out, include_size, "%s%cinclude", root, PRISMIO_PATH_SEP);
        snprintf(lib_out, lib_size, "%s%clib", root, PRISMIO_PATH_SEP);
        return 1;
    }

    // Search upward from the executable as well as from the working directory.
    // A development compiler normally lives at .prismio/build/<mode>/prismio,
    // while an installed compiler lives at <toolchain>/bin/prismio. Both need
    // to keep finding the same manifest when invoked from an unrelated cwd.
    static const char* relative[] = {
        ".", "..", "../..", "../../..", NULL
    };
    char candidate[1024];
    char* compiler_dir = prismio_executable_directory();
    char* text = NULL;

    for (int i = 0; relative[i] && !text; i++) {
        if (!compiler_dir) break;
        snprintf(candidate, sizeof(candidate), "%s%c%s%cthird_party%cllvm-paths.json",
                 compiler_dir, PRISMIO_PATH_SEP, relative[i],
                 PRISMIO_PATH_SEP, PRISMIO_PATH_SEP);
        if (file_exists(candidate)) text = read_file(candidate);
    }
    if (compiler_dir) free(compiler_dir);

    static const char* prefixes[] = {
        "third_party/llvm-paths.json", "third_party\\llvm-paths.json",
        "../third_party/llvm-paths.json", "..\\third_party\\llvm-paths.json",
        NULL
    };
    for (int i = 0; prefixes[i] && !text; i++) {
        if (file_exists(prefixes[i])) text = read_file(prefixes[i]);
    }

    if (!text) return 0;

    int ok = json_string_field(text, "include", include_out, include_size)
          && json_string_field(text, "lib", lib_out, lib_size);
    if (ok && link_out && link_size > 0) {
        char recorded[256];
        if (json_string_field(text, "link_library", recorded, (int)sizeof(recorded))) {
            llvm_link_name(recorded, link_out, link_size);
        }
    }
    if (ok && rsp_out && rsp_size > 0
        && !json_string_field(text, "link_rsp", rsp_out, rsp_size)) {
        rsp_out[0] = '\0';
    }
    free(text);
    return ok;
}

// The three-argument form every existing caller wants: directories only.
static int find_llvm_paths(char* include_out, int include_size, char* lib_out, int lib_size) {
    return find_llvm_paths_ex(include_out, include_size, lib_out, lib_size, NULL, 0, NULL, 0);
}

// Use the clang that belongs to the LLVM C API linked into this compiler.
//
// Textual IR is versioned input. LLVM 22, for example, emits the
// `nocreateundeforpoison` attribute that a clang 21 parser does not know. The
// setup manifest already records one validated LLVM installation; ignoring its
// bin directory and resolving an unrelated `clang` from PATH made a self-build
// fail only after all frontend work had completed. Fall back to PATH only for a
// legacy manifest/install that has no sibling driver.
//
// g_clang_binary is the same driver unquoted, or "" when the answer was the bare
// `clang` from PATH. The toolchain stamp needs the file rather than the command:
// an in-place LLVM upgrade changes neither the runtime sources nor this string,
// and the object cache's own note above records that exact gap as one nothing
// notices.
static char g_clang_binary[1200];

static const char* native_clang_command(void) {
    static int ready = 0;
    static char command[1200];
    if (ready) return command;
    ready = 1;
    snprintf(command, sizeof(command), "clang");
    g_clang_binary[0] = '\0';

    char include_dir[1024] = "";
    char lib_dir[1024] = "";
    if (!find_llvm_paths(include_dir, sizeof(include_dir), lib_dir, sizeof(lib_dir))) {
        return command;
    }

    char* root = get_directory(include_dir);
    char candidate[1200];
#ifdef _WIN32
    snprintf(candidate, sizeof(candidate), "%s%cbin%cclang.exe",
             root, PRISMIO_PATH_SEP, PRISMIO_PATH_SEP);
#else
    snprintf(candidate, sizeof(candidate), "%s%cbin%cclang",
             root, PRISMIO_PATH_SEP, PRISMIO_PATH_SEP);
#endif
    free(root);
    if (!file_exists(candidate)) return command;

    char* quoted = command_quote_arg(candidate);
    if (quoted && strlen(quoted) < sizeof(command)) {
        snprintf(command, sizeof(command), "%s", quoted);
        snprintf(g_clang_binary, sizeof(g_clang_binary), "%s", candidate);
    }
    free(quoted);
    return command;
}

static int write_text_file(const char* path, const char* content) {
    FILE* file = fopen(path, "wb");
    if (!file) {
        return 1;
    }
    fputs(content, file);
    fclose(file);
    return 0;
}

// An installed toolchain looks like
//
//     <prefix>/bin/prismio(.exe)
//     <prefix>/lib/runtime.{lib,a}     linked into every compiled program
//     <prefix>/lib/backend.{lib,a}     linked into the compiler only
//     <prefix>/stdlib/
//
// and is located purely relative to the running executable: no hardcoded prefixes,
// no environment variables, no runtime sources shipped, nothing extracted from the
// binary. Also accepts lib/ sitting directly beside the executable, which is what a
// plain unpacked build tree looks like.
static int find_in_lib_dir(char* out, int out_size, const char* filename) {
    static const char* relative_dirs[] = { "..", ".", NULL };

    char* compiler_dir = prismio_executable_directory();
    if (!compiler_dir) {
        return 0;
    }

    char candidate[1024];
    for (int d = 0; relative_dirs[d] != NULL; d++) {
        snprintf(candidate, sizeof(candidate), "%s%c%s%clib%c%s",
                 compiler_dir, PRISMIO_PATH_SEP, relative_dirs[d],
                 PRISMIO_PATH_SEP, PRISMIO_PATH_SEP, filename);
        if (accept_if_exists(out, out_size, candidate)) {
            free(compiler_dir);
            return 1;
        }
    }

    free(compiler_dir);
    return 0;
}

// Runtime bitcode is deliberately sharded by runtime translation module. Each
// unit remains visible to LLVM for whole-program optimisation without forcing a
// single monolithic runtime artifact on the toolchain layout.
static const char* prismio_runtime_modules[] = {
    "lang_runtime",
    "program_support",
};

#define PRISMIO_RUNTIME_MODULE_COUNT \
    ((int)(sizeof(prismio_runtime_modules) / sizeof(prismio_runtime_modules[0])))

#define PRISMIO_PLIB_MAX 128
#define PRISMIO_PLIB_SECTIONS_MAX 16
#define PRISMIO_PLIB_TRIPLE_MAX 127

// One target's code in a PLIB: the module compiled for `triple`, normally and
// under `--verify`. "" is the host the toolchain was packaged on, which is how an
// implicit-target build asks for it -- the same split the runtime makes between
// `lib/runtime/*.bc` and `lib/runtime/<triple>/*.bc`.
typedef struct {
    char triple[PRISMIO_PLIB_TRIPLE_MAX + 1];
    unsigned long long bitcode_offset;
    unsigned long long bitcode_size;
    unsigned long long verify_bitcode_offset;
    unsigned long long verify_bitcode_size;
} PrismioPlibSection;

typedef struct {
    char* module;
    char* path;
    PrismioPlibSection* sections;
    int section_count;
} PrismioPlib;

static PrismioPlib prismio_plibs[PRISMIO_PLIB_MAX];
static int prismio_plib_count;
static char prismio_plib_error[512];

static unsigned read_u32_le(const unsigned char* p) {
    return (unsigned)p[0] | ((unsigned)p[1] << 8) |
           ((unsigned)p[2] << 16) | ((unsigned)p[3] << 24);
}

static unsigned long long read_u64_le(const unsigned char* p) {
    unsigned long long value = 0;
    for (int i = 7; i >= 0; i--) value = (value << 8) | p[i];
    return value;
}

static char* plib_empty(void) {
    char* value = (char*)rt_base_alloc(1);
    value[0] = '\0';
    return value;
}

// The section table: `count` entries, each a 20-byte header -- triple, normal and
// verify lengths -- then those three payloads. Returns 0 and fills `out`, or 1
// with prismio_plib_error set. `*end` is the offset just past the last payload,
// which the caller compares against the file size.
static int plib_read_sections(FILE* file, const char* path, unsigned long long offset,
                              unsigned count, PrismioPlibSection* out,
                              unsigned long long* end) {
    for (unsigned i = 0; i < count; i++) {
        unsigned char header[20];
        if (fseek(file, (long)offset, SEEK_SET) != 0
            || fread(header, 1, sizeof(header), file) != sizeof(header)) {
            snprintf(prismio_plib_error, sizeof(prismio_plib_error),
                     "%s is truncated in its section table", path);
            return 1;
        }
        unsigned triple_len = read_u32_le(header);
        unsigned long long code_len = read_u64_le(header + 4);
        unsigned long long verify_len = read_u64_le(header + 12);
        if (triple_len > PRISMIO_PLIB_TRIPLE_MAX
            || code_len == 0 || code_len > 512ULL * 1024ULL * 1024ULL
            || verify_len == 0 || verify_len > 512ULL * 1024ULL * 1024ULL
            || fread(out[i].triple, 1, triple_len, file) != triple_len) {
            snprintf(prismio_plib_error, sizeof(prismio_plib_error),
                     "%s has an invalid section %u", path, i);
            return 1;
        }
        out[i].triple[triple_len] = '\0';
        for (unsigned j = 0; j < i; j++) {
            if (strcmp(out[j].triple, out[i].triple) == 0) {
                snprintf(prismio_plib_error, sizeof(prismio_plib_error),
                         "%s has two sections for target \"%s\"", path, out[i].triple);
                return 1;
            }
        }
        out[i].bitcode_offset = offset + sizeof(header) + triple_len;
        out[i].bitcode_size = code_len;
        out[i].verify_bitcode_offset = out[i].bitcode_offset + code_len;
        out[i].verify_bitcode_size = verify_len;
        offset = out[i].verify_bitcode_offset + verify_len;
    }
    *end = offset;
    return 0;
}

// Read and register one module-level Prismio library. PLIB v3 is: magic, module
// and interface lengths, a section count, the module name, the interface, then
// one code section per packaged target (plib_read_sections). The interface
// remains compiler input; the section matching the build's target is linked
// later as LLVM bitcode (plib_section_for_target).
char* compiler_plib_interface(const char* path, const char* expected_module) {
    prismio_plib_error[0] = '\0';
    FILE* file = fopen(path, "rb");
    if (!file) {
        snprintf(prismio_plib_error, sizeof(prismio_plib_error),
                 "cannot open %s", path);
        return plib_empty();
    }

    unsigned char header[24];
    if (fread(header, 1, sizeof(header), file) != sizeof(header)
        || memcmp(header, "PRPLIB3\n", 8) != 0) {
        snprintf(prismio_plib_error, sizeof(prismio_plib_error),
                 "%s is not a valid PLIB v3 artifact", path);
        fclose(file);
        return plib_empty();
    }

    unsigned module_len = read_u32_le(header + 8);
    unsigned long long interface_len = read_u64_le(header + 12);
    unsigned section_count = read_u32_le(header + 20);
    if (module_len == 0 || module_len > 255 || interface_len > 64ULL * 1024ULL * 1024ULL
        || section_count == 0 || section_count > PRISMIO_PLIB_SECTIONS_MAX) {
        snprintf(prismio_plib_error, sizeof(prismio_plib_error),
                 "%s has an invalid PLIB header", path);
        fclose(file);
        return plib_empty();
    }

    char module[256];
    if (fread(module, 1, module_len, file) != module_len) {
        snprintf(prismio_plib_error, sizeof(prismio_plib_error),
                 "%s is truncated before its module name", path);
        fclose(file);
        return plib_empty();
    }
    module[module_len] = '\0';
    if (strcmp(module, expected_module) != 0) {
        snprintf(prismio_plib_error, sizeof(prismio_plib_error),
                 "%s contains module %s, expected %s", path, module, expected_module);
        fclose(file);
        return plib_empty();
    }

    char* interface = (char*)rt_base_alloc((size_t)interface_len + 1);
    if (!interface || fread(interface, 1, (size_t)interface_len, file) != interface_len) {
        snprintf(prismio_plib_error, sizeof(prismio_plib_error),
                 "%s is truncated in its interface section", path);
        if (interface) interface[0] = '\0';
        fclose(file);
        return interface ? interface : plib_empty();
    }
    interface[interface_len] = '\0';

    PrismioPlibSection* sections =
        (PrismioPlibSection*)calloc(section_count, sizeof(PrismioPlibSection));
    unsigned long long end = 0;
    int failed = !sections
        || plib_read_sections(file, path, sizeof(header) + module_len + interface_len,
                              section_count, sections, &end) != 0;
    if (!sections) {
        snprintf(prismio_plib_error, sizeof(prismio_plib_error),
                 "out of memory reading %s", path);
    }
    if (!failed && (fseek(file, 0, SEEK_END) != 0
                    || (unsigned long long)ftell(file) != end)) {
        snprintf(prismio_plib_error, sizeof(prismio_plib_error),
                 "%s is truncated or has trailing data", path);
        failed = 1;
    }
    fclose(file);
    if (failed) {
        free(sections);
        interface[0] = '\0';
        return interface;
    }

    for (int i = 0; i < prismio_plib_count; i++) {
        if (strcmp(prismio_plibs[i].module, module) == 0) {
            free(sections);
            return interface;
        }
    }
    if (prismio_plib_count >= PRISMIO_PLIB_MAX) {
        snprintf(prismio_plib_error, sizeof(prismio_plib_error),
                 "more than %d compiled modules were imported", PRISMIO_PLIB_MAX);
        free(sections);
        interface[0] = '\0';
        return interface;
    }

    PrismioPlib* entry = &prismio_plibs[prismio_plib_count++];
    entry->module = (char*)malloc(strlen(module) + 1);
    entry->path = (char*)malloc(strlen(path) + 1);
    strcpy(entry->module, module);
    strcpy(entry->path, path);
    entry->sections = sections;
    entry->section_count = (int)section_count;
    return interface;
}

char* compiler_plib_error(void) {
    char* copy = (char*)rt_base_alloc(strlen(prismio_plib_error) + 1);
    strcpy(copy, prismio_plib_error);
    return copy;
}

int compiler_plib_module_registered(const char* module) {
    for (int i = 0; i < prismio_plib_count; i++) {
        if (strcmp(prismio_plibs[i].module, module) == 0) return 1;
    }
    return 0;
}

char* compiler_library_emission_module(void) {
    const char* module = getenv("PRISMIO_LIBRARY_MODULE");
    if (!module) module = "";
    char* copy = (char*)rt_base_alloc(strlen(module) + 1);
    strcpy(copy, module);
    return copy;
}

static int find_runtime_bitcode(char paths[][1024], int verify) {
    int found_all = 1;
    for (int i = 0; i < PRISMIO_RUNTIME_MODULE_COUNT; i++) {
        char relative[512];
        const char* variant = verify ? ".verify" : "";
        if (ir_target_is_explicit()) {
            snprintf(relative, sizeof(relative), "runtime/%s/%s%s.bc",
                     ir_target_triple(), prismio_runtime_modules[i], variant);
        } else {
            snprintf(relative, sizeof(relative), "runtime/%s%s.bc",
                     prismio_runtime_modules[i], variant);
        }
        if (!find_in_lib_dir(paths[i], 1024, relative)) {
            fprintf(stderr,
                    "ERROR: Prismio installation is incomplete or corrupted.\n"
                    "       Missing runtime module: lib/%s\n"
                    "       Reinstall Prismio and try again.\n",
                    relative);
            found_all = 0;
        }
    }
    return found_all;
}

// Content hashing, not timestamps: a checkout, a copy or a touch all move mtimes
// without changing code, and mtime comparison across machines is unreliable.
// FNV-1a is implemented here rather than shelling out to shasum/certutil so the
// check has no external dependency and gives identical results on every platform.
#define PRISMIO_FNV_OFFSET 1469598103934665603ULL
#define PRISMIO_FNV_PRIME  1099511628211ULL

static unsigned long long fnv1a_bytes(unsigned long long hash, const unsigned char* data) {
    for (const unsigned char* p = data; *p; p++) {
        // Normalize line endings so a CRLF checkout hashes the same as an LF one.
        if (*p == '\r') continue;
        hash ^= (unsigned long long)(*p);
        hash *= PRISMIO_FNV_PRIME;
    }
    return hash;
}

// The same hash over bytes that are not text. Neither of the two things the
// function above does to text is right for a binary: it stops at the first NUL,
// and it drops every 0x0D. An executable hashed that way would compare equal to
// a different executable that differs only in a carriage-return byte, and would
// ignore everything past its first zero -- which for a Mach-O or PE image is
// almost all of it.
static unsigned long long fnv1a_raw(unsigned long long hash,
                                    const unsigned char* data, size_t size) {
    for (size_t i = 0; i < size; i++) {
        hash ^= (unsigned long long)data[i];
        hash *= PRISMIO_FNV_PRIME;
    }
    return hash;
}

// Hash of the sources that make up the runtime bitcode modules, in table order. Returns a malloc'd
// 16-digit hex string, or an empty string when the sources are not on disk (a
// normal installed toolchain, where there is nothing to compare against).
char* compiler_runtime_source_hash(void) {
    unsigned long long hash = PRISMIO_FNV_OFFSET;
    char path[1024];
    int hashed = 0;

    for (int i = 0; i < PRISMIO_TOOLCHAIN_FILE_COUNT; i++) {
        if (!find_toolchain_source(path, sizeof(path), prismio_toolchain_files[i].name)) {
            char* empty = (char*)malloc(1);
            empty[0] = '\0';
            return empty;
        }

        char* text = read_file(path);
        if (!text) {
            char* empty = (char*)malloc(1);
            empty[0] = '\0';
            return empty;
        }

        // Fold the file name in too, so moving code between files is detected.
        hash = fnv1a_bytes(hash, (const unsigned char*)prismio_toolchain_files[i].name);
        hash = fnv1a_bytes(hash, (const unsigned char*)text);
        free(text);
        hashed++;
    }

    char* result = (char*)malloc(32);
    if (hashed == 0) {
        result[0] = '\0';
    } else {
        snprintf(result, 32, "%016llx", hash);
    }
    return result;
}

// The hash recorded beside the installed libraries when they were packaged.
// Empty when there is no installed toolchain or it predates hash recording.
char* compiler_installed_runtime_hash(void) {
    char path[1024];
    if (!find_in_lib_dir(path, sizeof(path), "runtime.hash")) {
        char* empty = (char*)malloc(1);
        empty[0] = '\0';
        return empty;
    }

    char* text = read_file(path);
    if (!text) {
        char* empty = (char*)malloc(1);
        empty[0] = '\0';
        return empty;
    }

    // Trim trailing whitespace the sidecar may have picked up.
    for (int i = (int)strlen(text) - 1; i >= 0; i--) {
        if (text[i] == '\n' || text[i] == '\r' || text[i] == ' ' || text[i] == '\t') {
            text[i] = '\0';
        } else {
            break;
        }
    }
    return text;
}

// Through execute_command rather than `system` directly, for Windows: `system`
// runs `cmd /c <line>`, and when the line starts with a quote cmd strips the
// first and the last one -- so `"C:\\...\\clang.exe" ... "out.o"` became a broken
// path, reported as "The filename, directory name, or volume label syntax is
// incorrect" by `prismio bootstrap` on CI. execute_command wraps the line in
// `cmd /S /C "..."`, which strips exactly the pair it added. On POSIX the two
// are the same call.
static int run_build_command(const char* command) {
    return execute_command(command);
}

// The same, with the command's own output held back until it is worth reading.
//
// Building a project-local toolchain issues 32 commands and every one of them is
// chatty: the compiler announces each module's IR on stdout, and clang warns
// about the module triple it overrides on stderr. That is sixty lines of noise
// around a build whose interesting output is one line. Captured to `log_path`
// and printed only when the command fails, which is the only time any of it
// answers a question.
static int run_quiet_build_command(const char* command, const char* log_path) {
    char* q_log = command_quote_arg(log_path);
    size_t len = strlen(command) + strlen(q_log) + 16;
    char* redirected = (char*)malloc(len);
    if (!redirected) {
        free(q_log);
        return run_build_command(command);
    }
    snprintf(redirected, len, "%s > %s 2>&1", command, q_log);
    int failed = run_build_command(redirected);
    free(redirected);
    free(q_log);

    if (failed) {
        char* text = read_file(log_path);
        if (text) {
            diag_progress_clear();
            fputs(text, stderr);
            free(text);
        }
    }
    delete_file(log_path);
    return failed;
}

// Per-stage wall-clock, on stderr, when PRISMIO_BUILD_TRACE is set.
//
// The cold-compile regression this exists for was recorded in TODO as a
// whole-build ratio -- "19-28% with PRISMIO_OBJ_CACHE=0" -- which names no stage,
// so every attempt to close it would have been a guess checked by re-timing the
// whole build. Wall clock rather than clock(): every expensive stage below is a
// child process, and clock() counts none of them.
static double build_trace_ms(void) {
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

static int build_trace_enabled(void) {
    const char* v = getenv("PRISMIO_BUILD_TRACE");
    return v && v[0] != '\0' && !(v[0] == '0' && v[1] == '\0');
}

static void build_trace_stage(const char* stage, double t0) {
    if (!build_trace_enabled()) return;
    fprintf(stderr, "[build trace] %-24s %8.1f ms\n", stage, build_trace_ms() - t0);
}

// SPEC 7.3's `--verify`, as seen from the build.
//
// Codegen swaps the allocator and deallocator *names* and changes nothing else.
// That covers everything ir_alloc_object handed out and nothing else -- but AIF
// Level 4 made strings and lists affine, and those are allocated inside
// lang_runtime.c, past the seam. Their release would then be a pointer the
// accounting never saw, which reads as a violation on every string a program
// drops.
//
// So a verify build compiles the runtime from source with PRISMIO_AIF_VERIFY
// defined, which points its own allocator at the same shims. That keeps both
// ends of every pairing on the same side of the swap, and it keeps the property
// worth having: the *generated code* is byte-identical either way.
static int g_verify_mode = 0;

void compiler_set_verify_mode(int on) { g_verify_mode = on ? 1 : 0; }

// `-g`, as seen from the build. The DWARF itself is built by the backend and
// travels inside the .ll; this flag is the two things the *driver* has to do
// differently once it is there.
//
// **-O0 for the program object.** The rest of this file argues for -O2 and the
// measurements behind it stand, but they are measurements of speed, and -g is a
// request for a different thing. At -O2 a Prismio local is promoted out of its
// stack slot in the first hundred milliseconds of the pipeline, and every
// question a debugger can then answer about it is "optimized out". LLVM does not
// lie in that state -- it drops locations rather than keeping stale ones -- so
// the result is not wrong, it is empty, and an empty debugger is what a user
// would report as "-g does not work". Someone who wants both can still ask:
// `prismio build x.psm -O2 -g` runs the IR pipeline inside the compiler and the
// compile unit records isOptimized, so the debugger says so.
//
// **dsymutil on Darwin.** Mach-O keeps DWARF in the object file and puts only a
// debug map in the executable, so `delete_file(program_obj)` below -- which has
// always run -- would take the debug info with it. dsymutil walks the map and
// copies the DWARF into a .dSYM bundle beside the binary, which is where lldb
// looks. On ELF the linker copies the sections into the executable itself and
// there is nothing to do. This is why -g on macOS was not simply "emit the
// metadata": everything downstream of the metadata was already deleting it.
static int g_debug_info = 0;

void compiler_set_debug_info(int on) { g_debug_info = on ? 1 : 0; }

// Cross-compilation
// The triple is not stored here: llvm-api-backend.c already holds it, because
// that is where LLVM answered the question, and a second copy is a second thing
// that can be stale. This file asks.
// The sysroot is stored here, and is not part of the target record, because it
// is not a property of the triple -- it is where *this machine* keeps the SDK
// for it. Two hosts building the same target legitimately pass different paths,
// and the compiler has no business guessing either one: an SDK it picked itself
// is exactly the kind of "helpfully wrong" that produces a link error someone
// spends an afternoon on.

static char g_sysroot[1024] = "";

void compiler_set_sysroot(const char* path) {
    snprintf(g_sysroot, sizeof(g_sysroot), "%s", path ? path : "");
}

// The clang flags that name the target: either "" or a string ending in a
// space, so a caller can always paste it straight in front of the rest of the
// command. "" is the host case, where clang goes on defaulting exactly as it
// always has and every existing build is byte-for-byte unaffected.
//
// Returned in a caller-owned buffer rather than a static one: it goes into the
// object cache key, and a key built from a buffer a later call can rewrite is a
// key that describes the wrong compile.
static char* target_clang_flags(void) {
    const char* triple = ir_target_is_explicit() ? ir_target_triple() : "";
    int has_sysroot = g_sysroot[0] != '\0';
    if (!triple[0] && !has_sysroot) {
        char* empty = (char*)malloc(1);
        if (empty) empty[0] = '\0';
        return empty;
    }

    char* q_sysroot = has_sysroot ? command_quote_arg(g_sysroot) : NULL;
    int len = (int)strlen(triple) + (q_sysroot ? (int)strlen(q_sysroot) : 0) + 64;
    char* out = (char*)malloc(len);
    snprintf(out, len, "%s%s%s%s%s%s",
             triple[0] ? "--target=" : "", triple, triple[0] ? " " : "",
             has_sysroot ? "-isysroot " : "", q_sysroot ? q_sysroot : "",
             has_sysroot ? " " : "");
    if (q_sysroot) free(q_sysroot);
    return out;
}

// Whether the thing being produced is Mach-O. dsymutil is asked only of a build
// that will have a debug map to walk, and after cross-compilation that is a
// question about the *target*, not about the host this compiler is running on.
static int target_is_mach_o(void) {
    if (!ir_target_is_explicit()) {
#ifdef __APPLE__
        return 1;
#else
        return 0;
#endif
    }
    const char* t = ir_target_triple();
    return strstr(t, "apple") != NULL || strstr(t, "darwin") != NULL;
}

// Ordered native inputs for the next executable link. UMS owns their meaning;
// the driver owns shell-safe spelling. Keeping this as arguments rather than a
// raw flags string means a manifest value can never become a second command or
// smuggle in an unrelated driver option.
//
// Each input is kept twice: spelled for a clang/cc driver, and spelled for
// MSVC's link.exe, which is what links a Windows program (link_program_msvc).
// The two differ in exactly the two inputs that name something indirectly:
// `-lfoo` is `foo.lib`, and `-L dir` is `/LIBPATH:dir`.
static char* g_native_link_args = NULL;
static char* g_native_link_args_msvc = NULL;
static int g_native_link_has_framework = 0;
// A response file names arguments in a clang driver's spelling, which link.exe
// does not read, so a target with one links through the driver on Windows too.
static int g_native_link_needs_driver = 0;
// An object, archive or response file the target links. Code in it may call the
// program's functions by name, which is what keeps them external
// (program_is_closed).
static int g_native_link_has_code = 0;

// Native code a target brings: `native { ... }`, `runtime` and `exportDynamic`.
//
// A target may compile C sources of its own and link them into the program -- a
// codec, a binding to a system library, or the case that made this general: the
// Prismio compiler, which is an ordinary Prismio program whose runtime and
// backend are written in C. Nothing here knows which program it is building. The
// manifest names the sources, include directories, defines, flags and response
// files; the driver compiles each source with the toolchain's clang and links
// the objects in declaration order. See compile_native_sources.
static char** g_native_sources = NULL;
static int g_native_source_count = 0;
static int g_native_source_cap = 0;
// Every compile flag the target declared, quoted, in declaration order.
static char* g_native_flags = NULL;
// The response files among those flags, so the object cache can key on what
// they say rather than only on their names.
static char** g_native_flag_files = NULL;
static int g_native_flag_file_count = 0;
static int g_native_flag_file_cap = 0;
// Whether the installed runtime bitcode is merged into the program. A target
// that declares `runtime = "none"` provides every runtime symbol itself.
static int g_installed_runtime = 1;
// Whether the executable's own symbols are visible to code it loads at run time.
static int g_export_dynamic = 0;
// `--freestanding`: no operating system under the program. The installed runtime
// is not merged (it is libc code), and the link takes no C library, no startup
// files and no `-lm`/`-lpthread`; the program's own native sources and link
// arguments supply the entry point and the linker script. Not reset by
// compiler_link_reset, which is per target and this is per command line.
static int g_freestanding = 0;
// For the one link in progress: the compiled native objects and the export
// flags, quoted, set by compiler_build_executable around link_program_object.
static const char* g_link_extra = "";

static void free_string_list(char*** items, int* count, int* cap) {
    for (int i = 0; i < *count; i++) free((*items)[i]);
    free(*items);
    *items = NULL;
    *count = 0;
    *cap = 0;
}

static int push_string(char*** items, int* count, int* cap, const char* value) {
    if (*count == *cap) {
        int grown = *cap ? *cap * 2 : 8;
        char** bigger = (char**)realloc(*items, (size_t)grown * sizeof(char*));
        if (!bigger) return 1;
        *items = bigger;
        *cap = grown;
    }
    size_t n = strlen(value ? value : "") + 1;
    char* copy = (char*)malloc(n);
    if (!copy) return 1;
    memcpy(copy, value ? value : "", n);
    (*items)[(*count)++] = copy;
    return 0;
}

void compiler_link_reset(void) {
    free(g_native_link_args);
    g_native_link_args = NULL;
    free(g_native_link_args_msvc);
    g_native_link_args_msvc = NULL;
    g_native_link_has_framework = 0;
    g_native_link_needs_driver = 0;
    g_native_link_has_code = 0;
    free_string_list(&g_native_sources, &g_native_source_count, &g_native_source_cap);
    free(g_native_flags);
    g_native_flags = NULL;
    free_string_list(&g_native_flag_files, &g_native_flag_file_count, &g_native_flag_file_cap);
    g_installed_runtime = 1;
    g_export_dynamic = 0;
}

static int append_quoted_argument(char** args, const char* argument) {
    char* quoted = command_quote_arg(argument ? argument : "");
    if (!quoted) return 1;

    size_t old_len = *args ? strlen(*args) : 0;
    size_t quoted_len = strlen(quoted);
    char* grown = (char*)realloc(*args, old_len + quoted_len + 2);
    if (!grown) {
        free(quoted);
        return 1;
    }
    *args = grown;
    grown[old_len] = ' ';
    memcpy(grown + old_len + 1, quoted, quoted_len + 1);
    free(quoted);
    return 0;
}

static int append_joined_argument(char** args, const char* prefix, const char* value,
                                  const char* suffix) {
    size_t len = strlen(prefix) + strlen(value ? value : "") + strlen(suffix) + 1;
    char* argument = (char*)malloc(len);
    if (!argument) return 1;
    snprintf(argument, len, "%s%s%s", prefix, value ? value : "", suffix);
    int result = append_quoted_argument(args, argument);
    free(argument);
    return result;
}

static int compiler_link_append_argument(const char* argument) {
    return append_quoted_argument(&g_native_link_args, argument)
        || append_quoted_argument(&g_native_link_args_msvc, argument);
}

static int has_suffix_ignoring_case(const char* text, const char* suffix) {
    size_t n = strlen(text), m = strlen(suffix);
    if (n < m) return 0;
    for (size_t i = 0; i < m; i++) {
        char a = text[n - m + i], b = suffix[i];
        if (a >= 'A' && a <= 'Z') a = (char)(a - 'A' + 'a');
        if (a != b) return 0;
    }
    return 1;
}

int compiler_link_library(const char* name) {
    const char* value = name ? name : "";
    return append_joined_argument(&g_native_link_args, "-l", value, "")
        || append_joined_argument(&g_native_link_args_msvc, "", value,
                                  has_suffix_ignoring_case(value, ".lib") ? "" : ".lib");
}

int compiler_link_search(const char* path) {
    return append_joined_argument(&g_native_link_args, "-L", path, "")
        || append_joined_argument(&g_native_link_args_msvc, "/LIBPATH:", path, "");
}

int compiler_link_file(const char* path) {
    g_native_link_has_code = 1;
    return compiler_link_append_argument(path);
}

int compiler_link_framework(const char* name) {
    g_native_link_has_framework = 1;
    if (compiler_link_append_argument("-framework") != 0) return 1;
    return compiler_link_append_argument(name);
}

int compiler_link_response_file(const char* path) {
    g_native_link_needs_driver = 1;
    g_native_link_has_code = 1;
    return append_joined_argument(&g_native_link_args, "@", path, "")
        || append_joined_argument(&g_native_link_args_msvc, "@", path, "");
}

int compiler_native_source(const char* path) {
    return push_string(&g_native_sources, &g_native_source_count, &g_native_source_cap, path);
}

int compiler_native_include(const char* directory) {
    return append_joined_argument(&g_native_flags, "-I", directory, "");
}

int compiler_native_define(const char* definition) {
    return append_joined_argument(&g_native_flags, "-D", definition, "");
}

int compiler_native_flag(const char* flag) {
    return append_quoted_argument(&g_native_flags, flag);
}

int compiler_native_response_file(const char* path) {
    return push_string(&g_native_flag_files, &g_native_flag_file_count,
                       &g_native_flag_file_cap, path)
        || append_joined_argument(&g_native_flags, "@", path, "");
}

void compiler_set_installed_runtime(int on) { g_installed_runtime = on ? 1 : 0; }
void compiler_set_freestanding(int on) { g_freestanding = on ? 1 : 0; }
int compiler_is_freestanding(void) { return g_freestanding; }

// One linker argument as written, for `--link-arg`. The same list a manifest's
// `link { }` block feeds, so the order is the order given. Not counted as linked
// code (compare compiler_link_file): `-T kernel.ld` adds no symbol a Prismio
// function could be called through, so it does not stop `program_is_closed`.
int compiler_link_flag(const char* flag) {
    return compiler_link_append_argument(flag);
}
void compiler_set_export_dynamic(int on) { g_export_dynamic = on ? 1 : 0; }

static int compiler_link_inputs_supported(void) {
    if (g_native_link_has_framework && !target_is_mach_o()) {
        fprintf(stderr,
                "ERROR: framework(...) is available only when building a Mach-O target.\n");
        return 0;
    }
    return 1;
}

// LAYOUT 3.2. A workload driver calls rt_profile_*, and an *installed*
// runtime.lib may predate them -- it is a binary someone built at some point,
// and this feature is newer than some of those points. The link then fails on
// six symbols and W2 turns it into a fallback, so the effect is a workload that
// silently never runs on exactly the machines where the toolchain was installed
// rather than built.
//
// This is the same shape as the verify flag above and is here for the same
// reason: a build mode whose object code needs something the installed library
// cannot be assumed to contain must compile the runtime itself. It differs in
// one way worth stating -- verify compiles from source to change the runtime's
// *behaviour*, this one only to guarantee its *vintage*. Nothing is defined and
// the generated code is unaffected.
//
static int g_workload_mode = 0;

void compiler_set_workload_mode(int on) { g_workload_mode = on ? 1 : 0; }

// IR -> object.
//
// This was `llc <ir> -filetype=obj` for a long time, and that ran the *codegen*
// pipeline only -- isel, scheduling, register allocation. llc does not run the
// IR pipeline, so mem2reg, SROA, GVN, LICM, inlining and vectorisation never
// touched a user program: every local stayed a stack slot and every field read
// was reloaded. Measured at 1.4x-3.0x across the retired corpus (RESULTS-xlang 3.1).
//
// clang runs both pipelines in one process, is already required for the link,
// and takes .ll directly -- which is why compiler_temp_ir_path spells the
// suffix `.ll`. It also drops llc from the user-build path entirely.
//
// -O2 rather than -O3: measured across the corpus, -O3 lands between 0.98x and
// 1.03x of -O2, which is noise, and costs the same compile time
// (aif/evidence/xlang/optlevel.py). -flto is speed-neutral too and worth ~15%
// of binary size, but needs linker plugin support that is not portable enough
// to make a default.
// Both live in the object-cache section below and are used here: the curated
// module is cached on the same key shape and in the same directory as the
// toolchain objects, because it is the same kind of thing -- a build product of
// the runtime sources that no program-specific input can change.
static char* object_cache_dir(void);
static char* object_cache_temp_path(const char* entry);
static int object_cache_disabled(void);
static int object_cache_trace(void);

// M1.1 -- the curated inlinable module
// Every container access in a Prismio loop is a `bl` into the separately
// compiled C runtime, and the optimiser cannot see through it. Measured, that
// seam is worth 1.03x-2.31x across the corpus and 2.00x on g2_tuned
// (aif/evidence/RESULTS-M1-lto.md).
// The fix is Swift's `@inlinable` spelled at IR level: take the hot container
// ops out of the runtime's own IR, rewrite their linkage to
// `available_externally` -- the body is visible to the inliner but emits no
// code -- and link that module into the program's before -O2. Calls that do not
// get inlined still resolve to the runtime archive's copy, so nothing is
// defined twice and the ordinary native link is unchanged.
// **Why not -flto.** It was measured and it does not work here without more
// machinery, for a reason worth recording: the backend emits program functions
// carrying no target attributes at all, while clang stamps `target-cpu` and a
// 33-entry `target-features` on every runtime function, so the LTO inliner
// answers `cost=never: conflicting attributes` before it ever prices the call.
// Making that match needs the *exact* string clang used -- a superset fails, a
// newer CPU fails, and LLVMGetHostCPUName() answers a different chip than clang
// picks on this host. Merging sidesteps all of it, because `clang -O2` on the
// merged module fills its own defaults into the attribute-less functions, and
// does so self-consistently under --target since one invocation supplies both
// halves. The merge is also faster to compile (1.18x against -flto's 1.21x and
// a whole-runtime merge's 1.88x) and needs no linker plugin.
// **The curated set is not a list of whatever looked hot.** A function may be
// curated only if every symbol its body references is *exported* by the runtime
// object. A `static` in lang_runtime.c is absent from that object's symbol
// table, so inlining a body that reads one produces a program referencing a
// symbol nothing defines, and the link fails with "Undefined symbols ...
// _arena_alloc_slot". That is a reproduced failure, not a worry.
// `run_curated_closure_test` asserts the property rather than trusting it.
// `list_push` is the case worth knowing about, because it failed the rule twice
// over and both halves had to be fixed:
//   1. *It referenced three `static`s* -- rt_arena_hint, arena_depth and
//      arena_alloc_slot, all reached through rt_alloc on the growth path.
//   2. *It was too big to inline anyway.* The inliner priced it at cost=675
//      against a threshold of 225 and declined at every site, so adding it to
//      this list changed nothing at all: the emitted call counts were identical
//      with and without it, and the timing differences between those two builds
//      were pure measurement noise.
// Outlining the growth half into `list_push_grow` fixes both at once -- it takes
// the three statics with it, and it drops the remaining fast path from 227 IR
// lines to 69. See the comment on list_push_grow in lang_runtime.c.
// **`list_get_inline` was missing and it is the one codegen actually calls.**
// M1.1 curated `list_get`; M4.2 then added the `_inline` family and taught
// `inlineOpName` (src/ir/expr.psm) to emit those instead wherever the element
// type is statically flat -- and this list was not updated with it. So every
// corpus program with a flat element list paid a real `bl` per element access,
// through a five-line function, with the seam this whole mechanism exists to
// remove sitting right back in the hot loop. g4's movement system was two calls
// per iteration and no vectorization at all.
//
// It satisfies the closure rule trivially: its body references no symbols, only
// fields of RtList.
//
// **Its two struct siblings remain absent by measurement.** Curating
// `list_set_inline` and `list_push_inline` was 0.999x on the corpus for +3.1%
// compiler time, so their waiver is a result rather than an implementation gap.
// **`rt_free` is absent for the same reason, and it was tried.** Codegen emits it
// for every release, so it looked like the obvious next entry; curating it does
// inline the gate into the caller and remove a call per release, and it moved
// nothing. `tokenization` 1.67x against 1.72x uncurated and `tree_traversal`
// 0.953x against 0.960x are both inside this suite's noise. The cost that shows
// on a bulk-free shape is the gate's own load and branch, which inlining keeps;
// only a release that carries the block's size could drop it, and that is an ABI
// change rather than a curation one. Curating it also needs three of
// lang_runtime.c's `static`s exported to satisfy the closure rule, which is real
// surface for no measured gain.
// **`list_get_inline_scalar` belongs here for the same reason and by the same
// test.** It is what codegen emits for every read of a scalar-element list, and
// it satisfies the closure rule as trivially as `list_get_inline` does: its body
// calls nothing, and touches only fields of RtList. Left out, a `List<Int>` read
// pays a real `bl` per element -- measured at **8.9x** on a read loop, which is
// the whole of what putting scalars inline was supposed to buy.
//
// Its scalar write siblings are curated too. `scalar_store` folds into their
// bodies; representation fallback and growth cross the runtime boundary through
// exported
// `list_push_inline_scalar_slow`. That mirrors `list_push_grow`: the copied fast
// path stays cheap enough to inline and no arena-allocation static leaks into a
// program module.
//
// **The `List<String>` accessors are here for the same reason as the scalar
// ones**: they are what codegen emits for every element read and write of a
// String list, and a real `bl` per read is the cost the pair representation
// exists to remove. Growth, view copies and the boxed fallback cross the
// boundary through the exported `list_push_str_slow` and `list_set_str_slow`.
static const char* const PRISMIO_CURATED_OPS[] = {
    "list_get", "list_get_inline", "list_get_inline_scalar",
    "list_set_inline_scalar", "list_push_inline_scalar", "list_set", "list_len",
    "list_set_elem_owner", "list_set_elem_releaser",
    "rc_retain", "rc_release", "list_push",
    "list_str_data", "list_str_word", "list_push_str", "list_set_str",
    "data_view_check_index", "data_view_column", "data_view_len",
};
#define PRISMIO_CURATED_OP_COUNT \
    ((int)(sizeof(PRISMIO_CURATED_OPS) / sizeof(PRISMIO_CURATED_OPS[0])))
// The cache also depends on transformations performed by ir_curate_module,
// which are not bytes in lang_runtime.c. Bump this whenever that curation
// policy changes; M4.3c added invariant ready-view loads and exposed that the
// old key could otherwise reuse a semantically older curated module forever.
#define PRISMIO_CURATED_SCHEMA "curated-v8-string-pairs"

// On by default after the curated-module path became part of the ordinary
// Windows/Linux/macOS suite. `0` remains the measurement and emergency opt-out:
// the same compiler can still produce the old separate-runtime build without a
// revert, which is useful both for attribution and for diagnosing a toolchain.
static int inline_runtime_enabled(void) {
    const char* v = getenv("PRISMIO_INLINE_RUNTIME");
    return !(v && v[0] == '0' && v[1] == '\0');
}

// A cold inline-runtime build already asks clang to parse and optimise
// lang_runtime.c into LLVM IR. Keep that raw module until the runtime object is
// requested later in the same build, so clang can lower it directly instead of
// parsing and optimising the same C translation unit a second time. This is a
// transient within one compiler process, never a cache entry and never shared
// between builds.
static char* g_curated_raw_ir = NULL;

static void discard_curated_raw_ir(void) {
    if (!g_curated_raw_ir) return;
    delete_file(g_curated_raw_ir);
    free(g_curated_raw_ir);
    g_curated_raw_ir = NULL;
}

// Produce the curated module, or NULL if it cannot be produced for any reason.
//
// NULL is always safe: the caller compiles exactly as it did before. That is the
// same contract object_cache_path has, and for the same reason -- an
// optimisation that can fail a build is worse than no optimisation.
//
// Cached on the content of lang_runtime.c plus the compile flags, because the
// module is a function of both and of nothing else in the program being built.
// It is therefore produced once per toolchain per target and reused by every
// subsequent build, which is what keeps the steady-state cost at one in-process module merge.
static char* build_curated_module(const char* target_flags) {
    discard_curated_raw_ir();
    char lr_source[1024];
    if (!find_toolchain_source(lr_source, sizeof(lr_source), "lang_runtime.c")) return NULL;

    char* text = read_file(lr_source);
    if (!text) return NULL;

    // --verify compiles the runtime with -DPRISMIO_AIF_VERIFY, so its IR
    // differs and a module built for one mode must not serve the other. Same
    // hazard the object cache guards, same fix.
    const char* verify = g_verify_mode ? "-DPRISMIO_AIF_VERIFY " : "";

    unsigned long long hash = PRISMIO_FNV_OFFSET;
    hash = fnv1a_bytes(hash, (const unsigned char*)PRISMIO_CURATED_SCHEMA);
    hash = fnv1a_bytes(hash, (const unsigned char*)target_flags);
    hash = fnv1a_bytes(hash, (const unsigned char*)verify);
    hash = fnv1a_bytes(hash, (const unsigned char*)text);
    for (int i = 0; i < PRISMIO_CURATED_OP_COUNT; i++) {
        hash = fnv1a_bytes(hash, (const unsigned char*)PRISMIO_CURATED_OPS[i]);
    }
    free(text);

    char* dir = object_cache_dir();
    if (!dir) return NULL;
    if (ensure_directory_exists(dir) != 0) { free(dir); return NULL; }

    char name[128];
    snprintf(name, sizeof(name), "curated-%016llx.ll", hash);
    char* entry = join_path(dir, name);
    free(dir);
    if (!entry) return NULL;

    // PRISMIO_OBJ_CACHE=0 has to reach this cache too, and for the same reason
    // it exists for the objects: the key covers the source and the flags but
    // *not* the clang that turned one into the other, so an in-place toolchain
    // upgrade leaves a stale entry that nothing notices. A bypass that skipped
    // only half the build products would be a bypass that does not bypass.
    //
    // It also makes "cold build" mean the same thing here as everywhere else,
    // which is what the compile-time measurement depends on.
    int bypass = object_cache_disabled();
    if (bypass) {
        if (object_cache_trace()) fprintf(stderr, "[objcache off] curated\n");
    } else if (file_exists(entry)) {
        if (object_cache_trace()) fprintf(stderr, "[objcache hit] curated\n");
        return entry;
    } else if (object_cache_trace()) {
        fprintf(stderr, "[objcache miss] curated\n");
    }

    // Built to a pid-qualified sibling and renamed into place, never written at
    // the cache path directly -- two builds racing on one entry would otherwise
    // link a half-written module. See object_cache_temp_path.
    char* tmp_ll = object_cache_temp_path(entry);
    char* tmp_raw = NULL;
    int failed = 0;

    {
        size_t n = strlen(tmp_ll) + 16;
        tmp_raw = (char*)malloc(n);
        if (!tmp_raw) { failed = 1; }
        else snprintf(tmp_raw, n, "%s.raw.bc", tmp_ll);
    }

    char* q_src = failed ? NULL : command_quote_arg(lr_source);
    char* q_tmp = failed ? NULL : command_quote_arg(tmp_ll);
    char* q_raw = failed ? NULL : command_quote_arg(tmp_raw);

    if (!failed) {
        int len = (int)(strlen(q_src) + strlen(q_tmp) + strlen(q_raw)
                        + strlen(target_flags) + 256
                        + PRISMIO_CURATED_OP_COUNT * 64);
        char* command = (char*)malloc(len);
        if (!command) failed = 1;

        // 1. the runtime's own IR, at the same -O2 the runtime object is built
        //    with, so the bodies being inlined are the bodies that would have
        //    been called.
        //
        //    **Bitcode, not textual IR**, because this module is also what the
        //    runtime object is lowered from later in the build. Measured on this
        //    host: the bitcode round trip produces an object *byte-identical* to
        //    `clang -O2 -c lang_runtime.c`, and the textual one does not.
        if (!failed) {
            snprintf(command, len, "%s %s%s-O2 -Wno-deprecated-declarations -emit-llvm -c %s -o %s",
                     native_clang_command(), target_flags, verify, q_src, q_raw);
            double t0 = build_trace_ms();
            if (run_build_command(command) != 0) failed = 1;
            build_trace_stage("curated: runtime IR", t0);
        }

        free(command);
    }

    // 2. the curated ops out of it, in process. Everything else is reduced to a
    //    declaration and then dropped, which is what makes the module small
    //    enough that the merge costs 1.18x rather than the whole runtime's
    //    1.88x. Byte-identical to what `llvm-extract` produced when this was a
    //    shell-out, which is how the port was checked.
    if (!failed) {
        double t0 = build_trace_ms();
        if (ir_curate_module(tmp_raw, PRISMIO_CURATED_OPS,
                             PRISMIO_CURATED_OP_COUNT, tmp_ll) != 0) {
            failed = 1;
        }
        build_trace_stage("curated: extract", t0);
    }

    // A bypassed cache builds to the temporary and uses it in place; installing
    // it would repopulate the very entry the caller asked to skip.
    if (!failed && bypass) {
        free(q_src); free(q_tmp); free(q_raw);
        g_curated_raw_ir = tmp_raw;
        tmp_raw = NULL;
        free(entry);
        return tmp_ll;
    }

    if (!failed && fs_rename(tmp_ll, entry) != 0) {
        // A failed install is not a failed build: use the temporary this once
        // and pay for it again next time.
        free(q_src); free(q_tmp); free(q_raw);
        g_curated_raw_ir = tmp_raw;
        tmp_raw = NULL;
        free(entry);
        return tmp_ll;
    }

    free(q_src); free(q_tmp); free(q_raw);

    if (failed) {
        if (tmp_raw) { delete_file(tmp_raw); free(tmp_raw); }
        delete_file(tmp_ll);
        free(tmp_ll);
        free(entry);
        return NULL;
    }

    g_curated_raw_ir = tmp_raw;
    tmp_raw = NULL;
    free(tmp_ll);
    return entry;
}

// Merge the curated module into the program's, returning a path to the merged
// IR, or NULL to compile the program's IR unchanged.
static char* merge_curated_into_program(const char* ir_file, const char* target_flags) {
    char* curated = build_curated_module(target_flags);
    if (!curated) return NULL;

    size_t n = strlen(ir_file) + 32;
    char* merged = (char*)malloc(n);
    if (!merged) { free(curated); return NULL; }
    snprintf(merged, n, "%s.merged.ll", ir_file);

    double t0 = build_trace_ms();
    int ok = ir_link_modules(ir_file, curated, merged) == 0;
    build_trace_stage("curated: merge", t0);
    free(curated);

    if (!ok) {
        delete_file(merged);
        free(merged);
        return NULL;
    }
    return merged;
}

// `PRISMIO_CODEGEN=clang` restores the old route, for comparing the two. It is a
// measurement switch, not a supported mode: it needs the pinned clang.
static int codegen_uses_clang(void) {
    const char* v = getenv("PRISMIO_CODEGEN");
    return v && strcmp(v, "clang") == 0;
}

// `-mmacosx-version-min=<v> `, or "" -- the macOS version a build's objects are
// compiled for (ir_host_macos_version), for the clang that compiles its native C
// or links it. Without it clang uses its SDK's version, and an executable needs
// the newest macOS of any object in it. A host build on a Mac needs it, and so
// does a `--target` that names macOS without a version, which ir_emit_object
// fills in the same way; a triple with a version carries its own.
static void macos_min_flag(char* out, size_t size) {
    out[0] = '\0';
    int wants = 0;
    if (!ir_target_is_explicit()) {
#ifdef __APPLE__
        wants = !codegen_uses_clang();
#endif
    } else {
        const char* triple = ir_target_triple();
        size_t n = strlen(triple);
        wants = (n >= 6 && strcmp(triple + n - 6, "-macos") == 0) ||
                (n >= 7 && strcmp(triple + n - 7, "-macosx") == 0);
    }
    if (wants && ir_host_macos_version()[0]) {
        snprintf(out, size, "-mmacosx-version-min=%s ", ir_host_macos_version());
    }
}

// Whether every caller of the program's functions is in the merged module, so
// all but `main` can be internal (internalize_executable, llvm-api-backend.c).
// C the target compiles or links may call a Prismio function by its symbol, and
// exportDynamic exists so that code loaded at run time can.
static int program_is_closed(void) {
    return g_native_source_count == 0 && !g_native_link_has_code && !g_export_dynamic;
}

// `*extra_objects` is how many objects beyond `program_obj` the in-process
// emission wrote, one per extra codegen partition (ir_partition_object_path).
static int compile_ir_to_object(const char* ir_file, const char* program_obj,
                                int* extra_objects) {
    *extra_objects = 0;
    // In process first. The clang command below is what this reproduces, flag
    // for flag, and stays as the fallback for a backend built without headers.
    diag_progress(g_debug_info ? "generating code" : "optimizing");
    if (!codegen_uses_clang()) {
        double t0 = build_trace_ms();
        int emitted = ir_emit_object(ir_file, program_obj,
                                     ir_target_is_explicit() ? ir_target_triple() : NULL,
                                     g_debug_info ? 0 : 3, program_is_closed(),
                                     extra_objects);
        build_trace_stage("program -O3 (whole program, in process)", t0);
        if (emitted >= 0) return emitted;
    }

    char* target = target_clang_flags();
    char* q_ir = command_quote_arg(ir_file);
    char* q_obj = command_quote_arg(program_obj);
    // The driver's own path counts too. Leaving it out went unnoticed while it
    // was Homebrew's 43-character Cellar path; the pinned toolchain's lives in
    // the checkout, and the truncated command lost its closing quote.
    int len = (int)(strlen(native_clang_command()) + strlen(q_ir) + strlen(q_obj)
                    + strlen(target) + 160);
    char* command = (char*)malloc(len);

    // --target as well as the triple already written on the module: clang needs
    // the flag to pick the right assembler and object format.
    //
    // **-Wno-override-module, and the reason it is not a papered-over bug.**
    // The clang *driver* always compiles for the SDK's deployment target --
    // arm64-apple-macosx26.0.0 here -- while a module carries at most what
    // LLVMGetDefaultTargetTriple() gives, arm64-apple-darwin25.5.0. Those never
    // match, so clang always overrides and always warns. Measured: it warns
    // identically against a module with **no triple at all**, which a plain host
    // build emits, so this was never about what we stamp and could not be fixed
    // by stamping better or by stamping nothing.
    //
    // What the warning could in principle have caught is a real ABI
    // disagreement between the triple we describe `-g` offsets against and the
    // one clang codegens for. That is worth keeping, so it is now an assertion
    // instead of a warning: run_target_test requires the data layout we stamp to
    // equal the one clang computes for the same target, for the host and for
    // wasm32. A warning on every build that everyone learns to scroll past is
    // worth less than one test that fails.
    //
    // Flat List access has one loop-invariant fallback branch: inline bodies
    // when elem_size is non-zero, boxed pointers otherwise. LLVM 22's ordinary
    // O2 pipeline hoists the header loads but leaves that branch in every
    // iteration. Non-trivial unswitching versions the loop once and then
    // vectorises each version. On the seven-program gate it is neutral at the
    // median and improves g4 by 11.1%, reproduced at 14.3% in the five-arm run;
    // g5 is too layout-noisy to claim. Every checksum is unchanged. g4's
    // program-O2 stage costs about 6 ms more (56 ms to 62 ms). Two executables
    // grow by 16 KiB, still more than 4x smaller than the Rust controls.
    // **-O3, and the -O2 that used to be here was measured on a compiler that
    // could not vectorise.** The old note recorded -O3 as "between 0.98x and
    // 1.03x of -O2, which is noise, and costs the same compile time". Re-run on
    // the benchmark suite after the loop guard landed, that is no longer true:
    // `tokenization` is **0.64x** at -O3, with knapsack 0.96, convolution 0.96
    // and mergesort 0.97. `prime_sieve` is the one loss at 1.06.
    //
    // It also settles a fairness question: the C++ arm of the cross-language
    // suite is built `-O3` and the Rust arm `opt-level=3`, so an -O2 Prismio was
    // being compared against two rivals at their highest setting.
    //
    // Priced: +16 bytes on the benchmark suite executable, and suite compile
    // time 0.56s -> 0.59s.
    snprintf(command, len,
             "%s %s-Wno-override-module %s -c %s -o %s",
             native_clang_command(), target,
             g_debug_info ? "-O0" : "-O3 -mllvm -enable-nontrivial-unswitch",
             q_ir, q_obj);
    double t0 = build_trace_ms();
    int result = run_build_command(command);
    build_trace_stage("program -O3 (whole program)", t0);
    free(command);
    free(target);
    free(q_ir);
    free(q_obj);
    return result;
}

// Who links a program. The object is finished machine code by now, and object
// files do not care which LLVM wrote them, so this is the one step that can use
// the *system's* toolchain -- the way rustc hands its objects to `cc`. The
// system linker is not optional anyway: it comes with the C library and SDK a
// program links against (Xcode's Command Line Tools, a distribution's libc
// development files, Visual Studio's C++ tools).
//
// In order: PRISMIO_CC; the pinned clang, when this compiler runs from a
// checkout that has one (so development builds link exactly as before); then
// `cc`. A cross build needs a driver that takes `--target`, which `cc` is only
// when it is clang. A Windows host build does not come here at all: it links
// with MSVC's link.exe (link_program_msvc) unless PRISMIO_CC says otherwise.
static const char* link_driver_command(void) {
    static char command[1200];
    static int ready = 0;
    if (ready) return command;
    ready = 1;
    const char* env = getenv("PRISMIO_CC");
    native_clang_command();
    if (env && *env) {
        snprintf(command, sizeof(command), "%s", env);
    } else if (g_clang_binary[0]) {
        snprintf(command, sizeof(command), "%s", native_clang_command());
    } else {
#ifdef _WIN32
        snprintf(command, sizeof(command), "clang");
#else
        snprintf(command, sizeof(command), ir_target_is_explicit() ? "clang" : "cc");
#endif
    }
    return command;
}

#ifdef _WIN32
// Linking a Windows program with MSVC's link.exe
//
// This step used to run `clang` as the link driver, which meant a Windows user
// needed LLVM installed to build a program, while macOS and Linux needed only the
// system's `cc`. clang never did the linking itself: it found Visual Studio and
// the Windows SDK and ran their link.exe. The libraries it links against
// (libcmt, kernel32, the UCRT) come only from there, so a Windows machine that
// can link a C program has link.exe already, and running it directly removes the
// one piece of LLVM a user build still needed.
//
// What follows is the part of clang's MSVC toolchain the link used: find the
// tools, find the SDK, and pass the same arguments clang did -- `-out:`,
// `-defaultlib:libcmt -defaultlib:oldnames`, `-nologo` and the library paths.
//
// **A developer prompt is taken as it is.** vcvars sets VCToolsInstallDir, and
// LIB with every library directory; clang adds no -libpath when LIB is set, and
// neither does this. Outside one -- the usual case, and CI's -- the tools come
// from vswhere, which every Visual Studio 2017+ and Build Tools install carries,
// and the SDK from the newest `Windows Kits\10\Lib\10.*` that has this
// architecture's kernel32.lib and ucrt.lib. Not from the registry, which is
// what clang also consults: an SDK installed outside Program Files is found
// only through WindowsSdkDir, that is, from a developer prompt.

static const char* msvc_target_arch(void) {
#if defined(_M_ARM64) || defined(__aarch64__)
    return "arm64";
#elif defined(_M_X64) || defined(__x86_64__)
    return "x64";
#else
    return "x86";
#endif
}

static void trim_trailing_space(char* text) {
    for (int i = (int)strlen(text) - 1; i >= 0; i--) {
        if (text[i] != '\n' && text[i] != '\r' && text[i] != ' ' && text[i] != '\t') break;
        text[i] = '\0';
    }
}

// The VC tools directory, `...\VC\Tools\MSVC\<version>`, or 0.
static int msvc_tools_dir(char* out, size_t size, const char* exe_file) {
    const char* env = getenv("VCToolsInstallDir");
    if (env && *env) {
        snprintf(out, size, "%s", env);
        trim_trailing_space(out);
        size_t n = strlen(out);
        if (n > 0 && (out[n - 1] == '\\' || out[n - 1] == '/')) out[n - 1] = '\0';
        return 1;
    }

    const char* program_files = getenv("ProgramFiles(x86)");
    if (!program_files || !*program_files) program_files = "C:\\Program Files (x86)";
    char vswhere[1024];
    snprintf(vswhere, sizeof(vswhere),
             "%s\\Microsoft Visual Studio\\Installer\\vswhere.exe", program_files);
    if (!file_exists(vswhere)) return 0;

    char* answer_path = compiler_temp_path(exe_file, "vswhere.txt");
    char* q_vswhere = command_quote_arg(vswhere);
    char* q_answer = command_quote_arg(answer_path);
    char command[2560];
    snprintf(command, sizeof(command),
             "%s -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.%s "
             "-property installationPath > %s",
             q_vswhere, strcmp(msvc_target_arch(), "arm64") == 0 ? "ARM64" : "x86.x64",
             q_answer);
    free(q_vswhere);
    free(q_answer);
    char* install = execute_command(command) == 0 ? read_file(answer_path) : NULL;
    delete_file(answer_path);
    free(answer_path);
    if (!install) return 0;
    char* newline = strpbrk(install, "\r\n");
    if (newline) *newline = '\0';
    if (!install[0]) { free(install); return 0; }

    char version_path[1400];
    snprintf(version_path, sizeof(version_path),
             "%s\\VC\\Auxiliary\\Build\\Microsoft.VCToolsVersion.default.txt", install);
    char* version = read_file(version_path);
    if (version) {
        trim_trailing_space(version);
        snprintf(out, size, "%s\\VC\\Tools\\MSVC\\%s", install, version);
        free(version);
    }
    free(install);
    return version != NULL;
}

// `10.0.26100.0` against `10.0.22621.0`, part by part.
static int compare_dotted_versions(const char* a, const char* b) {
    while (*a || *b) {
        long x = strtol(a, (char**)&a, 10);
        long y = strtol(b, (char**)&b, 10);
        if (x != y) return x < y ? -1 : 1;
        if (*a == '.') a++;
        if (*b == '.') b++;
        if ((*a && (*a < '0' || *a > '9')) || (*b && (*b < '0' || *b > '9'))) break;
    }
    return 0;
}

// The Windows 10+ SDK's `Lib\<version>` directory, or 0.
static int windows_sdk_lib_dir(char* out, size_t size) {
    const char* arch = msvc_target_arch();
    char root[1024];
    const char* env_dir = getenv("WindowsSdkDir");
    if (env_dir && *env_dir) {
        snprintf(root, sizeof(root), "%s", env_dir);
    } else {
        const char* program_files = getenv("ProgramFiles(x86)");
        if (!program_files || !*program_files) program_files = "C:\\Program Files (x86)";
        snprintf(root, sizeof(root), "%s\\Windows Kits\\10", program_files);
    }
    size_t n = strlen(root);
    if (n > 0 && (root[n - 1] == '\\' || root[n - 1] == '/')) root[n - 1] = '\0';

    char pattern[1100];
    snprintf(pattern, sizeof(pattern), "%s\\Lib\\10.*", root);
    WIN32_FIND_DATAA entry;
    HANDLE search = FindFirstFileA(pattern, &entry);
    if (search == INVALID_HANDLE_VALUE) return 0;
    char best[MAX_PATH] = "";
    do {
        if (!(entry.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)) continue;
        char kernel32[1400], ucrt[1400];
        snprintf(kernel32, sizeof(kernel32), "%s\\Lib\\%s\\um\\%s\\kernel32.lib",
                 root, entry.cFileName, arch);
        snprintf(ucrt, sizeof(ucrt), "%s\\Lib\\%s\\ucrt\\%s\\ucrt.lib",
                 root, entry.cFileName, arch);
        if (!file_exists(kernel32) || !file_exists(ucrt)) continue;
        if (!best[0] || compare_dotted_versions(entry.cFileName, best) > 0) {
            snprintf(best, sizeof(best), "%s", entry.cFileName);
        }
    } while (FindNextFileA(search, &entry));
    FindClose(search);
    if (!best[0]) return 0;
    snprintf(out, size, "%s\\Lib\\%s", root, best);
    return 1;
}

static int link_program_msvc(const char* program_obj, const char* exe_file) {
    const char* arch = msvc_target_arch();
    char tools[1024];
    if (!msvc_tools_dir(tools, sizeof(tools), exe_file)) {
        diag_progress_clear();
        fprintf(stderr,
                "ERROR: linking a Windows program needs Microsoft's C++ build tools, and\n"
                "       none were found. Install Visual Studio or its Build Tools with the\n"
                "       \"Desktop development with C++\" workload, or set PRISMIO_CC to a\n"
                "       linker driver such as clang.\n");
        return 1;
    }
    const char* host = strcmp(arch, "arm64") == 0 ? "Hostarm64"
                     : strcmp(arch, "x64") == 0 ? "Hostx64" : "Hostx86";
    char link_exe[1200];
    snprintf(link_exe, sizeof(link_exe), "%s\\bin\\%s\\%s\\link.exe", tools, host, arch);
    if (!file_exists(link_exe)) {
        diag_progress_clear();
        fprintf(stderr, "ERROR: the C++ build tools at %s have no %s link.exe\n", tools, arch);
        return 1;
    }

    char* libpaths = NULL;
    const char* lib_env = getenv("LIB");
    if (!lib_env || !*lib_env) {
        char sdk[1200];
        if (!windows_sdk_lib_dir(sdk, sizeof(sdk))) {
            diag_progress_clear();
            fprintf(stderr,
                    "ERROR: linking a Windows program needs the Windows SDK, and none with\n"
                    "       %s libraries was found under Windows Kits\\10. Install it with\n"
                    "       the \"Desktop development with C++\" workload.\n", arch);
            return 1;
        }
        char dir[1400];
        snprintf(dir, sizeof(dir), "%s\\lib\\%s", tools, arch);
        int failed = append_joined_argument(&libpaths, "-libpath:", dir, "");
        snprintf(dir, sizeof(dir), "%s\\ucrt\\%s", sdk, arch);
        failed |= append_joined_argument(&libpaths, "-libpath:", dir, "");
        snprintf(dir, sizeof(dir), "%s\\um\\%s", sdk, arch);
        failed |= append_joined_argument(&libpaths, "-libpath:", dir, "");
        if (failed) { free(libpaths); return 1; }
    }

    char* q_link = command_quote_arg(link_exe);
    char* q_obj = command_quote_arg(program_obj);
    char* out_arg = NULL;
    append_joined_argument(&out_arg, "-out:", exe_file, "");
    const char* native = g_native_link_args_msvc ? g_native_link_args_msvc : "";
    size_t len = strlen(q_link) + strlen(q_obj) + (out_arg ? strlen(out_arg) : 0)
                 + (libpaths ? strlen(libpaths) : 0) + strlen(g_link_extra)
                 + strlen(native) + 128;
    char* command = (char*)malloc(len);
    int result = 1;
    if (command && out_arg) {
        // -Brepro: without it link.exe stamps the wall clock into every PE header,
        // so relinking identical objects gives different bytes. The local toolchain
        // keys each stdlib .plib on the compiler binary's hash, and on Windows an
        // unchanged `prismio build` rebuilt all of them -- ld64 and lld on the other
        // platforms were already deterministic, which is why only Windows missed.
        // -STACK:16 MiB. A Windows executable's main thread gets 1 MiB unless the
        // image says otherwise, where macOS and Linux give 8 -- and the compiler is
        // deeply recursive: a seed-built compiler died with a stack overflow
        // (0xC00000FD) on its first real input, with no message. It is address
        // space reserved, not memory committed. tools/bootstrap.ps1 sets the same
        // value for the generations it links itself.
        snprintf(command, len,
                 "%s%s -defaultlib:libcmt -defaultlib:oldnames -nologo -Brepro -STACK:16777216%s %s%s%s",
                 q_link, out_arg, libpaths ? libpaths : "", q_obj, g_link_extra, native);
        result = run_build_command(command);
    }
    free(command);
    free(out_arg);
    free(libpaths);
    free(q_link);
    free(q_obj);
    return result;
}
#endif

// Whether the C library keeps `sin`, `sqrt` and the rest in a separate libm,
// and threads in a separate libpthread. glibc and musl do, and clang links
// neither by default: the benchmark suite's fft and raytracer failed CI's first
// Linux link with `undefined reference to cos`. Darwin's libSystem and the
// Windows CRT carry them, and wasm targets get them from their own libc.
//
// libpthread is the one a new glibc hides. Since 2.34 the threads live in libc
// and libpthread is an empty stub, so a program links on the machines this was
// built on and fails on Ubuntu 20.04, Debian 11 or RHEL 8, whose glibc keeps
// `pthread_create` and `pthread_once` -- both of which the runtime calls -- in
// libpthread alone.
static int target_splits_libc(void) {
    if (!ir_target_is_explicit()) {
#if defined(__APPLE__) || defined(_WIN32)
        return 0;
#else
        return 1;
#endif
    }
    const char* t = ir_target_triple();
    return strstr(t, "linux") != NULL || strstr(t, "bsd") != NULL;
}

// The runtime has already been linked into the program's LLVM module before
// optimisation. The native link therefore receives one program object plus any
// explicit UMS inputs; there is no opaque runtime archive at this boundary.
static int link_program_object(const char* program_obj, const char* exe_file) {
#ifdef _WIN32
    // Native objects, a response file and an export table are all spelled for a
    // clang driver, so a target with any of them links through one.
    int needs_driver = g_native_source_count > 0 || g_native_link_needs_driver ||
                       g_export_dynamic;
    const char* chosen = getenv("PRISMIO_CC");
    if ((!chosen || !*chosen) && !ir_target_is_explicit() && !needs_driver) {
        return link_program_msvc(program_obj, exe_file);
    }
#endif
    char* q_obj = command_quote_arg(program_obj);
    char* q_exe = command_quote_arg(exe_file);
    char* target = target_clang_flags();
    const char* native = g_native_link_args ? g_native_link_args : "";
    // A build for macOS states the deployment version its object was compiled
    // for, rather than letting the driver default to its SDK's.
    char min_os[64];
    macos_min_flag(min_os, sizeof(min_os));
    // The 16 MiB stack link_program_msvc gives every program it links, for the
    // links that go through a driver instead. A project host is one of them -- it
    // has native sources and exports -- and at Windows' default 1 MiB it overflowed
    // (0xC00000FD) compiling the first standard library module, which left the
    // host built and unable to build anything else.
    const char* stack = "";
#ifdef _WIN32
    if (!ir_target_is_explicit() || strstr(ir_target_triple(), "windows") != NULL) {
        stack = " -Wl,/STACK:16777216";
    }
#endif
    const char* driver = link_driver_command();
    int len = (int)(strlen(driver) + strlen(min_os) + strlen(q_obj) + strlen(q_exe) +
                    strlen(target) + strlen(native) + strlen(g_link_extra) +
                    strlen(stack) + 128);
    char* command = (char*)malloc(len);

    // -dead_strip: ld64 keeps every function of every object it is given unless
    // told otherwise, and neither the runtime's nor a target's native C is
    // pruned before it gets there. Exported symbols (exportDynamic) are roots,
    // so nothing a loaded module could resolve is removed.
    // Freestanding: no C library and no startup files, a static image, and lld.
    // The system linker on a macOS or Linux host links for that host's format and
    // cannot place an ELF kernel at the address its script names; lld takes
    // `--target` and the script the same way on every host. `--ld-path=` through
    // `--link-arg` picks one that is not on PATH.
    const char* mode = g_freestanding ? "-nostdlib -static -fuse-ld=lld " : "";
    snprintf(command, len, "%s %s%s%s%s%s%s%s -o %s%s%s",
             driver, target, min_os, mode, q_obj, g_link_extra, native, stack, q_exe,
             (!g_freestanding && target_splits_libc()) ? " -lm -lpthread" : "",
             (!g_freestanding && target_is_mach_o()) ? " -Wl,-dead_strip" : "");
    int result = run_build_command(command);

    free(command);
    free(target);
    free(q_obj);
    free(q_exe);
    return result;
}

// The section compiled for the target this build is producing, or NULL.
//
// **A PLIB section for another target is never a fallback.** Before sections were
// per target, a `--target x86_64-apple-macos` build on an arm64 host merged the
// arm64 bitcode of every non-generic `std` function: LLVM warned that the triples
// and data layouts differed, adopted the arm64 triple for the merged module, and
// the build went on. For a 32-bit target the pointer width differs as well. A
// missing section is therefore an installation error, exactly as a missing
// `lib/runtime/<triple>/` module is.
static const PrismioPlibSection* plib_section_for_target(const PrismioPlib* plib) {
    const char* triple = ir_target_is_explicit() ? ir_target_triple() : "";
    for (int i = 0; i < plib->section_count; i++) {
        if (strcmp(plib->sections[i].triple, triple) == 0) return &plib->sections[i];
    }
    return NULL;
}

static int extract_plib_bitcode(const PrismioPlib* plib, const char* output) {
    const PrismioPlibSection* section = plib_section_for_target(plib);
    if (!section) {
        fprintf(stderr,
                "ERROR: Prismio installation is incomplete or corrupted.\n"
                "       Missing standard-library bitcode for %s in %s\n"
                "       Reinstall Prismio and try again.\n",
                ir_target_triple(), plib->path);
        return 1;
    }
    FILE* input = fopen(plib->path, "rb");
    FILE* out = NULL;
    unsigned long long offset = g_verify_mode
        ? section->verify_bitcode_offset : section->bitcode_offset;
    unsigned long long size = g_verify_mode
        ? section->verify_bitcode_size : section->bitcode_size;
    if (!input || fseek(input, (long)offset, SEEK_SET) != 0) goto failed;
    out = fopen(output, "wb");
    if (!out) goto failed;

    unsigned char buffer[16384];
    unsigned long long left = size;
    while (left > 0) {
        size_t want = left < sizeof(buffer) ? (size_t)left : sizeof(buffer);
        size_t got = fread(buffer, 1, want, input);
        if (got != want || fwrite(buffer, 1, got, out) != got) goto failed;
        left -= got;
    }
    if (fclose(out) != 0) { out = NULL; goto failed; }
    out = NULL;
    fclose(input);
    return 0;

failed:
    if (out) fclose(out);
    if (input) fclose(input);
    delete_file(output);
    fprintf(stderr,
            "ERROR: compiled standard-library artifact is unreadable: %s\n"
            "       Reinstall Prismio and try again.\n", plib->path);
    return 1;
}

// Extract selected PLIB sections, validate every independently shipped runtime
// module, then merge the complete library graph in one LLVM context. Keeping
// artifacts module-wise is a distribution concern; reparsing and reprinting the
// growing program once per artifact was unnecessary compile-time work.
static char* merge_libraries_into_program(const char* ir_file,
                                          const char* exe_file) {
    char runtime[PRISMIO_RUNTIME_MODULE_COUNT][1024];
    // A freestanding program never merges the installed runtime, so the check
    // for a per-triple copy of it (find_runtime_bitcode) is not reached either:
    // there is no `lib/runtime/x86_64-unknown-none-elf/` and there must not need
    // to be one.
    int runtime_count =
        (g_installed_runtime && !g_freestanding) ? PRISMIO_RUNTIME_MODULE_COUNT : 0;
    if (runtime_count > 0 && !find_runtime_bitcode(runtime, g_verify_mode)) return NULL;

    int module_count = prismio_plib_count + runtime_count;
    const char** modules =
        (const char**)calloc((size_t)module_count, sizeof(const char*));
    int* modes = (int*)calloc((size_t)module_count, sizeof(int));
    char** extracted = prismio_plib_count > 0
        ? (char**)calloc((size_t)prismio_plib_count, sizeof(char*)) : NULL;
    if ((module_count > 0 && (!modules || !modes)) || (prismio_plib_count > 0 && !extracted)) {
        free(modules);
        free(modes);
        free(extracted);
        return NULL;
    }

    int failed = 0;
    for (int i = 0; i < prismio_plib_count; i++) {
        char suffix[96];
        snprintf(suffix, sizeof(suffix), "plib-%d-%d.bc", PRISMIO_GETPID(), i);
        extracted[i] = compiler_temp_path(exe_file, suffix);
        if (!extracted[i]
                || extract_plib_bitcode(&prismio_plibs[i], extracted[i]) != 0) {
            failed = 1;
            break;
        }
        modules[i] = extracted[i];
        modes[i] = 1;
    }
    for (int i = 0; i < runtime_count; i++) {
        modules[prismio_plib_count + i] = runtime[i];
        modes[prismio_plib_count + i] = 0;
    }

    char suffix[96];
    snprintf(suffix, sizeof(suffix), "libraries-%d.ll", PRISMIO_GETPID());
    char* merged = compiler_temp_path(exe_file, suffix);
    if (!merged) failed = 1;
    if (!failed) {
        double t0 = build_trace_ms();
        failed = ir_link_library_modules(
            ir_file, modules, modes, module_count, merged);
        build_trace_stage("library bitcode merge", t0);
    }

    for (int i = 0; i < prismio_plib_count; i++) {
        if (!extracted[i]) continue;
        delete_file(extracted[i]);
        free(extracted[i]);
    }
    free(extracted);
    free(modules);
    free(modes);

    if (failed) {
        if (merged) {
            delete_file(merged);
            free(merged);
        }
        return NULL;
    }
    return merged;
}

// Toolchain object cache
// Every build compiles the toolchain sources from scratch and deletes the
// objects afterwards. Measured on this host: lang_runtime.c and
// program_support.c cost 203 ms of a 411 ms build of a 34-line program, so
// **half of every small build is recompiling code that did not change**. It is
// the same object every time -- the runtime does not depend on the program.
// The key is the content of the source plus the exact compile command, hashed
// with the same FNV-1a used for the staleness check above, for the reason given
// there: mtimes move on a checkout or a copy and content does not. Flags are in
// the key because `--verify` compiles the same file to a different object
// (-DPRISMIO_AIF_VERIFY), and an object built for one mode linked into the other
// is exactly the "half the allocations are outside the accounting" failure the
// verify path already guards against.
// **What the key does not cover: an in-place upgrade of clang itself.** The same
// source and the same flags through a different compiler produce a different
// object, and nothing here notices. Set `PRISMIO_OBJ_CACHE=0` to bypass the
// cache after a toolchain upgrade, or delete the directory. Spawning
// `clang --version` to fold into the key was measured at 28 ms -- 14% of what
// the cache saves -- and was not worth paying on every build.

static int object_cache_disabled(void) {
    const char* v = getenv("PRISMIO_OBJ_CACHE");
    return v && v[0] == '0' && v[1] == '\0';
}

// Prints one line per toolchain object saying whether it came from the cache.
// The test that this cache works asks for exactly this, because "the build was
// faster" is not an observation a test can make reliably on a shared host.
static int object_cache_trace(void) {
    const char* v = getenv("PRISMIO_OBJ_CACHE_TRACE");
    return v && v[0] != '\0' && !(v[0] == '0' && v[1] == '\0');
}

// PRISMIO_OBJ_CACHE_DIR *is* the directory when it is set, rather than a parent
// to append a name to. The bootstrap scripts read the same variable and use it
// directly, and two readings of one variable is how the two caches would end up
// in two places while both reporting hits.
static char* object_cache_dir(void) {
    const char* override = getenv("PRISMIO_OBJ_CACHE_DIR");
    if (override && override[0]) {
        char* copy = (char*)malloc(strlen(override) + 1);
        strcpy(copy, override);
        return copy;
    }

    const char* base;
#ifdef _WIN32
    base = getenv("TEMP");
    if (!base || !base[0]) base = getenv("TMP");
    if (!base || !base[0]) base = ".";
#else
    base = getenv("TMPDIR");
    if (!base || !base[0]) base = "/tmp";
#endif
    // Shared across every build on the host, which is the point: a test suite
    // building 119 programs compiles the runtime once rather than 119 times.
    return join_path(base, "prismio-objcache");
}

// FNV-1a of a file's bytes; `*ok` is 0 when the file cannot be read.
static unsigned long long file_content_hash(const char* path, int* ok) {
    FILE* file = fopen(path, "rb");
    if (!file) { *ok = 0; return 0; }
    unsigned long long hash = PRISMIO_FNV_OFFSET;
    unsigned char buffer[16384];
    size_t got;
    while ((got = fread(buffer, 1, sizeof(buffer), file)) > 0) {
        for (size_t i = 0; i < got; i++) {
            hash ^= buffer[i];
            hash *= PRISMIO_FNV_PRIME;
        }
    }
    *ok = ferror(file) == 0;
    fclose(file);
    return hash;
}

// The cache entry for one native source, or NULL when the source cannot be read
// or the cache directory cannot be made. A NULL is always safe: the caller
// compiles as it did before.
//
// The key is the source's bytes, the exact flags, and the contents of every
// response file those flags name -- a response file is flags too, and editing
// one changes what every source compiles to without changing any name in the
// command. The headers a source includes are not in the key, because nothing
// can know them before the compile runs: clang reports them afterwards (-MD),
// and the entry records each with its hash in `<entry>.deps`, which
// native_deps_current checks on every hit.
static char* native_object_entry(const char* role, const char* source_path,
                                 const char* flags) {
    int ok = 1;
    unsigned long long source_hash = file_content_hash(source_path, &ok);
    if (!ok) return NULL;

    unsigned long long hash = PRISMIO_FNV_OFFSET;
    hash = fnv1a_bytes(hash, (const unsigned char*)role);
    hash = fnv1a_bytes(hash, (const unsigned char*)flags);
    char source_key[32];
    snprintf(source_key, sizeof(source_key), "%016llx", source_hash);
    hash = fnv1a_bytes(hash, (const unsigned char*)source_key);
    for (int i = 0; i < g_native_flag_file_count; i++) {
        unsigned long long file_hash = file_content_hash(g_native_flag_files[i], &ok);
        if (!ok) return NULL;
        snprintf(source_key, sizeof(source_key), "%016llx", file_hash);
        hash = fnv1a_bytes(hash, (const unsigned char*)source_key);
    }

    char* dir = object_cache_dir();
    if (ensure_directory_exists(dir) != 0) {
        free(dir);
        return NULL;
    }

    char name[160];
    snprintf(name, sizeof(name), "%s-%016llx.obj", role, hash);
    char* path = join_path(dir, name);
    free(dir);
    return path;
}

static char* native_deps_path(const char* entry) {
    size_t n = strlen(entry) + sizeof(".deps");
    char* path = (char*)malloc(n);
    if (path) snprintf(path, n, "%s.deps", entry);
    return path;
}

// Whether every file an entry was compiled from still has the bytes it had.
// One line per file: sixteen hex digits, a space, and the path.
static int native_deps_current(const char* entry) {
    char* deps = native_deps_path(entry);
    if (!deps) return 0;
    FILE* file = fopen(deps, "rb");
    free(deps);
    if (!file) return 0;

    char line[4200];
    int current = 1;
    int lines = 0;
    while (current && fgets(line, sizeof(line), file)) {
        size_t n = strlen(line);
        while (n > 0 && (line[n - 1] == '\n' || line[n - 1] == '\r')) line[--n] = '\0';
        if (n < 18 || line[16] != ' ') { current = 0; break; }
        unsigned long long recorded = strtoull(line, NULL, 16);
        int ok = 1;
        unsigned long long now = file_content_hash(line + 17, &ok);
        if (!ok || now != recorded) current = 0;
        lines++;
    }
    fclose(file);
    return current && lines > 0;
}

// Turns the make-style dependency list clang wrote (-MD -MF) into `<entry>.deps`.
// The format escapes a space in a path as `\ ` and a dollar as `$$`, and wraps
// long lists with a backslash before the newline; a path containing anything
// else is taken byte for byte. Everything after the first ": " is a prerequisite
// -- the target before it may itself contain a drive letter's colon.
static int native_deps_record(const char* entry, const char* depfile) {
    char* text = read_file(depfile);
    if (!text) return 1;
    const char* p = strstr(text, ": ");
    if (!p) { free(text); return 1; }
    p += 2;

    char* deps = native_deps_path(entry);
    if (!deps) { free(text); return 1; }
    size_t tmp_len = strlen(deps) + 32;
    char* tmp = (char*)malloc(tmp_len);
    if (!tmp) { free(deps); free(text); return 1; }
    snprintf(tmp, tmp_len, "%s.tmp-%d", deps, PRISMIO_GETPID());
    FILE* out = fopen(tmp, "wb");
    int failed = out == NULL;

    char path[4096];
    int n = 0;
    for (; !failed; p++) {
        char c = *p;
        if (c == '\\' && (p[1] == '\n' || (p[1] == '\r' && p[2] == '\n'))) {
            p += p[1] == '\r' ? 2 : 1;
            c = ' ';
        } else if (c == '\\' && p[1] == ' ') {
            if (n < (int)sizeof(path) - 1) path[n++] = ' ';
            p++;
            continue;
        } else if (c == '$' && p[1] == '$') {
            if (n < (int)sizeof(path) - 1) path[n++] = '$';
            p++;
            continue;
        }
        if (c == '\0' || c == ' ' || c == '\t' || c == '\n' || c == '\r') {
            if (n > 0) {
                path[n] = '\0';
                int ok = 1;
                unsigned long long hash = file_content_hash(path, &ok);
                if (!ok || fprintf(out, "%016llx %s\n", hash, path) < 0) failed = 1;
                n = 0;
            }
            if (c == '\0') break;
            continue;
        }
        if (n < (int)sizeof(path) - 1) path[n++] = c;
    }
    if (out && fclose(out) != 0) failed = 1;
    // `fs_rename` replaces an existing list. Plain `rename` refuses one on Windows,
    // and this one *is* there after a header edit -- the key is the source and the
    // flags, so the same entry is rewritten -- which kept the stale hashes and made
    // every later build a miss.
    if (!failed && fs_rename(tmp, deps) != 0) {
        // Another build recorded the same entry first; its list is as good.
        delete_file(tmp);
    } else if (failed) {
        delete_file(tmp);
    }
    free(tmp);
    free(deps);
    free(text);
    return failed;
}

// A sibling of `entry` in the cache directory, which is where the compiler is
// told to write the object before it is renamed into place.
//
// **It has to be a sibling.** The first version compiled next to the *output
// executable* and renamed into $TMPDIR, and `rename()` cannot cross a
// filesystem: on any host where the two differ -- /tmp as tmpfs on Linux, a
// build directory on a second volume -- every install fails with EXDEV, the
// build still succeeds, and the cache silently never populates. Nothing local
// would ever have shown it, because this Mac has one volume.
static char* object_cache_temp_path(const char* entry) {
    const char* file = entry;
    for (const char* p = entry; *p; p++) {
        if (*p == '/' || *p == '\\') file = p + 1;
    }
    size_t dir_len = (size_t)(file - entry);
    size_t len = dir_len + strlen(file) + 32;
    char* tmp = (char*)malloc(len);
    snprintf(tmp, len, "%.*s.tmp-%d-%s", (int)dir_len, entry, PRISMIO_GETPID(), file);
    return tmp;
}

// Compiling a target's native sources
//
// Each source becomes one object, compiled by the toolchain's clang with the
// target's own flags after `-O2` -- the level the runtime has always been built
// at, because this is where a program's hottest C lives -- and `-g` when the
// profile asks for debug info. Objects are cached across builds and across
// projects on content (native_object_entry), so an unchanged source costs a
// lookup rather than a compile.
//
// `objects[i]` receives each object's path and `cached[i]` whether it belongs to
// the cache (and so must outlive the build). Answers 0, or 1 once a compile
// failed.
static int compile_native_sources(const char* exe_file, char** objects, int* cached) {
    if (g_native_source_count == 0) return 0;

    char* target = target_clang_flags();
    const char* declared = g_native_flags ? g_native_flags : "";
    // Before the target's own flags, so a target that needs a newer macOS can
    // say so -- the compiler does, for the LLVM it links (tools/setup_llvm.py).
    char min_os[64];
    macos_min_flag(min_os, sizeof(min_os));
    // What compiling C for a machine with no OS means: no hosted library to
    // assume (-ffreestanding), no GOT to load addresses through (-fno-pic), and
    // no stack-protector canary, which reads a guard symbol the C library defines.
    const char* freestanding =
        g_freestanding ? " -ffreestanding -fno-pic -fno-stack-protector" : "";
    size_t flags_len = strlen(target) + strlen(min_os) + strlen(declared) +
                       strlen(freestanding) + 16;
    char* flags = (char*)malloc(flags_len);
    if (!flags) { free(target); return 1; }
    snprintf(flags, flags_len, "%s%s-O2%s%s%s", target, min_os, freestanding,
             g_debug_info ? " -g" : "",
             declared);
    free(target);

    int result = 0;
    for (int i = 0; i < g_native_source_count && result == 0; i++) {
        const char* source = g_native_sources[i];
        char* role = path_without_extension(path_file_name(source));
        char* entry = NULL;
        if (object_cache_disabled()) {
            if (object_cache_trace()) fprintf(stderr, "[objcache off] %s\n", role);
        } else {
            entry = native_object_entry(role, source, flags);
            if (entry && file_exists(entry) && native_deps_current(entry)) {
                if (object_cache_trace()) fprintf(stderr, "[objcache hit] %s\n", role);
                objects[i] = entry;
                cached[i] = 1;
                free(role);
                continue;
            }
            if (object_cache_trace()) fprintf(stderr, "[objcache miss] %s\n", role);
        }

        // Compiled to a pid-qualified temporary beside the cache entry and moved
        // into place, never written at the entry directly: two builds racing on
        // one entry would otherwise link a half-written object.
        char unique[160];
        snprintf(unique, sizeof(unique), "native%d-%s", i, role);
        char* out = entry ? object_cache_temp_path(entry) : compiler_temp_obj_path(exe_file, unique);
        size_t dep_len = strlen(out) + 3;
        char* dep = (char*)malloc(dep_len);
        char* q_src = command_quote_arg(source);
        char* q_out = command_quote_arg(out);
        char* q_dep = dep ? (snprintf(dep, dep_len, "%s.d", out), command_quote_arg(dep)) : NULL;
        size_t command_len = strlen(native_clang_command()) + strlen(flags) + strlen(q_src)
                             + strlen(q_out) + (q_dep ? strlen(q_dep) : 0) + 64;
        char* command = (char*)malloc(command_len);
        if (!dep || !q_dep || !command) {
            result = 1;
        } else {
            snprintf(command, command_len, "%s %s -MD -MF %s -c %s -o %s",
                     native_clang_command(), flags, q_dep, q_src, q_out);
            double t0 = build_trace_ms();
            diag_progress("compiling native sources");
            if (run_build_command(command) != 0) result = 1;
            build_trace_stage(role, t0);
        }

        if (result == 0 && entry && native_deps_record(entry, dep) == 0 &&
                fs_rename(out, entry) == 0) {
            // A failed install is not a failed build: the temporary is linked
            // and the compile is paid for again next time.
            free(out);
            out = entry;
            entry = NULL;
            cached[i] = 1;
        }
        objects[i] = out;
        if (dep) { delete_file(dep); free(dep); }
        free(q_dep);
        free(q_src);
        free(q_out);
        free(command);
        free(entry);
        free(role);
    }
    free(flags);
    return result;
}

// The native objects as link arguments, quoted, each after a space.
static char* native_object_arguments(char** objects) {
    char* args = NULL;
    for (int i = 0; i < g_native_source_count; i++) {
        if (objects[i] && append_quoted_argument(&args, objects[i]) != 0) {
            free(args);
            return NULL;
        }
    }
    if (!args) {
        args = (char*)malloc(1);
        if (args) args[0] = '\0';
    }
    return args;
}

// The defined, external text and data symbols of the target's native objects,
// as `<nm> --defined-only --extern-only --format=posix` prints them: the raw
// text, or NULL when nm did not run. Mach-O names keep their leading `_`.
//
// Two parsing details, both of which cost a CI round in tools/bootstrap.ps1
// before they were understood. nm interleaves a `<file>:` header line per
// object, so a whitespace split would produce `/EXPORT:lang_runtime.obj:` and
// fail the link; the line is matched as `<name> <type>` instead, and a header
// line has no type field so it falls out (native_export_name). And only the
// defined text and data types are taken, so a weak or comdat symbol is skipped
// rather than exported.
static char* native_export_symbols(const char* nm, char** objs, int count,
                                   const char* exe_file) {
    char* list_path = compiler_temp_path(exe_file, "exports.txt");
    if (!list_path) return NULL;

    char* q_nm = command_quote_arg(nm);
    size_t command_size = strlen(list_path) + strlen(q_nm) + 128;
    int any = 0;
    for (int i = 0; i < count; i++) {
        if (!objs[i]) continue;
        command_size += strlen(objs[i]) + 8;
        any = 1;
    }
    char* command = any ? (char*)malloc(command_size) : NULL;
    if (!command) { free(q_nm); free(list_path); return NULL; }
    int written = snprintf(command, command_size,
                           "%s --defined-only --extern-only --format=posix", q_nm);
    free(q_nm);
    for (int i = 0; i < count; i++) {
        if (!objs[i]) continue;
        char* quoted = command_quote_arg(objs[i]);
        written += snprintf(command + written, command_size - written, " %s", quoted);
        free(quoted);
    }
    char* q_list = command_quote_arg(list_path);
    snprintf(command + written, command_size - written, " > %s", q_list);
    free(q_list);

    int failed = run_build_command(command);
    free(command);

    char* text = failed ? NULL : read_file(list_path);
    delete_file(list_path);
    free(list_path);
    return text;
}

// The length of the exportable name `line` (of `len` bytes) begins with, or 0
// when the line is a file header or its symbol type is not one of `types`.
// COFF's text and data are `TDBR`; Mach-O also puts constant data in `S`.
static size_t native_export_name(const char* line, size_t len, const char* types) {
    size_t name_len = 0;
    while (name_len < len && line[name_len] != ' ' && line[name_len] != '\t') name_len++;
    size_t type_at = name_len;
    while (type_at < len && (line[type_at] == ' ' || line[type_at] == '\t')) type_at++;

    int typed = type_at < len && strchr(types, line[type_at]) != NULL
                && (type_at + 1 >= len
                    || line[type_at + 1] == ' ' || line[type_at + 1] == '\t');
    if (name_len == 0 || !typed || line[0] == '.' || line[0] == '$') return 0;
    return name_len;
}

// The export list or response file of the link in progress, removed after it.
static char* g_export_rsp = NULL;

#ifndef _WIN32
// The macOS and Linux half of `exportDynamic`: the native objects' symbols and
// nothing else, as the Windows half below has always done.
//
// **Not `-rdynamic`, which is what this was.** That exports every global symbol
// the executable has, and for the compiler that is the ~44,000 C++ symbols of
// the LLVM it links statically: 22 MB of export trie and string table in a
// 135 MB binary, and every one of those functions a root `-dead_strip` must keep
// whether anything calls it or not. `run --jit` resolves a jitted module's
// runtime calls in this process, and the runtime is the native objects.
//
// Returns the flag to append, or NULL to fall back to `-rdynamic` -- nm missing
// costs size, never correctness.
static char* unix_export_flags(char** objs, int count, const char* exe_file) {
    // The toolchain's own llvm-nm when there is one, beside the clang that
    // compiled the objects; the system's `nm` takes the same flags otherwise.
    char nm[1200] = "nm";
    native_clang_command();
    if (g_clang_binary[0]) {
        char* dir = get_directory(g_clang_binary);
        char candidate[1200];
        snprintf(candidate, sizeof(candidate), "%s%cllvm-nm", dir ? dir : ".", PRISMIO_PATH_SEP);
        free(dir);
        if (file_exists(candidate)) snprintf(nm, sizeof(nm), "%s", candidate);
    }
    char* text = native_export_symbols(nm, objs, count, exe_file);
    if (!text) return NULL;

    int mach_o = target_is_mach_o();
    char* list_path = compiler_temp_path(exe_file, "exports.list");
    FILE* list = list_path ? fopen(list_path, "wb") : NULL;
    if (!list) {
        free(list_path);
        free(text);
        return NULL;
    }
    // ld64 reads one (underscored) name per line; GNU ld and lld a version-
    // script-shaped `{ name; ... };`.
    if (!mach_o) fputs("{\n", list);
    int written = 0;
    char* line = text;
    while (*line) {
        char* end = strchr(line, '\n');
        size_t len = end ? (size_t)(end - line) : strlen(line);
        size_t name_len = native_export_name(line, len, "TDBRS");
        if (name_len > 0) {
            fprintf(list, mach_o ? "%.*s\n" : "  %.*s;\n", (int)name_len, line);
            written++;
        }
        if (!end) break;
        line = end + 1;
    }
    if (!mach_o) fputs("};\n", list);
    fclose(list);
    free(text);
    if (written == 0) {
        delete_file(list_path);
        free(list_path);
        return NULL;
    }

    free(g_export_rsp);
    g_export_rsp = list_path;
    size_t n = strlen(list_path) + 64;
    char* flag = (char*)malloc(n);
    if (!flag) return NULL;
    snprintf(flag, n, mach_o ? "-Wl,-exported_symbols_list,%s" : "-Wl,--dynamic-list=%s", list_path);
    char* quoted = command_quote_arg(flag);
    free(flag);
    size_t q = quoted ? strlen(quoted) + 2 : 0;
    char* arg = quoted ? (char*)malloc(q) : NULL;
    if (arg) snprintf(arg, q, " %s", quoted);
    free(quoted);
    return arg;
}
#endif

#ifdef _WIN32
// The Windows half of `exportDynamic`.
//
// A COFF executable exports nothing unless it was linked with an export table,
// so without one a program that loads code at run time -- the compiler's
// `run --jit`, resolving a jitted module's externals in its own process -- finds
// none of the symbols it carries and reports `Symbols not found: [ ... ]`. There
// is no flag: `-rdynamic` is not something clang-cl understands.
//
// **Read out of the objects rather than written down.** The target's native
// objects are the surface it means to export; a list kept anywhere else would be
// a second copy of it and would drift silently. native_export_symbols reads
// them.
//
// Best-effort: everything except `run --jit` works without an export table, so a
// missing llvm-nm says so and the link proceeds. Returns a malloc'd string of
// flags to append, or NULL.

static char* windows_export_flags(char** objs, int count, const char* exe_file) {
    char* text = native_export_symbols("llvm-nm", objs, count, exe_file);
    if (!text) {
        fprintf(stderr,
                "NOTE: llvm-nm did not run, so this program is linked without an\n"
                "      export table; code it loads at run time will not find its symbols.\n");
        return NULL;
    }

    // A name can be shorter than the flag that carries it, so the output length
    // is not an upper bound on the flags -- three times it is.
    size_t flags_size = strlen(text) * 3 + 64;
    char* flags = (char*)malloc(flags_size);
    if (!flags) { free(text); return NULL; }
    flags[0] = '\0';

    size_t used = 0;
    int exported = 0;
    char* line = text;
    while (*line) {
        char* end = strchr(line, '\n');
        size_t len = end ? (size_t)(end - line) : strlen(line);

        size_t name_len = native_export_name(line, len, "TDBR");
        if (name_len > 0) {
            used += (size_t)snprintf(flags + used, flags_size - used,
                                     " -Wl,/EXPORT:%.*s", (int)name_len, line);
            exported++;
        }

        if (!end) break;
        line = end + 1;
    }
    free(text);

    if (exported == 0) { free(flags); return NULL; }

    // **Through a response file, not on the command line.** cmd.exe refuses a
    // line longer than 8191 characters, and 191 exports are several thousand on
    // their own: CI's `prismio bootstrap` failed with "The command line is too
    // long." as soon as the quoting in front of it was fixed. clang expands
    // `@file` itself, one argument per whitespace-separated token; the names
    // are C identifiers, so none needs quoting. The file is removed after the
    // link (g_export_rsp).
    char* rsp_path = compiler_temp_path(exe_file, "exports.rsp");
    FILE* rsp = rsp_path ? fopen(rsp_path, "wb") : NULL;
    if (!rsp) {
        free(rsp_path);
        return flags;
    }
    for (char* c = flags; *c; c++) fputc(*c == ' ' ? '\n' : *c, rsp);
    fclose(rsp);
    free(flags);
    free(g_export_rsp);
    g_export_rsp = rsp_path;
    char* q_rsp_path = command_quote_arg(rsp_path);
    size_t arg_len = strlen(q_rsp_path) + 3;
    char* arg = (char*)malloc(arg_len);
    if (arg) snprintf(arg, arg_len, " @%s", q_rsp_path);
    free(q_rsp_path);
    return arg;
}
#endif

// Mach-O only, and a warning rather than a failure if it does not work.
//
// A .dSYM is a copy of debug info that already exists somewhere else, so a
// program that built and linked is a program that runs. Failing the build
// because the bundle could not be written would turn a degraded -g into no
// binary at all. The warning names the tool so the cause is not a mystery.
static void write_dsym(const char* exe_file) {
#ifdef __APPLE__
    char* q_exe = command_quote_arg(exe_file);
    int len = (int)strlen(q_exe) + 64;
    char* command = (char*)malloc(len);
    snprintf(command, len, "dsymutil %s", q_exe);
    if (run_build_command(command) != 0) {
        fprintf(stderr,
                "warning: dsymutil failed; the binary has a debug map but no .dSYM,\n"
                "         so a debugger will find no source lines for it.\n");
    }
    free(command);
    free(q_exe);
#else
    (void)exe_file; // ELF: the linker copied the debug sections into the binary
#endif
}

int ir_jit_run_file(const char* ir_path, const char* program_name);

// What the pinned seed still calls. The pinned seed (bootstrap/seed.json) is IR for an
// earlier compiler, linked against *these* C sources, so a function it names can
// leave only after the seed is refreshed (tools/refresh_seed.sh). Kept, like
// `list_set_elem_inline`, only in a compiler built from repository sources:
// both build.ums and the bootstrap scripts define PRISMIO_BOOTSTRAP_COMPAT, and
// nothing a user program links does. A seed-built generation uses them only to
// build the next generation, which calls none of them. Delete all four with the
// next seed refresh.
#ifdef PRISMIO_BOOTSTRAP_COMPAT
int compiler_spawn_wait(const char* program, const char* directory);

int compiler_run_executable(const char* exe_file) {
    return compiler_spawn_wait(exe_file, "") == 0 ? 0 : 1;
}

// The seed's step runner handed this a tail already quoted for a shell.
int compiler_run_executable_with(const char* exe_file, const char* arguments) {
    char* q_exe = command_quote_arg(exe_file);
    size_t n = strlen(q_exe) + (arguments ? strlen(arguments) : 0) + 2;
    char* line = (char*)malloc(n);
    int result = 1;
    if (line) {
        snprintf(line, n, "%s %s", q_exe, arguments ? arguments : "");
        result = run_build_command(line);
        free(line);
    }
    free(q_exe);
    return result;
}

int compiler_bootstrap_executable(const char* ir_file, const char* exe_file) {
    (void)ir_file;
    (void)exe_file;
    fprintf(stderr, "ERROR: this compiler predates native targets; build the compiler with "
                    "tools/bootstrap.sh, or with `prismio build` in its checkout.\n");
    return 1;
}

int ir_jit_run_main(const char* program_name) {
    (void)program_name;
    fprintf(stderr, "ERROR: --jit needs a compiler built from this tree.\n");
    return 1;
}
#endif


// `run --jit`: the program's IR merged with its imported standard-library
// bitcode, exactly as a build merges it, then run in this process. Not with the
// runtime modules -- this process carries the runtime and exports it, which is
// how the jitted module's runtime calls resolve -- so the merge is the build's
// with `runtime = "none"`.
int compiler_jit_run(const char* ir_file, const char* program_name) {
    int saved = g_installed_runtime;
    g_installed_runtime = 0;
    char* merged = merge_libraries_into_program(ir_file, ir_file);
    g_installed_runtime = saved;
    if (!merged) return 1;
    diag_progress_clear();
    int status = ir_jit_run_file(merged, program_name);
    delete_file(merged);
    free(merged);
    return status;
}

// Imported PLIB modules and, unless the target declared `runtime = "none"`, every
// runtime bitcode module are merged into the program before final
// optimisation; the target's native sources are compiled beside it and linked
// with the program object.
// The failure core every freestanding program needs, added unless the program
// brought a source of its own for it. Found in an installed toolchain's
// `lib/runtime/freestanding/`, or in a checkout's `runtime/freestanding/`. Not
// finding it is not an error here: a program that never fails does not reference
// it, and one that does gets the linker's undefined-symbol report, which names the
// function.
static void add_freestanding_panic_core(void) {
    if (!g_freestanding) return;
    for (int i = 0; i < g_native_source_count; i++) {
        if (strcmp(path_file_name(g_native_sources[i]), "panic.c") == 0) return;
    }
    char path[1024];
    if (find_in_lib_dir(path, sizeof(path), "runtime/freestanding/panic.c")
        || find_toolchain_entry(path, sizeof(path), "runtime", "freestanding/panic.c")) {
        compiler_native_source(path);
    }
}

int compiler_build_executable(const char* ir_file, const char* exe_file) {
    add_freestanding_panic_core();
    if (compiler_prepare_output_path(exe_file) != 0) {
        fprintf(stderr, "ERROR: could not create output directory\n");
        return 1;
    }
    if (!compiler_link_inputs_supported()) return 1;

    // In memory unless clang is the one reading it (PRISMIO_CODEGEN=clang). The
    // path is still made: it is how ir_emit_object recognises the module.
    ir_hold_merged_module(!codegen_uses_clang());
    char* merged_ir = merge_libraries_into_program(ir_file, exe_file);
    ir_hold_merged_module(0);
    if (!merged_ir) return 1;

    char* program_obj = compiler_temp_obj_path(exe_file, "program");
    int partition_objects = 0;
    int result = compile_ir_to_object(merged_ir, program_obj, &partition_objects);

    int native_count = g_native_source_count;
    char** objects = native_count > 0 ? (char**)calloc((size_t)native_count, sizeof(char*)) : NULL;
    int* cached = native_count > 0 ? (int*)calloc((size_t)native_count, sizeof(int)) : NULL;
    if (native_count > 0 && (!objects || !cached)) result = 1;
    if (result == 0) result = compile_native_sources(exe_file, objects, cached);

    char* extra = NULL;
    if (result == 0) {
        extra = objects ? native_object_arguments(objects) : NULL;
        if (objects && !extra) result = 1;
    }
    // The program's other codegen partitions link beside its first object,
    // ahead of the native ones, as the one object used to.
    for (int p = 1; p <= partition_objects && result == 0; p++) {
        char path[1200];
        ir_partition_object_path(program_obj, p, path, sizeof(path));
        char* quoted = command_quote_arg(path);
        size_t n = strlen(quoted) + (extra ? strlen(extra) : 0) + 2;
        char* joined = quoted ? (char*)malloc(n) : NULL;
        if (!joined) {
            result = 1;
        } else {
            snprintf(joined, n, " %s%s", quoted, extra ? extra : "");
            free(extra);
            extra = joined;
        }
        free(quoted);
    }
    if (result == 0 && g_export_dynamic) {
#ifdef _WIN32
        char* exports = windows_export_flags(objects, native_count, exe_file);
        // /Brepro for the reason link_program_msvc passes it, on the driver path
        // it replaces here: a toolchain host's standard library is keyed on the
        // host's bytes, and a wall-clock PE timestamp made every rebuild a miss.
        const char* tail = " -Wl,/Brepro";
#else
        char* exports = unix_export_flags(objects, native_count, exe_file);
        const char* tail = exports ? "" : " -rdynamic";
#endif
        size_t n = (extra ? strlen(extra) : 0) + (exports ? strlen(exports) : 0) + strlen(tail) + 1;
        char* joined = (char*)malloc(n);
        if (joined) {
            snprintf(joined, n, "%s%s%s", extra ? extra : "", exports ? exports : "", tail);
            free(extra);
            extra = joined;
        } else {
            result = 1;
        }
        free(exports);
    }

    if (result == 0) {
        g_link_extra = extra ? extra : "";
        result = link_program_object(program_obj, exe_file);
        g_link_extra = "";
    }
    if (g_export_rsp) {
        delete_file(g_export_rsp);
        free(g_export_rsp);
        g_export_rsp = NULL;
    }

    // Before the object goes away, and only while it is still there to walk. See
    // g_debug_info: on Mach-O the executable carries a debug map, not DWARF, and
    // the DWARF it points at is in the object file the next line deletes.
    if (result == 0 && g_debug_info && target_is_mach_o()) write_dsym(exe_file);

    for (int i = 0; i < native_count && objects; i++) {
        if (objects[i] && !cached[i]) delete_file(objects[i]);
        free(objects[i]);
    }
    free(objects);
    free(cached);
    free(extra);
    delete_file(program_obj);
    for (int p = 1; p <= partition_objects; p++) {
        char path[1200];
        ir_partition_object_path(program_obj, p, path, sizeof(path));
        delete_file(path);
    }
    delete_file(merged_ir);
    ir_release_held_module();
    discard_curated_raw_ir();
    free(program_obj);
    free(merged_ir);
    return result;
}

// The path in the *command* position needs more care than one in an argument
// position, which is why this does not just quote and go.
//
// On Windows, `prismio run app.psm -o build/app.exe` failed outright: cmd.exe
// reads `build/app.exe` as the command `build` with the switch `/app.exe`, even
// quoted. It then reported "Program exited with failure" -- blaming the compiled
// program for a mistake the compiler made invoking it. A forward slash in `-o`
// is a completely ordinary thing to write, so normalise instead of rejecting.
//
// Everywhere else the separator is left alone: llc and clang take forward
// slashes happily, and only the command position is parsed by the shell this way.
static char* run_command_path(const char* exe_file) {
    size_t len = strlen(exe_file);
    // Room for a leading "./" (or ".\") if the path has no directory part.
    char* path = (char*)malloc(len + 3);
    if (!path) return NULL;

    int has_separator = 0;
    for (size_t i = 0; i < len; i++) {
        if (exe_file[i] == '/' || exe_file[i] == '\\') has_separator = 1;
    }

    size_t out = 0;
    // A bare name would otherwise be looked up on PATH first, which can run a
    // different program with the same name than the one just built.
    if (!has_separator) {
        path[out++] = '.';
        path[out++] = PRISMIO_PATH_SEP;
    }

    for (size_t i = 0; i < len; i++) {
        char c = exe_file[i];
        path[out++] = (c == '/' || c == '\\') ? PRISMIO_PATH_SEP : c;
    }
    path[out] = '\0';
    return path;
}

static int compiler_hosted_env_begin(char** saved, int* was_set) {
    const char* current = getenv("PRISMIO_INTERNAL_HOSTED");
    *saved = NULL;
    *was_set = current != NULL;
    if (current) {
        *saved = (char*)malloc(strlen(current) + 1);
        if (!*saved) return 1;
        strcpy(*saved, current);
    }
#ifdef _WIN32
    if (_putenv_s("PRISMIO_INTERNAL_HOSTED", "1") != 0) return 1;
#else
    if (setenv("PRISMIO_INTERNAL_HOSTED", "1", 1) != 0) return 1;
#endif
    return 0;
}

static void compiler_hosted_env_end(char* saved, int was_set) {
#ifdef _WIN32
    _putenv_s("PRISMIO_INTERNAL_HOSTED", was_set ? saved : "");
#else
    if (was_set) setenv("PRISMIO_INTERNAL_HOSTED", saved, 1);
    else unsetenv("PRISMIO_INTERNAL_HOSTED");
#endif
    free(saved);
}

// Read once and then removed from the environment. The marker is an instruction
// to *this* process -- do not route, a launcher is waiting on you -- and every
// program a hosted compiler starts inherited it: a `prismio` that a project
// command or a user's program ran in turn believed it was hosted too, and never
// routed to the project's compiler. The children that do need it (a probe, a
// forward) have it set around their spawn by compiler_hosted_env_begin.
int compiler_is_hosted(void) {
    static int hosted = -1;
    if (hosted >= 0) return hosted;
    const char* value = getenv("PRISMIO_INTERNAL_HOSTED");
    hosted = value && value[0] == '1' && value[1] == '\0';
#ifdef _WIN32
    _putenv_s("PRISMIO_INTERNAL_HOSTED", "");
#else
    unsetenv("PRISMIO_INTERNAL_HOSTED");
#endif
    return hosted;
}

int compiler_is_current_executable(const char* path) {
    if (!path || !path[0]) return 0;
#ifdef _WIN32
    char current[MAX_PATH];
    char candidate[MAX_PATH];
    DWORD current_len = GetModuleFileNameA(NULL, current, MAX_PATH);
    DWORD candidate_len = GetFullPathNameA(path, MAX_PATH, candidate, NULL);
    if (current_len == 0 || current_len >= MAX_PATH ||
        candidate_len == 0 || candidate_len >= MAX_PATH) {
        return 0;
    }
    return _stricmp(current, candidate) == 0;
#else
    char* directory = prismio_executable_directory();
    if (!directory || prismio_argc < 1 || !prismio_argv || !prismio_argv[0]) {
        free(directory);
        return 0;
    }

    const char* leaf = path_file_name(prismio_argv[0]);
    size_t current_len = strlen(directory) + strlen(leaf) + 2;
    char* current = (char*)malloc(current_len);
    if (!current) {
        free(directory);
        return 0;
    }
    snprintf(current, current_len, "%s/%s", directory, leaf);

    struct stat current_stat;
    struct stat candidate_stat;
    int same = stat(current, &current_stat) == 0 &&
               stat(path, &candidate_stat) == 0 &&
               current_stat.st_dev == candidate_stat.st_dev &&
               current_stat.st_ino == candidate_stat.st_ino;
    free(current);
    free(directory);
    return same;
#endif
}

// Starting another program: an argument vector, a working directory, and its own
// exit status back.
//
// **Everything the driver runs on a user's behalf goes through here** -- the
// program `run` just built, each `run`/`shell` step of a project command, the
// project host a launcher forwards to, and the probes that ask a host whether it
// starts. They used to be shell lines built with command_quote_arg and handed
// to system(), and that failed three ways at once: an argument the user typed
// was shell syntax (`prismio sh '$(whoami)'` ran the substitution), every exit
// status came back as 0 or 1, and Windows' _spawnv joins arguments with spaces
// without quoting them, so a forwarded path with a space in it arrived as two.
// proc_spawn_* already had the answer -- posix_spawnp on one side and
// CreateProcess with CommandLineToArgvW's quoting on the other -- because
// std.process needed it first.
//
// `directory` is changed around the spawn rather than passed to it: posix_spawn's
// chdir action is a non-portable extension, and the driver starts one child at
// a time from the main thread, which is the condition that makes a process-wide
// chdir safe. It is restored before waiting, so nothing the parent does while
// the child runs sees it.
//
// Answers the child's status (128 + the signal, on POSIX, for one that was
// killed), or -1 when the program could not be started at all, having said why
// unless `quiet`.
static int spawn_and_wait(const char* program, char** arguments, int count,
                          const char* directory, int quiet) {
    char* saved = NULL;
    if (directory && directory[0]) {
#ifdef _WIN32
        saved = _getcwd(NULL, 0);
        int moved = saved && _chdir(directory) == 0;
#else
        saved = getcwd(NULL, 0);
        int moved = saved && chdir(directory) == 0;
#endif
        if (!moved) {
            if (!quiet) fprintf(stderr, "error: cannot enter %s: %s\n", directory, strerror(errno));
            free(saved);
            return -1;
        }
    }

    proc_spawn_begin(program);
    for (int i = 0; i < count; i++) proc_spawn_arg(arguments[i]);
    int output = quiet ? PRISMIO_STDIO_DISCARD : PRISMIO_STDIO_INHERIT;
    if (!quiet) diag_progress_clear();
    PrismioSpawnOut out;
    int started = proc_spawn_run(PRISMIO_STDIO_INHERIT, output, output, &out);

    if (saved) {
#ifdef _WIN32
        (void)_chdir(saved);
#else
        (void)chdir(saved);
#endif
        free(saved);
    }

    if (started != 0) {
        if (!quiet) {
#ifdef _WIN32
            fprintf(stderr, "error: could not start %s (Windows error %d)\n",
                    program, (int)out.error);
#else
            fprintf(stderr, "error: could not start %s: %s\n", program, strerror((int)out.error));
#endif
        }
        return -1;
    }
    return proc_wait(out.handle);
}

// The argument vector for the next compiler_spawn_wait, built one argument per
// call because a List does not cross the FFI boundary -- the shape proc_spawn_arg
// has for the same reason. Plain malloc: this runtime frees all of it.
static char** g_pending_args = NULL;
static int g_pending_count = 0;
static int g_pending_cap = 0;

static void pending_args_clear(void) {
    for (int i = 0; i < g_pending_count; i++) free(g_pending_args[i]);
    g_pending_count = 0;
}

void compiler_spawn_arg(const char* argument) {
    if (!argument) return;
    if (g_pending_count == g_pending_cap) {
        int grown = g_pending_cap ? g_pending_cap * 2 : 8;
        char** bigger = (char**)realloc(g_pending_args, (size_t)grown * sizeof(char*));
        if (!bigger) return;
        g_pending_args = bigger;
        g_pending_cap = grown;
    }
    size_t n = strlen(argument) + 1;
    char* copy = (char*)malloc(n);
    if (!copy) return;
    memcpy(copy, argument, n);
    g_pending_args[g_pending_count++] = copy;
}

// The pending vector itself, for the one runner that is not a process: `--jit`
// calls the program's `main` in this process and hands it the same arguments.
char** compiler_pending_arguments(int* count) {
    *count = g_pending_count;
    return g_pending_args;
}

// Runs `program` with the arguments added since the last call, in `directory`
// ("" keeps this process's). A program named without a separator is looked up
// on PATH, so a caller that means a file it built passes a path with one.
int compiler_spawn_wait(const char* program, const char* directory) {
    int status = spawn_and_wait(program, g_pending_args, g_pending_count, directory, 0);
    pending_args_clear();
    return status;
}

// Whether `name` would be found on PATH -- what picks `py -3` over the `python`
// that Windows may only have as a Microsoft Store stub.
int compiler_program_on_path(const char* name) {
#ifdef _WIN32
    char found[MAX_PATH];
    return SearchPathA(NULL, name, ".exe", MAX_PATH, found, NULL) > 0 ? 1 : 0;
#else
    const char* path = getenv("PATH");
    if (!path || !name || !name[0]) return 0;
    size_t name_len = strlen(name);
    while (*path) {
        const char* end = strchr(path, ':');
        size_t dir_len = end ? (size_t)(end - path) : strlen(path);
        char* candidate = (char*)malloc(dir_len + name_len + 2);
        if (!candidate) return 0;
        snprintf(candidate, dir_len + name_len + 2, "%.*s/%s", (int)dir_len, path, name);
        int runnable = access(candidate, X_OK) == 0;
        free(candidate);
        if (runnable) return 1;
        if (!end) break;
        path = end + 1;
    }
    return 0;
#endif
}

// The global compiler is a launcher once a project host exists. The command is
// forwarded as an argument vector, so every byte of every argument reaches the
// host unchanged, and the host's exit status is the command's.
int compiler_forward_cli(const char* host) {
    if (!host || !host[0] || prismio_argc < 1 || !prismio_argv) return 1;

    char* saved = NULL;
    int was_set = 0;
    if (compiler_hosted_env_begin(&saved, &was_set) != 0) {
        free(saved);
        return 1;
    }
    int status = spawn_and_wait(host, prismio_argv + 1, prismio_argc - 1, "", 0);
    compiler_hosted_env_end(saved, was_set);
    return status < 0 ? 1 : status;
}

// Ask another compiler one silent question and report only whether it answered.
//
// The child runs with PRISMIO_INTERNAL_HOSTED set, which is what makes the
// answer that binary's own: without it a probed compiler that is itself a
// launcher would forward the question to a third one and report on that
// instead. Output is discarded because a project build should report the
// selected host, not print a version banner or a diagnostic in its middle.
static int compiler_probe_executable(const char* exe_file, char** arguments, int count) {
    char* normalized = run_command_path(exe_file);
    if (!normalized) return 1;

    char* saved = NULL;
    int was_set = 0;
    if (compiler_hosted_env_begin(&saved, &was_set) != 0) {
        free(saved);
        free(normalized);
        return 1;
    }
    int status = spawn_and_wait(normalized, arguments, count, "", 1);
    compiler_hosted_env_end(saved, was_set);
    free(normalized);
    return status == 0 ? 0 : 1;
}

// A compiler candidate is not allowed to displace the last known-good local
// generation merely because clang linked it. Starting it with the cheapest
// side-effect-free command catches a bad image, a missing dynamic dependency,
// and an architecture mismatch before promotion.
int compiler_check_executable(const char* exe_file) {
    char* arguments[] = { "--version" };
    return compiler_probe_executable(exe_file, arguments, 1);
}

// The token this compiler emits code against. See PRISMIO_HOST_ABI in
// prismio_runtime.h for what a bump means and when to pay for one.
const char* compiler_host_abi(void) {
    return PRISMIO_HOST_ABI;
}

// Whether a project-local compiler emits code the current runtime still
// defines. `--internal-host-abi` is hidden and takes the asking compiler's own
// token -- this runtime's PRISMIO_HOST_ABI, since the asker is the binary this
// file is linked into -- so there are three outcomes and all of them are the
// same answer here:
// the host agrees and exits 0; it disagrees and exits 1; or it predates the
// command entirely, rejects the argument as unknown, and exits 1 -- which is
// exactly the "older than the question" case, reported without the old compiler
// having had to know it would one day be asked.
//
int compiler_check_host_abi(const char* exe_file) {
    char* arguments[] = { "--internal-host-abi", PRISMIO_HOST_ABI };
    return compiler_probe_executable(exe_file, arguments, 2);
}

// A project-local toolchain
//
// `toolchain.host` names a compiler the project builds and then runs. Since the
// runtime became installed bitcode with no source fallback, such a compiler can
// build *itself* -- bootstrap compiles runtime/*.c from the checkout -- and
// cannot build a single user program: find_in_lib_dir looks only beside the
// executable and one directory up, and `.prismio/build/debug/prismio` has
// neither. Every benchmark, corpus program and test fixture pointed at the
// project host failed with "Missing runtime module", and the message named an
// installation the developer had never installed.
//
// So building the host also builds the rest of the toolchain beside it, in the
// layout an install has:
//
//     .prismio/build/debug/prismio      the host
//     .prismio/build/lib/runtime/*.bc   what a program links
//     .prismio/build/stdlib/*.plib      what `import std.*` resolves to
//
// That is `<prefix>/bin`, `<prefix>/lib`, `<prefix>/stdlib` with the profile
// directory as the bin directory, so neither find_in_lib_dir nor
// standardModulePath had to learn a new shape -- and a developer working on
// `std/` or `runtime/` gets those changes in the next program they build, which
// is the whole reason a project pins a host.
//
// Rebuilt with the host rather than fingerprinted. Measured on this machine at
// 1.9 s against a host build of about 20 s: the 14 standard-library modules
// reach IR in 0.21 s and bitcode in 0.28 s, and the four runtime modules are
// 0.8 s of clang. A fingerprint that could skip it would have to cover the
// compiler, whose linked binary differs run to run even at an IR fixpoint, so it
// would have to hash `src/` -- a build-fingerprint feature this tree does not
// have.
static int read_binary_file(const char* path, unsigned char** data, size_t* size) {
    *data = NULL;
    *size = 0;
    FILE* file = fopen(path, "rb");
    if (!file) return 1;
    if (fseek(file, 0, SEEK_END) != 0) {
        fclose(file);
        return 1;
    }
    long length = ftell(file);
    if (length < 0 || fseek(file, 0, SEEK_SET) != 0) {
        fclose(file);
        return 1;
    }
    unsigned char* buffer = (unsigned char*)malloc((size_t)length + 1);
    if (!buffer) {
        fclose(file);
        return 1;
    }
    if (length > 0 && fread(buffer, 1, (size_t)length, file) != (size_t)length) {
        free(buffer);
        fclose(file);
        return 1;
    }
    fclose(file);
    *data = buffer;
    *size = (size_t)length;
    return 0;
}

// The directory holding `path`, canonical: absolute, with `.` and `..` resolved.
//
// A source path reaches the emitted bitcode's `source_filename` record, so the
// same file names a different artifact depending on how it was spelled.
// find_toolchain_entry answers relative to the working directory when that is
// where it found the checkout, and `prismio build` runs from wherever the
// developer stood -- so `runtime/lang_runtime.c` from the root and
// `../runtime/lang_runtime.c` from `ums/` produced two different `lang_runtime.bc`
// for one source. tools/package.py resolves its own root the same way
// (`Path(__file__).resolve()`), which is what lets the two producers be compared
// byte for byte.
//
// The platform call rather than lexical string surgery, because `..` past a
// symlinked directory is not the parent it looks like.
static char* absolute_directory(const char* path) {
    char* directory = get_directory(path);
    if (!directory || !directory[0]) return directory;
#ifdef _WIN32
    char resolved[1024];
    DWORD length = GetFullPathNameA(directory, (DWORD)sizeof(resolved), resolved, NULL);
    if (length == 0 || length >= sizeof(resolved)) return directory;
    char* canonical = (char*)malloc(strlen(resolved) + 1);
    if (!canonical) return directory;
    strcpy(canonical, resolved);
#else
    char* canonical = realpath(directory, NULL);
    if (!canonical) return directory;
#endif
    free(directory);
    return canonical;
}

static int set_env_var(const char* name, const char* value) {
#ifdef _WIN32
    return _putenv_s(name, value ? value : "") != 0;
#else
    if (!value) {
        unsetenv(name);
        return 0;
    }
    return setenv(name, value, 1) != 0;
#endif
}

static void write_u32_le(unsigned char* p, unsigned value) {
    for (int i = 0; i < 4; i++) p[i] = (unsigned char)((value >> (8 * i)) & 0xFF);
}

static void write_u64_le(unsigned char* p, unsigned long long value) {
    for (int i = 0; i < 8; i++) p[i] = (unsigned char)((value >> (8 * i)) & 0xFF);
}

// The same flags tools/package.py compiles a runtime module with, because the
// two produce the same artifact and `run_ums_test` imports the packaging code
// and compares their bytes -- two producers of one format is a drift neither
// side can see, and a local toolchain that behaves unlike the shipped one is
// worse than no local toolchain. Configuration files on Apple and Homebrew clang inject stack-probing
// attributes meant for immediate native code generation; they are not a portable
// bitcode contract and can make a later backend reject the merged module, so
// stack protection is left to the final whole-program invocation.
// -ffile-compilation-dir=. because clang records its working directory in the
// module's DIFile on Windows, and the two producers run from different ones: a
// project build from wherever `prismio build` was typed, package.py from the
// checkout root. That one line was the whole of the drift.
static int emit_runtime_bitcode(const char* clang, const char* runtime_dir,
                                const char* out_dir, const char* module,
                                int verify, const char* log_path) {
    char source[1024];
    char output[1024];
    snprintf(source, sizeof(source), "%s%c%s.c", runtime_dir, PRISMIO_PATH_SEP, module);
    snprintf(output, sizeof(output), "%s%c%s%s.bc", out_dir, PRISMIO_PATH_SEP,
             module, verify ? ".verify" : "");

    char* q_src = command_quote_arg(source);
    char* q_out = command_quote_arg(output);
    size_t len = strlen(clang) + strlen(q_src) + strlen(q_out) + 192;
    char* command = (char*)malloc(len);
    if (!command) {
        free(q_src);
        free(q_out);
        return 1;
    }
    snprintf(command, len,
             "%s -O2 -fno-stack-check -fno-stack-protector -ffile-compilation-dir=. "
             "-Wno-deprecated-declarations %s-emit-llvm -c %s -o %s",
             clang, verify ? "-DPRISMIO_AIF_VERIFY " : "", q_src, q_out);
    int failed = run_quiet_build_command(command, log_path);
    free(command);
    free(q_src);
    free(q_out);
    return failed;
}

// One code section of a PLIB: the module compiled to textual IR by the compiler
// under test, then assembled. PRISMIO_LIBRARY_MODULE is what makes codegen emit
// a library interface rather than a program, and PRISMIO_INTERNAL_HOSTED stops
// the freshly built host from forwarding this command back to the project host
// it is about to become.
static int emit_plib_section(const char* clang, const char* compiler,
                             const char* source, const char* module,
                             const char* base, int verify, const char* log_path,
                             unsigned char** data, size_t* size) {
    char ir_suffix[64];
    char bc_suffix[64];
    snprintf(ir_suffix, sizeof(ir_suffix), "plib-%d%s.ll", PRISMIO_GETPID(),
             verify ? "-verify" : "");
    snprintf(bc_suffix, sizeof(bc_suffix), "plib-%d%s.bc", PRISMIO_GETPID(),
             verify ? "-verify" : "");
    char* ir_path = compiler_temp_path(base, ir_suffix);
    char* bc_path = compiler_temp_path(base, bc_suffix);
    if (!ir_path || !bc_path) {
        free(ir_path);
        free(bc_path);
        return 1;
    }

    char* normalized = run_command_path(compiler);
    char* q_compiler = normalized ? command_quote_arg(normalized) : NULL;
    char* q_source = command_quote_arg(source);
    char* q_ir = command_quote_arg(ir_path);
    char* q_bc = command_quote_arg(bc_path);
    int failed = !q_compiler;

    if (!failed) {
        size_t len = strlen(q_compiler) + strlen(q_source) + strlen(q_ir) + 64;
        char* command = (char*)malloc(len);
        if (!command) {
            failed = 1;
        } else {
            snprintf(command, len, "%s build %s %s-o %s", q_compiler, q_source,
                     verify ? "--verify " : "", q_ir);
            failed = set_env_var("PRISMIO_LIBRARY_MODULE", module)
                     || run_quiet_build_command(command, log_path);
            set_env_var("PRISMIO_LIBRARY_MODULE", NULL);
            free(command);
        }
    }
    if (!failed) {
        size_t len = strlen(clang) + strlen(q_ir) + strlen(q_bc) + 48;
        char* command = (char*)malloc(len);
        if (!command) {
            failed = 1;
        } else {
            snprintf(command, len, "%s -emit-llvm -c -x ir %s -o %s", clang, q_ir, q_bc);
            failed = run_quiet_build_command(command, log_path);
            free(command);
        }
    }
    if (!failed) failed = read_binary_file(bc_path, data, size);

    delete_file(ir_path);
    delete_file(bc_path);
    free(q_compiler);
    free(q_source);
    free(q_ir);
    free(q_bc);
    free(normalized);
    free(ir_path);
    free(bc_path);
    return failed;
}

// PLIB v3, written by the same file that reads it -- see compiler_plib_interface
// for the layout. The interface section is the module's source: generic bodies
// have to be instantiated against the importing program's concrete types, so the
// frontend still parses them.
//
// A project toolchain is built for its host, so this writes the one host section
// (triple ""). tools/package.py writes the same bytes for the same inputs, plus a
// section per `--target` it was asked to package -- `run_ums_test` compares the
// host case byte for byte.
static int emit_stdlib_plib(const char* clang, const char* compiler,
                            const char* std_dir, const char* out_dir,
                            const char* module, const char* log_path) {
    char source[1024];
    char output[1024];
    char logical[288];
    snprintf(source, sizeof(source), "%s%c%s.psm", std_dir, PRISMIO_PATH_SEP, module);
    snprintf(output, sizeof(output), "%s%c%s.plib", out_dir, PRISMIO_PATH_SEP, module);
    snprintf(logical, sizeof(logical), "std.%s", module);

    unsigned char* interface = NULL;
    unsigned char* code = NULL;
    unsigned char* verify_code = NULL;
    size_t interface_size = 0, code_size = 0, verify_size = 0;

    int failed = read_binary_file(source, &interface, &interface_size);
    if (!failed) {
        failed = emit_plib_section(clang, compiler, source, logical, output, 0,
                                   log_path, &code, &code_size);
    }
    if (!failed) {
        failed = emit_plib_section(clang, compiler, source, logical, output, 1,
                                   log_path, &verify_code, &verify_size);
    }

    if (!failed) {
        size_t module_len = strlen(logical);
        unsigned char header[24];
        memcpy(header, "PRPLIB3\n", 8);
        write_u32_le(header + 8, (unsigned)module_len);
        write_u64_le(header + 12, (unsigned long long)interface_size);
        write_u32_le(header + 20, 1);
        unsigned char section[20];
        write_u32_le(section, 0);
        write_u64_le(section + 4, (unsigned long long)code_size);
        write_u64_le(section + 12, (unsigned long long)verify_size);

        FILE* file = fopen(output, "wb");
        if (!file) {
            failed = 1;
        } else {
            failed = fwrite(header, 1, sizeof(header), file) != sizeof(header)
                     || fwrite(logical, 1, module_len, file) != module_len
                     || (interface_size
                         && fwrite(interface, 1, interface_size, file) != interface_size)
                     || fwrite(section, 1, sizeof(section), file) != sizeof(section)
                     || fwrite(code, 1, code_size, file) != code_size
                     || fwrite(verify_code, 1, verify_size, file) != verify_size;
            if (fclose(file) != 0) failed = 1;
        }
        if (failed) delete_file(output);
    }

    free(interface);
    free(code);
    free(verify_code);
    return failed;
}

// The toolchain stamp: what `lib/runtime/*.bc` and `stdlib/*.plib` were built
// from, so that a build which changed neither does not build them again.
//
// The emission below is not free and it ran on every single `prismio build` of
// a project host: four clang invocations for the runtime and, per standard
// library module, two compiler runs and two clang runs. On this checkout that is
// 1.45s of an 8.2s self-build -- paid in full to reproduce, byte for byte, the
// files already on disk.
//
// One file, `lib/toolchain.stamp`, with one `<name> <key>` line per artifact and
// a version line first. Two properties of that shape matter. Every entry line is
// preceded by a newline, which is what lets a lookup match `\n<name> <key>\n`
// and stops `std.io` from being found inside a hypothetical `std.iomanip`. And
// the file is rewritten from the entries this run actually validated, so an
// entry for a module whose source was deleted disappears with the module.
//
// A missing, unreadable or unrecognised stamp is not an error anywhere here: it
// means everything is rebuilt, which is what this function did before.
#define PRISMIO_TOOLCHAIN_STAMP_HEADER "prismio-toolchain-stamp 1\n"

static int toolchain_cache_disabled(void) {
    const char* v = getenv("PRISMIO_TOOLCHAIN_CACHE");
    return v && v[0] == '0' && v[1] == '\0';
}

// Prints one line per artifact saying whether it was reused. Same reasoning as
// object_cache_trace: "the build was faster" is not an observation a test can
// make reliably on a shared host, so the test asks for this instead.
static int toolchain_cache_trace(void) {
    const char* v = getenv("PRISMIO_TOOLCHAIN_CACHE_TRACE");
    return v && v[0] != '\0' && !(v[0] == '0' && v[1] == '\0');
}

static void toolchain_cache_report(const char* verdict, const char* name) {
    if (!toolchain_cache_trace()) return;
    fprintf(stderr, "[toolchain %s] %s\n", verdict, name);
}

typedef struct {
    char* text;
    size_t len;
    size_t cap;
} ToolchainStamp;

// Appends `<name> <key>\n`. Returns non-zero only on allocation failure, and a
// caller that gets one drops the stamp rather than writing a partial one: an
// incomplete stamp claims artifacts are current that were never checked.
static int stamp_append(ToolchainStamp* stamp, const char* name, const char* key) {
    char line[384];
    int written = snprintf(line, sizeof(line), "%s %s\n", name, key);
    if (written < 0 || (size_t)written >= sizeof(line)) return 1;

    if (stamp->len + (size_t)written + 1 > stamp->cap) {
        size_t cap = stamp->cap ? stamp->cap : 512;
        while (cap < stamp->len + (size_t)written + 1) cap *= 2;
        char* grown = (char*)realloc(stamp->text, cap);
        if (!grown) return 1;
        stamp->text = grown;
        stamp->cap = cap;
    }
    memcpy(stamp->text + stamp->len, line, (size_t)written + 1);
    stamp->len += (size_t)written;
    return 0;
}

// The recorded stamp, or NULL when there is none this version can read. The
// header is compared rather than skipped, so a format change invalidates every
// entry instead of matching lines that now mean something else.
static char* stamp_read(const char* path) {
    char* text = read_file(path);
    if (!text) return NULL;
    if (strncmp(text, PRISMIO_TOOLCHAIN_STAMP_HEADER,
                strlen(PRISMIO_TOOLCHAIN_STAMP_HEADER)) != 0) {
        free(text);
        return NULL;
    }
    return text;
}

static int stamp_holds(const char* text, const char* name, const char* key) {
    if (!text) return 0;
    char line[384];
    int written = snprintf(line, sizeof(line), "\n%s %s\n", name, key);
    if (written < 0 || (size_t)written >= sizeof(line)) return 0;
    return strstr(text, line) != NULL;
}

// Size and mtime, and this is the one key in this file that is allowed to use
// them. The rule the hash helpers above state -- content, never timestamps -- is
// about *sources*: a checkout or a copy moves their mtimes without changing a
// line. clang is a binary this build did not produce and does not ship, hashing
// its hundreds of megabytes would cost more than the four compiles the key
// guards, and an upgrade that leaves both the size and the mtime alone is not a
// thing a package manager does. ccache keys its compiler the same way.
static unsigned long long clang_identity(unsigned long long hash) {
    hash = fnv1a_bytes(hash, (const unsigned char*)native_clang_command());
    if (!g_clang_binary[0]) return hash;

    char identity[160];
#ifdef _WIN32
    WIN32_FILE_ATTRIBUTE_DATA info;
    if (!GetFileAttributesExA(g_clang_binary, GetFileExInfoStandard, &info)) return hash;
    snprintf(identity, sizeof(identity), "%lu:%lu/%lu:%lu",
             (unsigned long)info.nFileSizeHigh, (unsigned long)info.nFileSizeLow,
             (unsigned long)info.ftLastWriteTime.dwHighDateTime,
             (unsigned long)info.ftLastWriteTime.dwLowDateTime);
#else
    struct stat info;
    if (stat(g_clang_binary, &info) != 0) return hash;
    snprintf(identity, sizeof(identity), "%lld/%lld",
             (long long)info.st_size, (long long)info.st_mtime);
#endif
    return fnv1a_bytes(hash, (const unsigned char*)identity);
}

// The key for the whole runtime bitcode set: what its C sources hash to, and
// which clang turns them into bitcode.
//
// The source half is the same value `lib/runtime.hash` records, which is what
// makes a reuse here and the staleness guard in src/driver/compile.psm incapable
// of disagreeing about whether these files match `runtime/`. Returns non-zero
// when there are no runtime sources to hash -- an installed toolchain with no
// checkout, where the caller has already decided there is nothing to build.
static int runtime_cache_key(char* out, int out_size) {
    char* source = compiler_runtime_source_hash();
    if (!source || !source[0]) {
        free(source);
        return 1;
    }
    unsigned long long hash = fnv1a_bytes(PRISMIO_FNV_OFFSET, (const unsigned char*)source);
    free(source);
    snprintf(out, out_size, "%016llx", clang_identity(hash));
    return 0;
}

// The compiler that will emit the PLIB code sections, hashed by its bytes.
//
// By its bytes and not by its sources, because the emission is literally
// `<compiler> build std/<module>.psm`: the binary *is* the dependency, and it is
// the only thing here that also covers a changed PLIB container format, a
// changed codegen and a changed `--verify` lowering at once.
//
// A link that is not byte-reproducible costs cache hits and nothing else -- a
// key that moves rebuilds, which is what a build with no cache does every time.
// 0 is the "could not read it" answer and disables the standard-library half of
// the cache; FNV-1a over a real executable does not produce it.
static unsigned long long compiler_binary_hash(const char* compiler) {
    unsigned char* data = NULL;
    size_t size = 0;
    if (read_binary_file(compiler, &data, &size) != 0) return 0;
    unsigned long long hash = fnv1a_raw(PRISMIO_FNV_OFFSET, data, size);
    free(data);
    return hash;
}

static int plib_cache_key(char* out, int out_size, const char* source_path,
                          unsigned long long compiler_hash) {
    char* text = read_file(source_path);
    if (!text) return 1;
    unsigned long long hash = fnv1a_raw(PRISMIO_FNV_OFFSET,
                                        (const unsigned char*)&compiler_hash,
                                        sizeof(compiler_hash));
    hash = fnv1a_bytes(hash, (const unsigned char*)text);
    free(text);
    snprintf(out, out_size, "%016llx", hash);
    return 0;
}

// Every file the runtime half of the stamp vouches for, present. A key that
// matches says the *inputs* have not moved; it says nothing about whether the
// outputs are still on disk, and a deleted `.bc` is exactly the state a reuse
// must not walk past.
static int runtime_bitcode_present(const char* runtime_out) {
    char path[1024];
    for (int i = 0; i < PRISMIO_RUNTIME_MODULE_COUNT; i++) {
        for (int verify = 0; verify < 2; verify++) {
            snprintf(path, sizeof(path), "%s%c%s%s.bc", runtime_out, PRISMIO_PATH_SEP,
                     prismio_runtime_modules[i], verify ? ".verify" : "");
            if (!file_exists(path)) return 0;
        }
    }
    return 1;
}

// Build the runtime bitcode and standard library a project-local compiler needs
// in order to build anything other than itself.
//
// Returns the number of standard-library modules the toolchain now provides --
// rebuilt here or reused from the last build -- 0 when this project has no
// Prismio checkout to build them from (an ordinary project that pins a
// `toolchain.host` is not building a toolchain and must not be failed for it),
// and -1 when the emission was attempted and failed.
//
// **Reuse is per artifact and keyed on its own inputs**, through the stamp
// described above. A runtime `.c` edit rebuilds four `.bc` files and no PLIB; a
// `std/list.psm` edit rebuilds one PLIB and no bitcode; a `src/` edit changes
// the compiler binary and so rebuilds every PLIB, because every PLIB's code
// section is that compiler's output. Nothing is keyed on a timestamp comparison
// between a source and an output: a build that produced a *different* compiler
// from the same standard library source has to re-emit, and mtimes cannot see
// that.
int compiler_emit_local_toolchain(const char* root, const char* compiler) {
    char runtime_probe[1024];
    char std_probe[1024];
    if (!find_toolchain_source(runtime_probe, sizeof(runtime_probe), "lang_runtime.c")
        || !find_toolchain_entry(std_probe, sizeof(std_probe), "std", "string.psm")) {
        return 0;
    }

    char* runtime_dir = absolute_directory(runtime_probe);
    char* std_dir = absolute_directory(std_probe);
    char lib_dir[1024];
    char runtime_out[1024];
    char stdlib_out[1024];
    char log_path[1024];
    char stamp_path[1024];
    char hash_path[1024];
    snprintf(lib_dir, sizeof(lib_dir), "%s%clib", root, PRISMIO_PATH_SEP);
    snprintf(runtime_out, sizeof(runtime_out), "%s%cruntime", lib_dir, PRISMIO_PATH_SEP);
    snprintf(stdlib_out, sizeof(stdlib_out), "%s%cstdlib", root, PRISMIO_PATH_SEP);
    snprintf(log_path, sizeof(log_path), "%s%c.toolchain-%d.log", lib_dir,
             PRISMIO_PATH_SEP, PRISMIO_GETPID());
    snprintf(stamp_path, sizeof(stamp_path), "%s%ctoolchain.stamp", lib_dir,
             PRISMIO_PATH_SEP);
    snprintf(hash_path, sizeof(hash_path), "%s%cruntime.hash", lib_dir, PRISMIO_PATH_SEP);

    int failed = ensure_directory_exists(runtime_out) != 0
                 || ensure_directory_exists(stdlib_out) != 0;

    // The recorded stamp is dropped from disk before anything is built. Every
    // path out of here either writes a complete new one or leaves none at all,
    // so a build interrupted between the first rebuild and the last cannot leave
    // a file claiming that artifacts it never touched are current.
    int bypass = toolchain_cache_disabled();
    char* recorded = bypass ? NULL : stamp_read(stamp_path);
    delete_file(stamp_path);
    if (bypass) toolchain_cache_report("cache off", "runtime and stdlib");

    ToolchainStamp stamp = { NULL, 0, 0 };
    int stamp_broken = stamp_append(&stamp, "prismio-toolchain-stamp", "1");

    char runtime_key[64];
    int have_runtime_key = !failed && runtime_cache_key(runtime_key, sizeof(runtime_key)) == 0;

    const char* clang = native_clang_command();
    int runtime_current = have_runtime_key
                          && stamp_holds(recorded, "runtime", runtime_key)
                          && runtime_bitcode_present(runtime_out)
                          && file_exists(hash_path);
    if (!failed && runtime_current) {
        toolchain_cache_report("reused", "runtime");
    } else if (!failed) {
        toolchain_cache_report("rebuilt", "runtime");
        for (int i = 0; i < PRISMIO_RUNTIME_MODULE_COUNT && !failed; i++) {
            failed = emit_runtime_bitcode(clang, runtime_dir, runtime_out,
                                          prismio_runtime_modules[i], 0, log_path)
                     || emit_runtime_bitcode(clang, runtime_dir, runtime_out,
                                             prismio_runtime_modules[i], 1, log_path);
        }

        // Recorded the way an installed toolchain records it, so the freshness
        // check reads one file whether the toolchain was installed or built here.
        if (!failed) {
            char* value = compiler_runtime_source_hash();
            failed = write_text_file(hash_path, value) != 0;
            free(value);
        }
    }
    if (!failed && have_runtime_key) {
        stamp_broken = stamp_broken || stamp_append(&stamp, "runtime", runtime_key);
    }

    // The failure core a `--freestanding` build adds (runtime/freestanding/panic.c),
    // beside the runtime bitcode where an installed toolchain keeps it. Source and
    // not bitcode: it is compiled for the program's own triple, and a copy is
    // cheaper than a stamp entry for one file of sixty lines.
    if (!failed) {
        char core_source[1024];
        if (find_toolchain_source(core_source, sizeof(core_source), "freestanding/panic.c")) {
            char core_dir[1024];
            char core_out[1024];
            snprintf(core_dir, sizeof(core_dir), "%s%cfreestanding", runtime_out, PRISMIO_PATH_SEP);
            snprintf(core_out, sizeof(core_out), "%s%cpanic.c", core_dir, PRISMIO_PATH_SEP);
            char* text = read_file(core_source);
            if (text && ensure_directory_exists(core_dir) == 0) write_text_file(core_out, text);
            free(text);
        }
    }

    // The host is about to become this project's compiler, so every command it
    // issues here has to be answered by the binary named rather than forwarded
    // back to the host being replaced.
    char* saved = NULL;
    int was_set = 0;
    if (!failed && compiler_hosted_env_begin(&saved, &was_set) != 0) {
        free(saved);
        saved = NULL;
        failed = 1;
    }

    int written = 0;
    if (!failed) {
        // A `.plib` whose source is gone is not stale, it is wrong: the module
        // no longer exists and importing it would resolve against a build
        // artifact nothing produces any more.
        char* installed = list_modules(stdlib_out);
        for (char* name = installed; name && *name; ) {
            char* end = strchr(name, '\n');
            if (end) *end = '\0';
            char probe[1024];
            snprintf(probe, sizeof(probe), "%s%c%s.psm", std_dir, PRISMIO_PATH_SEP, name);
            if (!file_exists(probe)) {
                snprintf(probe, sizeof(probe), "%s%c%s.plib", stdlib_out,
                         PRISMIO_PATH_SEP, name);
                delete_file(probe);
            }
            name = end ? end + 1 : name + strlen(name);
        }
        rt_free(installed);

        // Computed even when the cache is bypassed. `PRISMIO_TOOLCHAIN_CACHE=0`
        // means this build must not *consult* the stamp; recording what it then
        // went and built is what stops one bypassed build from costing two, and
        // the entries it writes are as true as any other build's.
        unsigned long long compiler_hash = compiler_binary_hash(compiler);

        char* modules = list_modules(std_dir);
        for (char* name = modules; name && *name && !failed; ) {
            char* end = strchr(name, '\n');
            if (end) *end = '\0';

            char source[1024];
            char output[1024];
            char entry[288];
            char key[64];
            snprintf(source, sizeof(source), "%s%c%s.psm", std_dir, PRISMIO_PATH_SEP, name);
            snprintf(output, sizeof(output), "%s%c%s.plib", stdlib_out,
                     PRISMIO_PATH_SEP, name);
            snprintf(entry, sizeof(entry), "std.%s", name);

            int have_key = compiler_hash != 0
                           && plib_cache_key(key, sizeof(key), source, compiler_hash) == 0;
            if (have_key && stamp_holds(recorded, entry, key) && file_exists(output)) {
                toolchain_cache_report("reused", entry);
            } else {
                toolchain_cache_report("rebuilt", entry);
                failed = emit_stdlib_plib(clang, compiler, std_dir, stdlib_out, name,
                                          log_path);
            }
            if (!failed) {
                written++;
                if (have_key) {
                    stamp_broken = stamp_broken || stamp_append(&stamp, entry, key);
                }
            }
            name = end ? end + 1 : name + strlen(name);
        }
        rt_free(modules);
        compiler_hosted_env_end(saved, was_set);
    }

    // Written last and only on success. The cache is an optimisation, so a stamp
    // that cannot be built or cannot be written is not a build failure -- it is
    // the next build doing the work this one would have saved it.
    if (!failed && !stamp_broken && stamp.text) {
        if (write_text_file(stamp_path, stamp.text) != 0) delete_file(stamp_path);
    }
    free(stamp.text);
    free(recorded);

    free(runtime_dir);
    free(std_dir);
    if (failed) {
        fprintf(stderr,
                "ERROR: could not build the project-local runtime and standard library\n"
                "       under %s\n", root);
        return -1;
    }
    return written;
}

// Candidate and active are siblings, so this is one same-filesystem operation.
// The child compiler has exited before it gets here, which makes replacement
// valid on Windows too; the UMS side refuses to promote over the executable that
// owns the orchestrating process.
int compiler_promote_executable(const char* candidate_file, const char* active_file) {
#ifdef _WIN32
    return MoveFileExA(candidate_file, active_file,
                       MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH) ? 0 : 1;
#else
    return rename(candidate_file, active_file) == 0 ? 0 : 1;
#endif
}

// Trusting a project host
//
// `toolchain.host` names a file the launcher will execute on every command,
// `--version` and `check` included -- and the IntelliJ plugin runs `check` when a
// file is opened. A repository that committed an executable at that path had it
// run by opening the project. The generation handshake is no defence: any
// program that exits 0 passes it.
//
// So a host is only run if this machine promoted it. Promotion writes
// `<host>.trusted` beside it with the file's identity: device, inode (the file
// index on Windows), size and modification time to the nanosecond. A clone
// cannot bring a matching stamp, because the inode and the mtime are assigned
// when the checkout writes the file, and a host that is replaced or edited
// after promotion stops matching. Hashing the binary would say the same thing
// about content and cost a second per command on a 130 MB compiler; identity is
// a stat.
static int host_identity(const char* path, char* out, size_t size) {
#ifdef _WIN32
    HANDLE file = CreateFileA(path, GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE |
                              FILE_SHARE_DELETE, NULL, OPEN_EXISTING, 0, NULL);
    if (file == INVALID_HANDLE_VALUE) return 0;
    BY_HANDLE_FILE_INFORMATION info;
    int ok = GetFileInformationByHandle(file, &info) != 0;
    CloseHandle(file);
    if (!ok) return 0;
    snprintf(out, size, "%lu %lu %lu %lu %lu %lu %lu",
             (unsigned long)info.dwVolumeSerialNumber,
             (unsigned long)info.nFileIndexHigh, (unsigned long)info.nFileIndexLow,
             (unsigned long)info.nFileSizeHigh, (unsigned long)info.nFileSizeLow,
             (unsigned long)info.ftLastWriteTime.dwHighDateTime,
             (unsigned long)info.ftLastWriteTime.dwLowDateTime);
    return 1;
#else
    struct stat st;
    if (stat(path, &st) != 0) return 0;
#ifdef __APPLE__
    long long nanoseconds = (long long)st.st_mtimespec.tv_nsec;
#else
    long long nanoseconds = (long long)st.st_mtim.tv_nsec;
#endif
    snprintf(out, size, "%llu %llu %lld %lld %lld",
             (unsigned long long)st.st_dev, (unsigned long long)st.st_ino,
             (long long)st.st_size, (long long)st.st_mtime, nanoseconds);
    return 1;
#endif
}

static char* host_stamp_path(const char* host) {
    size_t n = strlen(host) + sizeof(".trusted");
    char* path = (char*)malloc(n);
    if (path) snprintf(path, n, "%s.trusted", host);
    return path;
}

#define HOST_STAMP_HEADER "prismio-host-stamp 1\n"

int compiler_host_stamp_write(const char* host) {
    char identity[256];
    if (!host_identity(host, identity, sizeof(identity))) return 1;
    char* path = host_stamp_path(host);
    if (!path) return 1;
    FILE* file = fopen(path, "wb");
    free(path);
    if (!file) return 1;
    int ok = fprintf(file, "%s%s\n", HOST_STAMP_HEADER, identity) > 0;
    return (fclose(file) == 0 && ok) ? 0 : 1;
}

int compiler_host_stamp_matches(const char* host) {
    char identity[256];
    if (!host_identity(host, identity, sizeof(identity))) return 0;
    char expected[320];
    snprintf(expected, sizeof(expected), "%s%s\n", HOST_STAMP_HEADER, identity);

    char* path = host_stamp_path(host);
    if (!path) return 0;
    FILE* file = fopen(path, "rb");
    free(path);
    if (!file) return 0;
    char recorded[320];
    size_t n = fread(recorded, 1, sizeof(recorded) - 1, file);
    fclose(file);
    recorded[n] = '\0';
    return strcmp(recorded, expected) == 0;
}

// Removing a directory tree, for `clean`
//
// Everything under `path` except the executable running this process: a hosted
// `clean` is that executable, Windows refuses to delete it, and the launcher
// removes it once this process has exited. The directory holding it is then left
// with that one file in it, which is not a failure. Symbolic links are removed,
// never followed. Answers 0 when everything else went.
static int remove_tree_failed = 0;

#ifdef _WIN32
static void remove_tree_at(const char* path) {
    size_t n = strlen(path);
    char* pattern = (char*)malloc(n + 3);
    if (!pattern) { remove_tree_failed = 1; return; }
    snprintf(pattern, n + 3, "%s\\*", path);
    WIN32_FIND_DATAA entry;
    HANDLE find = FindFirstFileA(pattern, &entry);
    free(pattern);
    if (find != INVALID_HANDLE_VALUE) {
        do {
            if (strcmp(entry.cFileName, ".") == 0 || strcmp(entry.cFileName, "..") == 0) continue;
            size_t child_len = n + strlen(entry.cFileName) + 2;
            char* child = (char*)malloc(child_len);
            if (!child) { remove_tree_failed = 1; continue; }
            snprintf(child, child_len, "%s\\%s", path, entry.cFileName);
            int directory = (entry.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) &&
                            !(entry.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT);
            if (directory) {
                remove_tree_at(child);
                _rmdir(child);
            } else if (!compiler_is_current_executable(child) && !DeleteFileA(child)) {
                remove_tree_failed = 1;
            }
            free(child);
        } while (FindNextFileA(find, &entry));
        FindClose(find);
    }
}
#else
static int remove_tree_entry(const char* path, const struct stat* st, int type,
                             struct FTW* ftw) {
    (void)st;
    (void)ftw;
    if (type == FTW_DP) {
        // A directory still holding the running executable is expected to stay.
        if (rmdir(path) != 0 && errno != ENOTEMPTY && errno != EEXIST) remove_tree_failed = 1;
        return 0;
    }
    if (compiler_is_current_executable(path)) return 0;
    if (unlink(path) != 0) remove_tree_failed = 1;
    return 0;
}
#endif

int compiler_remove_tree(const char* path) {
    if (!path || !path[0]) return 1;
    remove_tree_failed = 0;
#ifdef _WIN32
    DWORD attributes = GetFileAttributesA(path);
    if (attributes == INVALID_FILE_ATTRIBUTES) return 0;
    remove_tree_at(path);
    _rmdir(path);
#else
    struct stat st;
    if (lstat(path, &st) != 0) return 0;
    if (nftw(path, remove_tree_entry, 16, FTW_DEPTH | FTW_PHYS) != 0) return 1;
#endif
    return remove_tree_failed;
}

// LAYOUT 3.2 -- running a workload at build time
// The whole of the sandbox, and it is smaller than the clause makes it sound
// because this language's surface is small. W3 names three effects to stub:
// network, absolute filesystem paths, and environment access. Prismio's runtime
// exposes none of them -- str_*, list_*, print and the allocators, and that is
// the list. What a program *can* do is declare an `extern fn` for any symbol the
// C library happens to export, which is the real hole, and it is closed on the
// other side: codegen gives every extern the runtime does not define a body of
// rt_workload_stub instead of a link (see generateWorkloadStubs). So by the time
// a driver runs, the only foreign code it can reach is the Prismio runtime.
// That leaves what this function owns: argv, the working directory, and time.
//  - **argv is empty.** `process.args` reads the prismio_argv global, which a
//    driver never fills, so a workload cannot branch on the compiler's own command line
//    and produce a profile that depends on how the build was invoked.
//  - **The working directory is the output directory**, not the user's. A
//    relative path a workload opens through a stubbed extern goes nowhere, and
//    the profile lands beside the other build temporaries.
//  - **Time is bounded.** W2 lists "times out" as a fallback case, so it has to
//    be a case that can happen: a workload with an unbounded loop must warn and
//    fall back rather than hang the build forever.
// The timeout is enforced with the platform's own tool rather than by forking:
// `timeout` on Linux, and on macOS the same via a subshell watchdog, because
// coreutils' timeout is not installed by default there. A missing watchdog is
// not fatal -- the run simply is not bounded, which is the pre-existing
// behaviour of every other build command this file issues.
int compiler_run_workload(const char* exe_file, int timeout_seconds) {
    char* normalized = run_command_path(exe_file);
    if (!normalized) return 1;

    char* q_exe = command_quote_arg(normalized);
    int command_len = (int)strlen(q_exe) + 128;
    char* command = (char*)malloc(command_len);

#if defined(_WIN32)
    // No portable watchdog in cmd.exe. Recorded rather than faked: on Windows a
    // workload that hangs hangs the build, and the fix is a job object, which is
    // more platform code than this feature has earned until someone hits it.
    (void)timeout_seconds;
    snprintf(command, command_len, "%s", q_exe);
#else
    // `sh -c 'cmd & p=$!; (sleep N; kill $p) & wait $p'` is the portable form.
    // Using it unconditionally rather than probing for coreutils keeps one code
    // path on both Unixes.
    //
    // **The watchdog's redirections are load-bearing and were not obvious.** The
    // subshell inherits this process's stdout and stderr, which for any caller
    // that captures our output is a pipe. A reader waits for EOF, and EOF needs
    // *every* writer to close -- so a driver that finished in 40 ms still left
    // the reader blocked until the `sleep` expired, turning the timeout into a
    // floor on every workload build instead of a ceiling. It surfaced as the
    // test suite hanging with no process using any CPU.
    snprintf(command, command_len,
             "sh -c '%s & p=$!; { sleep %d; kill $p; } >/dev/null 2>&1 </dev/null & w=$!; "
             "wait $p; s=$?; kill $w 2>/dev/null; exit $s'",
             q_exe, timeout_seconds > 0 ? timeout_seconds : 60);
#endif

    int result = run_build_command(command);

    free(command);
    free(q_exe);
    free(normalized);
    return result;
}
