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
 * @author Phil Buonadonna
 * @author Gilman Tolle
 * Revision:    $Id: BaseStationM.nc,v 1.12 2007-04-28 00:59:26 jpaek Exp $
 */
  
/* 
 * TOSBaseM bridges packets between a serial channel and the radio.
 * Messages moving from serial to radio will be tagged with the group
 * ID compiled into the TOSBase, and messages moving from radio to
 * serial will be filtered by that same group id.
 */



/**
 * Tenet Base Station
 *
 * Based on TOSBase. Uses the components customized for Tenet.
 * See comments on BaseStation.nc
 *
 **/


/* modified by Jeongyeup Paek, 1/11/2006 */


module BaseStationM {
    provides interface StdControl;
    uses {
        interface StdControl as UARTControl;
        interface SendMsg as UARTSend[uint8_t typeid];
        interface ReceiveMsg as UARTReceive[uint8_t typeid];

        interface StdControl as RadioControl;
        interface SendMsg as RadioSend[uint8_t typeid];
        interface ReceiveMsg as RadioReceive[uint8_t typeid];

        interface Leds;
    }
}

implementation
{
    enum {
    #ifdef BS_Q_LEN
        UART_QUEUE_LEN = BS_Q_LEN,
        RADIO_QUEUE_LEN = BS_Q_LEN,
    #else
        #if defined(PLATFORM_TELOSB)
            UART_QUEUE_LEN = 30,
            RADIO_QUEUE_LEN = 30,
        #else
            UART_QUEUE_LEN = 10,
            RADIO_QUEUE_LEN = 10,
        #endif
    #endif
    };

    TOS_Msg     uartQueue[UART_QUEUE_LEN];
    uint8_t     uartIn, uartOut, uartCount;
    bool        uartBusy;

    TOS_Msg     radioQueue[RADIO_QUEUE_LEN];
    uint8_t     radioIn, radioOut, radioCount;
    bool        radioBusy;

    task void UARTSendTask();
    task void RadioSendTask();

    void failBlink();
    void dropBlink();

    command result_t StdControl.init() {
        result_t ok1, ok2;

        uartIn = uartOut = 0;
        uartBusy = FALSE;
        uartCount = 0;

        radioIn = radioOut = 0;
        radioBusy = FALSE;
        radioCount = 0;

        ok1 = call UARTControl.init();
        ok2 = call RadioControl.init();
        call Leds.init();

        return rcombine(ok1, ok2);
    }

    command result_t StdControl.start() {
        result_t ok1, ok2;
        ok1 = call UARTControl.start();
        ok2 = call RadioControl.start();
        return rcombine(ok1, ok2);
    }

    command result_t StdControl.stop() {
        result_t ok1, ok2;
        ok1 = call UARTControl.stop();
        ok2 = call RadioControl.stop();
        return rcombine(ok1, ok2);
    }

    int is_duplicate_packet(TOS_MsgPtr msg) {
        int i;
        uint8_t last_idx;
        if (uartCount == 0) return 0;
        if (uartIn == 0) last_idx = (uint8_t)(UART_QUEUE_LEN - 1);
        else last_idx = uartIn - 1;
        for (i = 0; i < msg->length; i++) {
            if (uartQueue[last_idx].data[i] != msg->data[i])
                return 0;
        }
        return 1;
    }

    // Put the received packet in the UART_send_Queue. (usually, packets from radio)
    event TOS_MsgPtr RadioReceive.receive[uint8_t typeid](TOS_MsgPtr Msg) {
        if (Msg->length > TOSH_DATA_LENGTH)
            return Msg;
        if ((!Msg->crc) || (Msg->group != TOS_AM_GROUP))
            return Msg;
        if (is_duplicate_packet(Msg))
            return Msg;
        atomic {
            if (uartCount < UART_QUEUE_LEN) {
                memcpy(&uartQueue[uartIn], Msg, sizeof(TOS_Msg));
                if( ++uartIn >= UART_QUEUE_LEN ) uartIn = 0;
                uartCount++;
                if (!uartBusy) {
                    if (post UARTSendTask()) {
                        uartBusy = TRUE;
                    }
                }
            } else {
                dropBlink();
            }
        }
        return Msg;
    }
    
    task void UARTSendTask() {
        bool noWork = FALSE;
        atomic {
            if (uartCount == 0) {
                uartBusy = FALSE;
                noWork = TRUE;
            }
        }
        if (noWork)
            return;
        if (!call UARTSend.send[uartQueue[uartOut].type](uartQueue[uartOut].addr, 
                uartQueue[uartOut].length, &uartQueue[uartOut])) {
            failBlink();
            post UARTSendTask();
        }
    }

    event result_t UARTSend.sendDone[uint8_t typeid](TOS_MsgPtr msg, result_t success) {
        if (!success) {
            failBlink();
        } else
            call Leds.yellowToggle();
        atomic {
            if (msg == &uartQueue[uartOut]) {
                uartCount--;
                if( ++uartOut >= UART_QUEUE_LEN ) uartOut = 0;
            }
        }
        post UARTSendTask();
        return SUCCESS;
    }

    // Put the received packet in the Radio_send_Queue. (usually, packets from uart)
    event TOS_MsgPtr UARTReceive.receive[uint8_t typeid](TOS_MsgPtr Msg) {
        if (Msg->length > TOSH_DATA_LENGTH)
            return Msg;
        atomic {
            if (radioCount < RADIO_QUEUE_LEN) {
                memcpy(&radioQueue[radioIn], Msg, sizeof(TOS_Msg));
                if( ++radioIn >= RADIO_QUEUE_LEN ) radioIn = 0;
                radioCount++;
                if (!radioBusy) {
                    if (post RadioSendTask()) {
                        radioBusy = TRUE;
                    }
                }
            } else {
                dropBlink();
            }
        }
        return Msg;
    }

    task void RadioSendTask() {
        bool noWork = FALSE;
        atomic {
            if (radioCount == 0) {
                radioBusy = FALSE;
                noWork = TRUE;
            }
        }
        if (noWork)
            return;
        radioQueue[radioOut].group = TOS_AM_GROUP;
        if (!call RadioSend.send[radioQueue[radioOut].type](radioQueue[radioOut].addr, 
                radioQueue[radioOut].length, &radioQueue[radioOut])) {
            failBlink();
            post RadioSendTask();
        }
    }

    event result_t RadioSend.sendDone[uint8_t typeid](TOS_MsgPtr msg, result_t success) {
        if (!success) {
            failBlink();
        } else
            call Leds.greenToggle();
        atomic {
            if (msg == &radioQueue[radioOut]) {
                if( ++radioOut >= RADIO_QUEUE_LEN ) radioOut = 0;
                radioCount--;
            }
        }
        post RadioSendTask();
        return SUCCESS;
    }

    void dropBlink() {
        call Leds.redToggle();
    }

    void failBlink() {
        call Leds.redToggle();
    }
}   

