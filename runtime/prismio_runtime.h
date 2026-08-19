#ifndef PRISMIO_RUNTIME_H
#define PRISMIO_RUNTIME_H

// Program support: the half of the old driver.c that a *compiled Prismio program*
// can legitimately call at its own runtime. Implemented in program_support.c and
// destined for runtime.lib / runtime.a.
//
// The dividing line is "would a user's program ever call this?". Command-line
// access and plain file/path helpers: yes -- tests/test_19_runtime_split.psm
// already externs executable_directory, join_path, command_quote_arg and
// file_exists, and src/main.psm externs read_file, get_directory and delete_file.
// Driving llc/clang to produce an executable: no, that is the compiler's job and
// lives in build_driver.c (backend.lib).
//
// build_driver.c includes this header because the build orchestration reuses these
// helpers; the dependency runs backend -> runtime and never the other way.

// --- file and path helpers ---
int file_exists(const char* path);
char* read_file(const char* path);
char* get_directory(const char* path);
char* join_path(const char* directory, const char* filename);
char* current_directory(void);
int delete_file(const char* path);
char* list_modules(const char* directory);

// Directory containing the running executable. executable_directory() falls back
// to "." so callers always get a usable string; prismio_executable_directory()
// returns NULL when the location genuinely cannot be determined, which the
// toolchain-source search in build_driver.c needs in order to try its next
// candidate. Both return malloc'd memory.
char* executable_directory(void);
char* prismio_executable_directory(void);

// --- command helpers ---
char* command_quote_arg(const char* arg);
int execute_command(const char* command);

// --- command line, as seen by the compiled program ---
// Backed by the prismio_argc / prismio_argv globals that generated code defines
// and fills from main's real argc/argv (see generate_module / generate_function in
// src/ir.psm), which is what makes these work identically on every platform.
int cli_arg_count(void);
char* cli_arg(int index);

// --- REQUIREMENTS 15: tasks and channels ---
// prismio_task_* are compiler-emitted: `spawn f(x)` and `join t` lower to them,
// so no program declares them by hand. The chan_* set is ordinary FFI surface a
// program externs for itself, because a channel is a library, not syntax.
//
// SPEC 11 item 10 is what shapes the split: a task *owns* its arguments and a
// channel *moves* its messages, so nothing the solver tiers is ever reachable
// from two tasks at once -- which is what keeps T3's count non-atomic.
void* prismio_task_spawn(void* fn, int nargs, void* a0, void* a1, void* a2);
int   prismio_task_join(void* handle);
void  prismio_task_release(void* handle);

void* chan_new(int capacity);
int   chan_send(void* handle, void* msg);
void* chan_recv(void* handle);
void* chan_share(void* handle);
void  chan_close(void* handle);
int   chan_len(void* handle);
void  chan_free(void* handle);

// --- LAYOUT 2/3: the measured access profile ---
// Present in every binary and called only from a workload driver, which is an
// instrumented build the compiler produces, runs and discards. A shipped program
// contains no call to any of these -- see the block comment in lang_runtime.c for
// why that, rather than a -D, is what keeps W4 true.
void rt_profile_begin(void);
void rt_profile_end(void);
void rt_profile_field(const char* type, const char* field, int is_write);
void rt_profile_range(const char* type, const char* field, long long value);
void rt_profile_alloc(const char* type);
void rt_profile_release(const char* type);
int  rt_profile_dump(const char* path, const char* workload, int runs);

// W3: the body every extern the sandbox cannot provide is given instead of a
// link to whatever libc exports. Warns once per symbol and returns 0.
long long rt_workload_stub(const char* name);

#endif
