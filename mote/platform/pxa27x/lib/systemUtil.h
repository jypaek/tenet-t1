#ifndef __SYSTEM_UTIL_H__
#define __SYSTEM_UTIL_H__

#include "inttypes.h"

/****
printFatalErrorMsg will print the parameter msg prepended with FATAL ERROR
and appended with status printed as a hex # to the STUART. 

*****/
void printFatalErrorMsg(const char *msg, uint32_t numArgs, ...);
void printFatalErrorMsgHex(const char *msg, uint32_t numArgs, ...);
void resetNode();

struct mallinfo {
  int arena;    /* total space allocated from system */
  int ordblks;  /* number of non-inuse chunks */
  int smblks;   /* unused -- always zero */
  int hblks;    /* number of mmapped regions */
  int hblkhd;   /* total space in mmapped regions */
  int usmblks;  /* unused -- always zero */
  int fsmblks;  /* unused -- always zero */
  int uordblks; /* total allocated space */
  int fordblks; /* total non-inuse space */
  int keepcost; /* top-most, releasable (via malloc_trim) space */
};	

struct mallinfo mallinfo() __attribute__((C,spontaneous));

#endif // __SYSTEM_UTIL_H__
