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
int delete_file(const char* path);

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

#endif
