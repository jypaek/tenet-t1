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
 * RadioComm
 *
 * GenericComm was split into two parts - one for radio and another
 * for UART communication. This component handles radio communication.
 * 
 **/



configuration RadioComm
{
	provides {
		interface StdControl as Control;

		interface SendMsg[uint8_t id];
		interface ReceiveMsg[uint8_t id];
	}
}
implementation
{
	components RadioCommM,
		RadioCRCPacket as RadioPacket, 
		HPLPowerManagementM,
		NoLeds as Leds; 

	Control = RadioCommM.Control;
	SendMsg = RadioCommM.SendMsg;
	ReceiveMsg = RadioCommM.ReceiveMsg;

	RadioCommM.RadioControl -> RadioPacket.Control;
	RadioCommM.RadioSend -> RadioPacket.Send;
	RadioCommM.RadioReceive -> RadioPacket.Receive;
	
	RadioCommM.PowerManagement -> HPLPowerManagementM.PowerManagement;
	RadioCommM.Leds -> Leds;
}

