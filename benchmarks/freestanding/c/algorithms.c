// Algorithms over fixed arrays in the frame: no allocation, no library.
#include "common.h"

static u32 fib(u32 n) {
    if (n < 2) return n;
    return fib(n - 1) + fib(n - 2);
}

u32 bench_fibonacci(u32 scale) {
    u32 total = 0;
    for (u32 r = 0; r < scale; r++) total += fib(27);
    return total;
}

#define SIEVE 200000

u32 bench_prime_sieve(u32 scale) {
    u32 total = 0;
    for (u32 r = 0; r < scale; r++) {
        u8 flags[SIEVE] = {0};
        u32 count = 0;
        for (u32 i = 2; i < SIEVE; i++) {
            if (flags[i] == 0) {
                count += 1;
                for (u32 j = i + i; j < SIEVE; j += i) flags[j] = 1;
            }
        }
        total += count;
    }
    return total;
}

static u32 gcd(u32 a, u32 b) {
    while (b != 0) {
        u32 t = a % b;
        a = b;
        b = t;
    }
    return a;
}

u32 bench_gcd_lcm(u32 scale) {
    u32 total = 0;
    for (u32 r = 0; r < scale; r++) {
        for (u32 a = 1; a <= 400; a++) {
            for (u32 b = 1; b <= 400; b++) total += gcd(a, b);
        }
    }
    return total;
}

#define SEARCH 4096

u32 bench_binary_search(u32 scale) {
    u32 table[SEARCH];
    for (u32 i = 0; i < SEARCH; i++) table[i] = i * 7 + 3;
    u32 s = 12345, found = 0, acc = 0;
    for (u32 q = 0; q < 100000 * scale; q++) {
        LCG(s);
        u32 key = s % 30000;
        u32 lo = 0, hi = SEARCH;
        while (lo < hi) {
            u32 mid = (lo + hi) >> 1;
            if (table[mid] < key) lo = mid + 1;
            else hi = mid;
        }
        if (lo < SEARCH && table[lo] == key) {
            found += 1;
            acc += lo;
        }
    }
    return found + acc * 3;
}

#define SORT 2048

static void quick(u32* a, i32 lo, i32 hi) {
    if (lo >= hi) return;
    u32 p = a[(lo + hi) >> 1];
    i32 i = lo, j = hi;
    while (i <= j) {
        while (a[i] < p) i++;
        while (a[j] > p) j--;
        if (i <= j) {
            u32 t = a[i];
            a[i] = a[j];
            a[j] = t;
            i++;
            j--;
        }
    }
    quick(a, lo, j);
    quick(a, i, hi);
}

u32 bench_quicksort(u32 scale) {
    u32 data[SORT];
    u32 s = 777, sum = 0;
    for (u32 r = 0; r < 40 * scale; r++) {
        for (u32 i = 0; i < SORT; i++) { LCG(s); data[i] = s >> 4; }
        quick(data, 0, SORT - 1);
        for (u32 i = 0; i < SORT; i++) sum += data[i] * (i + 1);
    }
    return sum;
}

static void sift(u32* a, i32 start, i32 end) {
    i32 root = start;
    while (root * 2 + 1 <= end) {
        i32 child = root * 2 + 1;
        i32 pick = root;
        if (a[pick] < a[child]) pick = child;
        if (child + 1 <= end && a[pick] < a[child + 1]) pick = child + 1;
        if (pick == root) return;
        u32 t = a[root];
        a[root] = a[pick];
        a[pick] = t;
        root = pick;
    }
}

u32 bench_heapsort(u32 scale) {
    u32 data[SORT];
    u32 s = 4242, sum = 0;
    for (u32 r = 0; r < 24 * scale; r++) {
        for (u32 i = 0; i < SORT; i++) { LCG(s); data[i] = s >> 4; }
        for (i32 start = (SORT - 2) / 2; start >= 0; start--) sift(data, start, SORT - 1);
        for (i32 end = SORT - 1; end > 0; end--) {
            u32 t = data[0];
            data[0] = data[end];
            data[end] = t;
            sift(data, 0, end - 1);
        }
        for (u32 i = 0; i < SORT; i++) sum += data[i] * (i + 1);
    }
    return sum;
}

#define ITEMS 64
#define CAPACITY 1500

static i32 imax(i32 a, i32 b) { return a > b ? a : b; }
static i32 imin(i32 a, i32 b) { return a < b ? a : b; }

u32 bench_knapsack(u32 scale) {
    i32 weight[ITEMS], value[ITEMS];
    u32 s = 99;
    for (u32 i = 0; i < ITEMS; i++) {
        LCG(s); weight[i] = (i32)((s >> 8) % 37) + 3;
        LCG(s); value[i] = (i32)((s >> 8) % 97) + 1;
    }
    u32 total = 0;
    for (u32 r = 0; r < 6 * scale; r++) {
        i32 best[CAPACITY + 1] = {0};
        for (u32 i = 0; i < ITEMS; i++) {
            i32 w = weight[i], v = value[i];
            for (i32 c = CAPACITY; c >= w; c--) best[c] = imax(best[c], best[c - w] + v);
        }
        total += (u32)best[CAPACITY];
    }
    return total;
}

#define STRING 600

u32 bench_edit_distance(u32 scale) {
    u8 a[STRING], b[STRING];
    u32 s = 31337;
    for (u32 i = 0; i < STRING; i++) { LCG(s); a[i] = (u8)((s >> 12) & 3); }
    for (u32 i = 0; i < STRING; i++) { LCG(s); b[i] = (u8)((s >> 12) & 3); }
    u32 total = 0;
    for (u32 r = 0; r < scale; r++) {
        i32 prev[STRING + 1], cur[STRING + 1];
        for (i32 j = 0; j <= STRING; j++) prev[j] = j;
        for (i32 i = 1; i <= STRING; i++) {
            cur[0] = i;
            for (i32 j = 1; j <= STRING; j++) {
                i32 cost = a[i - 1] == b[j - 1] ? 0 : 1;
                cur[j] = imin(imin(prev[j] + 1, cur[j - 1] + 1), prev[j - 1] + cost);
            }
            for (i32 j = 0; j <= STRING; j++) prev[j] = cur[j];
        }
        total += (u32)prev[STRING];
    }
    return total;
}

#define MATRIX 64

u32 bench_matrix_multiply(u32 scale) {
    u32 a[MATRIX * MATRIX], b[MATRIX * MATRIX], c[MATRIX * MATRIX];
    for (u32 i = 0; i < MATRIX; i++) {
        for (u32 j = 0; j < MATRIX; j++) {
            a[i * MATRIX + j] = (i * 3 + j * 5) % 17;
            b[i * MATRIX + j] = (i * 7 + j * 2) % 13;
        }
    }
    u32 total = 0;
    for (u32 r = 0; r < 8 * scale; r++) {
        for (u32 i = 0; i < MATRIX; i++) {
            for (u32 j = 0; j < MATRIX; j++) {
                u32 sum = 0;
                for (u32 k = 0; k < MATRIX; k++) sum += a[i * MATRIX + k] * b[k * MATRIX + j];
                c[i * MATRIX + j] = sum;
            }
        }
        for (u32 i = 0; i < MATRIX * MATRIX; i++) total += c[i];
        a[r % 64] += 1;
    }
    return total;
}
