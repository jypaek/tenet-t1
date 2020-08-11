/*
* "Copyright (c) 2006~2007 University of Southern California.
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
 * AlarmC is a platform-independant alarm module.
 * AlarmC wraps around platform dependant time services to provide
 * platform independant alarm(AbsoluteTimer) service.
 *
 * @modified Oct/26/2007
 * @author Jeongyeup Paek (jpaek@enl.usc.edu)
 **/

/* For micaz/mica2 */
// If the 'TIMESYNC_SYSTIME' is not defined, then we MUST use micaz/32bitTimer!!!!
// We use either Timer3 or Timer0 for the system local time.
// Timer3 is accessed through SysTimeC module, and
// timer0 is accessed through ClockC, which is ENLClock module.

configuration AlarmC {
    provides {
        interface AbsoluteTimer;
    }
}
implementation {
    components Main, AlarmM, LocalTimeC, 
    #if defined(PLATFORM_TELOS) || defined(PLATFORM_TELOSB)
            TimerC;
    #elif defined(PLATFORM_IMOTE2)
            SysTimeC;
    #elif defined(PLATFORM_PC)
            TimerC;
    #elif TIMESYNC_SYSTIME // We assume MICAZ (28.8kHz)
            SysTimeC;      // micaz, mica2, mica2dot (with Timer3)
    #else // MICAZ/MICA2/MICA2DOT (4.096kHz or 32.768kHz)
            TimerC, ClockC; // micaz, mica2, mica2dot (with Timer0)
    #endif

    AbsoluteTimer = AlarmM;
    AlarmM.LocalTime -> LocalTimeC;

    // Local time sources are initialized in LocalTimeC !!

#if defined(PLATFORM_TELOS) || defined(PLATFORM_TELOSB)
    AlarmM.TimerJiffy -> TimerC.TimerJiffy[unique("TimerJiffy")];
#elif defined(PLATFORM_IMOTE2)
    //imote2 does not use TimerC, it uses an oscilator from pxa27x/SysTime64.nc
    AlarmM.SysTime64 -> SysTimeC;
#elif defined(PLATFORM_PC)
    AlarmM.Timer -> TimerC.Timer[unique("Timer")];
#elif TIMESYNC_SYSTIME
    AlarmM.SysAlarm -> SysTimeC;
#else   // MICAZ
    AlarmM.AbTimer -> TimerC.AbsoluteTimer[unique("Timer")];
#endif

}

