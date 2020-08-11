#include "wmmx.h"

int startWMMX(){
  asm volatile ("mrc p15, 0, r9, c15, c1, 0\n\t" : : );
  asm volatile ("orr r10, r9, #0x3\n\t" : : );
  asm volatile ("mcr p15, 0, r10, c15, c1, 0\n\t" : : );
  return 1;
}

// Disable WMMX coprocessor
int stopWMMX() {
  asm volatile ("mov r10, #0\n\t" : : );
  asm volatile ("mcr p15, 0, r10, c15, c1, 0\n\t" : : );
  return 1;
}
