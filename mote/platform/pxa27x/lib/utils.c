#include "utils.h"
#include "inttypes.h"
#include "criticalSection.h"
#include <stdlib.h>


extern _PTR memalign(size_t, size_t);
/*
 * These functions are equivalent to the standard lib functions, except that
 * they disable all interrupts before executing the function.
 */

void *safe_malloc(size_t size) {
  DECLARE_CRITICAL_SECTION();
  void *retVal;

  CRITICAL_SECTION_BEGIN();
  retVal = malloc(size);
  CRITICAL_SECTION_END();
  return retVal;
}

void *safe_calloc(size_t nelem, size_t elsize) {
  DECLARE_CRITICAL_SECTION();
  void *retVal;

  CRITICAL_SECTION_BEGIN();
  retVal = calloc(nelem, elsize);
  CRITICAL_SECTION_END();
  return retVal;
}

void *safe_memalign(size_t alignment, size_t length){
  
  DECLARE_CRITICAL_SECTION();
  void *retVal;
  
  CRITICAL_SECTION_BEGIN();
  retVal = memalign(alignment, length);
  CRITICAL_SECTION_END();
  return retVal;
}


void *safe_realloc(void *ptr, size_t size) {
  DECLARE_CRITICAL_SECTION();
  void *retVal;

  CRITICAL_SECTION_BEGIN();
  retVal = realloc(ptr, size);
  CRITICAL_SECTION_END();
  return retVal;
}

void safe_free(void *ptr) {
  DECLARE_CRITICAL_SECTION();
  
  CRITICAL_SECTION_BEGIN();
  free(ptr);
  CRITICAL_SECTION_END();
  return;
}
