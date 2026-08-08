// AIF Level 4. Strings and lists are affine now, so codegen emits a release for
// them -- and the allocation at the other end of that pairing is in *this* file,
// not behind ir_alloc_object. Both ends have to swap together or a verify build
// reports every string release as a pointer that was never live.
//
// The build driver compiles this file with -DPRISMIO_AIF_VERIFY for `--verify`,
// which is why verify mode still changes no codegen: the swap happens when the
// runtime is compiled, not when the program is generated.
#ifdef PRISMIO_AIF_VERIFY
#include <stddef.h>
void* aif_verify_alloc(size_t size);
void  aif_verify_release(void* p);
void  aif_verify_arm(void);
#define rt_base_alloc(n) aif_verify_alloc(n)
#define rt_free(p)       aif_verify_release(p)
#else
#define rt_base_alloc(n) malloc(n)
#define rt_free(p)       free(p)
#endif

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

// wasm has no `region` runtime -- arena_push and friends are native-only -- so
// the hint is a no-op here and every allocation goes to the bump allocator,
// which is what a region would have been anyway. The symbols exist because
// codegen may emit calls to them.
#define rt_alloc(n) rt_base_alloc(n)
void rt_arena_hint_push(void) {}
void rt_arena_hint_pop(void) {}

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
    char* result = (char*)rt_alloc(len1 + len2 + 1);

    strcpy(result, s1);
    strcat(result, s2);

    return result;
}

char* str_substring(const char* s, int start, int length) {
    int str_len = (int)strlen(s);

    // Owned empty string rather than the literal "" -- see the native branch.
    if (start < 0 || start >= str_len) {
        start = str_len;
        length = 0;
    }

    if (start + length > str_len) {
        length = str_len - start;
    }

    char* result = (char*)rt_alloc(length + 1);
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

// Unchecked-length read, for a caller that already knows the string's length.
//
// str_char_at() measures the whole string on every call, so the lexer -- which
// reads one character at a time -- spent O(n) per character and was therefore
// O(n^2) over a file. Scanning the 155 KB compiler meant several gigabytes of
// strlen traffic and was most of its compile time.
//
// The contract is 0 <= index <= str_length(s). index == length is deliberately
// allowed and returns the NUL terminator, because one-character lookahead at the
// end of input is normal and the buffer is always NUL-terminated. The lexer
// holds the length in the Lexer struct and checks against it, so the bound is
// still enforced -- just not re-measured on every character.
char str_byte_at(const char* s, int index) {
    if (index < 0) return '\0';
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
        char* result = (char*)rt_alloc(strlen(s) + 1);
        strcpy(result, s);
        return result;
    }

    int old_len = (int)strlen(old_str);
    int new_len = (int)strlen(new_str);
    int prefix_len = (int)(pos - s);
    int suffix_len = (int)strlen(pos + old_len);

    char* result = (char*)rt_alloc(prefix_len + new_len + suffix_len + 1);
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
    char* result = (char*)rt_alloc(32);
    return int_to_str_buffer(n, result);
}

char* str_clone(const char* s) {
    int len = (int)strlen(s);
    char* result = (char*)rt_alloc(len + 1);
    strcpy(result, s);
    return result;
}

// One-character string. The lexer assembles a decoded string literal a character
// at a time and there is no other way to turn a Char into a String -- the
// language has no string builder and no char-to-string conversion.
char* str_from_char(char c) {
    char* result = (char*)rt_alloc(2);
    result[0] = c;
    result[1] = '\0';
    return result;
}

char* str_trim(const char* s) {
    while (*s == ' ' || *s == '\t' || *s == '\n' || *s == '\r') {
        s++;
    }

    // All-whitespace falls through to a one-byte allocation -- see the native branch.

    const char* end = s + strlen(s) - 1;
    while (end > s && (*end == ' ' || *end == '\t' || *end == '\n' || *end == '\r')) {
        end--;
    }

    int len = (int)(end - s + 1);
    char* result = (char*)rt_alloc(len + 1);
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
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

// AIF Level 4, second half: `region` absorbs collections too.
//
// COMPILER-AUDIT scheduled Level 4 after Level 3 so that regions would already
// exist to take the string traffic -- but the arena is reached through
// ir_alloc_region, and only a struct literal goes through that. A string is
// allocated in this file, by str_concat, which has no idea where it is being
// called from.
//
// So the *call site* says. Codegen brackets a producing runtime call whose value
// aif_arena_at_node accepted with rt_arena_hint_push/pop, and the allocation
// inside bumps from the arena instead of the heap. The bracket goes around the
// call only -- arguments are already evaluated by then -- so a nested allocation
// that was not accepted does not inherit the hint.
//
// The hint is a depth, not a flag, because a producing call can be an argument
// to another one. It is never pushed outside a region: aif_arena_at_node needs an
// enclosing one before it says yes.
void* arena_alloc(size_t size);

static int rt_arena_hint = 0;

void rt_arena_hint_push(void) { rt_arena_hint++; }
void rt_arena_hint_pop(void)  { if (rt_arena_hint > 0) rt_arena_hint--; }

static void* rt_alloc(size_t size) {
    if (rt_arena_hint > 0) return arena_alloc(size);
    return rt_base_alloc(size);
}

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
    char* result = (char*)rt_alloc(len1 + len2 + 1);

    strcpy(result, s1);
    strcat(result, s2);

    return result;
}

