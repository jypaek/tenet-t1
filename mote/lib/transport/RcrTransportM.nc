/*
* "Copyright (c) 2006~2008 University of Southern California.
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
 * RcrTransport: Rate-controlled Reliable Transport protocol.
 *
 * - centralized rate adaptation
 * - end-2-end reliable loss recovery
 * - centralized/end-2-end rate allocation
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified May/23/2008
 **/


#include "rcrtransport.h"
#include "tr_list.h"
#include "tr_seqno.c"
#include "TrLoggerMote.h"

module RcrTransportM {
    provides {
        interface StdControl;
        interface RcrtSend as ConnectionSend;
    }
    uses {
        interface RoutingSend;
        interface RoutingReceive;

        interface StdControl as LoggerControl;
        interface TrPktLogger as PktLogger;

        interface TrPacket;
        interface LocalTime;
        interface LocalTimeInfo;

        interface Timer as RateControlTimer;
        interface Timer as SubTimer;
    #ifdef RCRT_2_CON
        interface Timer as RateControlTimer2;
        interface Timer as SubTimer2;
    #endif
        interface Timer as RetryTimer;

    #ifdef RCRT_DEBUG
        interface SendMsg as DebugSend;
        interface ReceiveMsg as DebugReceive;
    #endif
    }
}

implementation {

    struct rcConnection {
        uint16_t tid;
        uint16_t dstAddr;
        uint16_t lastSentSeqNo;
        uint16_t lastAckedSeqNo;
        uint16_t req_rate;
        uint16_t irate;     // rate 'r_i' inversed (inter-packet interval)
        uint16_t last_feedback_fid;
        uint16_t retryCnt;
        uint16_t rtt;
        uint32_t last_feedback_recvtime;
        int8_t token;
        uint8_t cid;        // connection id
        uint8_t state;
        uint8_t window;
        uint8_t waiting;
    };

#ifdef RCRT_2_CON
    struct rcConnection RConn[2];
    struct eepromData waitBuf[2];
#else
    struct rcConnection RConn[1];
    struct eepromData waitBuf[1];
#endif

    TOS_Msg mybuf;

    uint8_t postPendingFlag;
    bool sending;

    tr_list recoverList;
    tr_listEntry rle[RCRT_RLIST_LEN];

    struct eepromData eepromWriteBuf;
    struct eepromData eepromReadBuf;
    bool writebusy;
    bool readbusy;
    uint8_t eraseid;
    uint8_t eepromState;

    struct pending_sendDone {
        void *msg;
        bool pending;
#ifdef RCRT_2_CON
    } psd[2];
#else
    } psd[1];
#endif

    task void retransmitDataPacket();

    enum {
        RCRT_S_IDLE = 1,
        RCRT_S_SYN_SEND = 2,
        RCRT_S_SYN_ACK_WAIT = 3,
        RCRT_S_ACTIVE = 4,
        RCRT_S_FIN_SEND = 5,
        RCRT_S_FIN_ACK_WAIT = 6,
    };

    enum {
        RCRT_PENDING_SYN = 0x10,
        RCRT_PENDING_FIN = 0x20,
        RCRT_PENDING_TRANSMIT_WAIT = 0x40,
        RCRT_PENDING_RETRANSMIT = 0x80,
        RCRT_PENDING_WRITE_LOGGER = 0x04,
        RCRT_PENDING_READ_LOGGER = 0x08,
        RCRT_PENDING_ERASE_LOGGER = 0x01,
    };

