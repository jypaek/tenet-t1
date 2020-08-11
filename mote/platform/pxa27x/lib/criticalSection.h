#ifndef __CRITICAL_SECTION_H__
#define __CRITICAL_SECTION_H__
#include "inttypes.h"

extern inline uint32_t __nesc_atomic_start(void);
extern inline void __nesc_atomic_end(uint32_t);

#define DECLARE_CRITICAL_SECTION()  uint32_t fInterruptFlags
#define CRITICAL_SECTION_BEGIN() fInterruptFlags = __nesc_atomic_start()
#define CRITICAL_SECTION_END()   __nesc_atomic_end(fInterruptFlags)

#endif // __CRITICAL_SECTION_H__
