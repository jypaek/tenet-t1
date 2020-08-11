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
 * GlobalAlarm module which provides an alarm that fires at specific 
 * time-synchronized global time.
 *
 * @modified Oct/26/2007
 * @author Jeongyeup Paek (jpaek@enl.usc.edu)
 **/


module GlobalAlarmM {
    provides {
        interface AbsoluteTimer as GlobalAbsoluteTimer;
    }
    uses {
        interface GlobalTime;
        interface AbsoluteTimer as LocalAbsoluteTimer;
    }
}
implementation {

    /**
     * Set an alarm(AbsoluteTimer) that fires at a specific global time.
     *
     * It first converts global time into a corresponding local time,
     * and then sets a local alarm.
     * @return FAIL if time is not synchronized.
     **/
    command result_t GlobalAbsoluteTimer.set(uint32_t gtime) {
        uint32_t localAlarmTime;
        
        localAlarmTime = gtime;
        if (call GlobalTime.global2Local(&localAlarmTime) == FAIL) {
            return FAIL;
        }
        return call LocalAbsoluteTimer.set(localAlarmTime);
    }
    
    command result_t GlobalAbsoluteTimer.cancel() {
        return call LocalAbsoluteTimer.cancel();
    }

    event result_t LocalAbsoluteTimer.fired() {
        return signal GlobalAbsoluteTimer.fired();
    }

    default event result_t GlobalAbsoluteTimer.fired() {
        return SUCCESS;
    }

}

