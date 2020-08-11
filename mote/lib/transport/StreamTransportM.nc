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
 * StreamTransport: NACK based end-to-end reliable transport protocol.
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 1/24/2007
 **/


#include "streamtransport.h"
#include "TrLoggerMote.h"
#include "tr_list.h"
#include "tr_seqno.c"
#include "tr_checksum.h"
#include "tr_checksum.c"

module StreamTransportM {
    provides {
        interface StdControl;
        interface ConnectionSend;
    }
    uses {
        interface RoutingSend;
        interface RoutingReceive;

        interface StdControl as LoggerControl;
        interface TrPktLogger as PktLogger;

        interface TrPacket;

        interface Timer as RetryTimer;
        interface Timer as SubTimer;
    #ifdef STR_2_CON
        interface Timer as SubTimer2;
    #endif
    }
}

implementation {

    struct ActiveConnection {
        uint16_t tid;
        uint16_t cid;
        uint16_t passiveEndAddr;
        uint16_t lastSentSeqNo;
        uint8_t state;
        uint8_t finCnt;
    };

    enum {
        STR_PENDING_SYN = 0x10,
        STR_PENDING_FIN = 0x20,
        STR_PENDING_RETRANSMIT = 0x80,
        STR_PENDING_WRITE_LOGGER = 0x04,
        STR_PENDING_READ_LOGGER = 0x08,
        STR_PENDING_ERASE_LOGGER = 0x02,
    };

    enum {
        STR_S_IDLE = 1,
        STR_S_SYN_SEND = 2,
        STR_S_SYN_ACK_WAIT = 3,
        STR_S_ACTIVE = 4,
        STR_S_FIN_SEND = 5,
        STR_S_FIN_ACK_WAIT = 6,
    };

#ifdef STR_2_CON
    struct ActiveConnection AConn[2];
#else
    struct ActiveConnection AConn[1];
#endif

    TOS_Msg myMsgbuf;

    uint8_t postPendingFlag;
    bool sending;

    tr_list recoverList;
    tr_listEntry rle[STR_RLIST_LEN];

    struct eepromData eepromWriteBuf;
    struct eepromData eepromReadBuf;
    bool writebusy;
    bool readbusy;
    uint8_t eraseid;
    uint8_t eepromState;

    struct pending_sendDone {
        void *msg;
        bool pending;
#ifdef STR_2_CON
    } psd[2];
#else
    } psd[1];
#endif

    task void retransmitDataPacket();
    task void readLogger();


    /********************************************************/
    /**  Supple  ******************/
    /********************************************************/

    void resetConnection(int i) {
        AConn[i].passiveEndAddr = 0;
        AConn[i].tid = 0;
        AConn[i].cid = 0;
        AConn[i].lastSentSeqNo = 0;
        AConn[i].finCnt = 0;
        AConn[i].state = STR_S_IDLE;
        AConn[i].cid = 0;
        if (i == 0) {
            call SubTimer.stop();
    #ifdef STR_2_CON
        } else {
            call SubTimer2.stop();
    #endif
        }
        psd[i].pending = FALSE;
    }

    int isValidConnection(uint16_t tid, uint16_t addr) {
        if ((AConn[0].tid > 0) && (AConn[0].tid == tid) && (AConn[0].passiveEndAddr == addr))
            return 1;
    #ifdef STR_2_CON
        if ((AConn[1].tid > 0) && (AConn[1].tid == tid) && (AConn[1].passiveEndAddr == addr))
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
        if (interval < 10) interval = 10;
        if (i == 0)
            call SubTimer.start(TIMER_ONE_SHOT, interval);
    #ifdef STR_2_CON
        else
            call SubTimer2.start(TIMER_ONE_SHOT, interval);
    #endif
    }


    /********************************************************/
    /**  StdControl                     ******************/
    /********************************************************/

    command result_t StdControl.init() {
        resetConnection(0);
    #ifdef STR_2_CON
        resetConnection(1);
    #endif
        tr_list_init(&recoverList, rle, STR_RLIST_LEN);
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

    /********************************************************/
    /**  FLASH init/erase                ********************/
    /********************************************************/

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
            startRetryTimer(STR_PENDING_WRITE_LOGGER); // FAIL
        }
    }
