/*
* "Copyright (c) 2006 University of Southern California.
* All rights reserved.
*
* Permission to use, copy, modify, and distribute this software and its
* documentation for any purpose, without fee, and without written
* agreement is hereby granted, provided that the above copyright
* notice, the following two paragraphs and the author appear in all
* copies of this software.
*
* IN NO EVENT SHALL THE UNIVERSITY OF SOUTHERN CALIFORNIA BE LIABLE TO
* ANY PARTY FOR DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL
* DAMAGES ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS
* DOCUMENTATION, EVEN IF THE UNIVERSITY OF SOUTHERN CALIFORNIA HAS BEEN
* ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*
* THE UNIVERSITY OF SOUTHERN CALIFORNIA SPECIFICALLY DISCLAIMS ANY
* WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
* MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.  THE SOFTWARE
* PROVIDED HEREUNDER IS ON AN "AS IS" BASIS, AND THE UNIVERSITY OF
* SOUTHERN CALIFORNIA HAS NO OBLIGATION TO PROVIDE MAINTENANCE,
* SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS."
*
*/

/**
 * AlarmM is a platform-independant alarm module.
 * AlarmM wraps around platform dependant time services to provide
 * platform independant alarm(AbsoluteTimer) service.
 *
 * @modified Oct/26/2007
 * @author Jeongyeup Paek (jpaek@enl.usc.edu)
 **/


#if defined(PLATFORM_MICAZ) || defined(PLATFORM_MICA2) || defined(PLATFORM_MICA2DOT)
#ifdef TIMESYNC_SYSTIME
#include "SysAlarm.h"
#endif
#endif

module AlarmM {
    provides {
        interface AbsoluteTimer;
    }
    uses {
        interface LocalTime;
    #if defined(PLATFORM_TELOS) || defined(PLATFORM_TELOSB)
        interface TimerJiffy;
    #elif defined(PLATFORM_IMOTE2)
        interface SysTime64;
    #elif defined(PLATFORM_PC)
        interface Timer;
    #elif TIMESYNC_SYSTIME
        interface SysAlarm;
    #else   // Micaz/Mica2, without TIMESYNC_SYSTIME
        interface AbsoluteTimer as AbTimer;
    #endif
    }
}
implementation {

#if defined(PLATFORM_IMOTE2)
    bool alarm_busy = FALSE;
#endif

    // Set value should be in ticks...
    // Do not compare "if (atime < now)" since atime may wrap-around!
    command result_t AbsoluteTimer.set(uint32_t atime) {
    #if defined(PLATFORM_TELOS) || defined(PLATFORM_TELOSB)
        uint32_t now = call LocalTime.read();
        return call TimerJiffy.setOneShot(atime - now);
    #elif defined(PLATFORM_IMOTE2) 
        if (call SysTime64.setAlarm(atime))
            alarm_busy = TRUE;
        else
            alarm_busy = FALSE;
        return alarm_busy;
    #elif defined(PLATFORM_PC)
        uint32_t now = call LocalTime.read();
        return call Timer.start(TIMER_ONE_SHOT, atime - now);
    #elif TIMESYNC_SYSTIME
        return call SysAlarm.set(SYSALARM_ABSOLUTE, atime);
    #else
        return call AbTimer.set(atime);
    #endif
    }

    command result_t AbsoluteTimer.cancel() {
    #if defined(PLATFORM_TELOS) || defined(PLATFORM_TELOSB)
        return call TimerJiffy.stop();
    #elif defined(PLATFORM_IMOTE2) 
        alarm_busy = FALSE;
        //there is no SysTime64.cancelAlarm;
        return SUCCESS;
    #elif defined(PLATFORM_PC)
        return call Timer.stop();
    #elif TIMESYNC_SYSTIME
        return call SysAlarm.cancel();
    #else
        return call AbTimer.cancel();
    #endif
    }

#if defined(PLATFORM_TELOS) || defined(PLATFORM_TELOSB)
    event result_t TimerJiffy.fired() {
        signal AbsoluteTimer.fired();
        return SUCCESS;
    }
#elif defined(PLATFORM_IMOTE2) 
    async event result_t SysTime64.alarmFired(uint32_t p){
        if (alarm_busy)
            signal AbsoluteTimer.fired();
        alarm_busy = FALSE;
        return SUCCESS;
    }
#elif defined(PLATFORM_PC)
    event result_t Timer.fired() {
        signal AbsoluteTimer.fired();
        return SUCCESS;
    }
#elif TIMESYNC_SYSTIME
    task void AbsoluteTimerFiredTask() {
        signal AbsoluteTimer.fired();
    }
    async event void SysAlarm.fired() {
        post AbsoluteTimerFiredTask();
    }
#else
    event result_t AbTimer.fired()  {
        signal AbsoluteTimer.fired();
        return SUCCESS;
    }
#endif

    default event result_t AbsoluteTimer.fired() { return SUCCESS;}

}