/***************************************************************************/

    void resetConnection(int i) {
        RConn[i].dstAddr = 0;
        RConn[i].tid = 0;
        RConn[i].lastSentSeqNo = 0;
        RConn[i].lastAckedSeqNo = 0;
        RConn[i].state = RCRT_S_IDLE;
        RConn[i].window = RCRT_MAX_WINDOW;
        RConn[i].req_rate = 0;
        RConn[i].last_feedback_recvtime = 0;
        RConn[i].last_feedback_fid = 0;
        RConn[i].rtt = RCRT_FEEDBACK_TIMEOUT;
        RConn[i].retryCnt = 0;
        RConn[i].cid = 0;
        RConn[i].irate = 0; /* '0' rate means the timer is stopped */
        RConn[i].token = 0;
        RConn[i].waiting = 0;
        if (i == 0) {
            call SubTimer.stop();
            call RateControlTimer.stop();
    #ifdef RCRT_2_CON
        } else {
            call SubTimer2.stop();
            call RateControlTimer2.stop();
    #endif
        }
        psd[i].pending = FALSE;
    }

    int isValidConnection(uint16_t tid, uint16_t addr) {
        if ((RConn[0].tid > 0) && (RConn[0].tid == tid) && (RConn[0].dstAddr == addr))
            return 1;
    #ifdef RCRT_2_CON
        if ((RConn[1].tid > 0) && (RConn[1].tid == tid) && (RConn[1].dstAddr == addr))
            return 2;
    #endif
        return -1;    // address does not exist?
    }

    void startRetryTimer(uint8_t flag) {
        if (postPendingFlag == 0)   // This must be checked before setting the flag.
            call RetryTimer.start(TIMER_ONE_SHOT, TR_RETRY_TIME);
        postPendingFlag |= flag;
    }

    void SubTimer_start(int i, uint32_t interval) {
        if (i == 0)
            call SubTimer.start(TIMER_ONE_SHOT, interval);
    #ifdef RCRT_2_CON
        else
            call SubTimer2.start(TIMER_ONE_SHOT, interval);
    #endif
    }

    void RateControlTimer_start(int i, uint32_t interval) {
        if (i == 0)
            call RateControlTimer.start(TIMER_ONE_SHOT, interval);
    #ifdef RCRT_2_CON
        else
            call RateControlTimer2.start(TIMER_ONE_SHOT, interval);
    #endif
    }

/***************************************************************************/

    command result_t StdControl.init() {
        resetConnection(0);
    #ifdef RCRT_2_CON
        resetConnection(1);
    #endif
        tr_list_init(&recoverList, rle, RCRT_RLIST_LEN);
        eepromState = TR_FLASH_INIT;
        writebusy = FALSE;
        readbusy = FALSE;
        postPendingFlag = 0;

        call LoggerControl.init();
        call PktLogger.init();
        return SUCCESS;
    }

    command result_t StdControl.start() {
        call LoggerControl.start();
        return SUCCESS;
    }

    command result_t StdControl.stop() {
        call LoggerControl.stop();
        return SUCCESS;
    }

/***************************************************************************/

    event void PktLogger.initDone(result_t success) {
        eepromState = TR_FLASH_IDLE;
        return;
    }

#if defined(PLATFORM_TELOSB) || defined(PLATFORM_TMOTE)
    event void PktLogger.eraseDone(uint8_t cid, result_t success) {
        eepromState = TR_FLASH_IDLE;
        return;
    }

    task void eraseLogger() {
        if (call PktLogger.erase(eraseid) == SUCCESS) {
            eepromState = TR_FLASH_INIT;
        } else {
            startRetryTimer(RCRT_PENDING_ERASE_LOGGER); // FAIL
        }
    }
