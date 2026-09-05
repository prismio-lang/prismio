// Where vector_growth's time is. Same workload as benchmarks/*/vector_growth:
// n pushes into a container that starts empty, with two modulos per iteration.
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#define N (1000000 * 4)
#define MOD 1000000007
static long long now_ns(void){struct timespec t;clock_gettime(CLOCK_MONOTONIC_RAW,&t);
    return (long long)t.tv_sec*1000000000LL+t.tv_nsec;}

typedef struct { int *data; int len, cap; } Vec;
static void vinit(Vec *v){v->data=NULL;v->len=0;v->cap=0;}
static void vgrow(Vec *v){
    v->cap = v->cap ? v->cap*2 : 8;
    v->data = realloc(v->data, (size_t)v->cap*sizeof(int));
}
// The push Prismio emits: header fields re-read through the handle every time.
static inline void vpush(Vec *v,int x){ if(v->len==v->cap) vgrow(v); v->data[v->len++]=x; }
__attribute__((noinline)) static void vpush_out(Vec *v,int x){ if(v->len==v->cap) vgrow(v); v->data[v->len++]=x; }

int main(int argc,char**argv){
    const char *w = argc>1?argv[1]:"full";
    Vec *v = malloc(sizeof(Vec)); vinit(v);
    int checksum = 0;
    long long t0 = now_ns();
    if (!strcmp(w,"full")) {
        for (int i=0;i<N;i++){ int x=i%997; vpush(v,x); checksum=(checksum+x)%MOD; }
    } else if (!strcmp(w,"outline")) {
        for (int i=0;i<N;i++){ int x=i%997; vpush_out(v,x); checksum=(checksum+x)%MOD; }
    } else if (!strcmp(w,"nosum")) {          // drop the checksum modulo
        for (int i=0;i<N;i++){ int x=i%997; vpush(v,x); checksum+=x; }
    } else if (!strcmp(w,"nomod")) {          // drop both modulos
        for (int i=0;i<N;i++){ int x=i&1023; vpush(v,x); checksum+=x; }
    } else if (!strcmp(w,"pushonly")) {       // no arithmetic at all
        for (int i=0;i<N;i++){ vpush(v,i); }
        checksum = v->len;
    } else if (!strcmp(w,"modonly")) {        // no push at all
        for (int i=0;i<N;i++){ int x=i%997; checksum=(checksum+x)%MOD; }
    } else if (!strcmp(w,"reserve")) {        // no growth: capacity up front
        v->cap=N; v->data=malloc((size_t)N*sizeof(int));
        for (int i=0;i<N;i++){ int x=i%997; vpush(v,x); checksum=(checksum+x)%MOD; }
    } else if (!strcmp(w,"usum")) {           // the same chain, unsigned
        unsigned uc = 0;
        for (int i=0;i<N;i++){ int x=i%997; vpush(v,x); uc=(uc+(unsigned)x)%(unsigned)MOD; }
        checksum = (int)uc;
    } else if (!strcmp(w,"umodonly")) {
        unsigned uc = 0;
        for (int i=0;i<N;i++){ unsigned x=(unsigned)i%997u; uc=(uc+x)%(unsigned)MOD; }
        checksum = (int)uc;
    } else { fprintf(stderr,"?\n"); return 2; }
    long long t1 = now_ns();
    printf("%-9s %8.3f ms   checksum %d len %d\n", w, (t1-t0)/1e6, checksum, v->len);
    return 0;
}
