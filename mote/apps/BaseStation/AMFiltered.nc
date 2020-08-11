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

/*
* Authors: Jeongyeup Paek
* Embedded Networks Laboratory, University of Southern California
* Modified: 1/11/2006
*/


/* AMFiltered.nc
    - This is module implementation for the fake GenericComm.nc.
    - It filters out certain AM types to work around the parameterized interface problem.
    - This module(GenericComm) should be used by the native GenericComm user modules
      (such as TimeSync, MultihopDse, etc) ONLY AFTER (manually) registering their
      AM types in the AMFiltered.h file.
*/


module AMFiltered {
    provides {
        interface SendMsg[uint8_t id];
        interface ReceiveMsg[uint8_t id];
        interface ReceiveMsg as ReceiveMsgRadioAll[uint8_t id];
    }
    uses {
        interface SendMsg as RadioSendMsg[uint8_t id];
        interface ReceiveMsg as RadioReceiveMsg[uint8_t id];
        interface SendMsg as UARTSendMsg[uint8_t id];
        interface ReceiveMsg as UARTReceiveMsg[uint8_t id];
    }
}
implementation {
#include "AMFiltered.h"

    /* 
     * bool isFiltered(uint8_t typeid);
     *
     * - Refer to "AMFiltered.h" for the filtered AM types.
     * - This is a way of working(hacking) around the parameterized interface problem,
     *   more specifically, the problem of multiple event signalling in a fan-out situations.
     * - Two main problems are: multiple 'sendDone' events and 'receive' events.
     */

    command result_t SendMsg.send[uint8_t id](uint16_t addr, uint8_t length, TOS_MsgPtr data) {
        // to TOS_LOCAL_ADDRESS means, send to the stargate of myself.
        if ((addr == TOS_UART_ADDR) || (addr == TOS_LOCAL_ADDRESS)) {
            return call UARTSendMsg.send[id](addr, length, data);
            // This calls UART-send with 'addr', but does not change the 'msg->addr'
        } else {
            return call RadioSendMsg.send[id](addr, length, data);
        }
    }

    event TOS_MsgPtr RadioReceiveMsg.receive[uint8_t typeid](TOS_MsgPtr msg) {
        if (isFiltered(typeid))
            return signal ReceiveMsg.receive[typeid](msg);
        else    // anything that wants bare bridge between radio and uart.
            return signal ReceiveMsgRadioAll.receive[typeid](msg);
    }
    event TOS_MsgPtr UARTReceiveMsg.receive[uint8_t typeid](TOS_MsgPtr msg) {
        return signal ReceiveMsg.receive[typeid](msg);
    }
    
    result_t signal_sendDone(uint8_t id, TOS_MsgPtr msg, result_t success) {
        return signal SendMsg.sendDone[id](msg, success);
    }
            
    event result_t RadioSendMsg.sendDone[uint8_t id](TOS_MsgPtr msg, result_t success) {
        return signal_sendDone(id, msg, success);
    }
    event result_t UARTSendMsg.sendDone[uint8_t id](TOS_MsgPtr msg, result_t success) {
        return signal_sendDone(id, msg, success);
    }
    default event result_t SendMsg.sendDone[uint8_t id](TOS_MsgPtr msg, result_t success) {
        return SUCCESS;
    }
    default event TOS_MsgPtr ReceiveMsg.receive[uint8_t typeid](TOS_MsgPtr msg) {
        return msg;
    }
    default event TOS_MsgPtr ReceiveMsgRadioAll.receive[uint8_t typeid](TOS_MsgPtr msg) {
        return msg;
    }
}