#endif

    task void writeLogger() {
        int cid = eepromWriteBuf.cid;
        int i;
        if (cid == RConn[0].cid) i = 0;
    #ifdef RCRT_2_CON
        else if (cid == RConn[1].cid) i = 1;
    #endif
        else return;
        if (writebusy == FALSE) return; // eepromWriteBuf is empty? -> error!
        if (eepromState == TR_FLASH_IDLE) {
            if (call PktLogger.write(i, eepromWriteBuf.seqno, (uint8_t *)&eepromWriteBuf, TR_FLASH_BYTES_PER_PKT)) {
                eepromState = TR_FLASH_BUSY;
                return; // SUCCESS
            }
        }
        startRetryTimer(RCRT_PENDING_WRITE_LOGGER); // FAIL
    }

    event void PktLogger.writeDone(uint8_t* data, uint8_t size, result_t success) {
        int cid = eepromWriteBuf.cid;
        int i;
        eepromState = TR_FLASH_IDLE;
        if (cid == RConn[0].cid) i = 0;
    #ifdef RCRT_2_CON
        else if (cid == RConn[1].cid) i = 1;
    #endif
        else return;
        if (success == SUCCESS) {
            writebusy = FALSE;
            if (psd[i].pending) {
                signal ConnectionSend.sendDone(RConn[i].cid, psd[i].msg, SUCCESS);
                psd[i].pending = FALSE;
            }
        } else {
            post writeLogger();
        }
        return;
    }

    task void readLogger() {
        tr_listEntry* me = tr_list_getFirst(&recoverList);
        uint16_t seqno = me->seqno;
        int i = me->id;
        if (readbusy || tr_list_isEmpty(&recoverList)) return;
        if (tr_seqno_cmp(RConn[i].lastAckedSeqNo, seqno) > 0 || 
            tr_seqno_cmp(RConn[i].lastSentSeqNo, seqno) < 0 ||
            RConn[i].tid == 0) {
            tr_list_deleteFirst(&recoverList);
            post readLogger();
            return;
        }
        if (eepromState == TR_FLASH_IDLE) {
            if (call PktLogger.read(i, seqno, (uint8_t *)&eepromReadBuf) == SUCCESS) {
                eepromState = TR_FLASH_BUSY;
                readbusy = TRUE;
                return; // SUCCESS
            }
        }
        startRetryTimer(RCRT_PENDING_READ_LOGGER); // FAIL
    }

    event void PktLogger.readDone(uint8_t* buffer, uint8_t size, result_t success) {
        eepromState = TR_FLASH_IDLE; // FLASH is idle, but eepromReadBuf is not yet.
        if (success == SUCCESS) {
            tr_list_deleteFirst(&recoverList);
            post retransmitDataPacket();
        } else {
            readbusy = FALSE;
            startRetryTimer(RCRT_PENDING_READ_LOGGER); // FAIL
        }
    }

    uint32_t interval_since_feedback(int i) {
        uint32_t currtime, interval_ms;
        currtime = call LocalTime.read();
        if (RConn[i].last_feedback_recvtime > 0) {
            interval_ms = call LocalTimeInfo.ticksToMs(currtime - RConn[i].last_feedback_recvtime);
            if (interval_ms == 0)       // we use zero as "don't know" value.
                interval_ms = 1;
            if (interval_ms < 120000UL) // something older than 2min... let's discard
                return interval_ms;
            RConn[i].last_feedback_recvtime = 0;    // clear old record.
        }
        return 0;
    }
    
    task void retransmitDataPacket() {
        TransportMsg *tmsg;
        rcrt_msg_t *rmsg;
        uint8_t paylen;
        uint8_t flag = RCRT_FLAG_DATA_RETX;
        int cid = eepromReadBuf.cid;
        int i;
        uint16_t seqdiff;

        if (!readbusy) return; //eepromReadBuf should not be empty!
        if (sending) {
            startRetryTimer(RCRT_PENDING_RETRANSMIT);
            return;
        }

        if (cid == RConn[0].cid) i = 0;
    #ifdef RCRT_2_CON
        else if (cid == RConn[1].cid) i = 1;
    #endif
        else {
            readbusy = FALSE;
            return;
        }

        seqdiff = tr_seqno_diff(RConn[i].lastSentSeqNo, RConn[i].lastAckedSeqNo);

        /* re-check the flag since some time might have passed */
        if (seqdiff > (RConn[i].window/2))
            flag |= RCRT_FLAG_ACK_REQ;
            
        tmsg = (TransportMsg *) call RoutingSend.getPayload(&mybuf, &paylen);
        
        rmsg = (rcrt_msg_t *) tmsg->data;
        rmsg->rate = RConn[i].irate;
        rmsg->interval = interval_since_feedback(i);
        rmsg->fid = RConn[i].last_feedback_fid;

        memcpy(rmsg->data, eepromReadBuf.msg, eepromReadBuf.length);
        paylen = eepromReadBuf.length + offsetof(rcrt_msg_t, data);

        call TrPacket.setHeader(tmsg, RConn[i].tid, eepromReadBuf.seqno, flag, 0);
        // set checksum after setting header and copying payload
        tmsg->checksum = tr_calculate_checksum(tmsg, paylen);

        if (call RoutingSend.send(RConn[i].dstAddr, TR_HDR_LEN + paylen, &mybuf)) {
            sending = TRUE;
            readbusy = FALSE;
        } else {
            startRetryTimer(RCRT_PENDING_RETRANSMIT);
        }
    }

