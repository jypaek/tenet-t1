#include "criticalSection.h"
#include "frequency.h"
#include "pxa27x_registers_def.h"

#if 0
typedef struct{
  uint32_t CCCR;
  uint32_t CLKCFG;
}frequencyInfo_t;

const frequencyInfo_t frequencyInfo[4] = {
  {CCCR_L(8) | CCCR_2N(2) |  }};  

#endif

#define CLKCFG_B    (1<<3)
#define CLKCFG_HT   (1<<2)
#define CLKCFG_F    (1<<1)
#define CLKCFG_T    (1)

void writeCLKCFG(uint32_t value){
  
  asm volatile (
		"mcr p14,0,%0,c6,c0,0\n\t"
		:
		: "r" (value)
		);
  
  return;
}
  
uint32_t readCLKCFG(){
  
  uint32_t result;
  asm volatile (
		"mrc p14,0,%0,c6,c0,0\n\t"
		:"=r" (result)
		);
  
  return result;
}
  
uint32_t getSystemFrequency(){
  
  uint32_t clkcfg = readCLKCFG();
  uint32_t frequency;
  
  if((CCSR & CCSR_CPDIS_S)){
    return 13;
  }
  else{
    frequency = 13 * (CCSR & 0x1f);
    frequency *= (clkcfg & CLKCFG_T) ? ((CCSR >> 7) & 0x7)/2 : 1; 
    if( (clkcfg & CLKCFG_HT) && (clkcfg  & CLKCFG_T)){
      return frequency/2; 
    }
    else{
      return frequency;
    }
  }
}
  
uint32_t getSystemBusFrequency(){
  
  uint32_t clkcfg = readCLKCFG();
  
  if((CCSR & CCSR_CPDIS_S)){
    return 13;
  }
  else{
    if(clkcfg & CLKCFG_B){
      return 13 * (CCSR & 0x1f);
    }
    else{
      return (13 * (CCSR & 0x1f))/2;
    }
  }
}
 
