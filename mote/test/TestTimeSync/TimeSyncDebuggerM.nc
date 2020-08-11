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
 * Date last modified: 03/17/03
 */

#include "TestTimeSyncMsg.h"

module TimeSyncDebuggerM
{
    provides
    {
        interface StdControl;
    }
    uses
    {
        interface GlobalTime;
        interface TimeSyncInfo;
        interface ReceiveMsg;
        interface SendMsg;
        interface Timer;
        interface Leds;
        interface TimeStamping;
    }
}

implementation
{
    TOS_Msg msg;
    bool reporting;
    uint8_t errcnt;
 
    command result_t StdControl.init() {
        reporting = FALSE;
        errcnt = 0;
        return SUCCESS;
    }

    command result_t StdControl.start() {
        call Timer.start(TIMER_REPEAT, 3000);    // every three seconds
        return SUCCESS;
    }

    command result_t StdControl.stop() {
        return call Timer.stop();
    }

    task void report() {
        if (reporting) {
            call Leds.greenToggle();
            if (call SendMsg.send(TOS_BCAST_ADDR, sizeof(TimeSyncPollReply), &msg) != SUCCESS) {
                if (post report() != SUCCESS)
                    reporting = FALSE;
            }
        }
    }

    event result_t SendMsg.sendDone(TOS_MsgPtr ptr, result_t success) {
        reporting = FALSE;
        return SUCCESS;
    }

    event result_t Timer.fired() {
        if (reporting)
            post report();
        return SUCCESS;
    }

    event TOS_MsgPtr ReceiveMsg.receive(TOS_MsgPtr p)
    {
        uint32_t localTime;
        TimeSyncPollReply *pPollReply = (TimeSyncPollReply *)(msg.data);

        call Leds.redToggle();

        if (!reporting)
        {
            pPollReply->nodeID = TOS_LOCAL_ADDRESS;
            pPollReply->msgID = ((TimeSyncPoll*)(p->data))->msgID;

            call TimeStamping.getStamp2(p, &localTime);
            if (localTime == 0) { // cannot identify the timestamp
                errcnt++;
                return p;
            }

            pPollReply->localClock = localTime;
            pPollReply->is_synced = 0;
            if (call GlobalTime.local2Global(&localTime) == SUCCESS)
                pPollReply->is_synced = 1;
            pPollReply->globalClock = localTime;
            pPollReply->skew = (nx_int32_t)(call TimeSyncInfo.getSkew()*1000000.0);
            pPollReply->rootID = call TimeSyncInfo.getRootID();
            pPollReply->seqNum = call TimeSyncInfo.getSeqNum();
            pPollReply->numEntries = call TimeSyncInfo.getNumEntries();
            pPollReply->offsetAvg = call TimeSyncInfo.getOffset();
            pPollReply->localAvg = call TimeSyncInfo.getSyncPoint();
            pPollReply->not_used = errcnt;

            reporting = TRUE;
            if (pPollReply->rootID == TOS_LOCAL_ADDRESS) { // if I am the root, then
                pPollReply->seqNum -= 1;            //   (seqNum is the next one)
                post report();                      //   report immediately.
            }
        }
        return p;
    }
}