/***************************************************************************/

    task void send_SYN() {
        TransportMsg *tmsg;
        rcrt_msg_t *rmsg;
        uint8_t paylen;
        int i;
        // must find which connection to send SYN
        if (RConn[0].state == RCRT_S_SYN_SEND) i = 0;
    #ifdef RCRT_2_CON
        else if (RConn[1].state == RCRT_S_SYN_SEND) i = 1;
    #endif
        else return;
        if (sending) {
            startRetryTimer(RCRT_PENDING_SYN);
            return;
        }
        tmsg = (TransportMsg *) call RoutingSend.getPayload(&mybuf, &paylen);
        rmsg = (rcrt_msg_t *) tmsg->data;
        rmsg->rate = RConn[i].req_rate;
        rmsg->interval = 0;
        rmsg->fid = 0;
        paylen = offsetof(rcrt_msg_t, data);

        call TrPacket.setHeader(tmsg, RConn[i].tid, 0, RCRT_FLAG_SYN, 0);
        // set checksum after setting header and copying payload
        tmsg->checksum = tr_calculate_checksum(tmsg, paylen);

        if (call RoutingSend.send(RConn[i].dstAddr, TR_HDR_LEN + paylen, &mybuf)) {
            sending = TRUE;
            SubTimer_start(i, RCRT_SYN_TIMEOUT);
            RConn[i].state = RCRT_S_SYN_ACK_WAIT;
        } else { // send failed
            startRetryTimer(RCRT_PENDING_SYN);
        }
    }

    //command uint8_t ConnectionSend.open(uint16_t tid, uint16_t dstAddr) {
    command uint8_t ConnectionSend.open(uint16_t tid, uint16_t dstAddr, uint16_t i_rate) {

        post send_SYN();

        if (RConn[0].state == RCRT_S_IDLE) {
            RConn[0].dstAddr = dstAddr;
            RConn[0].tid = tid;
            RConn[0].state = RCRT_S_SYN_SEND;
            RConn[0].req_rate = i_rate;
            RConn[0].cid = (uint8_t)(tid & 0x00ff);
            return RConn[0].cid;
    #ifdef RCRT_2_CON
        } else if (RConn[1].state == RCRT_S_IDLE) {
            RConn[1].dstAddr = dstAddr;
            RConn[1].tid = tid;
            RConn[1].state = RCRT_S_SYN_SEND;
            RConn[1].req_rate = i_rate;
            RConn[1].cid = (uint8_t)(tid & 0x00ff);
            return RConn[1].cid;
    #endif
        }
        return 0xff;
    }

/***************************************************************************/

    task void send_FIN() {
        TransportMsg *tmsg;
        uint8_t paylen;
        int i;
        // must find which connection to send FIN ACK
        if (RConn[0].state == RCRT_S_FIN_SEND) i = 0;
    #ifdef RCRT_2_CON
        else if (RConn[1].state == RCRT_S_FIN_SEND) i = 1;
    #endif
        else return;
        if (sending) {
            startRetryTimer(RCRT_PENDING_FIN);
            return;
        }
        tmsg = (TransportMsg *) call RoutingSend.getPayload(&mybuf, &paylen);
        call TrPacket.setHeader(tmsg, RConn[i].tid, tr_seqno_next(RConn[i].lastSentSeqNo), RCRT_FLAG_FIN, 0);
        // set checksum after setting header and copying payload
        tmsg->checksum = tr_calculate_checksum(tmsg, 0);

        if (call RoutingSend.send(RConn[i].dstAddr, TR_HDR_LEN, &mybuf)) {
            sending = TRUE;
            SubTimer_start(i, RCRT_FIN_TIMEOUT);
            RConn[i].state = RCRT_S_FIN_ACK_WAIT;
        } else { // send failed
            startRetryTimer(RCRT_PENDING_FIN);
        }
    }

    command result_t ConnectionSend.close(uint8_t cid) {
        int i;
        if (cid == RConn[0].cid) i = 0;
    #ifdef RCRT_2_CON
        else if (cid == RConn[1].cid) i = 1;
    #endif
        else return FAIL;
         
        if (RConn[i].waiting) {
            // cancel RConn[i].waiting send
            RConn[i].waiting = 0;
            signal ConnectionSend.sendDone(RConn[i].cid, psd[i].msg, FAIL);
        }
        
        RConn[i].retryCnt = 0;
        RConn[i].state = RCRT_S_FIN_SEND;
        post send_FIN();
        return SUCCESS;
    }

