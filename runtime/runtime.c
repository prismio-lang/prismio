#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#include <direct.h>
#include <process.h>
#include <windows.h>
extern int __argc;
extern char** __argv;
#define PRISMIO_GETPID _getpid
#define PRISMIO_MKDIR(path) _mkdir(path)
#define PRISMIO_RMDIR(path) _rmdir(path)
#define PRISMIO_PATH_SEP '\\'
#else
#include <sys/stat.h>
#include <unistd.h>
#define PRISMIO_GETPID getpid
#define PRISMIO_MKDIR(path) mkdir(path, 0777)
#define PRISMIO_RMDIR(path) rmdir(path)
#define PRISMIO_PATH_SEP '/'
#endif

#ifndef PRISMIO_EMBEDDED_SOURCES_HEADER
#define PRISMIO_EMBEDDED_SOURCES_HEADER "embedded_sources.h"
#endif
#include PRISMIO_EMBEDDED_SOURCES_HEADER

// Println function - prints a string and adds a newline
void println(const char* str) {
    printf("%s\n", str);
    fflush(stdout);
}

// Print function - prints a string without newline
void print(const char* str) {
    printf("%s", str);
    fflush(stdout);
}

// Print integer
void print_int(int value) {
    printf("%d", value);
    fflush(stdout);
}

// Print integer with newline
void println_int(int value) {
    printf("%d\n", value);
    fflush(stdout);
}

// Print boolean
void print_bool(int value) {
    printf("%s", value ? "true" : "false");
    fflush(stdout);
}

// Print boolean with newline
void println_bool(int value) {
    printf("%s\n", value ? "true" : "false");
    fflush(stdout);
}

// Print character
void print_char(char c) {
    printf("%c", c);
    fflush(stdout);
}

// Print character with newline
void println_char(char c) {
    printf("%c\n", c);
    fflush(stdout);
}

// Array structure
typedef struct {
    void* data;
    int length;
    int capacity;
} Array;

// Create array
Array* array_new(int element_size, int initial_capacity) {
    Array* arr = (Array*)malloc(sizeof(Array));
    arr->length = 0;
    arr->capacity = initial_capacity;
    arr->data = malloc(element_size * initial_capacity);
    return arr;
}

// Free array
void array_free(Array* arr) {
    free(arr->data);
    free(arr);
}

// Push element (generic)
void array_push(Array* arr, void* element, int element_size) {
    if (arr->length >= arr->capacity) {
        // Resize
        arr->capacity *= 2;
        arr->data = realloc(arr->data, element_size * arr->capacity);
    }

    // Copy element to end
    char* dest = (char*)arr->data + (arr->length * element_size);
    memcpy(dest, element, element_size);
    arr->length++;
}

// Get element
void* array_get(Array* arr, int index, int element_size) {
    if (index < 0 || index >= arr->length) {
        return NULL;
    }
    return (char*)arr->data + (index * element_size);
}

// Array length
int array_len(Array* arr) {
    return arr->length;
}

// ============================================
// String Comparison
// ============================================

int str_equals(const char* s1, const char* s2) {
    return strcmp(s1, s2) == 0 ? 1 : 0;
}

int str_compare(const char* s1, const char* s2) {
    return strcmp(s1, s2);
}

// ============================================
// String Length
// ============================================

int str_length(const char* s) {
    return strlen(s);
}

// ============================================
// String Concatenation
// ============================================

char* str_concat(const char* s1, const char* s2) {
    int len1 = strlen(s1);
    int len2 = strlen(s2);
    char* result = (char*)malloc(len1 + len2 + 1);

    strcpy(result, s1);
    strcat(result, s2);

    return result;
}

// ============================================
// String Substring
// ============================================

char* str_substring(const char* s, int start, int length) {
    int str_len = strlen(s);

    if (start < 0 || start >= str_len) {
        return "";
    }

    if (start + length > str_len) {
        length = str_len - start;
    }

    char* result = (char*)malloc(length + 1);
    strncpy(result, s + start, length);
    result[length] = '\0';

    return result;
}

