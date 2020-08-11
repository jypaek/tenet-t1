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
 *
 * Authors:		Jason Hill, David Gay, Philip Levis
 * Date last modified:  6/25/02
 *
 */

/**
 * @author Jason Hill
 * @author David Gay
 * @author Philip Levis
 */


/**
 * RadioCommM
 *
 * AMStandard was broken into two parts: one to handle UART communication
 * and another to handle Radio communication. RadioCommM handles the radio
 * communication.
 * 
 **/

module RadioCommM
{
	provides {
		interface StdControl as Control;
		
		interface SendMsg[uint8_t id];
		interface ReceiveMsg[uint8_t id];
	}
	uses {
		interface StdControl as RadioControl;
		interface BareSendMsg as RadioSend;
		interface ReceiveMsg as RadioReceive;
		interface PowerManagement;
		interface Leds;
	}
}
implementation
{
	bool state;
	TOS_MsgPtr buffer;
	
	// Initialization of this component
	command bool Control.init() {
		state = FALSE;
		call Leds.init();
		return call RadioControl.init();
	}

	// Command to be used for power managment
	command bool Control.start() {
		result_t ok2 = call RadioControl.start();
		state = FALSE;
		call PowerManagement.adjustPower();
		return ok2;
	}

	
	command bool Control.stop() {
		result_t ok2 = call RadioControl.stop();
		call PowerManagement.adjustPower();
		return ok2;
	}

	// Handle the event of the completion of a message transmission
	result_t reportSendDone(TOS_MsgPtr msg, result_t success) {
		state = FALSE;
		signal SendMsg.sendDone[msg->type](msg, success);

		return SUCCESS;
	}

	default event result_t SendMsg.sendDone[uint8_t id](TOS_MsgPtr msg, result_t success) {
		return SUCCESS;
	}

	// This task schedules the transmission of the Active Message
	task void sendTask() {
		TOS_MsgPtr buf;
		buf = buffer;

		if (!call RadioSend.send(buf)) {
			reportSendDone(buffer, FAIL);
		}
	}

	// Command to accept transmission of an Active Message
	command result_t SendMsg.send[uint8_t id](uint16_t addr, uint8_t length, TOS_MsgPtr data) {
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
				data->addr = addr;
				if (data->type == 0)// || (id != 0x77))
					data->type = id;
				if (data->group == 0)
					data->group = TOS_AM_GROUP;
				buffer = data;
			}
			return SUCCESS;
		}
		return FAIL;
	}

	event result_t RadioSend.sendDone(TOS_MsgPtr msg, result_t success) {
		return reportSendDone(msg, success);
	}

	// Handle the event of the reception of an incoming message
	TOS_MsgPtr radio_received(TOS_MsgPtr packet)	__attribute__ ((C, spontaneous)) {
		uint16_t addr = TOS_LOCAL_ADDRESS;

		if ((packet->crc == 1) && (packet->group == TOS_AM_GROUP)
			&& (packet->addr == TOS_BCAST_ADDR || packet->addr == addr)) {

			uint8_t type = packet->type;
			TOS_MsgPtr tmp;

			// dispatch message
			tmp = signal ReceiveMsg.receive[type](packet);
			if (tmp) 
				packet = tmp;
		}
		return packet;
	}

	// default do-nothing message receive handler
	default event TOS_MsgPtr ReceiveMsg.receive[uint8_t id](TOS_MsgPtr msg) {
		return msg;
	}

	event TOS_MsgPtr RadioReceive.receive(TOS_MsgPtr packet) {
		return radio_received(packet);
	}
}

