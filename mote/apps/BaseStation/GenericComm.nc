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
 * Tenet Base Station GenericComm
 *
 * This customized GenericComm provides two receive pathways:
 * 1. Receive AM types reserved in AMFiltered.h through ReceiveMsg
 * 2. Receive all but the reserved AM types through ReceiveMsgRadioAll
 * 
 * This allows us to provide GenericComm like functionality for certain
 * reserved types and TOS-base like functionality for rest of the types.
 *
 **/


/* Modified by Jeongyeup Paek */

configuration GenericComm
{
	provides {
		interface StdControl as Control;

		interface SendMsg[uint8_t id];

		interface ReceiveMsg[uint8_t id];	// for specific AM types
		interface ReceiveMsg as ReceiveMsgRadioAll[uint8_t id];	
		// for all AM types, excluding specific ones
	}
}
implementation
{
	components RadioComm, UARTForwardComm, AMFiltered;

	Control = RadioComm.Control;
	Control = UARTForwardComm.Control;

	SendMsg = AMFiltered.SendMsg;
	ReceiveMsg = AMFiltered.ReceiveMsg;
	ReceiveMsgRadioAll = AMFiltered.ReceiveMsgRadioAll;

	AMFiltered.RadioSendMsg -> RadioComm.SendMsg;
	AMFiltered.UARTSendMsg -> UARTForwardComm.SendMsg;

	AMFiltered.RadioReceiveMsg -> RadioComm.ReceiveMsg;
	AMFiltered.UARTReceiveMsg -> UARTForwardComm.ReceiveMsg;

}

