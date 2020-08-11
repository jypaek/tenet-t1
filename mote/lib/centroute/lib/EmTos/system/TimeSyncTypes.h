#ifndef TIMESYNCTYPES_H
#define TIMESYNCTYPES_H

//EssSysTime variables 
//#define MOTE_CLOCK_RATE 7372800  //in Hz  - THIS CANNOT BE CHANGED

// Vary these parameters to get different effective clock speeds
// We want a clock that ticks every .1 seconds
//#define MSCALE     0x1
//#define MINTERVAL  0xFFFF
//#define MSCALE     0x3
//#define MINTERVAL  0x00B4
//#define MINTERVAL  0x480

#define MOTE_CLOCK_FREQUENCY_TICKS_SEC 10

#include <MultihopTypes.h>

// Changed from 32 bit time to 64 bit time to be rid of the 
// .."Time offset".  Will now just store absolute time, removing
// ..any reliance on the microserver to employ offset corrections.
//   -John H
typedef struct{
  mote_id_t from;
  int64_t time;
} __attribute__ ((packed)) timeSynchPkt_t;


#ifdef TIMESYNC_DEBUG
  typedef struct{
    uint32_t from;
    uint32_t oldtime;
    uint32_t newtime;
  } __attribute__ ((packed)) timeDbgPkt_t;


#endif

#endif
