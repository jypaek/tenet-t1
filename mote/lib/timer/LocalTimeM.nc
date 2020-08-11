/*
* "Copyright (c) 2006~2009 University of Southern California.
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
 * LocalTimeM wraps around platform dependant time services to provide
 * platform independant LocalTime/LocalTimeInfo services.
 *
 * @modified Oct/9/2009
 *
 * @author Jeongyeup Paek (jpaek@usc.edu)
 **/


#if defined(PLATFORM_MICAZ) || defined(PLATFORM_MICA2) || defined(PLATFORM_MICA2DOT)
#ifdef TIMESYNC_SYSTIME
#include "SysAlarm.h"
#endif
#endif

enum {
    // we use scaler within LocalTimeM s/w module
    #if defined(PLATFORM_IMOTE2) 
        TSCALER = 6,
    #else
        TSCALER = 0,
    #endif

    #if defined(PLATFORM_TELOS) || defined(PLATFORM_TELOSB)
        TICKS_PER_SEC = 32768L
    #elif defined(PLATFORM_IMOTE2) 
        TICKS_PER_SEC = 3250000L    //3.25MHz - Marcos
    #elif defined(TIMESYNC_SYSTIME)
        // we use 1/32 pre-scaler for SYSTIME
        #if defined(PLATFORM_MICA2DOT)
            TICKS_PER_SEC = 15625L  // 500000/32
        #else
            TICKS_PER_SEC = 28800L  // 921600/32
        #endif
    #else
        TICKS_PER_SEC = 32768L
    #endif
};