// ============================================
// String Character At
// ============================================

char str_char_at(const char* s, int index) {
    int len = strlen(s);

    if (index < 0 || index >= len) {
        return '\0';
    }

    return s[index];
}

// ============================================
// String Contains
// ============================================

int str_contains(const char* haystack, const char* needle) {
    return strstr(haystack, needle) != NULL ? 1 : 0;
}

// ============================================
// String Starts With
// ============================================

int str_starts_with(const char* s, const char* prefix) {
    int s_len = strlen(s);
    int prefix_len = strlen(prefix);

    if (prefix_len > s_len) {
        return 0;
    }

    return strncmp(s, prefix, prefix_len) == 0 ? 1 : 0;
}

// ============================================
// String Ends With
// ============================================

int str_ends_with(const char* s, const char* suffix) {
    int s_len = strlen(s);
    int suffix_len = strlen(suffix);

    if (suffix_len > s_len) {
        return 0;
    }

    return strcmp(s + (s_len - suffix_len), suffix) == 0 ? 1 : 0;
}

// ============================================
// String Index Of
// ============================================

int str_index_of(const char* haystack, const char* needle) {
    const char* pos = strstr(haystack, needle);

    if (pos == NULL) {
        return -1;
    }

    return pos - haystack;
}

// ============================================
// String Replace (first occurrence)
// ============================================

char* str_replace(const char* s, const char* old_str, const char* new_str) {
    const char* pos = strstr(s, old_str);

    if (pos == NULL) {
        // No match, return copy
        char* result = (char*)malloc(strlen(s) + 1);
        strcpy(result, s);
        return result;
    }

    int old_len = strlen(old_str);
    int new_len = strlen(new_str);
    int prefix_len = pos - s;
    int suffix_len = strlen(pos + old_len);

    char* result = (char*)malloc(prefix_len + new_len + suffix_len + 1);

    // Copy prefix
    strncpy(result, s, prefix_len);
    result[prefix_len] = '\0';

    // Copy new string
    strcat(result, new_str);

    // Copy suffix
    strcat(result, pos + old_len);

    return result;
}

// ============================================
// String To Integer
// ============================================

int str_to_int(const char* s) {
    return atoi(s);
}

// ============================================
// Integer To String
// ============================================

char* int_to_str(int n) {
    char* result = (char*)malloc(32);  // enough for any int
    sprintf(result, "%d", n);
    return result;
}

// ============================================
// String Clone/Copy
// ============================================

char* str_clone(const char* s) {
    int len = strlen(s);
    char* result = (char*)malloc(len + 1);
    strcpy(result, s);
    return result;
}

// ============================================
// String Trim (whitespace)
// ============================================

char* str_trim(const char* s) {
    // Find start (skip leading whitespace)
    while (*s == ' ' || *s == '\t' || *s == '\n' || *s == '\r') {
        s++;
    }

    if (*s == '\0') {
        return "";
    }

    // Find end (skip trailing whitespace)
    const char* end = s + strlen(s) - 1;
    while (end > s && (*end == ' ' || *end == '\t' || *end == '\n' || *end == '\r')) {
        end--;
    }

    int len = end - s + 1;
    char* result = (char*)malloc(len + 1);
    strncpy(result, s, len);
    result[len] = '\0';

    return result;
}

// ============================================
// String Split (simplified - single delimiter)
// ============================================

typedef struct {
    char** parts;
    int count;
} StringArray;

StringArray* str_split(const char* s, char delimiter) {
    // Count delimiters
    int count = 1;
    for (const char* p = s; *p; p++) {
        if (*p == delimiter) count++;
    }

    StringArray* result = (StringArray*)malloc(sizeof(StringArray));
    result->parts = (char**)malloc(count * sizeof(char*));
    result->count = count;

    int part_index = 0;
    const char* start = s;
    const char* p = s;

    while (1) {
        if (*p == delimiter || *p == '\0') {
            int len = p - start;
            result->parts[part_index] = (char*)malloc(len + 1);
            strncpy(result->parts[part_index], start, len);
            result->parts[part_index][len] = '\0';
            part_index++;

            if (*p == '\0') break;
            start = p + 1;
        }
        p++;
    }

    return result;
}