/***************************************************************************/

    task void transmitWaitingPacket() {
        uint8_t paylen;
        TransportMsg *tmsg = (TransportMsg *) call RoutingSend.getPayload(&mybuf, &paylen);
        rcrt_msg_t *rmsg;
        uint8_t flag = RCRT_FLAG_DATA;
        uint16_t seqdiff;
        int i;

        if ((RConn[0].waiting == 1) && (RConn[0].token > 0)) i = 0;
    #ifdef RCRT_2_CON
        else if ((RConn[1].waiting == 1) && (RConn[1].token > 0)) i = 1;
    #endif
        else return;
        if (sending || writebusy) {
            startRetryTimer(RCRT_PENDING_TRANSMIT_WAIT);
            return;
        }

        seqdiff = tr_seqno_diff(waitBuf[i].seqno, RConn[i].lastAckedSeqNo);

        if (seqdiff > (RConn[i].window/2)) {
            if (seqdiff == (RConn[i].window)) {
                uint32_t timeout = (uint32_t)RConn[i].irate;
                if (timeout < (uint32_t)RConn[i].rtt)
                    timeout = (uint32_t)RConn[i].rtt;
                if (timeout > RCRT_MAX_RTT) timeout = RCRT_MAX_RTT; // max timeout = 20sec
                SubTimer_start(i, 2*timeout);
            }
            else if (seqdiff > RConn[i].window) // window is full.
                return;                         // should not send more until cum.ack recved.
            flag |= RCRT_FLAG_ACK_REQ;
        }

        rmsg = (rcrt_msg_t *) tmsg->data;
        rmsg->rate = RConn[i].irate;
        rmsg->interval = interval_since_feedback(i);
        rmsg->fid = RConn[i].last_feedback_fid;
        
        /* copy packet payload from write-buf */
        memcpy(rmsg->data, waitBuf[i].msg, waitBuf[i].length);
        paylen = waitBuf[i].length + offsetof(rcrt_msg_t, data);
        
        call TrPacket.setHeader(tmsg, RConn[i].tid, waitBuf[i].seqno, flag, 0);
        // set checksum after setting header and copying payload
        tmsg->checksum = tr_calculate_checksum(tmsg, paylen);

        if (call RoutingSend.send(RConn[i].dstAddr, TR_HDR_LEN + paylen, &mybuf)) {
            sending = TRUE;
            RConn[i].waiting = FALSE;
            RConn[i].lastSentSeqNo = waitBuf[i].seqno;// update last sent seqno
            memcpy(&eepromWriteBuf, &waitBuf[i], sizeof(struct eepromData));
            writebusy = TRUE;
            post writeLogger();
            RConn[i].token--;
        } else {
            startRetryTimer(RCRT_PENDING_TRANSMIT_WAIT);
        }
    }
    
    command result_t ConnectionSend.send(uint8_t cid, uint8_t length, void *packet) {
        uint16_t next_seqno;
        int i;
        if (cid == RConn[0].cid) i = 0;
    #ifdef RCRT_2_CON
        else if (cid == RConn[1].cid) i = 1;
    #endif
        else return FAIL;
        if (RConn[i].state != RCRT_S_ACTIVE) return FAIL;
        if (length > RCRT_DATA_LENGTH) return FAIL;
        if (RConn[i].waiting) return FAIL;

        next_seqno = tr_seqno_next(RConn[i].lastSentSeqNo); // set to increased sequence number

        waitBuf[i].length = length;     // length without header
        waitBuf[i].seqno = next_seqno;
        waitBuf[i].cid = cid;
        memcpy(waitBuf[i].msg, packet, length); // copy only the payload
        psd[i].msg = packet;   // for sendDone with original pointer

        RConn[i].waiting = 1;
        if (RConn[i].token > 0) {
            post transmitWaitingPacket();
        }
        return SUCCESS;
    }

