#include "profile.h"
#include "trace.h"

profileInfo_t globalProfileInfo;

#define STOPPROFCOUNTER\
asm volatile (\
	      " mov r0, #0                          \n"\
	      " mcr p14,0,r0,c0,c1,0                \n"\
	      :\
	      : \
	      : "r0"\
	      ) 
 

inline void startProfile(){
  asm volatile (
		// evtc3=07 Icache access
		// evtc2=00 Icache miss
		// evtc1=0A Dcache access
		// evtc0=0B Dcache miss
		" mov r0, #0x0700                      \n"
		" mov r0, r0, lsl #16                  \n"
		" mov r1, #0xa                         \n"
		" mov r1, r1, lsl #8                   \n"
                " add r1, r1, #0xb                     \n"
                " orr r0, r0, r1                       \n"
		" mcr p14,0,r0,c8,c1,0                 \n"
                // turn off overflow interrupts
		" mov r0, #0x0                         \n"
                " mcr p14,0,r0,c4,c1,0                 \n"
                // setup PMNC, reset counters and enable
		" mov r0, #0x7                         \n"
		" mcr p14,0,r0,c0,c1,0                 \n"
		:
		:
		);
  return;
}

inline void stopProfile(){
  unsigned long IC_access, IC_miss, DC_access, DC_miss, cycles;
  //disable the counters so that we don't get errant results while reading out stuff
  asm volatile (
		" mov r0, #0                          \n"
		" mcr p14,0,r0,c0,c1,0                \n"
		:
		: 
		: "r0"
		);
  asm volatile (
		" mrc p14,0,r1,c1,c1,0               \n"
		" mov r2, %0                         \n"
		" str r1,[r2]                        \n"
		:
		: "r" (&cycles)
		: "r1", "r2"
		);
  asm volatile (
		" mrc p14,0,r1,c3,c2,0               \n"
		" mov r2, %0                         \n"
		" str r1,[r2]                        \n"
		:
		: "r" (&IC_access)
		: "r1", "r2"
		);
  asm volatile (
		" mrc p14,0,r1,c2,c2,0               \n"
		" mov r2, %0                         \n"
		" str r1,[r2]                        \n"
		:
		: "r" (&IC_miss)
		: "r1", "r2"
		);
  asm volatile (
		" mrc p14,0,r1,c1,c2,0               \n"
		" mov r2, %0                         \n"
		" str r1,[r2]                        \n"
		:
		: "r" (&DC_access)
		: "r1", "r2"
		);
  asm volatile (
		" mrc p14,0,r1,c0,c2,0               \n"
		" mov r2, %0                         \n"
		" str r1,[r2]                        \n"
		:
		: "r" (&DC_miss)
		: "r1", "r2"
		);

  globalProfileInfo.IC_access = IC_access;
  globalProfileInfo.IC_miss = IC_miss;
  globalProfileInfo.DC_access = DC_access;
  globalProfileInfo.DC_miss = DC_miss;
  globalProfileInfo.cycles = cycles;
  
  return;
}

void printProfile(profilePrintInfo_t printmask){
  float DC_mrate, IC_mrate, CPI;
  
  if(printmask == profilePrintAll){
    CPI = (float) globalProfileInfo.cycles / globalProfileInfo.IC_access;
    IC_mrate = (float) globalProfileInfo.IC_miss/ globalProfileInfo.IC_access;
    DC_mrate = (float) globalProfileInfo.DC_miss/ globalProfileInfo.DC_access;
    
    trace(1ULL<<27,"CYC=%d  CPI=%f  ICM=%f  DCM=%f \r\n", 
	  globalProfileInfo.cycles, CPI, IC_mrate, DC_mrate);
  }
  if(printmask == profilePrintCycles){
    trace(1ULL<<27,"CYC=%d\r\n", globalProfileInfo.cycles);
  }
}