void str_split_free(StringArray* arr) {
    for (int i = 0; i < arr->count; i++) {
        free(arr->parts[i]);
    }
    free(arr->parts);
    free(arr);
}

// ============================================
// File I/O Functions
// ============================================

// Check if file exists
int file_exists(const char* path) {
    FILE* file = fopen(path, "r");
    if (file) {
        fclose(file);
        return 1;
    }
    return 0;
}

// Read entire file into string
char* read_file(const char* path) {
    FILE* file = fopen(path, "rb");
    if (!file) {
        return NULL;
    }

    // Get file size
    fseek(file, 0, SEEK_END);
    long size = ftell(file);
    fseek(file, 0, SEEK_SET);

    // Allocate buffer
    char* buffer = (char*)malloc(size + 1);
    if (!buffer) {
        fclose(file);
        return NULL;
    }

    // Read file
    size_t read = fread(buffer, 1, size, file);
    buffer[read] = '\0';

    fclose(file);
    return buffer;
}

// Get directory from file path
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
    char* result = (char*)malloc(strlen(stem) + 5);
    sprintf(result, "%s.exe", stem);
    free(stem);
    return result;
}

char* compiler_temp_ir_path(const char* source_path) {
    char* directory = get_directory(source_path);
    const char* filename = path_file_name(source_path);
    const char* dot = strrchr(filename, '.');
    int stem_len = dot ? (int)(dot - filename) : (int)strlen(filename);
    int pid = PRISMIO_GETPID();

    int has_directory = strcmp(directory, ".") != 0;
    int result_len = (has_directory ? (int)strlen(directory) + 1 : 0) +
                     (int)strlen(".prismio-") + stem_len +
                     (int)strlen("-2147483648.ll") + 1;
    char* result = (char*)malloc(result_len);

    if (has_directory) {
        sprintf(result, "%s%c.prismio-%.*s-%d.ll", directory,
#ifdef _WIN32
                '\\',
#else
                '/',
#endif
                stem_len, filename, pid);
    } else {
        sprintf(result, ".prismio-%.*s-%d.ll", stem_len, filename, pid);
    }

    free(directory);
    return result;
}