/***************************************************************************/

    event result_t RoutingSend.sendDone(uint16_t dstAddr, uint16_t nextHop, TOS_MsgPtr msg, 
                                        void* payload, result_t success) {
        TransportMsg *tmsg = (TransportMsg *) payload;
        int i = isValidConnection(tmsg->tid, dstAddr) - 1;
        
        switch (tmsg->flag) {

            case (RCRT_FLAG_DATA):                     /* DATA packet sent */
            case (RCRT_FLAG_DATA | RCRT_FLAG_ACK_REQ): /* DATA packet (with cmack request) sent */
                if (i >= 0) {
                    if (!writebusy) {
                        signal ConnectionSend.sendDone(RConn[i].cid, psd[i].msg, SUCCESS);
                        psd[i].pending = FALSE;
                        // I should always return SUCCESS... I should look reliable
                    } else {    // signal sendDone after eeprom write done
                        psd[i].pending = TRUE;
                    }
                }
                /* send next waiting packet */
                startRetryTimer(RCRT_PENDING_TRANSMIT_WAIT);
                break;

            case (RCRT_FLAG_DATA_RETX):             /* Retransmission done */
            case (RCRT_FLAG_DATA_RETX | RCRT_FLAG_ACK_REQ):
                /* read next lost packet */
                startRetryTimer(RCRT_PENDING_READ_LOGGER);
                break;

            case (RCRT_FLAG_SYN):    /* SYN sent */
                if ((i >= 0) && (success != SUCCESS)) {  // re-send SYN
                    RConn[i].state = RCRT_S_SYN_SEND;
                    post send_SYN();
                }
                break;

            case (RCRT_FLAG_FIN):    /* FIN sent */
                // Current state should be RCRT_S_FIN_ACK_WAIT
                if ((i >= 0) && (success != SUCCESS)) {  // re-send FIN
                    RConn[i].state = RCRT_S_FIN_SEND;
                    post send_FIN();
                }
                break;

            default :
                break;
        } // End of switch

        sending = FALSE;
        return SUCCESS;
    }

/***************************************************************************/

    void process_feedback_packet(uint8_t *payload, int i) {
        rcrt_feedback_t *fb = (rcrt_feedback_t *) payload;
        uint16_t missingSeq;
        int j;

        /* don't process duplicate feedback */
        if ((uint16_t)(RConn[i].last_feedback_fid - fb->fid) < 10) // same or older than last
            return;

        /* update feedback info */
        RConn[i].last_feedback_recvtime = call LocalTime.read();
        RConn[i].last_feedback_fid = fb->fid;

        /* update RTT info */
        if ((fb->rtt != 0) && (fb->rtt < RCRT_MAX_RTT))
            RConn[i].rtt = fb->rtt;
        
        /* process_rate_control(fb->rate); */
        if (fb->rate != RConn[i].irate) {
            if (fb->rate > RConn[i].irate) {  // slow down now
                RateControlTimer_start(i, fb->rate);
                RConn[i].token--;    // skip one token (compensating for feedback)
            }
            RConn[i].irate = fb->rate; /* rate that I should use */
        }
        
        /* process_cummulative_ack(fb->cack_seqno, fb->nack_len); */
        if ((tr_seqno_cmp(fb->cack_seqno, RConn[i].lastAckedSeqNo) > 0) &&
            (tr_seqno_cmp(fb->cack_seqno, RConn[i].lastSentSeqNo) <= 0)) {
            RConn[i].lastAckedSeqNo = fb->cack_seqno;
            RConn[i].retryCnt = 0;
        } else {
            // cumulative ack out of range!!
        }
        
        /* process_negative_ack(fb->nack_len, fb->nacklist); */
        for (j = 0; j < RCRT_NACK_MLIST_LEN; j++) {
            missingSeq = fb->nacklist[j];

            if (j >= fb->nack_len) break;
            if (tr_list_isFull(&recoverList)) break;
            if ((missingSeq == 0) || (missingSeq > TR_MAX_SEQNO)) break;
            if (tr_seqno_diff(RConn[i].lastSentSeqNo, missingSeq) > TR_VALID_RANGE)
                break;  // NACK seqno is out of valid range

            if (tr_seqno_cmp(RConn[i].lastAckedSeqNo, missingSeq) < 0)
                tr_list_insert(&recoverList, i, missingSeq); /* no need for dup check */
        }

        /* if there is NACK, read flash for retransmition */
        if (fb->nack_len > 0)
            post readLogger();
    }