#endif

    /********************************************************/
    /**  Read/Write FLASH                  ******************/
    /********************************************************/

    task void writeLogger() {
        int cid = eepromWriteBuf.cid;
        int i;
        if (cid == AConn[0].cid) i = 0;
    #ifdef STR_2_CON
        else if (cid == AConn[1].cid) i = 1;
    #endif
        else return;
        if (writebusy == FALSE) return; // eepromWriteBuf is empty? -> error!
        if (eepromState == TR_FLASH_IDLE) {
            if (call PktLogger.write(i, eepromWriteBuf.seqno, (uint8_t *)&eepromWriteBuf, sizeof(struct eepromData))) {
                eepromState = TR_FLASH_BUSY;
                return; // SUCCESS
            }
        }
        startRetryTimer(STR_PENDING_WRITE_LOGGER); // FAIL
    }

    event void PktLogger.writeDone(uint8_t* data, uint8_t size, result_t success) {
        int cid = eepromWriteBuf.cid;
        int i;
        eepromState = TR_FLASH_IDLE;
        if (cid == AConn[0].cid) i = 0;
    #ifdef STR_2_CON
        else if (cid == AConn[1].cid) i = 1;
    #endif
        else return;
        if (success == SUCCESS) {
            writebusy = FALSE;
            if (psd[i].pending) { // sendDone should be signalled
                signal ConnectionSend.sendDone(AConn[i].cid, psd[i].msg, SUCCESS);
                // I should always return SUCCESS... I should look reliable
                psd[i].pending = FALSE;
            }
            post readLogger(); // check whether we have anything to read
        } else {
            post writeLogger();// retry writing
        }
        return;
    }

    task void readLogger() {
        tr_listEntry* me = tr_list_getFirst(&recoverList);
        uint16_t seqno = me->seqno;
        int i = me->id;
        if (readbusy || tr_list_isEmpty(&recoverList))
            return;
        if (tr_seqno_cmp(AConn[i].lastSentSeqNo, seqno) < 0 ||
            AConn[i].tid == 0) {
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
        startRetryTimer(STR_PENDING_READ_LOGGER); // FAIL
    }

    event void PktLogger.readDone(uint8_t* buffer, uint8_t size, result_t success) {
        eepromState = TR_FLASH_IDLE; // FLASH is idle, but eepromReadBuf is not yet.
        if (success == SUCCESS) {
            tr_list_deleteFirst(&recoverList);
            post retransmitDataPacket();
        } else {
            readbusy = FALSE;
            startRetryTimer(STR_PENDING_READ_LOGGER); // FAIL
        }
        return;
    }

    /********************************************************/
    /**  OPEN, and send_SYN                ******************/
    /********************************************************/

    task void send_SYN() {
        TransportMsg *tmsg;
        uint8_t paylen;
        int i;
        // must find which connection to send SYN
        if (AConn[0].state == STR_S_SYN_SEND) i = 0;
    #ifdef STR_2_CON
        else if (AConn[1].state == STR_S_SYN_SEND) i = 1;
    #endif
        else return;
        if (sending) {
            startRetryTimer(STR_PENDING_SYN);
            return;
        }
        tmsg = (TransportMsg *) call RoutingSend.getPayload(&myMsgbuf, &paylen);
        call TrPacket.setHeader(tmsg, AConn[i].tid, 0, STR_FLAG_SYN, 0);
        // set checksum after setting header and copying payload
        tmsg->checksum = tr_calculate_checksum(tmsg, 0);

        if (call RoutingSend.send(AConn[i].passiveEndAddr, TR_HDR_LEN, &myMsgbuf)) {
            sending = TRUE;
            SubTimer_start(i, STR_SYN_TIMEOUT);
            AConn[i].state = STR_S_SYN_ACK_WAIT;
        } else { // send failed
            startRetryTimer(STR_PENDING_SYN);
        }
    }

    command uint8_t ConnectionSend.open(uint16_t tid, uint16_t dstAddr) {
        
        post send_SYN();

        if (AConn[0].state == STR_S_IDLE) {
            AConn[0].passiveEndAddr = dstAddr;
            AConn[0].tid = tid;
            AConn[0].state = STR_S_SYN_SEND;
            AConn[0].cid = (uint8_t)(tid & 0x00ff);
            return AConn[0].cid;
    #ifdef STR_2_CON
        } else if (AConn[1].state == STR_S_IDLE) {
            AConn[1].passiveEndAddr = dstAddr;
            AConn[1].tid = tid;
            AConn[1].state = STR_S_SYN_SEND;
            AConn[1].cid = (uint8_t)(tid & 0x00ff);
            return AConn[1].cid;
    #endif
        } else {
            return 0xff;
        }
    }

    /********************************************************/
    /**  send and retransmit               ******************/
    /********************************************************/

    command result_t ConnectionSend.send(uint8_t cid, uint8_t length, void *packet) {
        TransportMsg *tmsg;
        uint8_t paylen;
        int i;
        if (cid == AConn[0].cid) i = 0;
    #ifdef STR_2_CON
        else if (cid == AConn[1].cid) i = 1;
    #endif
        else return FAIL;
        if (AConn[i].state != STR_S_ACTIVE) return FAIL;
        if (length > (call RoutingSend.maxPayloadLength() - TR_HDR_LEN)) return FAIL;
        if (sending || writebusy) return FAIL;

        tmsg = (TransportMsg *) call RoutingSend.getPayload(&myMsgbuf, &paylen);
        memcpy(tmsg->data, packet, length);

        call TrPacket.setHeader(tmsg, AConn[i].tid, tr_seqno_next(AConn[i].lastSentSeqNo), STR_FLAG_DATA, 0);
        // set checksum after setting header and copying payload
        tmsg->checksum = tr_calculate_checksum(tmsg, length);

        // copy packet to eepromWriteBuf so that we can write packet to the flash
        eepromWriteBuf.cid = cid;
        eepromWriteBuf.length = length;                 // length without header
        eepromWriteBuf.seqno = tmsg->seqno;
        memcpy(eepromWriteBuf.msg, tmsg->data, length); // copy only the payload

        psd[i].msg = packet;   // for sendDone with original pointer

        if (call RoutingSend.send(AConn[i].passiveEndAddr, TR_HDR_LEN + length, &myMsgbuf)) {
            sending = TRUE;
            writebusy = TRUE;
            post writeLogger();
            AConn[i].lastSentSeqNo = tmsg->seqno;
            return SUCCESS;
        }
        return FAIL;
    }

    /**
     * Retransmit the packet that have been read from the flash.
     */
    task void retransmitDataPacket() {
        TransportMsg *tmsg;
        uint8_t paylen;
        int cid = eepromReadBuf.cid;
        int i;
        
        if (!readbusy) return; //eepromReadBuf should not be empty!
        if (sending) {
            startRetryTimer(STR_PENDING_RETRANSMIT);
            return;
        }

        if (cid == AConn[0].cid) i = 0;
    #ifdef STR_2_CON
        else if (cid == AConn[1].cid) i = 1;
    #endif
        else {
            readbusy = FALSE;
            return;
        }

        tmsg = (TransportMsg *) call RoutingSend.getPayload(&myMsgbuf, &paylen);

        memcpy(tmsg->data, eepromReadBuf.msg, eepromReadBuf.length);
        myMsgbuf.length = offsetof(TransportMsg, data) + eepromReadBuf.length;

        call TrPacket.setHeader(tmsg, AConn[i].tid, eepromReadBuf.seqno, STR_FLAG_DATA_RETX, 0);
        // set checksum after setting header and copying payload
        tmsg->checksum = tr_calculate_checksum(tmsg, eepromReadBuf.length);

        if (call RoutingSend.send(AConn[i].passiveEndAddr, myMsgbuf.length, &myMsgbuf)) {
            sending = TRUE;
            readbusy = FALSE;
            // Check for more retransmissions to be done, after sendDone event has arrived
        } else {
            startRetryTimer(STR_PENDING_RETRANSMIT);
        }
    }

    void process_NACK_packet(uint16_t *nackinfo, int i) {
        uint16_t missingSeq;
        uint8_t j;

        for (j = 0; j < STR_NACK_MLIST_LEN; j++) {
            // must make sure that STR_NACK_MLIST_LEN is smaller than nackinfo!!
            missingSeq = nackinfo[j];
            if (tr_list_isFull(&recoverList)) break;
            if ((missingSeq == 0) || (missingSeq > TR_MAX_SEQNO)) break;
            if (tr_seqno_diff(AConn[i].lastSentSeqNo, missingSeq) > TR_VALID_RANGE)
                break; // sequence number out of valid range!!

            tr_list_insert(&recoverList, i, missingSeq); /* no need for dup check */
        }
        post readLogger();
    }

    /********************************************************/
    /**  CLOSE and send_FIN             ******************/
    /********************************************************/

    task void send_FIN() {
        TransportMsg *tmsg;
        uint8_t paylen;
        int i;
        // must find which connection to send FIN ACK
        if (AConn[0].state == STR_S_FIN_SEND) i = 0;
    #ifdef STR_2_CON
        else if (AConn[1].state == STR_S_FIN_SEND) i = 1;
    #endif
        else return;
        if (sending) {
            startRetryTimer(STR_PENDING_FIN);
            return;
        }
        tmsg = (TransportMsg *) call RoutingSend.getPayload(&myMsgbuf, &paylen);
        call TrPacket.setHeader(tmsg, AConn[i].tid, tr_seqno_next(AConn[i].lastSentSeqNo), STR_FLAG_FIN, 0);
        // set checksum after setting header and copying payload
        tmsg->checksum = tr_calculate_checksum(tmsg, 0);

        if (call RoutingSend.send(AConn[i].passiveEndAddr, TR_HDR_LEN, &myMsgbuf)) {
            sending = TRUE;
            SubTimer_start(i, STR_FIN_TIMEOUT);
            AConn[i].state = STR_S_FIN_ACK_WAIT;
        } else { // send failed
            startRetryTimer(STR_PENDING_FIN);
        }
    }

    command result_t ConnectionSend.close(uint8_t cid) {
        int i;
        if (cid == AConn[0].cid) i = 0;
    #ifdef STR_2_CON
        else if (cid == AConn[1].cid) i = 1;
    #endif
        else return FAIL;
        AConn[i].state = STR_S_FIN_SEND;
        post send_FIN();
        return SUCCESS;
    }

    /********************************************************/
    /**  SendDone and Receive Events       ******************/
    /********************************************************/

    event result_t RoutingSend.sendDone(uint16_t dstAddr, uint16_t nextHop, TOS_MsgPtr msg, 
                                        void* payload, result_t success) {
        TransportMsg *tmsg = (TransportMsg *) payload;
        int i = isValidConnection(tmsg->tid, dstAddr) - 1;
        
        switch (tmsg->flag) {

            case (STR_FLAG_DATA):       /* DATA packet sent */
                if (i >= 0) {
                    if (!writebusy) {
                        signal ConnectionSend.sendDone(AConn[i].cid, psd[i].msg, SUCCESS);
                        psd[i].pending = FALSE;
                        // I should always return SUCCESS... I should look reliable
                    } else {    // signal sendDone after eeprom write done
                        psd[i].pending = TRUE;
                    }
                }
                break;

            case (STR_FLAG_DATA_RETX):   /* Retransmission done */
                /* read next lost packet */
                startRetryTimer(STR_PENDING_READ_LOGGER);
                break;

            case (STR_FLAG_SYN):    /* SYN sent */
                if ((i >= 0) && (success != SUCCESS)) {  // re-send SYN
                    AConn[i].state = STR_S_SYN_SEND;
                    post send_SYN();
                }
                break;

            case (STR_FLAG_FIN):    /* FIN sent */
                if ((i >= 0) && (success != SUCCESS)) {  // re-send FIN
                    AConn[i].state = STR_S_FIN_SEND;
                    post send_FIN();
                }
                break;

            default : // do nothing...
                break;
        } // End of switch
        sending = FALSE;
        return SUCCESS;
    }

    event void RoutingReceive.receive(uint16_t srcAddr, TOS_MsgPtr msg, 
                                            void* payload, uint8_t paylen) {
        TransportMsg *tmsg = (TransportMsg *) payload;
        int ok = isValidConnection(tmsg->tid, srcAddr);
        uint8_t datalen = paylen - offsetof(TransportMsg, data);
        int i = ok - 1;

        if (paylen < offsetof(TransportMsg, data)) return;
        if (tr_checksum_check(tmsg, datalen) < 0) return;
        if (ok <= 0) return;

        switch (tmsg->flag) {

            case (STR_FLAG_SYN_ACK):        /** SYN ACK received **/
                if (AConn[i].state == STR_S_SYN_ACK_WAIT) {
                    if (i == 0)
                        call SubTimer.stop();
                #ifdef STR_2_CON
                    else
                        call SubTimer2.stop();
                #endif
                    AConn[i].state = STR_S_ACTIVE;
                    AConn[i].lastSentSeqNo = 0;
                    signal ConnectionSend.openDone(AConn[i].cid, AConn[i].tid, srcAddr, SUCCESS);
                }
                break;

            case (STR_FLAG_FIN_ACK):        /** FIN ACK received **/
                resetConnection(i); // If I have received FIN ACK, then I'm completely done.
                tr_list_clearID(&recoverList, i);
            #if defined(PLATFORM_TELOSB)
                eraseid = i;
                post eraseLogger();
            #endif
                break;

            case (STR_FLAG_NACK):       /** NACK received **/
                if (AConn[i].state == STR_S_FIN_ACK_WAIT)
                    SubTimer_start(i, STR_FIN_TIMEOUT); // reset the FIN ACK Timeout
                process_NACK_packet((uint16_t *)tmsg->data, i);
                break;

            default : // do nothing...
                break;
        } // End of switch
        return;
    }

    /********************************************************/
    /**  Timer Events                      ******************/
    /********************************************************/

    void StateTimerFired(int i) {
        if (AConn[i].state == STR_S_SYN_ACK_WAIT) {
            // We were waiting for SYN ACK, but we timed out.
            if (AConn[i].lastSentSeqNo++ < STR_MAX_NUM_RETX) {
                AConn[i].state = STR_S_SYN_SEND;
                post send_SYN();
            } else {
                signal ConnectionSend.openDone(AConn[i].cid, AConn[i].tid, AConn[i].passiveEndAddr, FAIL);
                resetConnection(i); // We must signal BEFORE reseting the connection.
            }
        } else if (AConn[i].state == STR_S_FIN_ACK_WAIT) {
            // need to send the FIN again = "post send_FIN();"
            if (++AConn[i].finCnt < STR_MAX_NUM_RETX) {
                AConn[i].state = STR_S_FIN_SEND;
                post send_FIN();
            } else {
                resetConnection(i);
                tr_list_clearID(&recoverList, i);
            #if defined(PLATFORM_TELOSB) || defined(PLATFORM_TMOTE)
                eraseid = i;
                post eraseLogger();
            #endif
            }
        }
    }
    event result_t SubTimer.fired() {
        StateTimerFired(0);
        return SUCCESS;
    }
#ifdef STR_2_CON
    event result_t SubTimer2.fired() {
        StateTimerFired(1);
        return SUCCESS;
    }
#endif

    event result_t RetryTimer.fired() {
        if (postPendingFlag & STR_PENDING_WRITE_LOGGER)
            post writeLogger();
        if (postPendingFlag & STR_PENDING_READ_LOGGER)
            post readLogger();
        if (postPendingFlag & STR_PENDING_RETRANSMIT)
            post retransmitDataPacket();
        if (postPendingFlag & STR_PENDING_SYN)
            post send_SYN();
        if (postPendingFlag & STR_PENDING_FIN)
            post send_FIN();
    #if defined(PLATFORM_TELOSB) || defined(PLATFORM_TMOTE)
        if (postPendingFlag & STR_PENDING_ERASE_LOGGER)
            post eraseLogger();
    #endif
        postPendingFlag = 0;
        return SUCCESS;
    }

    command uint8_t ConnectionSend.maxPayloadLength() {
        return (uint8_t)(call RoutingSend.maxPayloadLength() - TR_HDR_LEN);
    }

    /********************************************************/
    /**  defaults                         ******************/
    /********************************************************/

    default event void ConnectionSend.sendDone(uint8_t cid, void *data, result_t success) {return;}
    default event void ConnectionSend.openDone(uint8_t cid, uint16_t tid, uint16_t dst, result_t success) {}

}

