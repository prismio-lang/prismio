#ifdef PRISMIO_WASM

typedef unsigned int size_t;
#define NULL ((void*)0)

extern unsigned char __heap_base;

__attribute__((import_module("env"), import_name("print")))
void wasm_host_print(const char* str);
__attribute__((import_module("env"), import_name("println")))
void wasm_host_println(const char* str);
__attribute__((import_module("env"), import_name("print_float")))
void wasm_host_print_float(double value);
__attribute__((import_module("env"), import_name("println_float")))
void wasm_host_println_float(double value);

static unsigned int wasm_heap_ptr = 0;

static unsigned int wasm_align8(unsigned int value) {
    return (value + 7u) & ~7u;
}

void* memcpy(void* dest, const void* src, size_t count) {
    unsigned char* d = (unsigned char*)dest;
    const unsigned char* s = (const unsigned char*)src;
    for (size_t i = 0; i < count; i++) {
        d[i] = s[i];
    }
    return dest;
}

void* malloc(size_t size) {
    if (wasm_heap_ptr == 0) {
        wasm_heap_ptr = wasm_align8((unsigned int)&__heap_base);
    }

    unsigned int raw = wasm_heap_ptr;
    unsigned int total = wasm_align8((unsigned int)size + 4u);
    wasm_heap_ptr += total;
    *((unsigned int*)raw) = (unsigned int)size;
    return (void*)(raw + 4u);
}

void free(void* ptr) {
    (void)ptr;
}

// Reset the bump allocator to the base — a cheap per-frame arena. String/data
// literals live below __heap_base and are unaffected.
void heap_reset(void) {
    wasm_heap_ptr = 0;
}

void* realloc(void* ptr, size_t size) {
    if (!ptr) {
        return malloc(size);
    }

    unsigned int old_size = *(((unsigned int*)ptr) - 1);
    void* next = malloc(size);
    if (next) {
        unsigned int copy_size = old_size < (unsigned int)size ? old_size : (unsigned int)size;
        memcpy(next, ptr, copy_size);
    }
    return next;
}

size_t strlen(const char* s) {
    size_t len = 0;
    while (s[len] != '\0') {
        len++;
    }
    return len;
}

char* strcpy(char* dest, const char* src) {
    size_t i = 0;
    while (src[i] != '\0') {
        dest[i] = src[i];
        i++;
    }
    dest[i] = '\0';
    return dest;
}

char* strncpy(char* dest, const char* src, size_t count) {
    size_t i = 0;
    while (i < count && src[i] != '\0') {
        dest[i] = src[i];
        i++;
    }
    while (i < count) {
        dest[i] = '\0';
        i++;
    }
    return dest;
}

char* strcat(char* dest, const char* src) {
    size_t offset = strlen(dest);
    size_t i = 0;
    while (src[i] != '\0') {
        dest[offset + i] = src[i];
        i++;
    }
    dest[offset + i] = '\0';
    return dest;
}

int strcmp(const char* a, const char* b) {
    size_t i = 0;
    while (a[i] != '\0' && b[i] != '\0') {
        if (a[i] != b[i]) {
            return ((unsigned char)a[i]) - ((unsigned char)b[i]);
        }
        i++;
    }
    return ((unsigned char)a[i]) - ((unsigned char)b[i]);
}

int strncmp(const char* a, const char* b, size_t count) {
    for (size_t i = 0; i < count; i++) {
        if (a[i] != b[i] || a[i] == '\0' || b[i] == '\0') {
            return ((unsigned char)a[i]) - ((unsigned char)b[i]);
        }
    }
    return 0;
}

char* strstr(const char* haystack, const char* needle) {
    size_t needle_len = strlen(needle);
    if (needle_len == 0) {
        return (char*)haystack;
    }

    for (size_t i = 0; haystack[i] != '\0'; i++) {
        if (strncmp(haystack + i, needle, needle_len) == 0) {
            return (char*)(haystack + i);
        }
    }
    return NULL;
}

