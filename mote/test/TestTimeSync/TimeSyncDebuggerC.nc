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

#include "TestTimeSyncMsg.h"

configuration TimeSyncDebuggerC
{
    provides interface StdControl;
}

implementation 
{
    components TimeSyncDebuggerM, TimeSyncC, 
               GenericComm, 
               Main,
               LedsC,
               TimerC,
               TimeStampingC;

    StdControl = TimeSyncDebuggerM;
    Main.StdControl -> GenericComm;

    TimeSyncDebuggerM.ReceiveMsg   -> GenericComm.ReceiveMsg[AM_TIMESYNCPOLL];
    TimeSyncDebuggerM.SendMsg      -> GenericComm.SendMsg[AM_TIMESYNCPOLLREPLY];

    TimeSyncDebuggerM.Timer        -> TimerC.Timer[unique("Timer")];
    TimeSyncDebuggerM.GlobalTime   -> TimeSyncC;
    TimeSyncDebuggerM.TimeSyncInfo -> TimeSyncC;
    TimeSyncDebuggerM.Leds         -> LedsC;
    TimeSyncDebuggerM.TimeStamping -> TimeStampingC;
}

