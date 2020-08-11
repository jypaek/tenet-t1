#ifndef __UTILS_H__
#define __UTILS_H__

#include <stddef.h>

/*
 * These functions are equivalent to the standard lib functions, except that
 * they disable all interrupts before executing the function.
 */

void *safe_malloc(size_t size);
void *safe_calloc(size_t nelem, size_t elsize);
void *safe_realloc(void *ptr, size_t size);
void *safe_memalign(size_t alignment, size_t length);
void safe_free(void *ptr);


#endif