/***************************************************************************/

    event void RoutingReceive.receive(uint16_t srcAddr, TOS_MsgPtr msg, 
                                            void* payload, uint8_t paylen) {
        TransportMsg *tmsg = (TransportMsg *) payload;
        uint8_t datalen = paylen - offsetof(TransportMsg, data);
        int i = isValidConnection(tmsg->tid, srcAddr) - 1;

        if (paylen < offsetof(TransportMsg, data)) return;
        if (tr_checksum_check(tmsg, datalen) < 0) return;
        if (i < 0) return;

        switch (tmsg->flag) {

            case (RCRT_FLAG_SYN_ACK):        /** SYN ACK received **/
                if (RConn[i].state == RCRT_S_SYN_ACK_WAIT) {
                    if (i == 0)
                        call SubTimer.stop();
                #ifdef RCRT_2_CON
                    else
                        call SubTimer2.stop();
                #endif
                    RConn[i].state = RCRT_S_ACTIVE;
                    RConn[i].lastSentSeqNo = 0;
                    RConn[i].retryCnt = 0;
                    process_feedback_packet(tmsg->data, i);
                    signal ConnectionSend.openDone(RConn[i].cid, RConn[i].tid, srcAddr, SUCCESS);
                }
                break;

            case (RCRT_FLAG_SYN_NACK):       /** SYN NACK received **/
                if (RConn[i].state == RCRT_S_SYN_ACK_WAIT) {
                    if (i == 0)
                        call SubTimer.stop();
                #ifdef RCRT_2_CON
                    else
                        call SubTimer2.stop();
                #endif
                    signal ConnectionSend.openDone(RConn[i].cid, RConn[i].tid, srcAddr, FAIL);
                    resetConnection(i);
                }
                break;
                
            case (RCRT_FLAG_FIN_ACK):        /** FIN ACK received **/
                resetConnection(i);
                tr_list_clearID(&recoverList, i);
                #if defined(PLATFORM_TELOSB)
                    eraseid = i;
                    post eraseLogger();
                #endif
                break;

            case (RCRT_FLAG_FEEDBACK):       /** ACK received **/
                if (RConn[i].state == RCRT_S_FIN_ACK_WAIT) {
                    RConn[i].retryCnt = 0;
                    SubTimer_start(i, RCRT_FIN_TIMEOUT); // reset FIN ACK Timeout
                }
                process_feedback_packet(tmsg->data, i);
                break;
            default:
        }// End of switch
        return;
    }

/***************************************************************************/

    void RateControlTimerFired(int i) {
        if (RConn[i].token < RCRT_MAX_TOKENS)
            RConn[i].token++;
        post transmitWaitingPacket(); // waiting
        RateControlTimer_start(i, RConn[i].irate);
    }
    
    void StateTimerFired(int i) {
        if (RConn[i].state == RCRT_S_SYN_ACK_WAIT) {
            // We were waiting for SYN ACK, but we timed out.
            if (RConn[i].retryCnt++ < RCRT_MAX_NUM_RETX) {
                RConn[i].state = RCRT_S_SYN_SEND;
                post send_SYN();
            } else {
                signal ConnectionSend.openDone(RConn[i].cid, RConn[i].tid, RConn[i].dstAddr, FAIL);
                resetConnection(i); // We must signal BEFORE reseting the connection.
            }
        } else if (RConn[i].state == RCRT_S_FIN_ACK_WAIT) {
            // We were waiting for FIN ACK, but we timed out.
            if (RConn[i].retryCnt++ < RCRT_MAX_NUM_RETX) {
                RConn[i].state = RCRT_S_FIN_SEND;
                post send_FIN();
            } else {
                resetConnection(i);
            #if defined(PLATFORM_TELOSB) || defined(PLATFORM_TMOTE)
                eraseid = i;
                post eraseLogger();
            #endif
            }
        } else if (RConn[i].state == RCRT_S_ACTIVE) {
            if (tr_seqno_diff(RConn[i].lastSentSeqNo, RConn[i].lastAckedSeqNo) >= RConn[i].window) {
                // this means that there were no feedback since I set the timer on.
                // set timer to 2 * max of (rtt, 1/rate).
                uint32_t timeout = (uint32_t)RConn[i].irate;
                if (timeout < (uint32_t)RConn[i].rtt)
                    timeout = (uint32_t)RConn[i].rtt;
                if (timeout > RCRT_MAX_RTT) timeout = RCRT_MAX_RTT;
                SubTimer_start(i, 2*timeout);
                
                // re-insert last un-acked packet to retransmit list
                if (tr_list_isEmpty(&recoverList))
                    tr_list_insert(&recoverList, i, tr_seqno_next(RConn[i].lastAckedSeqNo));
                post readLogger(); //retransmit!!!
            }
        }
    }

    event result_t RateControlTimer.fired() {
        RateControlTimerFired(0);
        return SUCCESS;
    }
    event result_t SubTimer.fired() {
        StateTimerFired(0);
        return SUCCESS;
    }