// ============================================
// String Substring
// ============================================

char* str_substring(const char* s, int start, int length) {
    int str_len = strlen(s);

    // The out-of-range answer is an empty string the caller *owns*. It used to be
    // the literal "", which was fine while nothing freed a string and is a free
    // of a .rodata pointer now that they are affine (AIF Level 4). Anything
    // declared to return String hands back something a release can take.
    if (start < 0 || start >= str_len) {
        start = str_len;
        length = 0;
    }

    if (start + length > str_len) {
        length = str_len - start;
    }

    char* result = (char*)rt_alloc(length + 1);
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

// See the native definition for why this exists.
char str_byte_at(const char* s, int index) {
    if (index < 0) return '\0';
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
        char* result = (char*)rt_alloc(strlen(s) + 1);
        strcpy(result, s);
        return result;
    }

    int old_len = strlen(old_str);
    int new_len = strlen(new_str);
    int prefix_len = pos - s;
    int suffix_len = strlen(pos + old_len);

    char* result = (char*)rt_alloc(prefix_len + new_len + suffix_len + 1);

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
    char* result = (char*)rt_alloc(32);  // enough for any int
    sprintf(result, "%d", n);
    return result;
}

// ============================================
// String Clone/Copy
// ============================================

char* str_clone(const char* s) {
    int len = strlen(s);
    char* result = (char*)rt_alloc(len + 1);
    strcpy(result, s);
    return result;
}

