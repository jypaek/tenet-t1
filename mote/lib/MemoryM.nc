/**
 *
 * Dynamic Memory Management * 
 *
 * 
 * If malloc and free calls are supported by the compiler (avr-gcc)
 * and is known to work reliably, just wraps those calls, otherwise
 * (msp430-gcc) implement our own malloc and free. If
 * INSTRUMENTED_MEMORY is defined, also provides statistics on dynamic
 * memory usage.
 *
 * @author Ben Greenstein
 **/

#if defined(PLATFORM_TELOSB) && defined(INSTRUMENTED_MEMORY)
extern size_t __bss_end;
#endif

module MemoryM {
  provides interface Memory;
}
implementation {

#if defined(PLATFORM_TELOSB) && defined(INSTRUMENTED_MEMORY)

#include <stdlib.h>

  /* norace is not safe but these are just statistics
   * not worth slowing down the whole system */
  norace uint16_t bytesAllocated = 0;
  norace uint16_t ptrsAllocated = 0;
  norace uint16_t maxBytesAllocated = 0;
  norace uint16_t maxPtrsAllocated = 0;
  

#define XSIZE(x) ((*x)>>1)
#define FREE_P(x) (!((*x)&1))
#define MARK_BUSY(x) ((*x)|=1)
#define MARK_FREE(x) ((*x)&=0xfffe)

#define GET_HEAP_BOTTOM(__x)  __asm__ __volatile__("mov	r1, %0": "=r" ((uint16_t)__x) :)

 void *imalloc (size_t size)
   {
     static char once = 0;
     size_t * heap_bottom;
     size_t kk = (size_t) (&__bss_end);		/* this will possibly introduce */
     size_t * heap_top = (size_t *)((kk+1)&~1);	/* 1 byte hole between .bss and heap */
     char f = 0;
     
     if (!once)
       {
         once = 1;
         *heap_top = 0xFFFE;
       }
     GET_HEAP_BOTTOM (heap_bottom);
     heap_bottom -= 20;
     size = (size+1) >> 1;	/* round to 2 */
     do
       {
         size_t xsize = XSIZE (heap_top);
         size_t * heap_next = &heap_top[xsize + 1];
         if ((xsize<<1)+2 == 0)
           {
             f = 1;
           }
         if (FREE_P (heap_top))
           {
             if (f)
               {
                 xsize = heap_bottom - heap_top - 1;
               }
             else if (FREE_P(heap_next))
               {
                 *heap_top = ( (XSIZE(heap_next)<<1) + 2 == 0
                               ? 0xfffe
                               : (xsize + XSIZE(heap_next) + 1)<<1);
                 continue;
               }
             if (xsize >= size)
               {
                 if (f)
                   heap_top[size + 1] = 0xfffe;
                 else if (xsize != size)
                   heap_top[size + 1] = (xsize - size - 1) << 1;
                 *heap_top = size << 1;
                 MARK_BUSY (heap_top);
                 return heap_top+1;
               }
           }
         heap_top += xsize + 1;
       }
     while (!f);
     return NULL;
   }
 
 void ifree (void *p)
   {
     size_t *t = (size_t*)p - 1;
     MARK_FREE (t);
   }
 
 size_t alloc_size(void *p){
   if (p)
     return (*((size_t*)p - 1)) - 1;
   else
     return 0;
 }


 void stats_malloc(size_t size){
   size++; size>>=1; size<<=1; // round up to nearest word
   bytesAllocated += size;
   ptrsAllocated++;
   if (bytesAllocated > maxBytesAllocated) maxBytesAllocated = bytesAllocated;
   if (ptrsAllocated > maxPtrsAllocated) maxPtrsAllocated = ptrsAllocated; 
 }
 void stats_free(size_t size){
   if (bytesAllocated > size) bytesAllocated -= size;
   else bytesAllocated = 0;
   if (ptrsAllocated > 0) ptrsAllocated--;
 }

  async command void *Memory.malloc(size_t size){
    void *ptr;
    atomic ptr = imalloc(size);
    if (ptr != NULL) stats_malloc(size);
    return ptr;
  }
  async command void Memory.free(void *ptr){
    if (ptr) {
      stats_free(alloc_size(ptr));
      atomic ifree(ptr);
    }
  }

  command uint16_t Memory.bytesAllocated(){ return bytesAllocated;}
  command uint16_t Memory.ptrsAllocated(){ return ptrsAllocated;}
  command uint16_t Memory.maxBytesAllocated(){ return maxBytesAllocated;}
  command uint16_t Memory.maxPtrsAllocated(){ return maxPtrsAllocated;}
  
#else 

  async command void *Memory.malloc(size_t size){
    void *ptr;
    atomic ptr = malloc(size);
    return ptr;
  }
  async command void Memory.free(void *ptr){
    if (ptr) atomic free(ptr);
  }

  command uint16_t Memory.bytesAllocated(){ return 0;}
  command uint16_t Memory.maxBytesAllocated(){ return 0;}
  command uint16_t Memory.ptrsAllocated(){ return 0;}
  command uint16_t Memory.maxPtrsAllocated(){ return 0;}
#endif
}



