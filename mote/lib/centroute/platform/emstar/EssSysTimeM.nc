module EssSysTimeM{
  provides {
    interface StdControl;
    interface EssSysTimeI;
  }uses{
    interface Leds;
#ifdef EMSTAR_NO_KERNEL
    interface EmTimerI as SysTimer;
#else
    interface Timer as SysTimer;
#endif
  }
}implementation{

#include "TimeSyncTypes.h"

  // There are actually 1024 "timer ticks" in one second
#define TIMER_TICKS_PER_SECOND 1024

  // The mote time mirrors unix time which is in microseconds.  Do a quick
  // ..division to find out how much to increment the stored time every tick
#define TIME_INTERVAL 1000000 / MOTE_CLOCK_FREQUENCY_TICKS_SEC


  // From 32 to 64 bits.  Now uses unix time.
  //   -John H
  int64_t currentTime;

  /***********************************************
   * StdControl functions
   ***********************************************/
  command result_t StdControl.init() {
    // Initialize time to 0.  Corrosponds to Jan 1, 1970.
    return SUCCESS;
  }

  command result_t StdControl.start() {
    // Start a timer to fire once per intended resolution frequency
    call SysTimer.start(TIMER_REPEAT, TIMER_TICKS_PER_SECOND / MOTE_CLOCK_FREQUENCY_TICKS_SEC);
    return SUCCESS;
  }

  command result_t StdControl.stop(){
    call SysTimer.stop();
    return SUCCESS;
  }

  /***********************************************
   * EssSysTimeI implementation
   ***********************************************/

  // At any time pass a int64_t value to setTime and that will be the new mote
  // ..time.  Done atomically as it can be done straight from a packet receive
  // ..interrupt.
  async command int64_t EssSysTimeI.setTime(int64_t setTimeVal) {
    atomic currentTime = setTimeVal;
    return setTimeVal;
  }

  async command int64_t EssSysTimeI.getTime(){
    int64_t current_time_atomic;
    atomic current_time_atomic = currentTime;

    return current_time_atomic;
  }

  // Simply convert to milliseconds before returning the time
  async command int64_t EssSysTimeI.getTimeMilliSeconds(){
    int64_t current_time_atomic;
    atomic current_time_atomic = currentTime / 1000;

    return current_time_atomic;
  }

  async command uint32_t EssSysTimeI.getTimeResolution() {
	return MOTE_CLOCK_FREQUENCY_TICKS_SEC;
  }

  // Should be firing once everytime we want to update the time.  Increment
  // ..the time according to our intended timer resolution.
  event result_t SysTimer.fired() {
    atomic {
      currentTime += TIME_INTERVAL;
    }
    return SUCCESS;
  }
}
