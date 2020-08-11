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
 * PacketTransport: Simple end-to-end ACK based Reliable Transport Protocol.
 *
 * A fixed number of end-to-end retransmissions will be performed based on
 * end-to-end acknowledgement. No windowing, and hence a bit slow.
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 2/6/2006
 **/


#include "packettransport.h"
#include "tr_checksum.h"
#include "tr_checksum.c"

module PacketTransportM {
    provides {
        interface StdControl;
        interface TransportSend as Send;
        interface PacketTransportReceive as Receive;
        interface TransportSend as NoAckSend;
    }
    uses {
        interface RoutingSend;
        interface RoutingReceive;
        interface RoutingTable;

        interface TrPacket;
#ifdef EMSTAR_NO_KERNEL
        interface EmTimerI as RetryTimer;
        interface EmTimerI as SubTimer;
#else
        interface Timer as RetryTimer;
        interface Timer as SubTimer;
#endif
    }
}

implementation {

    struct PTRConnection {
        uint16_t tid;
        uint16_t otherEndAddr;
        uint16_t seqno;
        void *msgPtr;  // This is to report back the 'sendDone' event.
        // Since we are signaling 'sendDone' after the 'End-to-End' ACK is received,
        // we cannot signal with the TOS_MsgPtr of the received ACK, but we should
        // use the original 'sent' msg pointer.
        uint8_t length;
        uint8_t retxCount;
        uint8_t state;
        uint32_t timer;
    };

    struct PTRConnection PList[PTR_NUM_ONESHOT];
    TOS_Msg mybuf;
    uint16_t mySeqNo;
    uint8_t postPendingFlag;
    bool sending;
    bool timerRunning;
    
    enum {
        PTR_S_IDLE = 21,
        PTR_S_SEND = 22,
        PTR_S_ACK_WAIT = 23,
        PTR_S_RECV = 24,
        PTR_S_ACK_SENT = 25,
        PTR_S_RETX = 26
    };
    enum {
        PTR_PENDING_ACK = 0x04,
        PTR_PENDING_RETX = 0x02,
    };

    void ConnTimer_start(uint8_t cid, uint32_t interval);

    void resetPTRConnection(uint8_t cid) {
        PList[cid].tid = 0;
        PList[cid].state = PTR_S_IDLE;
        PList[cid].msgPtr = NULL;
        PList[cid].timer = 0;
    }

    uint8_t find_cid_from_oneshot_tid(uint16_t tid, uint16_t addr, uint16_t seqno) {
        int i;
        for (i = 0; i < PTR_NUM_ONESHOT; i++) {
            if ((PList[i].tid > 0) && (PList[i].tid == tid) 
                    && ((PList[i].seqno == seqno) || (seqno == 0))
                    // if seqno==0, ignore seqno while searching
                    && (PList[i].otherEndAddr == addr)) {
                return i;
            }
        }
        return 0xff;    // address does not exist?
    }

    uint8_t find_available_oneshot_cid() {
        int i;
        for (i = 0; i < PTR_NUM_ONESHOT; i++) {
            if (PList[i].tid == 0)   return i;
        }
        return 0xff;
    }


    command result_t StdControl.init() {
        int i;
        for (i = 0; i < PTR_NUM_ONESHOT; i++) {
            resetPTRConnection(i);
        }
        postPendingFlag = 0;
        mySeqNo = 1;
        sending = FALSE;
        timerRunning = FALSE;
        return SUCCESS;
    }
    command result_t StdControl.start() { return SUCCESS; }
    command result_t StdControl.stop() { return SUCCESS; }

    void startRetryTimer(uint8_t flag) {
        if (postPendingFlag == 0)   // This must be checked before setting the flag.
            call RetryTimer.start(TIMER_ONE_SHOT, TR_RETRY_TIME);
        postPendingFlag |= flag;
    }


    task void send_ACK() {
        TransportMsg *tmsg;
        uint8_t cid; // must find which connection to send ack to.
        uint8_t length;

        if (sending) {
            startRetryTimer(PTR_PENDING_ACK);
            return;
        }
        for (cid = 0; cid < PTR_NUM_ONESHOT; cid++) {
            if (PList[cid].state == PTR_S_RECV) break;
        }
        if (cid == PTR_NUM_ONESHOT) return;

        tmsg = (TransportMsg *) call RoutingSend.getPayload(&mybuf, &length);
        call TrPacket.setHeader(tmsg, PList[cid].tid, PList[cid].seqno, PTR_FLAG_ACK, 0);
        // set checksum after setting header and copying payload
        tmsg->checksum = tr_calculate_checksum(tmsg, 0);

        if (call RoutingSend.send(PList[cid].otherEndAddr, offsetof(TransportMsg, data), &mybuf) == SUCCESS) {
            dbg(DBG_USR1, "[PTR] send_ACK: to %d (cid=%d, tid=%d, seq=%d)\n",
                        PList[cid].otherEndAddr, cid, tmsg->tid, tmsg->seqno);
            sending = TRUE;
            PList[cid].state = PTR_S_ACK_SENT;
        } else {  // send failed
            startRetryTimer(PTR_PENDING_ACK);
        }
    }


    command result_t Send.send(uint16_t tid, uint16_t dstAddr, 
                               uint8_t length, void *packet) {
        TransportMsg *tmsg;
        uint8_t cid, paylen;

        if ((length > (call RoutingSend.maxPayloadLength() - TR_HDR_LEN)) || // if msg too long, or
            (sending) ||                                                  // sending busy, or
            (find_cid_from_oneshot_tid(tid, dstAddr, 0) != 0xff)) {       // pending transmission exists
            return FAIL;
        }
        if ((cid = find_available_oneshot_cid()) == 0xff)
            return FAIL;
        
        tmsg = (TransportMsg*) call RoutingSend.getPayload(&mybuf, &paylen);
        
        /* I really didn't want to do this memcpy, 
           but something is altering the pointer somehow. 
           It is a bug, and a quick hack is to isolate it.
           Good thing about this is that app can do whatever with that buffer now */
        memcpy(tmsg->data, packet, length);

        PList[cid].tid          = tid;
        PList[cid].otherEndAddr = dstAddr;
        PList[cid].msgPtr       = packet;
        PList[cid].length       = length;
        PList[cid].seqno        = mySeqNo++; if (mySeqNo == 0) mySeqNo = 1;
        PList[cid].retxCount    = 0;

        call TrPacket.setHeader(tmsg, PList[cid].tid, PList[cid].seqno, PTR_FLAG_SEND, 0);
        // set checksum after setting header and copying payload
        tmsg->checksum = tr_calculate_checksum(tmsg, length);

        if (call RoutingSend.send(dstAddr, length + TR_HDR_LEN, &mybuf) != SUCCESS) {
            // If the immediate 'send' fails, return immediately w/o maintaining state.
            dbg(DBG_USR1, "[PTR] send FAILED: tid=%d, seqno=%d, flag=%d\n", 
                                tmsg->tid, tmsg->seqno, tmsg->flag);
            resetPTRConnection(cid);
            return FAIL;
        }
        dbg(DBG_USR1, "[PTR] send: tid=%d, seqno=%d, flag=%d\n", 
                            tmsg->tid, tmsg->seqno, tmsg->flag);
        sending = TRUE;
        ConnTimer_start(cid, PTR_ACK_TIMEOUT 
                                + (call RoutingTable.getDepth()*9)
                                + ((TOS_LOCAL_ADDRESS % 10)*2));
        PList[cid].state = PTR_S_ACK_WAIT;
        return SUCCESS;
    }

    task void retx_send() {
        void *org_data;
        TransportMsg *tmsg;
        uint8_t length, paylen;
        uint8_t cid;

        if (sending) {
            startRetryTimer(PTR_PENDING_RETX);
            return;
        }
        for (cid = 0; cid < PTR_NUM_ONESHOT; cid++) {
            if (PList[cid].state == PTR_S_RETX)
                break;
        }
        if (cid == PTR_NUM_ONESHOT) return;

        org_data = PList[cid].msgPtr;
        length = PList[cid].length;
        PList[cid].retxCount++;

        tmsg = (TransportMsg*) call RoutingSend.getPayload(&mybuf, &paylen);
        call TrPacket.setHeader(tmsg, PList[cid].tid, PList[cid].seqno, PTR_FLAG_SEND, 0);
        memcpy(tmsg->data, org_data, length);
        // set checksum after setting header and copying payload
        tmsg->checksum = tr_calculate_checksum(tmsg, length);

        if (call RoutingSend.send(PList[cid].otherEndAddr, length + TR_HDR_LEN, &mybuf) == SUCCESS) {
            dbg(DBG_USR1, "[PTR] send (retx): tid=%d, seqno=%d, flag=%d\n", 
                             tmsg->tid, tmsg->seqno, tmsg->flag);
            sending = TRUE;
            ConnTimer_start(cid, PTR_ACK_TIMEOUT 
                                    + (call RoutingTable.getDepth()*9)
                                    + ((TOS_LOCAL_ADDRESS % 10)*2));
            PList[cid].state = PTR_S_ACK_WAIT;
        } else {
            startRetryTimer(PTR_PENDING_RETX);
        }
    }


    event result_t RoutingSend.sendDone(uint16_t dstAddr, uint16_t nextHop, TOS_MsgPtr msg, 
                                        void* payload, result_t success) {
        TransportMsg *tmsg = (TransportMsg *) payload;
        uint16_t seqno = tmsg->seqno;
        uint16_t tid = tmsg->tid;
        uint8_t flag = tmsg->flag;
        uint8_t cid = find_cid_from_oneshot_tid(tid, dstAddr, seqno);

        if (!sending) return SUCCESS;

        switch (flag) {

            case (PTR_FLAG_SEND):   /* packet sent */
                if (cid == 0xff) {
                    dbg(DBG_USR1, "[PTR] Couldn't find what I've sent \n");
                } else if (success != SUCCESS) {
                    if (PList[cid].retxCount < PTR_MAX_NUM_RETX)  {
                        post retx_send();
                        PList[cid].state = PTR_S_RETX;
                        PList[cid].timer = 0;
                    } else {
                        signal Send.sendDone(tid, PList[cid].msgPtr, FAIL);
                        resetPTRConnection(cid);    // Clear state!!!!!!!!
                    }
                }
                // Do nothing if sent successfully.
                break;

            case (PTR_FLAG_ACK):    // ACK sent
                if (cid == 0xff) {
                    dbg(DBG_USR1, "[PTR] Couldn't find what ACK I sent\n");
                } else if (success != SUCCESS) {
                    PList[cid].state = PTR_S_RECV;
                } else { // ACK is sent... we're done. forget about it now.
                    resetPTRConnection(cid);
                }
                post send_ACK();    // send the next ONESHOT_ACK, if pending.
                break;

            case (PTR_FLAG_NOACK_SEND): // Null Transport pkt 
                signal NoAckSend.sendDone(tid, payload, success);
                //break;

            default :
                // do nothing...
                break;
        } // End of switch
        sending = FALSE;
        return SUCCESS;
    }


    event void RoutingReceive.receive(uint16_t srcAddr, TOS_MsgPtr msg,
                                      void* payload, uint8_t datalen) {
        TransportMsg *tmsg = (TransportMsg *) payload;
        uint8_t cid;
        uint16_t tid = tmsg->tid;
        uint16_t seqno = tmsg->seqno;
        uint8_t flag = tmsg->flag;

        if (datalen < offsetof(TransportMsg, data)) return;
        datalen = datalen - offsetof(TransportMsg, data); // subtract TransportMsg header size
            
        if (tr_checksum_check(tmsg, datalen) < 0) {
            dbg(DBG_USR1, "[PTR] checksum error\n");
            return;
        }
        
        dbg(DBG_USR1, "[PTR] receive: srdAddr=%d, flag=%#x\n", srcAddr, flag);

        switch (flag) {

            case (PTR_FLAG_SEND):   // PTR data packet received
                cid = find_available_oneshot_cid();
                if (cid == 0xff) {
                    dbg(DBG_USR1, "[PTR] ACK reply queue full\n");
                    return;
                }
                PList[cid].tid          = tid;
                PList[cid].otherEndAddr = srcAddr;
                PList[cid].seqno        = seqno;
                PList[cid].msgPtr       = msg;
                PList[cid].retxCount    = 0;
                PList[cid].state        = PTR_S_RECV;
                dbg(DBG_USR1, " -->  PTR data pkt received\n");
                post send_ACK();
                signal Receive.receive(tid, srcAddr, tmsg->data, datalen);
                break;

            case (PTR_FLAG_ACK):    // PTR ACK received
                cid = find_cid_from_oneshot_tid(tid, srcAddr, seqno);
                if (cid < PTR_NUM_ONESHOT) {
                    dbg(DBG_USR1, " -->  PTR ACK received\n");
                    signal Send.sendDone(PList[cid].tid, PList[cid].msgPtr, SUCCESS);
                    resetPTRConnection(cid); // Clear state after signalling!!
                }
                break;

            default:
                dbg(DBG_USR1, "[PTR] receive: Packet with Unidentified flag\n");
        }// End of switch
        return;
    }

    void ConnTimer_fired(uint8_t cid) {
        if (PList[cid].state != PTR_S_ACK_WAIT)  // wat not waiting for ACK
            return;
        if (PList[cid].retxCount < PTR_MAX_NUM_RETX) {
            post retx_send();
            PList[cid].state = PTR_S_RETX;     // End-2-End retransmission triggered
        } else {                                    // give up!
            signal Send.sendDone(PList[cid].tid, PList[cid].msgPtr, FAIL);
            resetPTRConnection(cid);
            sending = FALSE;
        }
    }

    event result_t RetryTimer.fired() {
        if (postPendingFlag & PTR_PENDING_ACK)
            post send_ACK();
        if (postPendingFlag & PTR_PENDING_RETX)
            post retx_send();
        postPendingFlag = 0;
        return SUCCESS;
    }

    command result_t NoAckSend.send(uint16_t tid, uint16_t addr, 
                                    uint8_t length, void *data) {
        TransportMsg *tmsg;
        uint8_t paylen;
        
        if (length > (call RoutingSend.maxPayloadLength() - TR_HDR_LEN))
            return FAIL;
        if (sending)
            return FAIL;
        tmsg = (TransportMsg*) call RoutingSend.getPayload(&mybuf, &paylen);

        call TrPacket.setHeader(tmsg, tid, mySeqNo++, PTR_FLAG_NOACK_SEND, 0);
        memcpy(tmsg->data, data, length);
        // set checksum after setting header and copying payload
        tmsg->checksum = tr_calculate_checksum(tmsg, length);

        if (mySeqNo == 0) mySeqNo = 1;

        if (call RoutingSend.send(addr, length + TR_HDR_LEN, &mybuf) != SUCCESS) {
            return FAIL;
        }
	sending = TRUE;
        
        return SUCCESS;
    }

    command uint8_t Send.maxPayloadLength() {
        return (call RoutingSend.maxPayloadLength() - TR_HDR_LEN);
    }
    command uint8_t NoAckSend.maxPayloadLength() {
        return (call RoutingSend.maxPayloadLength() - TR_HDR_LEN);
    }

    void ConnTimer_start(uint8_t cid, uint32_t interval) {
        // assume valid cid
        PList[cid].timer = interval;
        if (timerRunning == FALSE) {
            timerRunning = TRUE;
            call SubTimer.start(TIMER_ONE_SHOT, CONNECTION_TIMER_INTERVAL);
        }
    }


    event result_t SubTimer.fired() {
        uint8_t i;
        timerRunning = FALSE;
        for (i = 0; i < PTR_NUM_ONESHOT; i++) {
            if (PList[i].timer > 0) {
                if (PList[i].timer <= CONNECTION_TIMER_INTERVAL) {
                    PList[i].timer = 0;
                    ConnTimer_fired(i);
                } else {
                    PList[i].timer -= CONNECTION_TIMER_INTERVAL;
                    timerRunning = TRUE;
                }
            }
        }
        if (timerRunning)
            call SubTimer.start(TIMER_ONE_SHOT, CONNECTION_TIMER_INTERVAL);
        return SUCCESS;
    }

    default event void Send.sendDone(uint16_t tid, void *data, result_t succ) { }
    default event void NoAckSend.sendDone(uint16_t tid, void *data, result_t succ) { }
    default event void Receive.receive(uint16_t tid, uint16_t src, void *data, uint8_t len) { }
}

