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
 * Based on UARTComm
 *  No address or type filtering on reception
 *  msg->addr is not used while sending
 **/

configuration UARTForwardComm
{
    provides {
        interface StdControl as Control;

        // The interface are as parameterised by the active message id
        interface SendMsg[uint8_t id];
        interface SendMsg as SendMsgAll[uint8_t id];
        interface ReceiveMsg[uint8_t id];
        interface ReceiveMsg as ReceiveMsgAll[uint8_t id];
    }
}
implementation
{
    components UARTForwardM, 
        UARTFramedPacket as UARTPacket,
        NoLeds as Leds;

    Control = UARTForwardM.Control;
    SendMsg = UARTForwardM.SendMsg;
    SendMsgAll = UARTForwardM.SendMsgAll;
    ReceiveMsg = UARTForwardM.ReceiveMsg;
    ReceiveMsgAll = UARTForwardM.ReceiveMsgAll;

    UARTForwardM.UARTControl -> UARTPacket.Control;
    UARTForwardM.UARTSend -> UARTPacket.Send;
    UARTForwardM.UARTReceive -> UARTPacket.Receive;

    UARTForwardM.Leds -> Leds;
}

