
/*                                  tab:4
 * "Copyright (c) 2000-2003 The Regents of the University  of California.  
 * All rights reserved.
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose, without fee, and without written agreement is
 * hereby granted, provided that the above copyright notice, the following
 * two paragraphs and the author appear in all copies of this software.
 * 
 * IN NO EVENT SHALL THE UNIVERSITY OF CALIFORNIA BE LIABLE TO ANY PARTY FOR
 * DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES ARISING OUT
 * OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN IF THE UNIVERSITY OF
 * CALIFORNIA HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 * 
 * THE UNIVERSITY OF CALIFORNIA SPECIFICALLY DISCLAIMS ANY WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE.  THE SOFTWARE PROVIDED HEREUNDER IS
 * ON AN "AS IS" BASIS, AND THE UNIVERSITY OF CALIFORNIA HAS NO OBLIGATION TO
 * PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS."
 *
 * Copyright (c) 2002-2003 Intel Corporation
 * All rights reserved.
 *
 * This file is distributed under the terms in the attached INTEL-LICENSE     
 * file. If you do not find these files, copies can be found by writing to
 * Intel Research Berkeley, 2150 Shattuck Avenue, Suite 1300, Berkeley, CA, 
 * 94704.  Attention:  Intel License Inquiry.
 */
/*
 *
 * Authors:     Jason Hill, David Gay, Philip Levis
 * Date last modified:  6/25/02
 *
 */

/**
 * @author Jason Hill
 * @author David Gay
 * @author Philip Levis
 */


/**
 * UARTForward
 *
 * Sends the packet to the UART without modifying the msg->addr field
 * No address/type filtering on messages received on UART
 * 
 **/


module UARTForwardM
{
    provides {
        interface StdControl as Control;
        interface SendMsg[uint8_t id];
        interface SendMsg as SendMsgAll[uint8_t id];
        interface ReceiveMsg[uint8_t id];
        interface ReceiveMsg as ReceiveMsgAll[uint8_t id];
    }

    uses {
        interface StdControl as UARTControl;
        interface BareSendMsg as UARTSend;
        interface ReceiveMsg as UARTReceive;
        interface Leds;
    }
}
implementation {
#include "AMFiltered.h"

    bool state;
    TOS_MsgPtr buffer;
    
    command bool Control.init() {
        state = FALSE;
        call Leds.init();
        return call UARTControl.init();
    }

    command bool Control.start() {
        return call UARTControl.start();
    }
    
    command bool Control.stop() {
        return call UARTControl.stop();
    }

    result_t reportSendDone(TOS_MsgPtr msg, result_t success) {
        state = FALSE;
        if (isFiltered(msg->type)) {
            signal SendMsg.sendDone[msg->type](msg, success);
        } else {
            signal SendMsgAll.sendDone[msg->type](msg, success);
        }
        return SUCCESS;
    }

    task void sendTask() {
        TOS_MsgPtr buf;
        buf = buffer;
        if (!call UARTSend.send(buf))
            reportSendDone(buffer, FAIL);
    }

    result_t _SendMsg_send(uint8_t id, uint16_t addr, uint8_t length, TOS_MsgPtr data) {
        if (!state) {
            state = TRUE;
            if (length > DATA_LENGTH) {
                state = FALSE;
                return FAIL;
            }
            if (!(post sendTask())) {
                state = FALSE;
                return FAIL;
            } else {
                data->length = length;
                if (data->type == 0)
                    data->type = id;
                if (data->group == 0)
                    data->group = TOS_AM_GROUP;
                buffer = data;
            }
            return SUCCESS;
        }
        return FAIL;
    }

    command result_t SendMsg.send[uint8_t id](uint16_t addr, uint8_t length, TOS_MsgPtr data) {
        return _SendMsg_send(id, addr, length, data);
    }
    command result_t SendMsgAll.send[uint8_t id](uint16_t addr, uint8_t length, TOS_MsgPtr data) {
        return _SendMsg_send(id, addr, length, data);
    }

    TOS_MsgPtr uart_received(TOS_MsgPtr packet) __attribute__ ((C, spontaneous)) {
        //if (packet->crc == 1 && packet->group == TOS_AM_GROUP) {
        if (packet->crc == 1) {
            // We don't check address here... UART doesn't care..!!
            //&&(packet->addr == TOS_BCAST_ADDR || packet->addr == TOS_LOCAL_ADDRESS))
            // Should we check crcs for UART packet?
            uint8_t type = packet->type;
            TOS_MsgPtr tmp;
            if (isFiltered(type))
                tmp = signal ReceiveMsg.receive[type](packet);
            else    // anything that wants bare bridge between radio and uart.
                tmp = signal ReceiveMsgAll.receive[type](packet);
            if (tmp)
                packet = tmp;
        }
        return packet;
    }

    event TOS_MsgPtr UARTReceive.receive(TOS_MsgPtr packet) {
        if (packet->group == 0)
            packet->group = TOS_AM_GROUP;
        return uart_received(packet);
    }

    event result_t UARTSend.sendDone(TOS_MsgPtr msg, result_t success) {
        return reportSendDone(msg, success);
    }

    default event result_t SendMsgAll.sendDone[uint8_t id](TOS_MsgPtr msg, result_t success) {
        return SUCCESS;
    }
    default event result_t SendMsg.sendDone[uint8_t id](TOS_MsgPtr msg, result_t success) {
        return SUCCESS;
    }
    default event TOS_MsgPtr ReceiveMsg.receive[uint8_t id](TOS_MsgPtr msg) {
        return msg;
    }
    default event TOS_MsgPtr ReceiveMsgAll.receive[uint8_t id](TOS_MsgPtr msg) {
        return msg;
    }
}


