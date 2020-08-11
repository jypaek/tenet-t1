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
 * LocalTime related helper functions.
 * 
 * @modified Oct/26/2007
 * @author Jeongyeup Paek (jpaek@enl.usc.edu)
 **/


interface LocalTimeInfo {

    command uint32_t getClockFreq();

    /**
     * Convert local clock ticks into missliseconds.
     *
     * @param  ms : Time in milliseconds.
     * @return clock ticks corresponding to 'ms' (practically, CLOCK_FREQ*ms/1000).
     **/
    command uint32_t msToTicks(uint32_t ms);

    /**
     * Convert milliseconds into local clock ticks.
     *
     * @param  ticks : Time in local-clock-ticks unit.
     * @return time in milliseconds corresponding to 'ticks' (practically, ms/CLOCK_FREQ/1000).
     **/
    command uint32_t ticksToMs(uint32_t ticks);

    /**
     * Adjust time interval by 1000/1024 so that Timer can fire after actual 'interval'.
     *
     * @param  interval Time interval which the unit is 1024/1000 milliseconds.
     * @return 1000/1024 converted time interval.
     **/
    command uint32_t msToTimerInterval(uint32_t interval);
}