// One-character string. The lexer assembles a decoded string literal a character
// at a time and there is no other way to turn a Char into a String -- the
// language has no string builder and no char-to-string conversion.
char* str_from_char(char c) {
    char* result = (char*)rt_alloc(2);
    result[0] = c;
    result[1] = '\0';
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

    // An all-whitespace input falls through to a one-byte allocation rather than
    // returning the literal "" -- see str_substring for why a String return is
    // always something the caller can release.

    // Find end (skip trailing whitespace)
    const char* end = s + strlen(s) - 1;
    while (end > s && (*end == ' ' || *end == '\t' || *end == '\n' || *end == '\r')) {
        end--;
    }

    int len = end - s + 1;
    char* result = (char*)rt_alloc(len + 1);
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

// A note on how the frontend spells "this slot is empty", because it is not
// what it looks like and getting it wrong is a segfault rather than a warning.
//
// An absent child is the **empty string**, not a null pointer -- create_node()
// initialises every pointer slot to "". So `str_equals(p, "")` is the right
// question and a null test is not: a null test says "present" for an empty slot
// and the caller then dereferences it.
//
// What makes `str_equals(p, "")` fragile is the other direction. A punned
// pointer is a `char*`, so strcmp reads the *bytes of the pointed-to struct*,
// and a struct beginning with a zero-valued enum begins with a NUL byte -- so
// it compares equal to "" and a live node reads as an empty slot. src/ast.psm
// states the invariant that keeps this from firing and enforces it at the two
// enums that matter.

// Native builds use libc malloc; the per-frame arena reset is a no-op here.
void heap_reset(void) { }

// ============================================================================
// Arenas (AIF Level 3, SPEC 5.2)
//
// A stack of bump allocators. `region r { ... }` pushes one on entry and pops it
// on every exit; an allocation the analysis proved cannot outlive that region
// comes from the top of the stack, and the whole block goes back at once.
//
// COMPILER-AUDIT 3 expected the arena handle to be *threaded* to each allocation
// site as a second argument. It is dynamically scoped instead, which keeps
// ir_alloc_region a `fn(size) -> ptr` like the other two hooks and needs no new
// frontend plumbing. The cost of that choice is that a callee cannot be given a
// different arena from its caller's -- which does not arise, because only sites
// lexically inside the block are routed here (SPEC 5.2's own wording), and the
// analysis has already proved each of those dies no later than this region.
//
// Chunks are a linked list so a region that outgrows its first block keeps
// going rather than falling back to the heap; pointers already handed out stay
// valid because earlier chunks are not moved.
// ============================================================================

#define ARENA_CHUNK_MIN 8192
#define ARENA_MAX_DEPTH 64

typedef struct ArenaChunk {
    struct ArenaChunk* next;
    size_t used, cap;
    unsigned char* base;
} ArenaChunk;

static ArenaChunk* arena_stack[ARENA_MAX_DEPTH];
static int arena_depth = 0;

// Reported by arena_stats so a test can assert an allocation came from a region
// rather than from malloc -- the two are indistinguishable from the value.
static long arena_bytes_served, arena_objects_served, arena_regions_entered;

// Chunks are pooled rather than returned to libc, and that is what makes
// LAYOUT 4's `arenaSetupCost` of ~40 cycles a real number instead of an
// aspiration. Without the pool a region that serves one allocation pays a malloc
// for its chunk and a free at the pop -- 180 cycles, more than the 87 an arena
// saves per allocation -- so the cost model would have to decline every small
// scope and automatic placement (LAYOUT 7.1) could never fire. With it, entering
// a region is a depth increment and a pointer swap.
//
// Only default-sized chunks are pooled. An oversized one was cut for a single
// large allocation and holding it would keep an arbitrary amount of memory live
// for the rest of the program.
//
// The pool is capped, and the cap is the difference between "pooled" and
// "never returned to the OS". Uncapped, a program's peak arena footprint stays
// resident for the rest of its life: one pass that nests deeply or chains many
// chunks sets a high-water mark nothing ever gives back, and peak RSS carries it
// to exit. Trimming rather than removing, because removing the pool is what the
// note above says would stop automatic placement firing at all.
//
// ARENA_POOL_MAX * ARENA_CHUNK_MIN is the resident ceiling: 64 KB. The cap has
// to clear ordinary *nesting* -- chunks held by live regions are on the stack,
// not in the pool, so it only has to cover what a single pop hands back plus
// reuse across iterations, and a loop entering one region reuses one chunk.
#define ARENA_POOL_MAX 8
static ArenaChunk* arena_pool;
static int arena_pool_count;

static ArenaChunk* arena_chunk_new(size_t need) {
    if (need <= ARENA_CHUNK_MIN && arena_pool) {
        ArenaChunk* c = arena_pool;
        arena_pool = c->next;
        arena_pool_count--;
        c->used = 0;
        c->next = NULL;
        return c;
    }

    size_t cap = need > ARENA_CHUNK_MIN ? need : ARENA_CHUNK_MIN;
    ArenaChunk* c = (ArenaChunk*)malloc(sizeof(ArenaChunk));
    if (!c) return NULL;
    c->base = (unsigned char*)malloc(cap);
    if (!c->base) { free(c); return NULL; }
    c->used = 0;
    c->cap = cap;
    c->next = NULL;
    return c;
}

void arena_push(void) {
#ifdef PRISMIO_AIF_VERIFY
    aif_verify_arm();
#endif
    if (arena_depth >= ARENA_MAX_DEPTH) {
        fprintf(stderr, "internal error: regions nested more than %d deep\n", ARENA_MAX_DEPTH);
        exit(1);
    }
    arena_stack[arena_depth++] = NULL;   // chunks are taken on first use
    arena_regions_entered++;
}

void arena_pop(void) {
    if (arena_depth <= 0) return;
    ArenaChunk* c = arena_stack[--arena_depth];
    while (c) {
        ArenaChunk* next = c->next;
        if (c->cap == ARENA_CHUNK_MIN && arena_pool_count < ARENA_POOL_MAX) {
            c->next = arena_pool;
            arena_pool = c;
            arena_pool_count++;
        } else {
            free(c->base);
            free(c);
        }
        c = next;
    }
    arena_stack[arena_depth] = NULL;
}

void* arena_alloc(size_t size) {
    // No region active. Codegen only routes a site here when one is, so this is
    // a corrupted arena stack rather than an ordinary case -- but falling back
    // to the ordinary allocator keeps SPEC 1's invariant (never wrong, only
    // slower) instead of returning NULL into code that will not check it. Through
    // rt_base_alloc rather than malloc so a verify build still accounts for it.
    if (arena_depth <= 0) return rt_base_alloc(size);

    size_t need = (size + 15u) & ~(size_t)15u;   // 16-byte aligned, as malloc is
    ArenaChunk* c = arena_stack[arena_depth - 1];
    if (!c || c->used + need > c->cap) {
        ArenaChunk* fresh = arena_chunk_new(need);
        if (!fresh) return rt_base_alloc(size);
        fresh->next = c;
        arena_stack[arena_depth - 1] = fresh;
        c = fresh;
    }

    void* p = c->base + c->used;
    c->used += need;
    arena_bytes_served += (long)need;
    arena_objects_served++;
    return p;
}

long arena_objects(void) { return arena_objects_served; }
long arena_bytes(void)   { return arena_bytes_served; }
long arena_regions(void) { return arena_regions_entered; }

// ============================================================================
// AIF `verify` mode (SPEC 7.3)
//
// A verify build swaps the allocator and deallocator names through
// ir_set_alloc_function / ir_set_free_function and changes nothing else -- the
// same seam COMPILER-AUDIT 3 describes for T2, used here for its first real
// purpose. Codegen is identical to a release build.
//
// What this covers, of SPEC 7.3's table:
//
//   Tier T0/T1, "no access after frame or region exit" -- partially. Released
//   memory is poisoned before it goes back to the allocator, so a read that
//   should not have happened returns a recognisable pattern rather than data
//   that is merely stale-but-plausible. Reads are not instrumented, so this
//   makes such a bug loud rather than impossible.
//
//   The balance itself, which is not in the table and should be: every object
//   released exactly once, and none left over. That is what catches a missed
//   drop path (leak) and a doubled one (release of something not live), which
//   are the two ways Level 2 can be wrong.
//
// What it does not cover, and why:
//
//   A = Unique / A <= Borrowed  need a count word in the object header, which
//                               is the same layout change T3 needs.
//   E = Region(r)               needs arenas; Level 3.
//   E <= Caller                 needs static-root reachability at return.
//   T = Isolated / Transferred  vacuous -- the language has no tasks.
//   C = Acyclic                 needs a periodic heap walk.
// ============================================================================

#define AIF_VERIFY_BUCKETS 4096
#define AIF_VERIFY_POISON  0xDD

typedef struct AifLive {
    struct AifLive* next;
    void* p;
    size_t size;
    long serial;        // allocation order, so a leak report names something
} AifLive;

static AifLive* aif_live[AIF_VERIFY_BUCKETS];
static long aif_allocs, aif_releases, aif_violations;
static int aif_report_armed;

static unsigned aif_live_hash(const void* p) {
    uintptr_t v = (uintptr_t)p;
    v ^= v >> 33;
    v *= 0xff51afd7ed558ccdull;
    v ^= v >> 29;
    return (unsigned)v & (AIF_VERIFY_BUCKETS - 1);
}

void aif_verify_report(void) {
    long leaked = 0;
    for (int i = 0; i < AIF_VERIFY_BUCKETS; i++) {
        for (AifLive* n = aif_live[i]; n; n = n->next) {
            // The serial is the allocation's order in the run, which is the only
            // handle a leak report can offer without debug info: "the 116th
            // object" is enough to find the site by counting sites.
            if (leaked < 20) {
                fprintf(stderr, "aif-verify: leaked #%ld (%lu bytes)\n",
                        n->serial, (unsigned long)n->size);
            }
            leaked++;
        }
    }
    fprintf(stderr, "aif-verify: %ld allocated, %ld released, %ld leaked, %ld violation(s)\n",
            aif_allocs, aif_releases, leaked, aif_violations);
    if (leaked || aif_violations) {
        fprintf(stderr, "aif-verify: FAILED -- an inferred fact did not hold at run time\n");
    }
}

// Armed by the first allocation *or* the first region entry. Once LAYOUT 7.1
// places arenas automatically, a program can run to completion without a single
// call through the seam -- every allocation served from a bump block -- and
// arming only there would print no report at all, which reads as "the seam was
// not redirected" rather than as "nothing needed accounting".
void aif_verify_arm(void) {
    if (!aif_report_armed) {
        aif_report_armed = 1;
        atexit(aif_verify_report);
    }
}

void* aif_verify_alloc(size_t size) {
    aif_verify_arm();
    void* p = malloc(size);
    if (!p) return NULL;

    aif_allocs++;
    AifLive* n = (AifLive*)malloc(sizeof(AifLive));
    if (n) {
        n->p = p;
        n->size = size;
        n->serial = aif_allocs;
        unsigned b = aif_live_hash(p);
        n->next = aif_live[b];
        aif_live[b] = n;
    }
    return p;
}

void aif_verify_release(void* p) {
    if (!p) return;

    unsigned b = aif_live_hash(p);
    AifLive** link = &aif_live[b];
    while (*link && (*link)->p != p) link = &(*link)->next;

    if (!*link) {
        // Either released twice, or never came from here. Both mean a fact was
        // wrong: the value was freed on a path the analysis did not account for.
        fprintf(stderr, "aif-verify: release of a pointer that is not live (%p)\n", p);
        aif_violations++;
        return;
    }

    AifLive* n = *link;
    *link = n->next;
    memset(p, AIF_VERIFY_POISON, n->size);
    free(n);
    free(p);
    aif_releases++;
}

#endif

// ============================================
// Growable list (List<T> for reference elements) — backs Prismio's List<T>.
// Stores pointer-sized elements; works on native and wasm32.
// ============================================
// ============================================
// AIF Level 5 -- T3, non-atomic reference counting (SPEC 3, T3).
//
// The count lives in a **prefix header**: rc_alloc returns base + RC_HDR, and the
// count is the word immediately in front of the pointer the program holds. That
// choice is what keeps the seam a fourth allocator name and nothing else.
// COMPILER-AUDIT 3's table says T3 is only "partly" expressible because "the
// header word changes struct layout, which named_struct and every
// ir_struct_field_ptr index would have to account for" -- true of a header word
// inside the object, and avoided entirely by putting it in front. The struct type
// LLVM sees is unchanged and every field index still means what it meant.
//
// **The count starts at zero, not one**, and that is the whole design rather than
// an off-by-one. What is counted here is *container edges*, because they are the
// only holder class this compiler both tracks and releases: a T3 value's escape is
// Caller or Global by definition of the tier, so aif_frees_at_scope_node can never
// admit its binding, and a struct field has no teardown yet. A value in no
// container is therefore held by nothing that will ever release, and counting the
// creating expression would put every such value permanently at one. At zero it
// simply leaks, which is exactly what it did before this existed.
//
// So: one container is one count, the teardown decrements, and the value dies with
// the last container that held it. A release without a matching retain cannot
// happen -- only a container retains, and only the same container releases.
//
// **An OPAQUE site is never refcounted.** The pointer came back from a function
// this compilation cannot see, so there is no header in front of it and reading
// one is reading whatever the allocator put there. That excludes all 37 of the
// compiler's own T3 sites, which is why the self-host exercises none of this.
// ============================================

#define RC_HDR 16       // >= sizeof(size_t), and keeps the payload 16-byte aligned

static size_t* rc_slot(void* p) {
    return &((size_t*)p)[-1];
}

void* rc_alloc(size_t size) {
    unsigned char* base = (unsigned char*)rt_base_alloc(size + RC_HDR);
    if (!base) return 0;
    void* payload = base + RC_HDR;
    *rc_slot(payload) = 0;
    return payload;
}

void rc_retain(void* p) {
    if (p) (*rc_slot(p))++;
}

void rc_release(void* p) {
    if (!p) return;
    size_t* c = rc_slot(p);
    if (*c == 0) return;            // never retained: nothing holds it, nothing frees it
    if (--(*c) == 0) {
        rt_free((unsigned char*)p - RC_HDR);
    }
}

// ============================================
// AIF T4b -- the cycle collector (CYCLES 3)
//
// Trial deletion (Bacon-Rajan), scoped to the T4b residue, traversing **only
// cyclic edges** (CYCLES 4). That restriction is the design's own contribution
// and it is available because the compiler owns the type graph: every edge of a
// value-level cycle connects two types in one SCC, so traversing only fields
// whose type is in the owner's SCC finds every cycle and never leaves the
// skeleton. A Node with two child pointers and six fields of strings and spans
// is walked through two edges, not eight, and the collector never descends into
// the string graph at all.
//
// **A T4b object is told what its cyclic children are.** `cyc_set_type` stamps a
// per-type function generated by codegen, for the same reason `list_set_elem_owner`
// exists: reading a header in front of a pointer to find out would be reading
// memory this compilation did not allocate.
//
// The count is container edges, exactly as at Level 5 -- a T4b value's escape is
// Caller or Global by the tier's definition, so no binding ever releases it.
// What T4b adds over T3 is the case Level 5 cannot handle: a decrement that does
// *not* reach zero is the only way a cycle can become garbage, so that is when a
// candidate root is buffered.
// ============================================

#define CYC_BLACK  0
#define CYC_GREY   1
#define CYC_WHITE  2
#define CYC_PURPLE 3

typedef void (*CycVisitor)(void*);

typedef struct {
    size_t rc;
    unsigned char colour;
    unsigned char buffered;
    void (*children)(void*, CycVisitor);
    void (*release)(void*);
} CycHeader;

// Rounded so the payload stays 16-byte aligned, like RC_HDR above.
#define CYC_HDR ((sizeof(CycHeader) + 15u) & ~(size_t)15u)

static CycHeader* cyc_hdr(void* p) {
    return (CycHeader*)((unsigned char*)p - CYC_HDR);
}

// CYCLES 6.1: collection is triggered by candidate-buffer occupancy, never by a
// timer -- a timer would make a program's pause profile a function of how fast
// the machine is, which is exactly the unpredictability SPEC's latency claim
// rejects. CYCLES 10 lists both of these as tuning constants needing
// measurement; they are the document's defaults and are not measured here.
#define CYC_THETA_BUFFER 4096
#define CYC_K_ROOTS      256

static void** cyc_candidates;
static int cyc_cand_count, cyc_cand_cap;

// The traversal's child window. Recursion uses a slice of this rather than a
// local array, so a wide object does not put its whole fan-out on the C stack.
static void** cyc_walk;
static int cyc_walk_len, cyc_walk_cap;

static long long cyc_allocated, cyc_collected, cyc_collections;

static void cyc_walk_push(void* p) {
    if (cyc_walk_len == cyc_walk_cap) {
        int grow = cyc_walk_cap ? cyc_walk_cap * 2 : 64;
        cyc_walk = (void**)realloc(cyc_walk, (size_t)grow * sizeof(void*));
        cyc_walk_cap = grow;
    }
    cyc_walk[cyc_walk_len++] = p;
}

static void cyc_buffer(void* p) {
    if (cyc_cand_count == cyc_cand_cap) {
        int grow = cyc_cand_cap ? cyc_cand_cap * 2 : 256;
        cyc_candidates = (void**)realloc(cyc_candidates, (size_t)grow * sizeof(void*));
        cyc_cand_cap = grow;
    }
    cyc_candidates[cyc_cand_count++] = p;
}

static void cyc_free_object(void* p) {
    CycHeader* h = cyc_hdr(p);
    cyc_collected++;
    // The generated release reclaims the object's *non*-cyclic owned fields and
    // the storage. Struct-field ownership declines a cyclic field precisely so
    // that it is the collector, not a recursive release, that follows it.
    if (h->release) {
        h->release(p);
    } else {
        rt_free((unsigned char*)p - CYC_HDR);
    }
}

static void cyc_mark_grey(void* x) {
    CycHeader* h = cyc_hdr(x);
    if (h->colour == CYC_GREY) return;
    h->colour = CYC_GREY;
    if (!h->children) return;

    int base = cyc_walk_len;
    h->children(x, cyc_walk_push);
    int end = cyc_walk_len;
    for (int i = base; i < end; i++) {
        void* y = cyc_walk[i];
        if (!y) continue;
        // Trial deletion of an internal reference. What survives with a non-zero
        // count is what something outside the candidate subgraph still holds.
        CycHeader* yh = cyc_hdr(y);
        if (yh->rc > 0) yh->rc--;
        cyc_mark_grey(y);
    }
    cyc_walk_len = base;
}

static void cyc_scan_black(void* x) {
    CycHeader* h = cyc_hdr(x);
    h->colour = CYC_BLACK;
    if (!h->children) return;

    int base = cyc_walk_len;
    h->children(x, cyc_walk_push);
    int end = cyc_walk_len;
    for (int i = base; i < end; i++) {
        void* y = cyc_walk[i];
        if (!y) continue;
        cyc_hdr(y)->rc++;
        if (cyc_hdr(y)->colour != CYC_BLACK) cyc_scan_black(y);
    }
    cyc_walk_len = base;
}

static void cyc_scan(void* x) {
    CycHeader* h = cyc_hdr(x);
    if (h->colour != CYC_GREY) return;
    if (h->rc > 0) {
        cyc_scan_black(x);         // reachable from outside; the cycle is live
        return;
    }
    h->colour = CYC_WHITE;
    if (!h->children) return;

    int base = cyc_walk_len;
    h->children(x, cyc_walk_push);
    int end = cyc_walk_len;
    for (int i = base; i < end; i++) {
        if (cyc_walk[i]) cyc_scan(cyc_walk[i]);
    }
    cyc_walk_len = base;
}

static void cyc_collect_white(void* x) {
    CycHeader* h = cyc_hdr(x);
    if (h->colour != CYC_WHITE || h->buffered) return;
    h->colour = CYC_BLACK;

    // Children are gathered *before* the object is freed: cyc_free_object hands
    // the storage back, and reading the field afterwards is a use-after-free.
    int base = cyc_walk_len;
    if (h->children) h->children(x, cyc_walk_push);
    int end = cyc_walk_len;

    int n = end - base;
    void** kids = NULL;
    if (n > 0) {
        kids = (void**)malloc((size_t)n * sizeof(void*));
        for (int i = 0; i < n; i++) kids[i] = cyc_walk[base + i];
    }
    cyc_walk_len = base;

    cyc_free_object(x);

    for (int i = 0; i < n; i++) {
        if (kids[i]) cyc_collect_white(kids[i]);
    }
    free(kids);
}

// CYCLES 6.2: at most K roots per collection, and the rest stay buffered.
// Bounding by roots rather than by traversal steps is what removes the need for
// an abort path in the common case -- the walk from K roots through cyclic edges
// only is bounded by the cyclic skeleton reachable from them.
static void cyc_collect(int all) {
    int take = all ? cyc_cand_count : (cyc_cand_count < CYC_K_ROOTS ? cyc_cand_count : CYC_K_ROOTS);
    if (take <= 0) return;
    cyc_collections++;

    void** roots = (void**)malloc((size_t)take * sizeof(void*));
    for (int i = 0; i < take; i++) roots[i] = cyc_candidates[i];
    for (int i = take; i < cyc_cand_count; i++) cyc_candidates[i - take] = cyc_candidates[i];
    cyc_cand_count -= take;

    // Unbuffered before the walk, so CollectWhite is allowed to reclaim a root:
    // its own `buffered` flag is what would otherwise stop it.
    for (int i = 0; i < take; i++) cyc_hdr(roots[i])->buffered = 0;

    for (int i = 0; i < take; i++) cyc_mark_grey(roots[i]);
    for (int i = 0; i < take; i++) cyc_scan(roots[i]);
    for (int i = 0; i < take; i++) cyc_collect_white(roots[i]);

    free(roots);
}

// A final pass at exit, which is CYCLES 6.1's "explicit request". Without it a
// short program never reaches Theta_buffer and the collector never runs, so a
// fixture could not tell an implemented collector from an absent one.
static int cyc_exit_registered;

static void cyc_final(void) {
    while (cyc_cand_count > 0) cyc_collect(1);
}

void* cyc_alloc(size_t size) {
    if (!cyc_exit_registered) {
        cyc_exit_registered = 1;
        atexit(cyc_final);
    }
    unsigned char* base = (unsigned char*)rt_base_alloc(size + CYC_HDR);
    if (!base) return 0;
    void* payload = base + CYC_HDR;
    CycHeader* h = cyc_hdr(payload);
    h->rc = 0;
    h->colour = CYC_BLACK;
    h->buffered = 0;
    h->children = 0;
    h->release = 0;
    cyc_allocated++;
    return payload;
}

void cyc_set_type(void* p, void (*children)(void*, CycVisitor), void (*release)(void*)) {
    if (!p) return;
    CycHeader* h = cyc_hdr(p);
    h->children = children;
    h->release = release;
}

void cyc_retain(void* p) {
    if (p) cyc_hdr(p)->rc++;
}

void cyc_release(void* p) {
    if (!p) return;
    CycHeader* h = cyc_hdr(p);
    if (h->rc == 0) return;         // never retained: nothing holds it, nothing frees it
    if (--h->rc == 0) {
        cyc_free_object(p);
        return;
    }
    // CYCLES 3.2. A count that dropped without reaching zero is the only way a
    // cycle can become garbage, so this is the one place a candidate is born.
    if (!h->buffered) {
        h->colour = CYC_PURPLE;
        h->buffered = 1;
        cyc_buffer(p);
        if (cyc_cand_count >= CYC_THETA_BUFFER) cyc_collect(0);
    }
}

// CYCLES 6.1's third trigger, "or on explicit request". Exposed because the
// other two -- buffer occupancy and allocation failure -- are both unreachable
// in a fixture small enough to reason about, and a collector that only ever runs
// at exit cannot be shown to restore counts on a *live* cycle.
void cyc_collect_now(void) { cyc_collect(1); }

long long cyc_objects(void)     { return cyc_allocated; }
long long cyc_reclaimed(void)   { return cyc_collected; }
long long cyc_collections_run(void) { return cyc_collections; }

// AIF item 3. `elem_own` is what the container was told about its elements at
// construction, and being told is the only way it can know: the elements are
// plain pointers, and reading a header in front of one to find out would be
// reading memory this program may not have allocated.
//
// Set once, by codegen, from aif_elem_owner_at_node -- which answers NONE unless
// every element site agrees, so a list that reaches here with a mode is a list
// whose elements are uniformly reclaimable.
#define XEFY_ELEM_NONE   0
#define XEFY_ELEM_OBJECT 1
#define XEFY_ELEM_LIST   2
#define XEFY_ELEM_RC     3   // Level 5: a decrement, and the last holder frees
#define XEFY_ELEM_TYPED  4   // struct-field ownership: the element type's own release
#define XEFY_ELEM_CYCLE  5   // T4b: a decrement, and a non-zero result is a candidate root

typedef struct {
    void** data;
    int len;
    int cap;
    int elem_own;
    // Struct-field ownership. Under XEFY_ELEM_TYPED the release differs per
    // element *type*, and an int cannot name a type -- so the container is told
    // the function. Same rule as elem_own, one step less abstract: the container
    // is told what to do because it has no way to ask.
    void (*elem_release)(void*);
} XefyList;

void* list_new(void) {
    XefyList* l = (XefyList*)rt_alloc(sizeof(XefyList));
    l->len = 0;
    l->cap = 4;
    l->elem_own = XEFY_ELEM_NONE;
    l->elem_release = 0;
    l->data = (void**)rt_alloc(sizeof(void*) * 4);
    return l;
}

void list_set_elem_owner(void* lp, int mode) {
    if (lp) ((XefyList*)lp)->elem_own = mode;
}

void list_set_elem_releaser(void* lp, void (*fn)(void*)) {
    if (lp) ((XefyList*)lp)->elem_release = fn;
}

// REQUIREMENTS 4. The checked unwrap behind `expect(x)`.
//
// A function rather than a branch in codegen, and returning its argument rather
// than being void, so the whole thing is one ordinary call expression -- no new
// blocks, no new backend surface, and the failure is loud instead of a null
// dereference somewhere downstream.
void* prismio_expect(void* p) {
    if (!p) {
        fprintf(stderr, "runtime error: expect() called on a `none` value\n");
        exit(1);
    }
    return p;
}

void list_push(void* lp, void* value) {
    XefyList* l = (XefyList*)lp;
    // AIF Level 5. The retain and the release are the same container's, driven by
    // the same stamped mode, so they cannot disagree about whether an element is
    // counted -- which is the failure a per-element answer would invite.
    if (l->elem_own == XEFY_ELEM_RC) rc_retain(value);
    if (l->elem_own == XEFY_ELEM_CYCLE) cyc_retain(value);
    if (l->len >= l->cap) {
        int nc = l->cap * 2;
        void** nd = (void**)rt_alloc(sizeof(void*) * nc);
        for (int i = 0; i < l->len; i++) nd[i] = l->data[i];
        rt_free(l->data);
        l->data = nd;
        l->cap = nc;
    }
    l->data[l->len] = value;
    l->len = l->len + 1;
}

// AIF Level 4. A list is two allocations -- the handle and the element block --
// so the deallocator seam, which takes one pointer and frees it, cannot reclaim
// it: `free(list)` leaks the block. Codegen calls this instead for a droppable
// List binding, which is why the drop list carries a kind and not just a slot.
//
// AIF item 3: the elements go too, when the container was told it owns them.
// That reverses Level 4's rule, and the reason the old one was right then is the
// reason it is wrong now. It read `list_push` as `retain_in(0)` -- the element's
// escape becomes the list's -- and concluded that whoever owns the element owns
// it at its own binding. Nobody does: an element's escape is the container's, so
// aif_frees_at_scope_node declines the binding, and until something released
// here every element of every list leaked. One owner, and it is this one.
//
// Reverse order, as everywhere else a scope unwinds: an element may hold a
// reference to one pushed before it, never after.
void list_release(void* lp) {
    if (!lp) return;
    XefyList* l = (XefyList*)lp;
    if (l->elem_own != XEFY_ELEM_NONE) {
        for (int i = l->len - 1; i >= 0; i--) {
            void* e = l->data[i];
            if (!e) continue;
            if (l->elem_own == XEFY_ELEM_LIST)    list_release(e);
            else if (l->elem_own == XEFY_ELEM_RC) rc_release(e);
            else if (l->elem_own == XEFY_ELEM_CYCLE) cyc_release(e);
            else if (l->elem_own == XEFY_ELEM_TYPED) {
                // Struct-field ownership. The element owns fields of its own, so
                // rt_free(e) here would reclaim the object and leak everything
                // hanging off it -- which is exactly what g3_scene_graph did with
                // 1365 Nodes and three owned fields each.
                if (l->elem_release) l->elem_release(e);
            }
            else                                  rt_free(e);
        }
    }
    rt_free(l->data);
    rt_free(l);
}

void* list_get(void* lp, int index) {
    XefyList* l = (XefyList*)lp;
    if (index < 0 || index >= l->len) return 0;
    return l->data[index];
}

// The overwritten element is released only under RC, where the container's own
// count says whether anything else still holds it. Under OBJECT it leaks: the
// container owns it, but so might the binding the value came from, and a free
// here would be the double free the whole ownership rule exists to prevent.
void list_set(void* lp, int index, void* value) {
    XefyList* l = (XefyList*)lp;
    if (index < 0 || index >= l->len) return;
    if (l->elem_own == XEFY_ELEM_RC) {
        rc_retain(value);
        rc_release(l->data[index]);
    }
    l->data[index] = value;
}

int list_len(void* lp) {
    XefyList* l = (XefyList*)lp;
    return l->len;
}