static char* int_to_str_buffer(int n, char* result) {
    unsigned int value;
    int negative = 0;
    if (n < 0) {
        negative = 1;
        value = (unsigned int)(0 - n);
    } else {
        value = (unsigned int)n;
    }

    char temp[16];
    int len = 0;
    do {
        temp[len] = (char)('0' + (value % 10u));
        value = value / 10u;
        len++;
    } while (value > 0u);

    int out = 0;
    if (negative) {
        result[out++] = '-';
    }
    while (len > 0) {
        result[out++] = temp[--len];
    }
    result[out] = '\0';
    return result;
}

// Println function - prints a string and adds a newline
void println(const char* str) {
    wasm_host_println(str);
}

// Print function - prints a string without newline
void print(const char* str) {
    wasm_host_print(str);
}

// Print integer
void print_int(int value) {
    char buffer[32];
    wasm_host_print(int_to_str_buffer(value, buffer));
}

// Print integer with newline
void println_int(int value) {
    char buffer[32];
    wasm_host_println(int_to_str_buffer(value, buffer));
}

// Print float
void print_float(double value) {
    wasm_host_print_float(value);
}

// Print float with newline
void println_float(double value) {
    wasm_host_println_float(value);
}

// Print boolean
void print_bool(int value) {
    wasm_host_print(value ? "true" : "false");
}

// Print boolean with newline
void println_bool(int value) {
    wasm_host_println(value ? "true" : "false");
}

// Print character
void print_char(char c) {
    char buffer[2];
    buffer[0] = c;
    buffer[1] = '\0';
    wasm_host_print(buffer);
}

// Print character with newline
void println_char(char c) {
    char buffer[2];
    buffer[0] = c;
    buffer[1] = '\0';
    wasm_host_println(buffer);
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
        arr->capacity *= 2;
        arr->data = realloc(arr->data, element_size * arr->capacity);
    }

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

int str_equals(const char* s1, const char* s2) {
    return strcmp(s1, s2) == 0 ? 1 : 0;
}

int str_compare(const char* s1, const char* s2) {
    return strcmp(s1, s2);
}

int str_length(const char* s) {
    return (int)strlen(s);
}

char* str_concat(const char* s1, const char* s2) {
    int len1 = (int)strlen(s1);
    int len2 = (int)strlen(s2);
    char* result = (char*)malloc(len1 + len2 + 1);

    strcpy(result, s1);
    strcat(result, s2);

    return result;
}

char* str_substring(const char* s, int start, int length) {
    int str_len = (int)strlen(s);

    if (start < 0 || start >= str_len) {
        return "";
    }

    if (start + length > str_len) {
        length = str_len - start;
    }

    char* result = (char*)malloc(length + 1);
    strncpy(result, s + start, (size_t)length);
    result[length] = '\0';

    return result;
}

char str_char_at(const char* s, int index) {
    int len = (int)strlen(s);

    if (index < 0 || index >= len) {
        return '\0';
    }

    return s[index];
}

int str_contains(const char* haystack, const char* needle) {
    return strstr(haystack, needle) != NULL ? 1 : 0;
}

int str_starts_with(const char* s, const char* prefix) {
    int s_len = (int)strlen(s);
    int prefix_len = (int)strlen(prefix);

    if (prefix_len > s_len) {
        return 0;
    }

    return strncmp(s, prefix, (size_t)prefix_len) == 0 ? 1 : 0;
}

int str_ends_with(const char* s, const char* suffix) {
    int s_len = (int)strlen(s);
    int suffix_len = (int)strlen(suffix);

    if (suffix_len > s_len) {
        return 0;
    }

    return strcmp(s + (s_len - suffix_len), suffix) == 0 ? 1 : 0;
}

int str_index_of(const char* haystack, const char* needle) {
    const char* pos = strstr(haystack, needle);

    if (pos == NULL) {
        return -1;
    }

    return (int)(pos - haystack);
}

char* str_replace(const char* s, const char* old_str, const char* new_str) {
    const char* pos = strstr(s, old_str);

    if (pos == NULL) {
        char* result = (char*)malloc(strlen(s) + 1);
        strcpy(result, s);
        return result;
    }

    int old_len = (int)strlen(old_str);
    int new_len = (int)strlen(new_str);
    int prefix_len = (int)(pos - s);
    int suffix_len = (int)strlen(pos + old_len);

    char* result = (char*)malloc(prefix_len + new_len + suffix_len + 1);
    strncpy(result, s, (size_t)prefix_len);
    result[prefix_len] = '\0';
    strcat(result, new_str);
    strcat(result, pos + old_len);

    return result;
}

