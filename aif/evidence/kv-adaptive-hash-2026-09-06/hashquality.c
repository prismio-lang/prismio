// What the hash costs and what it buys: three mixes against four key patterns,
// on the same index-table design std/map.psm uses.
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <time.h>
#define N 80000
#define ROUNDS 20
static long long now_ns(void){struct timespec t;clock_gettime(CLOCK_MONOTONIC_RAW,&t);
    return (long long)t.tv_sec*1000000000LL+t.tv_nsec;}

static int H;   // 0 murmur, 1 xorshift16, 2 identity
static inline int mix(int v){
    uint32_t h=(uint32_t)v;
    if(H==0){h^=h>>16;h*=2246822507u;h^=h>>13;h*=3266489909u;h^=h>>16;}
    else if(H==1){h^=h>>16;}
    return (int)(h&2147483647u);
}
typedef struct{int*slots,*keys,*values;int mask,len,cap;}M;
static void mi(M*m){m->mask=7;m->len=0;m->cap=8;m->slots=malloc(8*4);
    for(int i=0;i<8;i++)m->slots[i]=-1;m->keys=malloc(8*4);m->values=malloc(8*4);}
static long long probes;
static int mp(M*m,int key,int fs){int at=mix(key)&m->mask,step=1;
    for(;;){probes++;int e=m->slots[at];if(e<0)return fs?-at-2:-1;
        if(m->keys[e]==key)return e;at=(at+step)&m->mask;step++;}}
static void mr(M*m){int old=m->mask+1,cap=old*2;m->slots=realloc(m->slots,(size_t)cap*4);
    for(int i=0;i<cap;i++)m->slots[i]=-1;m->mask=cap-1;
    for(int e=0;e<m->len;e++){int at=mix(m->keys[e])&m->mask,step=1;
        while(m->slots[at]>=0){at=(at+step)&m->mask;step++;}m->slots[at]=e;}}
static int ms(M*m,int key,int value){int f=mp(m,key,1);
    if(f>=0){m->values[f]=value;return 1;}int at=-f-2;
    if(m->len==m->cap){m->cap*=2;m->keys=realloc(m->keys,(size_t)m->cap*4);
        m->values=realloc(m->values,(size_t)m->cap*4);}
    int i=m->len++;m->keys[i]=key;m->values[i]=value;m->slots[at]=i;
    if(m->len>(m->mask+1)/2)mr(m);return 0;}
static int mg(M*m,int key,int fb){int at=mp(m,key,0);return at<0?fb:m->values[at];}

static int key_of(int pattern, int i) {
    if (pattern == 0) return i;              // dense: 0,1,2,...
    if (pattern == 1) return i * 64;         // stride 64: aligned records
    if (pattern == 2) return i * 65536;      // stride 2^16: differs only high
    if (pattern == 3) return (int)((unsigned)i * 2654435761u); // already-scrambled ids
    if (pattern == 4) return i * 65537;      // adversarial for h ^ (h>>16): folds to 0
    return i * 131072;                        // adversarial-ish: k >> 16 == i << 1
}
int main(int argc,char**argv){
    const char *hn[]={"murmur3","xorshift16","identity"};
    const char *pn[]={"dense i","stride 64","stride 2^16","pre-scrambled","i*65537","i*2^17"};
    int pattern = argc>1?atoi(argv[1]):0;
    for(H=0;H<3;H++){ if (pattern>=4 && H==2) continue;
        M*m=malloc(sizeof(M));mi(m);probes=0;
        for(int i=0;i<N;i++)ms(m,key_of(pattern,i),i%101);
        long long ins_probes=probes; probes=0;
        long long t0=now_ns();
        for(int r=0;r<ROUNDS;r++)for(int i=0;i<N;i++){int k=key_of(pattern,i);ms(m,k,mg(m,k,0)+1);}
        long long t1=now_ns();
        printf("%-14s %-14s update %8.3f ms   probes/lookup %5.2f   (insert %5.2f)\n",
               pn[pattern], hn[H], (t1-t0)/1e6, (double)probes/(2.0*ROUNDS*N),
               (double)ins_probes/N);
        free(m->slots);free(m->keys);free(m->values);free(m);
    }
    return 0;
}