int delete_file(const char* path) {
    if (!path || path[0] == '\0') return 0;
    return remove(path) == 0 ? 0 : 1;
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

static int copy_existing_path(char* out, int out_size, const char** candidates) {
    for (int i = 0; candidates[i] != NULL; i++) {
        FILE* file = fopen(candidates[i], "rb");
        if (file) {
            fclose(file);
            strncpy(out, candidates[i], out_size - 1);
            out[out_size - 1] = '\0';
            return 1;
        }
    }
    return 0;
}

static int copy_existing_file_path(char* out, int out_size, const char* candidate) {
    FILE* file = fopen(candidate, "rb");
    if (file) {
        fclose(file);
        strncpy(out, candidate, out_size - 1);
        out[out_size - 1] = '\0';
        return 1;
    }
    return 0;
}

static char* compiler_executable_directory() {
#ifdef _WIN32
    char exe_path[1024];
    DWORD len = GetModuleFileNameA(NULL, exe_path, sizeof(exe_path));
    if (len > 0 && len < sizeof(exe_path)) {
        return get_directory(exe_path);
    }

    if (__argc > 0 && __argv[0] && __argv[0][0] != '\0') {
        return get_directory(__argv[0]);
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

char* executable_directory() {
    char* directory = compiler_executable_directory();
    if (directory) {
        return directory;
    }

    char* fallback = (char*)malloc(2);
    strcpy(fallback, ".");
    return fallback;
}

static int copy_toolchain_source_path(char* out, int out_size, const char* filename, const char** cwd_candidates) {
    char* compiler_dir = compiler_executable_directory();
    if (compiler_dir) {
        char candidate[1024];

        snprintf(candidate, sizeof(candidate), "%s%c..%cruntime%c%s",
                 compiler_dir, PRISMIO_PATH_SEP, PRISMIO_PATH_SEP, PRISMIO_PATH_SEP, filename);
        if (copy_existing_file_path(out, out_size, candidate)) {
            free(compiler_dir);
            return 1;
        }

        snprintf(candidate, sizeof(candidate), "%s%cruntime%c%s",
                 compiler_dir, PRISMIO_PATH_SEP, PRISMIO_PATH_SEP, filename);
        if (copy_existing_file_path(out, out_size, candidate)) {
            free(compiler_dir);
            return 1;
        }

        free(compiler_dir);
    }

    return copy_existing_path(out, out_size, cwd_candidates);
}

static char* quote_arg(const char* arg) {
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

char* command_quote_arg(const char* arg) {
    return quote_arg(arg);
}

static int run_build_command(const char* command) {
    int result = system(command);
    return result == 0 ? 0 : 1;
}

int execute_command(const char* command) {
#ifdef _WIN32
    int command_len = (int)strlen(command) + 16;
    char* wrapped = (char*)malloc(command_len);
    snprintf(wrapped, command_len, "cmd /S /C \"%s\"", command);
    int result = run_build_command(wrapped);
    free(wrapped);
    return result;
#else
    return run_build_command(command);
#endif
}

static char* compiler_temp_obj_path(const char* exe_file, const char* role) {
    char* directory = get_directory(exe_file);
    const char* filename = path_file_name(exe_file);
    const char* dot = strrchr(filename, '.');
    int stem_len = dot ? (int)(dot - filename) : (int)strlen(filename);
    int pid = PRISMIO_GETPID();
    int has_directory = strcmp(directory, ".") != 0;
    int result_len = (has_directory ? (int)strlen(directory) + 1 : 0) +
                     (int)strlen(".prismio-") + stem_len + 1 +
                     (int)strlen(role) + (int)strlen("-2147483648.obj") + 1;
    char* result = (char*)malloc(result_len);

    if (has_directory) {
        sprintf(result, "%s%c.prismio-%.*s-%s-%d.obj", directory,
#ifdef _WIN32
                '\\',
#else
                '/',
#endif
                stem_len, filename, role, pid);
    } else {
        sprintf(result, ".prismio-%.*s-%s-%d.obj", stem_len, filename, role, pid);
    }

    free(directory);
    return result;
}

static char* compiler_temp_source_dir(const char* exe_file) {
    char* directory = get_directory(exe_file);
    const char* filename = path_file_name(exe_file);
    const char* dot = strrchr(filename, '.');
    int stem_len = dot ? (int)(dot - filename) : (int)strlen(filename);
    int pid = PRISMIO_GETPID();
    int has_directory = strcmp(directory, ".") != 0;
    int result_len = (has_directory ? (int)strlen(directory) + 1 : 0) +
                     (int)strlen(".prismio-") + stem_len +
                     (int)strlen("-sources-2147483648") + 1;
    char* result = (char*)malloc(result_len);

    if (has_directory) {
        sprintf(result, "%s%c.prismio-%.*s-sources-%d",
                directory, PRISMIO_PATH_SEP, stem_len, filename, pid);
    } else {
        sprintf(result, ".prismio-%.*s-sources-%d", stem_len, filename, pid);
    }

    free(directory);
    return result;
}

static char* path_join(const char* directory, const char* filename) {
    int len = (int)strlen(directory) + 1 + (int)strlen(filename) + 1;
    char* result = (char*)malloc(len);
    sprintf(result, "%s%c%s", directory, PRISMIO_PATH_SEP, filename);
    return result;
}

char* join_path(const char* directory, const char* filename) {
    return path_join(directory, filename);
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

static void write_c_string_literal(FILE* file, const char* name, const char* value) {
    fprintf(file, "static const char %s[] =\n\"", name);
    int column = 0;

    for (const unsigned char* p = (const unsigned char*)value; *p; p++) {
        unsigned char c = *p;

        if (c == '\n') {
            fputs("\\n\"\n\"", file);
            column = 0;
            continue;
        }

        if (column > 96) {
            fputs("\"\n\"", file);
            column = 0;
        }

        if (c == '\\') {
            fputs("\\\\", file);
            column += 2;
        } else if (c == '"') {
            fputs("\\\"", file);
            column += 2;
        } else if (c == '\r') {
            fputs("\\r", file);
            column += 2;
        } else if (c == '\t') {
            fputs("\\t", file);
            column += 2;
        } else if (c < 32 || c > 126) {
            fprintf(file, "\\%03o", c);
            column += 4;
        } else {
            fputc(c, file);
            column += 1;
        }
    }

    fputs("\";\n\n", file);
}

static int write_embedded_sources_header(const char* path) {
    FILE* file = fopen(path, "wb");
    if (!file) {
        return 1;
    }

    fputs("#ifndef PRISMIO_EMBEDDED_SOURCES_H\n", file);
    fputs("#define PRISMIO_EMBEDDED_SOURCES_H\n\n", file);
    fputs("#define PRISMIO_EMBEDDED_SOURCE_AVAILABLE 1\n\n", file);
    write_c_string_literal(file, "prismio_embedded_runtime_c", prismio_embedded_runtime_c);
    write_c_string_literal(file, "prismio_embedded_llvm_bridge_c", prismio_embedded_llvm_bridge_c);
    fputs("#endif\n", file);

    fclose(file);
    return 0;
}

int compiler_build_executable(const char* ir_file, const char* exe_file) {
    const char* runtime_candidates[] = {
        "runtime\\runtime.c", "runtime/runtime.c",
        "..\\runtime\\runtime.c", "../runtime/runtime.c",
        "..\\..\\runtime\\runtime.c", "../../runtime/runtime.c",
        NULL
    };
    const char* bridge_candidates[] = {
        "runtime\\llvm-bridge.c", "runtime/llvm-bridge.c",
        "..\\runtime\\llvm-bridge.c", "../runtime/llvm-bridge.c",
        "..\\..\\runtime\\llvm-bridge.c", "../../runtime/llvm-bridge.c",
        NULL
    };

    if (compiler_prepare_output_path(exe_file) != 0) {
        fprintf(stderr, "ERROR: could not create output directory\n");
        return 1;
    }

    char runtime_c[1024];
    char bridge_c[1024];
    int using_embedded_sources = 0;
    char* embedded_dir = NULL;
    char* embedded_runtime_c = NULL;
    char* embedded_bridge_c = NULL;
    char* embedded_header = NULL;

#ifdef PRISMIO_EMBEDDED_SOURCE_AVAILABLE
    embedded_dir = compiler_temp_source_dir(exe_file);
    embedded_runtime_c = path_join(embedded_dir, "runtime.c");
    embedded_bridge_c = path_join(embedded_dir, "llvm-bridge.c");
    embedded_header = path_join(embedded_dir, "embedded_sources.h");

    if (ensure_directory_exists(embedded_dir) == 0 &&
        write_text_file(embedded_runtime_c, prismio_embedded_runtime_c) == 0 &&
        write_text_file(embedded_bridge_c, prismio_embedded_llvm_bridge_c) == 0 &&
        write_embedded_sources_header(embedded_header) == 0) {
        strncpy(runtime_c, embedded_runtime_c, sizeof(runtime_c) - 1);
        runtime_c[sizeof(runtime_c) - 1] = '\0';
        strncpy(bridge_c, embedded_bridge_c, sizeof(bridge_c) - 1);
        bridge_c[sizeof(bridge_c) - 1] = '\0';
        using_embedded_sources = 1;
    }
#endif

    if (!using_embedded_sources && !copy_toolchain_source_path(runtime_c, sizeof(runtime_c), "runtime.c", runtime_candidates)) {
        fprintf(stderr, "ERROR: could not find runtime/runtime.c\n");
        return 1;
    }

    if (!using_embedded_sources && !copy_toolchain_source_path(bridge_c, sizeof(bridge_c), "llvm-bridge.c", bridge_candidates)) {
        fprintf(stderr, "ERROR: could not find runtime/llvm-bridge.c\n");
        return 1;
    }

    char* program_obj = compiler_temp_obj_path(exe_file, "program");
    char* runtime_obj = compiler_temp_obj_path(exe_file, "runtime");
    char* bridge_obj = compiler_temp_obj_path(exe_file, "bridge");

    char* q_ir = quote_arg(ir_file);
    char* q_exe = quote_arg(exe_file);
    char* q_program_obj = quote_arg(program_obj);
    char* q_runtime_obj = quote_arg(runtime_obj);
    char* q_bridge_obj = quote_arg(bridge_obj);
    char* q_runtime_c = quote_arg(runtime_c);
    char* q_bridge_c = quote_arg(bridge_c);

    int command_len = (int)(strlen(q_ir) + strlen(q_exe) + strlen(q_program_obj) +
                            strlen(q_runtime_obj) + strlen(q_bridge_obj) +
                            strlen(q_runtime_c) + strlen(q_bridge_c) + 256);
    char* command = (char*)malloc(command_len);
    int result = 0;

    snprintf(command, command_len, "llc %s -filetype=obj -o %s", q_ir, q_program_obj);
    if (run_build_command(command) != 0) result = 1;

    if (result == 0) {
        snprintf(command, command_len, "clang -Wno-deprecated-declarations -c %s -o %s", q_runtime_c, q_runtime_obj);
        if (run_build_command(command) != 0) result = 1;
    }

    if (result == 0) {
        snprintf(command, command_len, "clang -Wno-deprecated-declarations -c %s -o %s", q_bridge_c, q_bridge_obj);
        if (run_build_command(command) != 0) result = 1;
    }

    if (result == 0) {
        snprintf(command, command_len, "clang %s %s %s -o %s",
                 q_program_obj, q_runtime_obj, q_bridge_obj, q_exe);
        if (run_build_command(command) != 0) result = 1;
    }

    delete_file(program_obj);
    delete_file(runtime_obj);
    delete_file(bridge_obj);
    if (embedded_runtime_c) delete_file(embedded_runtime_c);
    if (embedded_bridge_c) delete_file(embedded_bridge_c);
    if (embedded_header) delete_file(embedded_header);
    if (embedded_dir) PRISMIO_RMDIR(embedded_dir);

    free(command);
    free(q_ir);
    free(q_exe);
    free(q_program_obj);
    free(q_runtime_obj);
    free(q_bridge_obj);
    free(q_runtime_c);
    free(q_bridge_c);
    free(program_obj);
    free(runtime_obj);
    free(bridge_obj);
    if (embedded_runtime_c) free(embedded_runtime_c);
    if (embedded_bridge_c) free(embedded_bridge_c);
    if (embedded_header) free(embedded_header);
    if (embedded_dir) free(embedded_dir);

    return result;
}

int compiler_run_executable(const char* exe_file) {
    char* q_exe = quote_arg(exe_file);
    int command_len = (int)strlen(q_exe) + 8;
    char* command = (char*)malloc(command_len);

    snprintf(command, command_len, "%s", q_exe);
    int result = run_build_command(command);

    free(command);
    free(q_exe);
    return result;
}

int cli_arg_count() {
#ifdef _WIN32
    return __argc;
#else
    return 0;
#endif
}

char* cli_arg(int index) {
#ifdef _WIN32
    if (index < 0 || index >= __argc) {
        return "";
    }
    return __argv[index];
#else
    return "";
#endif
}

// Helpers for type punning ASTNode pointers in Prismio
void* ptr_to_node(void* ptr) { return ptr; }
void* node_to_ptr(void* ptr) { return ptr; }
void* ptr_to_token(void* ptr) { return ptr; }
void* token_to_ptr(void* ptr) { return ptr; }
