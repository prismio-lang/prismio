#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

uint64_t clock_gettime_nsec_np(int);

static char *repeat_text(const char *part, int count) {
    size_t part_len = strlen(part);
    size_t len = part_len * (size_t)count;
    char *out = malloc(len + 1);
    if (!out) abort();
    for (int i = 0; i < count; i++) {
        memcpy(out + (size_t)i * part_len, part, part_len);
    }
    out[len] = '\0';
    return out;
}

static void report(long checksum, uint64_t start, uint64_t end) {
    printf("checksum=%ld\nelapsed_ns=%llu\n", checksum,
           (unsigned long long)(end - start));
}

static long search_rare_run(char *hay, char *needle, int n, int reps) {
    long sum = 0;
    for (int k = 0; k < reps; k++) {
        hay[k % n] = (char)('a' + (k % 10));
        needle[0] = (char)('b' + (k % 5));
        char *hit = strstr(hay, needle);
        sum += hit ? (long)(hit - hay) : -1L;
    }
    return sum;
}

static int search_rare(void) {
    char *hay = repeat_text("abcdefghij", 4000);
    char *needle = repeat_text("ajia", 1);
    if (search_rare_run(hay, needle, 40000, 1000) > 0) return 1;
    uint64_t start = clock_gettime_nsec_np(4);
    long sum = search_rare_run(hay, needle, 40000, 200000);
    uint64_t end = clock_gettime_nsec_np(4);
    report(sum, start, end);
    free(needle);
    free(hay);
    return 0;
}

static long search_dense_run(const char *hay, char *needle, int reps) {
    long sum = 0;
    for (int k = 0; k < reps; k++) {
        needle[2] = (char)('c' + (k % 2));
        const char *hit = strstr(hay, needle);
        sum += hit ? (long)(hit - hay) : -1L;
    }
    return sum;
}

static int search_dense(void) {
    char *hay = repeat_text("jzxe", 10000);
    char *needle = repeat_text("jzce", 1);
    if (search_dense_run(hay, needle, 100) != -100) return 1;
    uint64_t start = clock_gettime_nsec_np(4);
    long sum = search_dense_run(hay, needle, 20000);
    uint64_t end = clock_gettime_nsec_np(4);
    report(sum, start, end);
    free(needle);
    free(hay);
    return 0;
}

static long search_long_run(const char *hay, char *needle, int reps) {
    long sum = 0;
    for (int k = 0; k < reps; k++) {
        needle[33] = (char)('x' + (k % 2));
        const char *hit = strstr(hay, needle);
        sum += hit ? (long)(hit - hay) : -1L;
    }
    return sum;
}

static int search_long(void) {
    char *hay = repeat_text("abcdefghij", 4000);
    char *needle = repeat_text("abcdefghij", 4);
    if (search_long_run(hay, needle, 100) != -100) return 1;
    uint64_t start = clock_gettime_nsec_np(4);
    long sum = search_long_run(hay, needle, 100000);
    uint64_t end = clock_gettime_nsec_np(4);
    report(sum, start, end);
    free(needle);
    free(hay);
    return 0;
}

static char *to_upper(const char *text, size_t len) {
    char *out = malloc(len + 1);
    if (!out) abort();
    for (size_t i = 0; i < len; i++) {
        char c = text[i];
        out[i] = c >= 'a' && c <= 'z' ? (char)(c - 32) : c;
    }
    out[len] = '\0';
    return out;
}

static long uppercase_run(char *base, int n, int reps) {
    long sum = 0;
    for (int k = 0; k < reps; k++) {
        base[k % n] = (char)('a' + (k % 26));
        char *upper = to_upper(base, (size_t)n);
        sum += (unsigned char)upper[k % n];
        free(upper);
    }
    return sum;
}

static int uppercase(void) {
    char *base = repeat_text("abcdefghij", 4000);
    if (uppercase_run(base, 40000, 2000) < 0) return 1;
    uint64_t start = clock_gettime_nsec_np(4);
    long sum = uppercase_run(base, 40000, 400000);
    uint64_t end = clock_gettime_nsec_np(4);
    report(sum, start, end);
    free(base);
    return 0;
}

static char *format_int(int value) {
    char reversed[12];
    int digits = 0;
    int negative = value < 0;
    unsigned magnitude = negative ? (unsigned)(-(long)value) : (unsigned)value;
    if (magnitude == 0) reversed[digits++] = '0';
    while (magnitude != 0) {
        reversed[digits++] = (char)('0' + magnitude % 10);
        magnitude /= 10;
    }
    int len = digits + negative;
    char *out = malloc((size_t)len + 1);
    if (!out) abort();
    int at = 0;
    if (negative) out[at++] = '-';
    while (digits != 0) out[at++] = reversed[--digits];
    out[len] = '\0';
    return out;
}

static long format_run(int reps) {
    long sum = 0;
    for (int k = 0; k < reps; k++) {
        char *text = format_int((int)((unsigned)k * 1103515245u));
        sum += (unsigned char)text[0] + (long)strlen(text);
        free(text);
    }
    return sum;
}

static int format(void) {
    if (format_run(2000) < 0) return 1;
    uint64_t start = clock_gettime_nsec_np(4);
    long sum = format_run(2000000);
    uint64_t end = clock_gettime_nsec_np(4);
    report(sum, start, end);
    return 0;
}

static char *concat_text(const char *a, size_t a_len,
                         const char *b, size_t b_len) {
    char *out = malloc(a_len + b_len + 1);
    if (!out) abort();
    memcpy(out, a, a_len);
    memcpy(out + a_len, b, b_len);
    out[a_len + b_len] = '\0';
    return out;
}

static long concat_run(char *a, const char *b, int n, int reps) {
    long sum = 0;
    for (int k = 0; k < reps; k++) {
        int at = k % n;
        a[at] = (char)('a' + (k % 26));
        char *joined = concat_text(a, (size_t)n, b, (size_t)n);
        sum += (unsigned char)joined[at] + (unsigned char)joined[n + at];
        free(joined);
    }
    return sum;
}

static int concat(void) {
    char *a = repeat_text("abcdefghij", 2000);
    char *b = repeat_text("klmnopqrst", 2000);
    if (concat_run(a, b, 20000, 2000) < 0) return 1;
    uint64_t start = clock_gettime_nsec_np(4);
    long sum = concat_run(a, b, 20000, 400000);
    uint64_t end = clock_gettime_nsec_np(4);
    report(sum, start, end);
    free(b);
    free(a);
    return 0;
}

int main(int argc, char **argv) {
    if (argc != 2) return 2;
    if (strcmp(argv[1], "search_rare") == 0) return search_rare();
    if (strcmp(argv[1], "search_dense") == 0) return search_dense();
    if (strcmp(argv[1], "search_long") == 0) return search_long();
    if (strcmp(argv[1], "uppercase") == 0) return uppercase();
    if (strcmp(argv[1], "format") == 0) return format();
    if (strcmp(argv[1], "concat") == 0) return concat();
    return 2;
}
