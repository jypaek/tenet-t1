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
 * Author: Phil Buonadonna
 * $Revision: 1.16 $
 */

/**
 * @author Phil Buonadonna
 */


/**
 * NewQueueSend
 *  - This module is very similar to the tinyOS QueuedSend module.
 *  - This module is uses 'pointer queue'. Responsibility of managing the real
 *    memory buffer space is left to the users of this module.
 *  - This module implements link-layer retransmission based on CC2420 ACK.
 *  - The only major difference is that this module does random backoff.
 *  - When transmission failure happens, we set random timer and retransmit when fired.
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 2/5/2006
 **/

module NewQueuedSendM {
    provides {
        interface StdControl;
        interface SendMsg[uint8_t typeid];
        interface RetransmitControl;
    }
    uses {
        interface StdControl as SubStdControl;
        
        interface SendMsg as SubSendMsg[uint8_t typeid];
    #if defined(PLATFORM_EMSTAR)       
        interface EmTimerI as ResendTimer;
    #else
        interface MacControl;
        interface Timer as ResendTimer;
    #endif

        interface Random;
    }
}
implementation {
#include "TosMsgPtrQueue.h"

enum {
#ifdef PLATFORM_MICAZ
    QSEND_QUEUESIZE = 4,
#else
    QSEND_QUEUESIZE = 9,
#endif
#if defined(PLATFORM_MICA2) || defined (PLATFORM_MICA2DOT)
    QSEND_MINIMUM_RESEND_TIME = 10,
#else
    QSEND_MINIMUM_RESEND_TIME = 5,
#endif
#ifdef LINK_NUM_RETX
    QSEND_DEFAULT_NUM_RETX = LINK_NUM_RETX,
#else
    QSEND_DEFAULT_NUM_RETX = 4,
#endif
};

    task void sendPacket();

    TOS_MsgPtr buffer[QSEND_QUEUESIZE];

    struct TosMsgPtrQueue queue;

    bool sending;
    bool timerSet;  // shows that retransmission timer is running
    bool initDone = FALSE;
    int8_t defaultNumRetx;
    int8_t numRetx; // keep track the number of retransmission

    command result_t StdControl.init() {
        if (!initDone) {
            TosMsgPtrQueue_init(&queue, buffer, QSEND_QUEUESIZE);
            call Random.init();
            call SubStdControl.init();

            sending = FALSE;
            timerSet = FALSE;
            call RetransmitControl.enableRetransmit();
            initDone = TRUE;
        }
        return SUCCESS;
    }
    command result_t StdControl.start() {
        call SubStdControl.start();
    #ifndef PLATFORM_EMSTAR
        call MacControl.enableAck();
    #endif
        return SUCCESS;
    }
    command result_t StdControl.stop() {
        call SubStdControl.stop();
        return SUCCESS;
    }
    
    command void RetransmitControl.enableRetransmit() {
        defaultNumRetx = QSEND_DEFAULT_NUM_RETX;
        numRetx = defaultNumRetx;
    }
    command void RetransmitControl.disableRetransmit() {
        defaultNumRetx = 0;
        numRetx = 0;
    }
    command void RetransmitControl.setNumRetransmit(int8_t num) {
        if (num >= 0)
            defaultNumRetx = num;
    }
    command int8_t RetransmitControl.getNumRetransmit() {
        return defaultNumRetx;
    }

    void startTimer() {
        uint16_t randomizedTime;
        uint8_t result;

        if ((TosMsgPtrQueue_isEmpty(&queue) == TRUE) ||
            (timerSet == TRUE)) {  // don't set the timer if it is already set
            return;
        }
        timerSet = TRUE;    // Set the timer flag

        // randomizedTime should be more than zero, otherwise timer won't fire
        randomizedTime = QSEND_MINIMUM_RESEND_TIME;
        randomizedTime += ((call Random.rand() + (2*TOS_LOCAL_ADDRESS)) & 0x1f);
        result = call ResendTimer.start(TIMER_ONE_SHOT, randomizedTime);
    }

    task void sendPacket() {
        result_t sendResult = SUCCESS;
        TOS_MsgPtr msgToSend;

        if (TosMsgPtrQueue_isEmpty(&queue) == TRUE)     // nothing to send
            return;
        else if (sending == TRUE || timerSet == TRUE)   // already sending
            return;

        msgToSend = TosMsgPtrQueue_getFirst(&queue);        // getfirst of the queue

        sendResult = call SubSendMsg.send[msgToSend->type](msgToSend->addr, msgToSend->length, msgToSend);
        // if send return success, keep the msg there
        // if fail start a timer, do automatic resend
        if (sendResult == FAIL) {
            startTimer();
        } else {
            sending = TRUE;
        }
    }

    event result_t ResendTimer.fired() {
        timerSet = FALSE;
        post sendPacket();  // what if fail to post?
        return SUCCESS;
    }

    command result_t SendMsg.send[uint8_t typeid](uint16_t address, uint8_t length, TOS_MsgPtr msg) {
        TOS_MsgPtr ptr;
        int i;

        if (TosMsgPtrQueue_isFull(&queue))
            return FAIL;

        for (i = 1; i <= queue.queueSize; i++) {
            ptr = TosMsgPtrQueue_get_ith(&queue, i);
            if (ptr->type == typeid) {  // do not enqueue packet if same AM type
                return FAIL;
            }
        }
        post sendPacket();

        msg->addr = address;
        msg->type = typeid;
        msg->length = length;
        TosMsgPtrQueue_enqueue(&queue, msg); // enqueue the packet

        return SUCCESS; 
    }

    task void sendDoneTask() {
        TOS_MsgPtr msg = TosMsgPtrQueue_getFirst(&queue);
        TOS_MsgPtr voidPtr;

        if (msg->ack == 1) {
            numRetx = 0;
        }
        if (numRetx == 0) {         
            voidPtr = TosMsgPtrQueue_dequeue(&queue);   // remove the message from the queue
            
            sending = FALSE;
            numRetx = defaultNumRetx;   // reset the retransmission count

            // signal up the application about the result
            signal SendMsg.sendDone[msg->type](msg, msg->ack == 1);

            // send next one
            post sendPacket();

        } else if (numRetx > 0){
            startTimer();
            sending = FALSE;
            numRetx--;
        }   
    }

    event result_t SubSendMsg.sendDone[uint8_t typeid](TOS_MsgPtr msg, result_t success) {
        uint8_t error, sendResult;

        // if queue is empty or the message is not mine, discard
        error = (TosMsgPtrQueue_isEmpty(&queue) == TRUE) 
                    || (TosMsgPtrQueue_getFirst(&queue) != msg);

        if (error == 0) {
            sendResult = ((success == SUCCESS) && 
                    (msg->ack == TRUE || msg->addr == TOS_LOCAL_ADDRESS ||
                    msg->addr == TOS_BCAST_ADDR || msg->addr == TOS_UART_ADDR));
            msg->ack = sendResult;
            post sendDoneTask();                
        }           
        return SUCCESS;
    }

    default event result_t SendMsg.sendDone[uint8_t typeid](TOS_MsgPtr msg, uint8_t result) {
        return SUCCESS;
    }
}


