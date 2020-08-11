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
 * TCMP: Tenet Control Message Protocol for Ping and Trace-route
 *
 * This is used for debugging purposes, and can be en/dis-abled at compile time
 * using definition of 'INCLUDE_TCMP'.
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 1/24/2007
 **/

#include "transport.h"

module TCMPM {
    provides {
        interface StdControl;
    }
    uses {
        interface RoutingSend;
        interface RoutingReceive;
        interface RoutingTable;
    #ifdef PLATFORM_PC // avoid infinite loop in TOSSIM
        interface Timer;
        interface Random;
    #endif
    }
}

implementation {

    enum {
        TCMP_FLAG_PING = 0x10,
        TCMP_FLAG_PING_ACK = 0x18,

        TCMP_FLAG_TRACERT = 0x20,
        TCMP_FLAG_TRACERT_ACK = 0x28,
    };

    bool sendbusy;
    TOS_MsgPtr aMsg;
    TOS_Msg msgBuf;

    command result_t StdControl.init() {
        aMsg = NULL;
        sendbusy = FALSE;
    #ifdef PLATFORM_PC // avoid infinite loop in TOSSIM
        call Random.init();
    #endif
        return SUCCESS;
    }

    command result_t StdControl.start() {
        return SUCCESS;
    }
    command result_t StdControl.stop() {
        return SUCCESS;
    }

    event result_t RoutingSend.sendDone(uint16_t dstAddr, uint16_t nextHop, 
                                        TOS_MsgPtr msg, void* payload, result_t success) {
        if (msg == aMsg) {        
            aMsg = NULL;
            sendbusy = FALSE;
        }
        return SUCCESS;
    }

    task void send_PING_ACK() {
        TransportMsg *tMsg;
        uint8_t paylen;

        if (aMsg == NULL) return;
        if (sendbusy) return;

        tMsg = (TransportMsg *) call RoutingSend.getPayload(aMsg, &paylen);
        if (tMsg->flag == TCMP_FLAG_PING_ACK) {
            if (call RoutingSend.send(aMsg->addr, TR_HDR_LEN + sizeof(uint16_t), aMsg)) {
                sendbusy = TRUE;
            } else {
                #ifdef PLATFORM_PC // avoid infinite loop in TOSSIM
                    uint16_t retryTime = call Random.rand() % 100;
                    call Timer.start(TIMER_ONE_SHOT, retryTime);
                #else
                    post send_PING_ACK();
                #endif
            }
        }
    }

    task void send_TRACERT_ACK() {
        TransportMsg *tMsg;
        uint8_t paylen;

        if (aMsg == NULL) return;
        if (sendbusy) return;

        tMsg = (TransportMsg *) call RoutingSend.getPayload(aMsg, &paylen);
        if (tMsg->flag == TCMP_FLAG_TRACERT_ACK) {
            if (call RoutingSend.send(aMsg->addr, TR_HDR_LEN + sizeof(uint16_t), aMsg)) {
                sendbusy = TRUE;
            } else {
                #ifdef PLATFORM_PC // avoid infinite loop in TOSSIM
                    uint16_t retryTime = call Random.rand() % 100;
                    call Timer.start(TIMER_ONE_SHOT, retryTime);
                #else
                    post send_TRACERT_ACK();
                #endif
            }
        }
    }

    event void RoutingReceive.receive(uint16_t srcAddr, TOS_MsgPtr msg,
                                            void* payload, uint8_t payloadLen) {
        TransportMsg *header = (TransportMsg *) payload;
        TransportMsg *tMsg;
        uint16_t parent;
        uint8_t paylen;

        if (payloadLen < offsetof(TransportMsg, data)) return;
        dbg(DBG_USR1, "  [TCMP] receive: srdAddr=%d, flag=%#x\n", srcAddr, header->flag);
        if (aMsg != NULL) return;
        if (sendbusy) return;

        switch (header->flag) {

            case (TCMP_FLAG_PING):
                dbg(DBG_USR1, " -->  Ping pkt received\n");
                aMsg = &msgBuf;
                tMsg = (TransportMsg *) call RoutingSend.getPayload(aMsg, &paylen);
                tMsg->flag = TCMP_FLAG_PING_ACK;
                tMsg->tid = header->tid;
                tMsg->seqno = header->seqno;
                parent = call RoutingTable.getParent();
                memcpy(tMsg->data, &parent, sizeof(uint16_t));
                aMsg->addr = srcAddr;
                post send_PING_ACK();
                break;

            case (TCMP_FLAG_TRACERT):
                dbg(DBG_USR1, " -->  Trace-Route pkt received\n");
                aMsg = &msgBuf;
                tMsg = (TransportMsg *) call RoutingSend.getPayload(aMsg, &paylen);
                tMsg->flag = TCMP_FLAG_TRACERT_ACK;
                tMsg->tid = header->tid;
                tMsg->seqno = header->seqno;
                parent = call RoutingTable.getParent();
                memcpy(tMsg->data, &parent, sizeof(uint16_t));
                aMsg->addr = srcAddr;
                post send_TRACERT_ACK();
                break;

            default:
                break;
        }// End of switch
        return;
    }

#ifdef PLATFORM_PC // avoid infinite loop in TOSSIM
    event result_t Timer.fired() {
        uint8_t paylen;
        TransportMsg *tMsg;
        if (aMsg != NULL) {
            tMsg = (TransportMsg *) call RoutingSend.getPayload(aMsg, &paylen);
            if (tMsg->flag == TCMP_FLAG_PING_ACK)
                post send_PING_ACK();
            if (tMsg->flag == TCMP_FLAG_TRACERT_ACK)
                post send_TRACERT_ACK();
        }
        return SUCCESS;
    }
#endif

}