module LocalTimeM {
    provides {
        interface LocalTime;
        interface LocalTimeInfo;
    }
    uses {
    #if defined(PLATFORM_TELOS) || defined(PLATFORM_TELOSB)
        interface LocalTime as ClockTime;
    #elif defined(PLATFORM_IMOTE2)
        interface SysTime64;
    #elif defined(PLATFORM_PC) || defined(PLATFORM_EMSTAR)
        // we are using gettimeofday
        ;
    #elif defined(TIMESYNC_SYSTIME)
        interface SysTime;
    #else   // Micaz/Mica2, without TIMESYNC_SYSTIME
        interface LocalTime as ClockTime;
    #endif
    }
}
implementation {

#if defined(PLATFORM_IMOTE2)
    bool alarm_busy = FALSE;
#endif

    // The returned value is in ticks...
    async command uint32_t LocalTime.read() {
    #if defined(PLATFORM_TELOS) || defined(PLATFORM_TELOSB)
        return call ClockTime.read();
    #elif defined(PLATFORM_IMOTE2)
        uint32_t ctLow, ctHigh;
        call SysTime64.getTime64(&ctLow, &ctHigh);
        //return call SysTime64.getTime32();
        ctLow = (ctLow>>TSCALER) & 0x01ffffff;
        ctHigh = (ctHigh<<(32-TSCALER)) & 0xfe000000;
        return (ctHigh + ctLow);
    #elif defined(PLATFORM_PC) || defined(PLATFORM_EMSTAR)
        //return (uint32_t)tos_state.tos_time;
        uint32_t curr_time;
        struct timeval tv;
        gettimeofday(&tv, NULL);
        curr_time = (tv.tv_sec % 1000000) * 1000;
        curr_time += (tv.tv_usec / 1000);
        return curr_time;
    #elif defined(TIMESYNC_SYSTIME)
        return call SysTime.getTime32();
    #else
        return call ClockTime.read();
    #endif
    }

    command uint32_t LocalTimeInfo.msToTimerInterval(uint32_t interval) {
        uint32_t t1,t2,t10,result;
        // Basically, we are doing 1024*interval/1000
        t10 = (256*interval)/25;
        t1 = t10 / 10;
        t2 = t1 + 1;
        if(t10 - (t1*10) > (t2*10) - t10)
            t1 = t2;
        result = t1;
    #if defined(PLATFORM_MICAZ) || defined(PLATFORM_MICA2) || defined(PLATFORM_MICA2DOT)
        #if defined(TIMESYNC_SYSTIME)
            return interval;
        #elif defined(ADJUST_1024_1000_IN_TIMERM)
            return interval;
        #else
            return result;
        #endif
    #elif defined(PLATFORM_IMOTE2)
            return interval;
    #else
        return result;
    #endif
    }

    command uint32_t LocalTimeInfo.getClockFreq() {
        // "TICKS_PER_SEC >> TSCALER" is the s/w clock frequency uses
        uint32_t freq = TICKS_PER_SEC >> TSCALER;
        return freq;
    }

    command uint32_t LocalTimeInfo.msToTicks(uint32_t ms) {
    #if defined(PLATFORM_EMSTAR)
        // when running under EmStar, all time is natively in ms,
        // so this conversion is not needed
        return ms;
    #else
        //GOAL: ((millisec * TICKS_PER_SEC) / 1000);
        uint32_t ms_h, ms_l;
        uint32_t tmp1, tmp2;
        uint32_t ticks_h, ticks_l, ticks;
        
        ms_h = (ms >> 16) & 0x0000ffff; // upper 2-bytes
        ms_l = (ms) & 0x0000ffff;       // lower 2-bytes
        
        if (TICKS_PER_SEC > 0x00010000) {
            tmp1 = (0x00010000)*(TICKS_PER_SEC/1000);
			tmp2 = 0;
        } else {
            tmp1 = ((0x00010000)*(TICKS_PER_SEC/8))/(1000L/8);
            tmp2 = ((0x00010000)*(TICKS_PER_SEC/8))%(1000L/8);
        }
		ticks_h = (ms_h * tmp1) + ((ms_h * tmp2 + (500L/8))/(1000L/8));
        
        if (TICKS_PER_SEC > 0x00010000)
            ticks_l = ms_l * (TICKS_PER_SEC / 1000L);
        else
            ticks_l = (ms_l * TICKS_PER_SEC) / 1000L;

        ticks = ((ticks_h + ticks_l) + ((1<<TSCALER)/2)) >> TSCALER;
        return ticks;
    #endif
    }

    command uint32_t LocalTimeInfo.ticksToMs(uint32_t ticks) {
    #if defined(PLATFORM_EMSTAR)
        // when running under EmStar, all time is natively in ms,
        // so this conversion is not needed
        return ticks;
    #else
        // GOAL: ((ticks * 1000) / TICKS_PER_SEC);
        uint32_t ticks_h, ticks_l;
        uint32_t tmp1, tmp2;
        uint32_t ms_h, ms_l, ms;
        
        ticks_h = (ticks >> 16) & 0x0000ffff; // upper 2-bytes
        ticks_l = (ticks) & 0x0000ffff;       // lower 2-bytes
        
        if (TICKS_PER_SEC > 0x00010000) {
            tmp1 = ((0x00010000<<TSCALER))/(TICKS_PER_SEC/1000);
            tmp2 = ((0x00010000<<TSCALER))%(TICKS_PER_SEC/1000);
        	ms_h = (ticks_h * tmp1) + ((ticks_h * tmp2 + TICKS_PER_SEC/2000)/(TICKS_PER_SEC/1000));
        } else {
            tmp1 = (((0x00010000<<TSCALER)*(1000L/8)))/(TICKS_PER_SEC/8);
            tmp2 = (((0x00010000<<TSCALER)*(1000L/8)))%(TICKS_PER_SEC/8);
        	ms_h = (ticks_h * tmp1) + ((ticks_h * tmp2)/(TICKS_PER_SEC/8));
        }

        if (TICKS_PER_SEC > 0x00010000)
            ms_l = (((ticks_l<<TSCALER) + (TICKS_PER_SEC/2000)) / (TICKS_PER_SEC/1000));
        else
            ms_l = (((ticks_l<<TSCALER)*(1000L/8) + ((TICKS_PER_SEC/8)/2)) / (TICKS_PER_SEC/8));

        ms = ms_h + ms_l;
        return ms;
    #endif
    }

#if defined(PLATFORM_IMOTE2) 
    async event result_t SysTime64.alarmFired(uint32_t val) {return SUCCESS;}
#endif
}

