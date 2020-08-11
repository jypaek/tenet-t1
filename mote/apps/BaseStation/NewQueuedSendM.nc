/*									tab:4
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
 * $Revision: 1.4 $
 */

/**
 * @author Phil Buonadonna
 */


/*
 * QueuedSend for Tenet Base Stataion
 * 
 * TinyOS QueuedSend was customized for Tenet base station.
 * It enables CC2420 hardware acks.
 * It signals sendDone for all the AM ID's reserved in AMFiltered with SendMsg
 * It signals sendDone for rest of the types with SendMsgAll
 * Randomized retransmission interval and some cleanup.
 *
 */

/* modified by Jeongyeup */

module NewQueuedSendM {
	provides {
		interface StdControl;
		interface SendMsg[uint8_t typeid];
		interface SendMsg as SendMsgAll[uint8_t typeid];
	}
	uses {
		interface StdControl as SubStdControl;
		interface SendMsg as SubSendMsg[uint8_t typeid];
		interface MacControl;
		interface Timer as ResendTimer;
		interface Random;
		interface Leds;
	}
}
implementation {
#include "TosMsgPtrQueue.h"
#include "AMFiltered.h"

	enum {
		QSEND_QUEUESIZE = 10,
        QSEND_MINIMUM_RESEND_TIME = 5,
        QSEND_DEFAULT_NUM_RETX = 5,
	};

	TOS_MsgPtr buffer[QSEND_QUEUESIZE];

	struct TosMsgPtrQueue queue;

	bool sending;
	bool timerSet;	// this flag shows the retransmission timer is running
	bool initDone = FALSE;

	int8_t defaultNumRetx;
	int8_t numRetx;	// keep track the number of retransmission

	command result_t StdControl.init() {
		if (!initDone) {
			TosMsgPtrQueue_init(&queue, buffer, QSEND_QUEUESIZE);
			call Random.init();
			call SubStdControl.init();
			call Leds.init();

			sending = FALSE;
			timerSet = FALSE;

			defaultNumRetx = QSEND_DEFAULT_NUM_RETX;
			numRetx = defaultNumRetx;
			
			initDone = TRUE;
		}
		return SUCCESS;
	}

	command result_t StdControl.start() {
		call SubStdControl.start();
		call MacControl.enableAck();
		return SUCCESS;
	}

	command result_t StdControl.stop() {
		call SubStdControl.stop();
		return SUCCESS;
	}

	void startTimer() {
		uint16_t randomizedTime;
		uint8_t result;

		if (TosMsgPtrQueue_isEmpty(&queue) == TRUE) {
			return;
		}
		if (timerSet == TRUE) {
			return;			// don't set the timer if it is already set
		}
		timerSet = TRUE;	// Set the timer flag

		// randomizedTime should be more than zero, otherwise timer won't fire
		randomizedTime = QSEND_MINIMUM_RESEND_TIME;
		randomizedTime += (call Random.rand() & 0x2f);
		result = call ResendTimer.start(TIMER_ONE_SHOT, randomizedTime);
	}


	task void sendPacket() {

		result_t sendResult = SUCCESS;
		TOS_MsgPtr msgToSend;

		if (TosMsgPtrQueue_isEmpty(&queue) == TRUE)		// nothing to send
			sendResult = FAIL;
		else if (sending == TRUE || timerSet == TRUE)	// already sending
			sendResult = FAIL;

		if (sendResult == FAIL)
			return;

		msgToSend = TosMsgPtrQueue_getFirst(&queue);		// getfirst of the queue

		sendResult = call SubSendMsg.send[msgToSend->type](msgToSend->addr, msgToSend->length, msgToSend);
		// if send return success, keep the msg there
		// if fail start a timer, do automatic resend
		if (sendResult == FAIL) {
			startTimer();
			sending = FALSE;
		} else {
			sending = TRUE;
		}
	}

	event result_t ResendTimer.fired() {
		timerSet = FALSE;
		post sendPacket();	// what if fail to post?
		return SUCCESS;
	}

	command result_t SendMsg.send[uint8_t typeid](uint16_t address, uint8_t length, TOS_MsgPtr msg) {
		TOS_MsgPtr ptr;
		int i;

		if (TosMsgPtrQueue_isFull(&queue))
			return FAIL;

		for (i = 1; i <= queue.queueSize; i++) {
			ptr = TosMsgPtrQueue_get_ith(&queue, i);
			if (ptr->type == typeid) {
				return FAIL;
			}
		}

		post sendPacket();

		msg->addr = address;
		msg->type = typeid;
		msg->length = length;
		TosMsgPtrQueue_enqueue(&queue, msg);

		return SUCCESS; 
	}
	
	command result_t SendMsgAll.send[uint8_t typeid](uint16_t address, uint8_t length, TOS_MsgPtr msg) {
		return call SendMsg.send[typeid](address, length, msg);
	}

	//task void sendDoneTask() {
	void signal_sendDone(TOS_MsgPtr msg) {
		TOS_MsgPtr voidPtr;

		if (msg->ack == 1) {
			numRetx = 0;
		}		
		if (numRetx == 0) {			
			voidPtr = TosMsgPtrQueue_dequeue(&queue);	// remove the message from the queue
			
			sending = FALSE;
			numRetx = defaultNumRetx;	// reset the retransmission count

			// signal up the application about the result
			if (isFiltered(msg->type))
				signal SendMsg.sendDone[msg->type](msg, (msg->ack == 1));
			else
				signal SendMsgAll.sendDone[msg->type](msg, (msg->ack == 1));

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
		error = ((TosMsgPtrQueue_isEmpty(&queue) == TRUE) 
					|| (TosMsgPtrQueue_getFirst(&queue) != msg));

		if (error == 0) {
			sendResult = ((msg->ack == TRUE) || 
			              (msg->addr == TOS_LOCAL_ADDRESS) ||
			              (msg->addr == TOS_BCAST_ADDR) || 
			              (msg->addr == TOS_UART_ADDR));
			sendResult &= (success == SUCCESS);
			msg->ack = sendResult;
			//post sendDoneTask();				
			signal_sendDone(msg);
		}
		return SUCCESS;
	}

	default event result_t SendMsgAll.sendDone[uint8_t typeid](TOS_MsgPtr msg, uint8_t result) {
		return SUCCESS;
	}
	default event result_t SendMsg.sendDone[uint8_t typeid](TOS_MsgPtr msg, uint8_t result) {
		return SUCCESS;
	}
}

