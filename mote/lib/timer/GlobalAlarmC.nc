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
 * Configuration file for GlobalAlarm module which provides 'alarm' service
 * based on time-synchronized global time (using FTSP)
 *
 * @modified Oct/26/2007
 * @author Jeongyeup Paek (jpaek@enl.usc.edu)
 **/

configuration GlobalAlarmC {
    provides {
        interface AbsoluteTimer as GlobalAbsoluteTimer; // alarm that fires at specific global time
    }
}
implementation {
    components  Main, GlobalAlarmM, TimeSyncC, AlarmC ;

    Main.StdControl -> TimeSyncC;

    // The goal is to transform global timer alarm into local timer alarm.
    GlobalAbsoluteTimer = GlobalAlarmM.GlobalAbsoluteTimer;
    GlobalAlarmM.LocalAbsoluteTimer -> AlarmC.AbsoluteTimer;
    GlobalAlarmM.GlobalTime -> TimeSyncC.GlobalTime;
}