int str_to_int(const char* s) {
    int sign = 1;
    int value = 0;
    if (*s == '-') {
        sign = -1;
        s++;
    }
    while (*s >= '0' && *s <= '9') {
        value = value * 10 + (*s - '0');
        s++;
    }
    return value * sign;
}

char* int_to_str(int n) {
    char* result = (char*)malloc(32);
    return int_to_str_buffer(n, result);
}

char* str_clone(const char* s) {
    int len = (int)strlen(s);
    char* result = (char*)malloc(len + 1);
    strcpy(result, s);
    return result;
}

char* str_trim(const char* s) {
    while (*s == ' ' || *s == '\t' || *s == '\n' || *s == '\r') {
        s++;
    }

    if (*s == '\0') {
        return "";
    }

    const char* end = s + strlen(s) - 1;
    while (end > s && (*end == ' ' || *end == '\t' || *end == '\n' || *end == '\r')) {
        end--;
    }

    int len = (int)(end - s + 1);
    char* result = (char*)malloc(len + 1);
    strncpy(result, s, (size_t)len);
    result[len] = '\0';

    return result;
}

typedef struct {
    char** parts;
    int count;
} StringArray;

StringArray* str_split(const char* s, char delimiter) {
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
            int len = (int)(p - start);
            result->parts[part_index] = (char*)malloc(len + 1);
            strncpy(result->parts[part_index], start, (size_t)len);
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

void* ptr_to_node(void* ptr) { return ptr; }
void* node_to_ptr(void* ptr) { return ptr; }
void* ptr_to_token(void* ptr) { return ptr; }
void* token_to_ptr(void* ptr) { return ptr; }
void* ptr_to_type(void* ptr) { return ptr; }
void* type_to_ptr(void* ptr) { return ptr; }

#else

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

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

// Print float
void print_float(double value) {
    printf("%g", value);
    fflush(stdout);
}

// Print float with newline
void println_float(double value) {
    printf("%g\n", value);
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

// Helpers for type punning ASTNode pointers in Prismio
void* ptr_to_node(void* ptr) { return ptr; }
void* node_to_ptr(void* ptr) { return ptr; }
void* ptr_to_token(void* ptr) { return ptr; }
void* token_to_ptr(void* ptr) { return ptr; }
void* ptr_to_type(void* ptr) { return ptr; }
void* type_to_ptr(void* ptr) { return ptr; }

// Native builds use libc malloc; the per-frame arena reset is a no-op here.
void heap_reset(void) { }

#endif

// ============================================
// Growable list (List<T> for reference elements) — backs Prismio's List<T>.
// Stores pointer-sized elements; works on native and wasm32.
// ============================================
typedef struct {
    void** data;
    int len;
    int cap;
} XefyList;

void* list_new(void) {
    XefyList* l = (XefyList*)malloc(sizeof(XefyList));
    l->len = 0;
    l->cap = 4;
    l->data = (void**)malloc(sizeof(void*) * 4);
    return l;
}

void list_push(void* lp, void* value) {
    XefyList* l = (XefyList*)lp;
    if (l->len >= l->cap) {
        int nc = l->cap * 2;
        void** nd = (void**)malloc(sizeof(void*) * nc);
        for (int i = 0; i < l->len; i++) nd[i] = l->data[i];
        l->data = nd;
        l->cap = nc;
    }
    l->data[l->len] = value;
    l->len = l->len + 1;
}

void* list_get(void* lp, int index) {
    XefyList* l = (XefyList*)lp;
    if (index < 0 || index >= l->len) return 0;
    return l->data[index];
}

void list_set(void* lp, int index, void* value) {
    XefyList* l = (XefyList*)lp;
    if (index >= 0 && index < l->len) l->data[index] = value;
}

int list_len(void* lp) {
    XefyList* l = (XefyList*)lp;
    return l->len;
}