#ifdef RCRT_2_CON
    event result_t RateControlTimer2.fired() {
        RateControlTimerFired(1);
        return SUCCESS;
    }
    event result_t SubTimer2.fired() {
        StateTimerFired(1);
        return SUCCESS;
    }
#endif

    event result_t RetryTimer.fired() {
        if (postPendingFlag & RCRT_PENDING_WRITE_LOGGER)
            post writeLogger();
        if (postPendingFlag & RCRT_PENDING_TRANSMIT_WAIT)
            post transmitWaitingPacket();
        if (postPendingFlag & RCRT_PENDING_READ_LOGGER)
            post readLogger();
        if (postPendingFlag & RCRT_PENDING_RETRANSMIT)
            post retransmitDataPacket();
        if (postPendingFlag & RCRT_PENDING_SYN)
            post send_SYN();
        if (postPendingFlag & RCRT_PENDING_FIN)
            post send_FIN();
    #if defined(PLATFORM_TELOSB) || defined(PLATFORM_TMOTE)
        if (postPendingFlag & RCRT_PENDING_ERASE_LOGGER)
            post eraseLogger();
    #endif
        postPendingFlag = 0;
        return SUCCESS;
    }

    command uint8_t ConnectionSend.maxPayloadLength() {
        return (uint8_t)(call RoutingSend.maxPayloadLength() - TR_HDR_LEN);
    }

#ifdef RCRT_DEBUG
    event result_t DebugSend.sendDone(TOS_MsgPtr msg, result_t success) {
        return SUCCESS;
    }
    
    TOS_Msg debugmsg;
    task void send_debug_msg() {
        call DebugSend.send(TOS_UART_ADDR, 20, &debugmsg);
    }
        
    event TOS_MsgPtr DebugReceive.receive(TOS_MsgPtr msg) {
        int i = 0;
    #ifdef RCRT_2_CON
        if ((RConn[0].state == RCRT_S_IDLE) && (RConn[1].state != RCRT_S_IDLE)) i = 1;
    #endif
        debugmsg.data[0] = RConn[i].state;
        debugmsg.data[1] = RConn[i].window;
        debugmsg.data[2] = writebusy;
        debugmsg.data[3] = readbusy;
        debugmsg.data[4] = (uint8_t)RConn[i].lastSentSeqNo;
        debugmsg.data[5] = (uint8_t)(RConn[i].lastSentSeqNo>>8);
        debugmsg.data[6] = (uint8_t)RConn[i].lastAckedSeqNo;
        debugmsg.data[7] = (uint8_t)(RConn[i].lastAckedSeqNo>>8);
        debugmsg.data[8] = (uint8_t)RConn[i].req_rate;
        debugmsg.data[9] = (uint8_t)(RConn[i].req_rate>>8);
        debugmsg.data[10] = (uint8_t)RConn[i].irate;
        debugmsg.data[11] = (uint8_t)(RConn[i].irate>>8);
        debugmsg.data[12] = RConn[i].token;
        debugmsg.data[13] = sending;
        debugmsg.data[14] = RConn[i].retryCnt;
        debugmsg.data[15] = eepromState;
        debugmsg.data[16] = (uint8_t)RConn[i].last_feedback_fid;
        debugmsg.data[17] = (uint8_t)(RConn[i].last_feedback_fid>>8);
        debugmsg.data[18] = (uint8_t)(RConn[i].rtt & 0x00ff);
        debugmsg.data[19] = (uint8_t)((RConn[i].rtt>>8) & 0x00ff);
        post send_debug_msg();
        return msg;
    }
#endif
}

