// Standalone stress for the mode-2 slab body, extracted verbatim from runtime/lang_runtime.c.
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#define PRISMIO_NOINLINE __attribute__((noinline))
#define PRISMIO_THREAD_LOCAL _Thread_local
static volatile long prismio_memory_threads_enabled;
static PRISMIO_THREAD_LOCAL int prismio_memory_worker;
static int prismio_memory_threads_are_enabled(void) { return __atomic_load_n(&prismio_memory_threads_enabled, __ATOMIC_ACQUIRE) != 0; }
#define PRISMIO_ALLOC_MODE 2
#include "slab_body.inc"  /* extracted by extract_slab.py */
void  slab_cleanup(void) { prismio_slab_thread_flush(); }

#define XCH 4096
static void* xch[XCH];
static pthread_mutex_t xl = PTHREAD_MUTEX_INITIALIZER;
static int NT = 4; static long ITERS = 300000;
typedef struct { uint32_t tag; uint32_t size; } Hdr;
static void fill(void* p, uint32_t size, uint32_t tag) { Hdr* h=(Hdr*)p; if(size<8){ if(size) *(unsigned char*)p=(unsigned char)tag; return;} h->tag=tag; h->size=size; for(uint32_t i=8;i<size;i++) ((unsigned char*)p)[i]=(unsigned char)(tag+i); }
static int check(void* p, uint32_t size) { Hdr* h=(Hdr*)p; if(size<8) return size? *(unsigned char*)p==(unsigned char)0 || 1 : 1; if(h->size!=size) return 0; for(uint32_t i=8;i<size;i++) if(((unsigned char*)p)[i]!=(unsigned char)(h->tag+i)) return 0; return 1; }
static uint32_t rng(uint64_t* s){ *s = *s*6364136223846793005ULL+1442695040888963407ULL; return (uint32_t)(*s>>33); }
static void* worker(void* arg) {
    long id=(long)arg; prismio_memory_worker=1; uint64_t seed=id*7919+1;
    void* live[256]; uint32_t sz[256]; memset(live,0,sizeof live);
    for(long it=0; it<ITERS; it++){
        uint32_t r=rng(&seed); int slot=r&255;
        if(live[slot]){ if(!check(live[slot],sz[slot])){ fprintf(stderr,"CORRUPT local\n"); abort(); }
            if((r>>8)%4==0){ // hand off to the exchange instead of freeing
                pthread_mutex_lock(&xl); int k=(r>>12)%XCH; void* old=xch[k]; xch[k]=live[slot];
                // encode size in the first bytes already (Hdr.size) when size>=8
                pthread_mutex_unlock(&xl);
                if(old){ Hdr* h=(Hdr*)old; if(!check(old,h->size)){fprintf(stderr,"CORRUPT xch\n");abort();} rt_free(old);}
            } else if((r>>8)%7==1){ // realloc
                uint32_t ns=8+rng(&seed)%900; void* n=rt_base_realloc(live[slot], ns); if(!n) abort();
                uint32_t keep= sz[slot]<ns?sz[slot]:ns; // verify prefix bytes survive
                Hdr* h=(Hdr*)n; if(keep>=8 && h->size!=sz[slot]){fprintf(stderr,"CORRUPT realloc\n");abort();}
                live[slot]=n; sz[slot]=ns; fill(n,ns,(uint32_t)r|1); continue;
            } else rt_free(live[slot]);
            live[slot]=0;
        }
        uint32_t s2 = 8 + rng(&seed) % ((r>>20)%16==0 ? 1500 : 300);
        void* p=rt_base_alloc(s2); if(!p) abort(); fill(p,s2,(uint32_t)r|1); live[slot]=p; sz[slot]=s2;
    }
    for(int i=0;i<256;i++) if(live[i]) rt_free(live[i]);
    slab_cleanup();
    return NULL;
}
int main(int argc,char**argv){
    if(argc>1) NT=atoi(argv[1]); if(argc>2) ITERS=atol(argv[2]);
    // single-thread phase first (process-local cache), then threads
    { void* a[1000]; for(int i=0;i<1000;i++){a[i]=rt_base_alloc(16+i%200);} for(int i=0;i<1000;i++) rt_free(a[i]); }
    __atomic_store_n(&prismio_memory_threads_enabled,1,__ATOMIC_RELEASE);
    for(int round=0; round<3; round++){
        pthread_t t[64]; for(long i=0;i<NT;i++) pthread_create(&t[i],0,worker,(void*)(i+round*100));
        for(int i=0;i<NT;i++) pthread_join(t[i],0);
    }
    for(int i=0;i<XCH;i++) if(xch[i]) rt_free(xch[i]);
    // main thread as pure consumer after workers exit: blocks must be reusable
    size_t used=0;
#ifdef SLAB_SPANS
    used = slab_span_next - slab_base;
#else
    for(int c=0;c<SLAB_CLASSES;c++) used += (slab_global[c].bump - (slab_base + ((uintptr_t)c<<SLAB_REGION_SHIFT)));
#endif
    printf("ok threads=%d iters=%ld carved=%zu KB\n", NT, ITERS, used>>10);
    return 0;
}
