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
 * Author: Miklos Maroti
 * Date last modified: 12/05/03
 */

#include "AM.h"
#include "TimeSyncMsg.h"    // HACK by jpaek
// Timestamping will be performed ONLY for messages with type AM_TIMESYNCMSG=0xAA.
// No other msgs will be timestamped....
// This is a HACK to go around the QueudedSend/Hop-by-hop Retx!!!!

module CC1000TimeStampingM
{
    provides
    {
        interface TimeStamping;
#ifdef TIMESTAMPING_CALIBRATE
        command uint8_t getBitOffset();
#endif
    }
    uses
    {
        interface RadioCoordinator as RadioSendCoordinator;
        interface RadioCoordinator as RadioReceiveCoordinator;
        interface LocalTime;
    }
}

implementation
{
#if defined(PLATFORM_MICA2)
    // 19.2 Kbps data, Manchester Encoding, time in jiffies (32768 HZ)
    //int8_t correction[8] __attribute__((C)) = { 46, 48, 49, 51, 53, 55, 56, 58 };

    // 38.4 Kbps data, Manchester Encoding, time in jiffies (32768 HZ)
    int8_t correction[8] __attribute__((C)) = { 24, 24, 25, 26, 27, 28, 28, 29 };
#elif defined(PLATFORM_MICA2DOT)
    // not yet calibrated
    int8_t correction[8] __attribute__((C)) = { 0, 0, 0, 0, 0, 0, 0, 0 };
//#elif defined(PLATFORM_MICA)
#else
    // time in jiffies (32768 HZ)
    int8_t correction __attribute__((C)) = 12;
#endif

    // the offset of the time-stamp field in the message, 
    // or -1 if no stamp is necessariy.
    norace int8_t sendStampOffset = -1;
    // the time stamp of the last received message
    norace uint32_t rcv_time;
    norace TOS_MsgPtr pTxMsg = 0;

    TimeStamp sendstamp;

    async event void RadioSendCoordinator.startSymbol(uint8_t bitsPerBlock, uint8_t offset, TOS_MsgPtr msgBuff)
    {
        uint32_t send_time;
        int8_t offsetCopy;

        atomic {
            send_time = call LocalTime.read();
            //msgBuff->time = call Timer.read() - msgBuff->time;

            if (msgBuff->type != AM_TIMESYNCMSG) // jpaek: we don't want to timestamp other pkts.
                offsetCopy = -1;
            else if (pTxMsg != 0 && pTxMsg != msgBuff)
                offsetCopy = -1;
            else
                offsetCopy = sendStampOffset;
        }

        if (offsetCopy < 0)
            return;

        sendstamp.sendingTime = *(uint32_t *)((int8_t*)msgBuff->data + offsetCopy) + send_time;
        sendstamp.stamped = 0xAA;

        memcpy(msgBuff->data + offsetCopy, (void*)&sendstamp, sizeof(TimeStamp));

        atomic sendStampOffset = -1;
    }

    async event void RadioReceiveCoordinator.startSymbol(uint8_t bitsPerBlock, uint8_t offset, TOS_MsgPtr msgBuff)
    {
        uint32_t stamp = call LocalTime.read();
    #ifndef TIMESTAMPING_CALIBRATE
    #if defined(PLATFORM_MICA2) || defined(PLATFORM_MICA2DOT)
        stamp -= correction[offset];
    #elif defined(PLATFORM_MICA) || defined(PLATFORM_PC)
        stamp -= correction;
    #endif
    #else
    #if defined(PLATFORM_MICA2) || defined(PLATFORM_MICA2DOT)
        bitOffset = offset;
    #endif
    #endif
        rcv_time = stamp;
    }

    command result_t TimeStamping.getStamp2(TOS_MsgPtr msg, uint32_t *time) {
        uint32_t currtime = call LocalTime.read();
        result_t ret = FAIL;
        atomic {
            if (currtime - rcv_time < 32768UL) {
                *time = rcv_time;
                ret = SUCCESS;
            } else {
                *time = 0;
            }
            rcv_time = 0;
        }
        return ret;
    }

#ifdef TIMESTAMPING_CALIBRATE
    norace uint8_t bitOffset;

    command uint8_t getBitOffset() {
        return bitOffset;
    }
#endif

#ifdef TOSH_DATA_LENGTH
#define MAX_OFFSET (TOSH_DATA_LENGTH-4)
#else
#define MAX_OFFSET 25
#endif

    //this needs to be called right after SendMsg.send() returned success, so
    //the code in addStamp() method runs before a task in the radio stack is
    //posted that writes to fifo -> which triggers coordinator event

    //if a msg is already being served by the radio, (sendStampOffset is
    //defined), timestamping returns fail

    command result_t TimeStamping.addStamp2(TOS_MsgPtr msg, int8_t offset)
    {
        result_t tmp;
        atomic {
            tmp = FAIL;
            // if correct value (negative value turns it off)
            if( 0 <= offset && offset <= MAX_OFFSET ) {
                atomic sendStampOffset = offset;
                pTxMsg = msg;
                tmp = SUCCESS;
            } else
                sendStampOffset = -1;
        }
        return tmp;
    }

    async event void RadioSendCoordinator.byte(TOS_MsgPtr msg, uint8_t byteCount) { }
    async event void RadioSendCoordinator.blockTimer() { }
    async event void RadioReceiveCoordinator.byte(TOS_MsgPtr msg, uint8_t byteCount) { }
    async event void RadioReceiveCoordinator.blockTimer() { }

}

