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

/**
 * TRD (Tiered Reliable Dissemination) module.
 *
 * TRD is a generic dissemination protocol that reliably delivers
 * packets to all nodes that runs TRD.
 * This module takes care of sending and receiving all TRD related
 * packets via the link-layer (NewQueuedSend/GenericComm).
 * TRD_State module maintains states so that it can decide when and
 * what to disseminated and receive.
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 8/21/2006
 **/


#include "trd.h"
#include "trd_seqno.h"
#include "trd_checksum.h"
#include "trd_seqno.c"
#include "trd_checksum.c"

module TRD_M {
    provides {
        interface TRD;
    #ifdef TRD_SEND_ENABLED
        interface TRD_Send;
    #endif
    }
    uses {
        interface TRD_State;

        interface ReceiveMsg as ReceiveTRD;
        interface ReceiveMsg as ReceiveControl;

        interface SendMsg as SendTRD;
        interface SendMsg as SendControl;
    }
}
implementation {

    TOS_Msg myMsg;
    bool sendBusy = FALSE;
    
#ifdef TRD_SEND_ENABLED
/**
 * Currently, it is customized for Tenet: disseminations are initiated
 * only at the masters, and the motes only receive and forward packets.
 * (This is why TRD_Send interface is undefined to be excluded.)
 **/
    command result_t TRD_Send.send(TOS_MsgPtr msg, uint8_t length) {
        TRD_Msg *rMsg = (TRD_Msg *)msg->data;
        if (length > TOSH_DATA_LENGTH - offsetof(TRD_Msg, data))
            return FAIL;
        if (sendBusy)
            return FAIL;
        rMsg->length = length;
        length += offsetof(TRD_Msg, data);
        rMsg->metadata.origin = TOS_LOCAL_ADDRESS;
        rMsg->metadata.seqno = call TRD_State.getNextSeqno();
        rMsg->metadata.age = 1; // new age
        rMsg->sender = TOS_LOCAL_ADDRESS;
        rMsg->checksum = 0;
        rMsg->checksum = trd_calculate_checksum(rMsg);
        
        if (call SendTRD.send(TOS_BCAST_ADDR, length, msg) == SUCCESS) {
            call TRD_State.newMsg(rMsg);
            sendBusy = TRUE;
        } else
            return FAIL;
        return SUCCESS;
    }

    command void* TRD_Send.getBuffer(TOS_MsgPtr msg, uint8_t *length) {
        TRD_Msg *rMsg;
        *length = TOSH_DATA_LENGTH - offsetof(TRD_Msg, data);
        if (msg == NULL)
            return NULL;
        rMsg = (TRD_Msg *)msg->data;
        return (void *)rMsg->data;  
    }
#endif
    
	/**
	 * Received a TRD_Msg (dissemination packet).
     * If it is a newMsg, signal it to above layer (app).
     **/
    event TOS_MsgPtr ReceiveTRD.receive(TOS_MsgPtr msg) {
        TRD_Msg *rMsg = (TRD_Msg *)msg->data;

        if (msg->length != (offsetof(TRD_Msg, data) + rMsg->length))
            return msg;
        if (trd_checksum_check(rMsg) < 0) // check check sum
            return msg;
            
        // if new message,
        if (call TRD_State.newMsg(rMsg) == TRUE) {
            signal TRD.receive((uint16_t)rMsg->metadata.origin, (uint8_t *)rMsg->data, rMsg->length);
        }
        return msg;
    }

	/**
	 * Received a TRD_ControlMsg (either summary or request).
     **/
    event TOS_MsgPtr ReceiveControl.receive(TOS_MsgPtr msg) {
        TRD_ControlMsg *cmsg = (TRD_ControlMsg *)msg->data;
        
        if (msg->length < offsetof(TRD_ControlMsg, metadata))
            return msg;
        if (trd_control_checksum_check(cmsg) < 0)
            return msg;
            
        if (cmsg->control_type == TRD_CONTROL_SUMMARY)
            call TRD_State.summaryReceived((TRD_SummaryMsg *)cmsg);
        else if (cmsg->control_type == TRD_CONTROL_REQUEST)
            call TRD_State.requestReceived((TRD_RequestMsg *)cmsg);
        return msg;
    }

    event result_t SendTRD.sendDone(TOS_MsgPtr msg, result_t success) {
        sendBusy = FALSE;
    #ifdef TRD_SEND_ENABLED
        if (msg != &myMsg) {
            call TRD_State.printTableEntry();
            return signal TRD_Send.sendDone(msg, success);
        }
    #endif
        return SUCCESS;
    }
    event result_t SendControl.sendDone(TOS_MsgPtr msg, result_t success) {
        sendBusy = FALSE;
        return SUCCESS;
    }

    result_t send_control_msg(TRD_ControlMsg *cmsg, uint8_t len, uint16_t toAddr) {
        if (sendBusy)
            return FAIL;

        cmsg->unused = 0x00;
        cmsg->checksum = 0;
        cmsg->checksum = trd_control_calculate_checksum(cmsg);
        // memcpy must be done after setting all values 
        memcpy(myMsg.data, (uint8_t *)cmsg, len);
        myMsg.length = len;

        if (call SendControl.send(toAddr, myMsg.length, &myMsg) == SUCCESS) {
            sendBusy = TRUE;
            return SUCCESS;
        }
        dbg(DBG_USR1, "radio busy: \n");
        return FAIL;
    }

    event result_t TRD_State.sendSummaryRequest(
                                  TRD_SummaryMsg *smsg, uint8_t len) {
        smsg->control_type = TRD_CONTROL_SUMMARY;
        dbg(DBG_USR1, "sending SUMMARY: \n");
        return send_control_msg((TRD_ControlMsg *)smsg, len, TOS_BCAST_ADDR);
    }

    event result_t TRD_State.sendRequestRequest(
                                TRD_RequestMsg *qmsg, uint8_t len, uint16_t toAddr) {
        qmsg->control_type = TRD_CONTROL_REQUEST;
        dbg(DBG_USR1, "sending REQUEST: \n");
        return send_control_msg((TRD_ControlMsg *)qmsg, len, toAddr);
    }

    event result_t TRD_State.rebroadcastRequest(TRD_Msg *rmsg, uint8_t len) {
        if (sendBusy)
            return FAIL;

        rmsg->sender = TOS_LOCAL_ADDRESS;
        rmsg->checksum = 0;
        rmsg->checksum = trd_calculate_checksum(rmsg);
        memcpy(myMsg.data, (uint8_t *)rmsg, len);
   
        dbg(DBG_USR1, "REBROADCAST: --- (%d:%d)\n", 
                       rmsg->metadata.origin, rmsg->metadata.seqno);
        if (call SendTRD.send(TOS_BCAST_ADDR, len, &myMsg) == SUCCESS) {
            sendBusy = TRUE;
            return SUCCESS;
        }
        dbg(DBG_USR1, "radio busy: \n");
        return FAIL;
    }

#ifdef TRD_SEND_ENABLED
    default event result_t TRD_Send.sendDone(TOS_MsgPtr msg, result_t success) {
        return SUCCESS;
    }
#endif
    default event void TRD.receive(uint16_t sender, uint8_t* payload, uint16_t paylen) { }
}

