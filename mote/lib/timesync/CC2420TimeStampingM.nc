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

/**
 * slightly modified
 * - Trim-down almost everything!! because timing is very important here.
 *   Few 32-bit operations can screw you up.
 * - Timestamping will be performed ONLY for messages with type 
 *   AM_TIMESYNCMSG=0xAA. No other msgs will be timestamped.
 *
 * @modified Feb/21/2008
 * @author Jeongyeup Paek (jpaek@enl.usc.edu)
 **/

#include "AM.h"
#include "TimeSyncMsg.h"    // HACK by jpaek

module CC2420TimeStampingM
{
    provides
    {
        interface TimeStamping;
    }
    uses
    {
        interface RadioCoordinator as RadioSendCoordinator;
        interface RadioCoordinator as RadioReceiveCoordinator;
        interface LocalTime;
        interface HPLCC2420RAM;
    }
}

implementation
{
    // the offset of the time-stamp field in the message, 
    // or -1 if no stamp is necessariy.
    int8_t sendStampOffset = -1;
    TOS_MsgPtr sendMsg = 0;

    uint16_t metadata_time = 0;
    uint32_t receiveTime = 0;
    TimeStamp sendstamp;

    enum{
        TX_FIFO_MSG_START = 10,
    };

    uint32_t getLocalTime() {
        return call LocalTime.read();
    }

    //this needs to be called right after SendMsg.send() returned success, so
    //the code in addStamp() method runs before a task in the radio stack is
    //posted that writes to fifo -> which triggers coordinator event
    command result_t TimeStamping.addStamp2(TOS_MsgPtr msg, int8_t offset)
    {
        result_t ret = FAIL;
        atomic {
            if (0 <= offset && offset <= TOSH_DATA_LENGTH-4) {
                sendStampOffset = offset;
                sendMsg = msg;
                ret = SUCCESS;
            } 
        }
        return ret;
    }

    async event void RadioSendCoordinator.startSymbol(uint8_t bitsPerBlock, uint8_t offset, TOS_MsgPtr msgBuff)
    {
        int8_t offsetCopy = -1;
        uint32_t time = getLocalTime();

        if (msgBuff->type != AM_TIMESYNCMSG) // jpaek: we don't want to timestamp other pkts.
            offsetCopy = -1;
        else if (sendMsg != 0 && sendMsg != msgBuff)
            offsetCopy = -1;
        else
            offsetCopy = sendStampOffset;

        if (offsetCopy < 0)
            return;

        sendstamp.sendingTime = *(uint32_t *)((int8_t*)msgBuff->data + offsetCopy) + time;
        sendstamp.stamped = 0xAA;

        call HPLCC2420RAM.write(TX_FIFO_MSG_START+offsetCopy, sizeof(TimeStamp), (void*)&sendstamp);
        atomic sendStampOffset = -1;
    }

    async event void RadioReceiveCoordinator.startSymbol(uint8_t bitsPerBlock, uint8_t offset, TOS_MsgPtr msgBuff)
    {
        uint32_t time = getLocalTime();
        // jpaek: we are already in atomic context... we don't need 'atomic'
        atomic {
            metadata_time = msgBuff->time;  // remember the 16-bit time stampped by CC2420 -jpaek
            receiveTime = time;
        }
    }

    command result_t TimeStamping.getStamp2(TOS_MsgPtr msg, uint32_t *time) {
        uint16_t time_s = msg->time;
        uint32_t currtime = getLocalTime();
        result_t ret = FAIL;
        atomic {
            if ((metadata_time != 0) && 
                (metadata_time == time_s)) {   // return time only if 16-bit time matches -jpaek
                if (currtime - receiveTime < 32768UL) {
                    *time = receiveTime;
                    ret = SUCCESS;
                } else {
                    *time = 0;
                }
            } else {
                *time = 0;      // if the real time was 'zero', we're unlucky.... -jpaek
            }
            metadata_time = 0;
            receiveTime = 0;
        }
        return ret;
    }

    async event result_t HPLCC2420RAM.readDone(uint16_t addr, uint8_t length, uint8_t* buffer){
        return SUCCESS;
    }
    async event result_t HPLCC2420RAM.writeDone(uint16_t addr, uint8_t length, uint8_t* buffer){
        return SUCCESS;
    }
    async event void RadioSendCoordinator.byte(TOS_MsgPtr msg, uint8_t byteCount) { }
    async event void RadioSendCoordinator.blockTimer() { }
    async event void RadioReceiveCoordinator.byte(TOS_MsgPtr msg, uint8_t byteCount) { }
    async event void RadioReceiveCoordinator.blockTimer() { }

}

