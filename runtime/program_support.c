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

// ============================================
// File I/O
// ============================================

int file_exists(const char* path) {
    FILE* file = fopen(path, "r");
    if (file) {
        fclose(file);
        return 1;
    }
    return 0;
}

// Returns an empty string on failure, never NULL. Prismio has no null String, so
// every caller checks the result with str_equals(content, "") -- and handing them a
// NULL turned "file not found" into strcmp(NULL, "") and an access violation. That
// made `prismio build missing.psm`, and any `import` naming a file that is not
// there, crash silently instead of reporting the error the code already had ready.
char* read_file(const char* path) {
    FILE* file = fopen(path, "rb");
    if (!file) {
        char* empty = (char*)malloc(1);
        empty[0] = '\0';
        return empty;
    }

    fseek(file, 0, SEEK_END);
    long size = ftell(file);
    fseek(file, 0, SEEK_SET);

    char* buffer = (char*)malloc(size + 1);
    if (!buffer) {
        fclose(file);
        char* empty = (char*)malloc(1);
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

// ============================================
// Paths
// ============================================

char* get_directory(const char* path) {
    const char* last_slash = strrchr(path, '/');
    const char* last_backslash = strrchr(path, '\\');

    const char* separator = last_slash > last_backslash ? last_slash : last_backslash;

    if (!separator) {
        char* result = (char*)malloc(2);
        strcpy(result, ".");
        return result;
    }

    int len = separator - path;
    char* result = (char*)malloc(len + 1);
    strncpy(result, path, len);
    result[len] = '\0';

    return result;
}

char* join_path(const char* directory, const char* filename) {
    int len = (int)strlen(directory) + 1 + (int)strlen(filename) + 1;
    char* result = (char*)malloc(len);
    sprintf(result, "%s%c%s", directory, PRISMIO_PATH_SEP, filename);
    return result;
}

// ============================================
// Locating the running executable
// ============================================

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

    char* fallback = (char*)malloc(2);
    strcpy(fallback, ".");
    return fallback;
}

// ============================================
// Commands
// ============================================

char* command_quote_arg(const char* arg) {
    int len = strlen(arg);
    char* result = (char*)malloc((len * 2) + 3);
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

// ============================================
// Command line
// ============================================

int cli_arg_count(void) {
    return prismio_argc;
}

char* cli_arg(int index) {
    if (index < 0 || index >= prismio_argc || prismio_argv == NULL) {
        return "";
    }
    return prismio_argv[index];
}
