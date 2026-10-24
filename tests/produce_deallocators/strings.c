// The foreign half of run_produce_deallocator_test: a library that hands out strings
// from its own allocator and counts what comes back to its own deallocator.
#include <stdio.h>
#include <stdlib.h>

static int released;

char* lib_string_make(int n) {
    char* text = malloc(48);
    if (text) snprintf(text, 48, "item-%d from the library's own heap", n);
    return text;
}

void lib_string_free(char* text) {
    released++;
    free(text);
}

int lib_string_released(void) { return released; }
