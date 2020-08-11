/*
 * Copyright (c) 2002, Vanderbilt University
 * All rights reserved.
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose, without fee, and without written agreement is
 * hereby granted, provided that the above copyright notice, the following
 * two paragraphs and the author appear in all copies of this software.
 * 
 * IN NO EVENT SHALL THE VANDERBILT UNIVERSITY BE LIABLE TO ANY PARTY FOR
 * DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES ARISING OUT
 * OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN IF THE VANDERBILT
 * UNIVERSITY HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 * 
 * THE VANDERBILT UNIVERSITY SPECIFICALLY DISCLAIMS ANY WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE.  THE SOFTWARE PROVIDED HEREUNDER IS
 * ON AN "AS IS" BASIS, AND THE VANDERBILT UNIVERSITY HAS NO OBLIGATION TO
 * PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS.
 *
 * Author: Miklos Maroti, Brano Kusy
 * Date last modified: 3/17/03
 */

/**
 * Wire to NewQueuedSend for Tenet
 *
 * @date Oct/30/2007
 * @author Jeongyeup Paek
 **/

#include "TimeSyncMsg.h"

configuration TimeSyncC
{
    provides interface StdControl;
    provides interface GlobalTime;

    //interfaces for extra functionality: need not to be wired 
    provides interface TimeSyncInfo;
}

implementation 
{
    components  Main, TimeSyncM
                , GenericComm                   // for receiving timesync beacons
            #ifndef TESTTIMESYNC    // not testing, but wiring to Tenet
                , NewQueuedSend as QueuedSendC  // for sending timesync beacons
            #endif
                , TimeStampingC
                , TimerC
                , LocalTimeC
                ;

    GlobalTime     = TimeSyncM;
    StdControl     = TimeSyncM;
    TimeSyncInfo   = TimeSyncM;
    
    Main.StdControl -> TimerC;
    Main.StdControl -> GenericComm;

#ifndef TESTTIMESYNC    // Tenet
    Main.StdControl        -> QueuedSendC;
    TimeSyncM.SendMsg      -> QueuedSendC.SendMsg[AM_TIMESYNCMSG];
#else                   // TestTimeSync
    TimeSyncM.SendMsg      -> GenericComm.SendMsg[AM_TIMESYNCMSG];
#endif
    TimeSyncM.ReceiveMsg   -> GenericComm.ReceiveMsg[AM_TIMESYNCMSG];
    TimeSyncM.Timer        -> TimerC.Timer[unique("Timer")];
    TimeSyncM.TimeStamping -> TimeStampingC;
    TimeSyncM.LocalTime    -> LocalTimeC;
}

