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
 * TRD_State module that maintains all information about all TRD
 * dissemination activities in the network.
 *
 * TRD is a generic dissemination protocol that reliably delivers
 * packets to all nodes that runs TRD.
 * TRD_State module maintains states so that it can decide when and
 * what to disseminated and receive.
 *
 * This module decides:
 * - whether a received packet is new or not,
 * - whether it should send out a summary of current table or not,
 * - whether to respond to a recovery request or not,
 * - whether to rebroadcast a dissemination packet or not,
 * - etc.
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 8/21/2006
 **/


#include "trd_nodecache.h"
#include "trd_metalist.c"
#include "trd_table.c"

module TRD_StateM {
    provides {
        interface StdControl;
        interface TRD_State;
    }
    uses {
        interface StdControl as TimerControl;
        interface StdControl as LoggerControl;
        interface TRD_Timer;
        interface TRD_Logger;
#if defined(PLATFORM_TMOTE)
        interface LocalTime<TMilli>;
        interface Timer2<TMilli> as AgingTimer;
#else
        interface Timer as AgingTimer;
        interface LocalTime;
        interface LocalTimeInfo;
#endif
    }
}
implementation {

    uint8_t  m_state;  // TRD state of this node
    TRD_Table m_table; // table which stores the summary of my flash
    
    uint8_t flash_busy;                 // flash busy flag
    uint8_t flash_buf[TOSH_DATA_LENGTH];// buffer for r/w from/to flash
    MetaList m_recoverlist; // list of pkts to recover from flash
    MetaListEntry rlistbuf[TRD_RECOVER_LIST_SIZE]; //mem space for recoverlist
    TRD_Metadata lastmeta;              // last msg received

#ifdef TRD_SEND_ENABLED
    uint16_t m_seqno = TRD_SEQNO_UNKNOWN; // my seqno
#endif

enum {
    TRD_S_INIT        = 0x01, // state after boot up
    TRD_S_INIT_READY  = 0x21, // received at least one new TRD msg
    TRD_S_STEADY      = 0x02, // summary synch'ed with neighbor after INIT_READY
    TRD_S_RX          = 0x04, // waiting for retx pkts that this node has requested for
    TRD_S_TX          = 0x08, // transmitting pkts that others requested to this node
    TRD_S_FAST_PACKET = 0x10, // transmit the msg instead of summary
};

enum {
    FLASH_IDLE = 0x01,
    FLASH_BUSY = 0x02, // flash busy, either reading or writing
    FLASH_INIT = 0x08, // flash not initialized yet
};

    task void readMemory();
    
    command result_t StdControl.init() {
        flash_busy = FLASH_INIT;    // this must come before TRD_Logger.init();
        lastmeta.origin = TRD_INVALID_ORIGIN;
        lastmeta.seqno = TRD_SEQNO_UNKNOWN;
        m_state = TRD_S_INIT;
        metalist_init(&m_recoverlist, rlistbuf, TRD_RECOVER_LIST_SIZE);
        dbg(DBG_USR1, "TRD_State.INIT\n");
        call TimerControl.init();   // init TRD_Timer
        call LoggerControl.init();  // Logger StdControl
        call TRD_Logger.init();     // must init(erase) eeprom, after 'flash_busy=INIT'
        call TRD_Timer.init();      // must be after TimerControl.init();
        return SUCCESS;
    }
    command result_t StdControl.start() {
        call LoggerControl.start();
#if defined(PLATFORM_TMOTE)
        call AgingTimer.startPeriodic(TRD_AGE_UNITTIME);
#else
        call AgingTimer.start(TIMER_REPEAT, TRD_AGE_UNITTIME);
#endif
        trd_table_init(&m_table); // must be after StdControl.init();
        return SUCCESS;
    }
    command result_t StdControl.stop() {
        call TimerControl.stop();
        return SUCCESS;
    }

#ifdef PLATFORM_PC
    void print_packet_class(trd_class_t msg_class, uint16_t ori, uint16_t seq) {
        if (ori == TOS_LOCAL_ADDRESS)
            return;
        switch (msg_class) {
            case TRD_CLASS_UNKNOWN: // unknown
                dbg(DBG_USR1, " -> UNKNOWN pkt received, strange??????\n"); break;
            case TRD_CLASS_TOO_OLD: // too old... drop
                dbg(DBG_USR1, " -> TOO OLD pkt, drop\n"); break;
            case TRD_CLASS_IN_OLD:  // in the cache, but I already have it
                dbg(DBG_USR1, " -> IN OLD pkt, ignore\n"); break;
            case TRD_CLASS_IN_LAST: // last one in the cache, 
                dbg(DBG_USR1, " -> IN LAST pkt, suppress\n"); break;
            case TRD_CLASS_NEWER:
                dbg(DBG_USR1, " -> NEWER pkt\n"); break;
            case TRD_CLASS_TOO_NEW:
                dbg(DBG_USR1, " -> TOO NEW pkt\n"); break;
            case TRD_CLASS_NULL:        // ori not found in cache table -> add
                if (flash_busy == FLASH_BUSY)
                    dbg(DBG_USR1, " -> NEW, UNKNOWN pkt, but FLASH BUSY\n");
                else
                    dbg(DBG_USR1, " -> NEW, UNKNOWN pkt, insert\n");
                break;
            case TRD_CLASS_NEXT_NEW:    // I was expecting this
                if (flash_busy == FLASH_BUSY)
                    dbg(DBG_USR1, " -> NEXT NEW pkt, but FLASH BUSY\n");
                else
                    dbg(DBG_USR1, " -> NEXT NEW pkt, insert\n");
                break;
            default:
        }
    }
#endif

    command bool TRD_State.newMsg(TRD_Msg *rmsg) {
        uint16_t origin = rmsg->metadata.origin;
        uint16_t seqno = rmsg->metadata.seqno;
        uint16_t age = rmsg->metadata.age;
        uint8_t size = rmsg->length + offsetof(TRD_Msg, data);
        uint16_t memloc;
        uint8_t check_age = 0;
        trd_class_t msg_class = trd_table_classify(&m_table, origin, seqno, age);

    #ifdef PLATFORM_PC
        print_packet_class(msg_class, origin, seqno);
    #endif
        if (flash_busy == FLASH_INIT)
            return FALSE;

        switch (msg_class) {
            case TRD_CLASS_IN_LAST: // last one in the cache, 
                if ((origin == lastmeta.origin) && (seqno == lastmeta.seqno))
                    call TRD_Timer.suppress(); // suppress, since recved duplicate
                break;
            case TRD_CLASS_NEWER:   // slightly newer, missing packet detected
                call TRD_Timer.reset();
                break;
            case TRD_CLASS_TOO_NEW: // too new to repair the holes.... 
                // must give up and re-start receiving.... 
                trd_table_removeNode(&m_table, origin);
                check_age = 1;
                // proceed below (add packet)
            case TRD_CLASS_NULL:    // origin not found in cache table -> add
                if (trd_table_isFull(&m_table)) {
                    // origin cannot be TOS_LOCAL_ADDRESS... if it is, then we are in trouble
                    trd_table_incrementAge(&m_table);
                    break; // give-up this packet
                } // else proceed below (add packet)
                //if ((m_state == TRD_S_STEADY) && (age > TRD_AGE_IGNORE_OLD))
                //    break;
            case TRD_CLASS_NEXT_NEW:    // I was expecting this !!
                if (flash_busy != FLASH_IDLE) // flash busy
                    break;  // cannot add into flash

                memcpy(flash_buf, rmsg, size);
                lastmeta.origin = rmsg->metadata.origin;
                lastmeta.seqno = rmsg->metadata.seqno;

                if (call TRD_Logger.write(&memloc, flash_buf, size) == SUCCESS) {
                    flash_busy = FLASH_BUSY;
                    if (trd_table_insert(&m_table, origin, seqno, memloc, age)) {
                        //if (origin != TOS_LOCAL_ADDRESS)
                        //    signal TRD_State.rebroadcastRequest((TRD_Msg *)flash_buf, len);
                        call TRD_Timer.reset(); // new packet .. advertise
                        if (m_state == TRD_S_STEADY) // fast retransmit
                            m_state = TRD_S_FAST_PACKET;

                        if ((m_state & TRD_S_INIT) || (check_age)) {
#if defined(PLATFORM_TMOTE)
                            uint32_t ct = call LocalTime.get();
#else
                            uint32_t ct = call LocalTime.read();    // in ticks
                            ct = call LocalTimeInfo.ticksToMs(ct);  // in milli sec
#endif
                            ct = (ct/(uint32_t)TRD_AGE_UNITTIME) + 1;    // in age-unit
                            if ((age < TRD_AGE_IGNORE_OLD) && (ct >= age)) {
                                m_state = TRD_S_INIT_READY;
                                if (origin != TOS_LOCAL_ADDRESS)
                                    return TRUE;
                            }
                        } else {
                            return TRUE;
                        }
                    }
                }
                break;
            //case TRD_CLASS_UNKNOWN: // unknown
            //case TRD_CLASS_TOO_OLD: // too old... drop
            //case TRD_CLASS_IN_OLD:  // in the cache, but I already have it
            default:
                break;
        }
        return FALSE;
    }
    
    /* Send the summary of my flash to neighbors */
    result_t send_summary(uint8_t ignore_old) {
        uint8_t msg[TOSH_DATA_LENGTH];
        TRD_SummaryMsg *smsg = (TRD_SummaryMsg *) msg;
        uint8_t len;
        uint8_t result = trd_table_summarize(&m_table, smsg, &len, ignore_old);

        if ((result == 0) &&            // Nothing in summary, AND
            (m_state & TRD_S_INIT)) {   // I am not yet in steady state
            //smsg->num_entries = -1; // don't need this anymore
            smsg->num_entries = 0;
        }
        smsg->sender = TOS_LOCAL_ADDRESS;
        return signal TRD_State.sendSummaryRequest(smsg, len);
    }

    event void TRD_Timer.fired() {
        result_t result = SUCCESS;

        if (m_state == TRD_S_FAST_PACKET) {
            TRD_Msg *rmsg = (TRD_Msg *) flash_buf;
            int len = rmsg->length + offsetof(TRD_Msg, data);
            result = signal TRD_State.rebroadcastRequest(rmsg, len);
            if (result == SUCCESS)
                m_state = TRD_S_STEADY;
        } else if (m_state & TRD_S_RX) { // RX is OR'ed only with INIT or STEADY
            m_state &= ~TRD_S_RX;
            dbg(DBG_USR1, "   ====>>>> move out of RX state after timeout >>>\n");
            call TRD_Timer.reset();
        } else if (m_state == TRD_S_STEADY) { // should send summary!!!!
            result = send_summary(1);
        } else if (m_state & TRD_S_INIT) { // should send summary!!!!
            result = send_summary(1);
        } else if (m_state == TRD_S_TX) {  // need to read pkts from flash
            post readMemory();
        }
        if (result == SUCCESS) {
            call TRD_Timer.processed();
        }
    }

    command void TRD_State.summaryReceived(TRD_SummaryMsg *smsg) {
        uint8_t i;
        uint8_t should_send_summary_immediately = FALSE;
        uint8_t should_suppress = FALSE;
        TRD_Metadata *reqmeta;
        uint8_t reqlen = offsetof(TRD_RequestMsg, metadata);
        uint16_t reqseqno;
        uint16_t reqaddr = smsg->sender;
        uint8_t reqbuf[TOSH_DATA_LENGTH];
        TRD_RequestMsg *reqmsg = (TRD_RequestMsg *)reqbuf;
        reqmsg->num_entries = 0;
        reqmsg->sender = TOS_LOCAL_ADDRESS;

        dbg(DBG_USR1, "SUMMARY.receive --- (from %d, num %d)\n", smsg->sender, smsg->num_entries);
        
        if (flash_busy == FLASH_INIT) return;

        if (smsg->num_entries < 0) {
            smsg->num_entries = 0;
            // Only Master will send negative summary.
            send_summary(0);
        } else if ((smsg->num_entries == 0) && 
                (trd_table_numEntries(&m_table) == 0) &&
                (m_state == TRD_S_STEADY)) {
            should_suppress = TRUE;
        }

        // This method does not do anything about those packets that
        // I have, but the sender of the summary doesn't
        for (i = 0; i < smsg->num_entries; i++) {
            TRD_Metadata *meta = &smsg->metadata[i];
            uint16_t s_origin = meta->origin;
            uint16_t s_seqno = meta->seqno;
            trd_class_t rclass = trd_table_classify(&m_table, s_origin, s_seqno, meta->age);
            uint16_t age;

            switch (rclass) {
                case TRD_CLASS_IN_LAST:
                    should_suppress = TRUE; // should suppress
                    break;
                case TRD_CLASS_NEXT_NEW:
                case TRD_CLASS_NEWER:
                    // should request for the new packet
                    reqseqno = trd_table_getLastSeqno(&m_table, s_origin, &age);
                    if ((trd_seqno_cmp(reqseqno, s_seqno) < 0) &&
                           (reqmsg->num_entries < TRD_REQUEST_ENTRIES)) {
                        reqmeta = (TRD_Metadata *) &reqmsg->metadata[reqmsg->num_entries++];
                        reqseqno = trd_seqno_next(reqseqno);
                        reqmeta->origin = s_origin;
                        reqmeta->seqno = reqseqno;
                        reqmeta->age = 0;
                    }
                    break;
                case TRD_CLASS_TOO_NEW: // too new, migth not be able to repair
                    // this means that I don't have the latest packets.
                    // should request for the new packet, but how many????
                    trd_table_removeNode(&m_table, s_origin);
                    // giveup whatever I have, and restart this node entry!!
                    //break;
                case TRD_CLASS_NULL:    // origin not known
                    // if table is full, think about node eviction here!!!!!
                case TRD_CLASS_UNKNOWN: // seqno not known
                    if (reqmsg->num_entries < TRD_REQUEST_ENTRIES) {
                        reqmeta = (TRD_Metadata *) &reqmsg->metadata[reqmsg->num_entries++];
                        reqmeta->origin = s_origin;
                        reqmeta->seqno = TRD_SEQNO_OLDEST; // want to retrieve ALL
                        // to recover ALL, get the oldest. then others will follow
                    }
                    break;
                case TRD_CLASS_IN_OLD:
                case TRD_CLASS_TOO_OLD: // remember: I am not old, but the summary is old
                    // old should have priority over new!!!!!!!!
                    should_send_summary_immediately = TRUE;
                    break;
                default:
                    break;
                //not in the node_cache.. should insert?
            }
        } // END for()

        if (trd_table_numEntries(&m_table) > smsg->num_entries) {
            if (!trd_table_ignoreSummary(&m_table, smsg))
                should_send_summary_immediately = TRUE;
        }

        if (reqmsg->num_entries > 0) {
            reqlen += sizeof(TRD_Metadata) * reqmsg->num_entries;

            if (!(m_state & TRD_S_RX)) {
                if ((signal TRD_State.sendRequestRequest(reqmsg, reqlen, reqaddr) == SUCCESS) && 
                    ((m_state == TRD_S_STEADY) || (m_state & TRD_S_INIT))) {
                    uint32_t wait_time = reqmsg->num_entries * TRD_RX_WAIT_TIME;
                    call TRD_Timer.set(wait_time); // set RX timeout time
                    m_state |= TRD_S_RX; // wait in RX state till all pkts are recovered
                    dbg(DBG_USR1, "   ====>>>> move to RX state >>>\n");
                }
            }
            else // RX state
                dbg(DBG_USR1, "Already sent request\n");
                
        } else if (should_send_summary_immediately) {
            dbg(DBG_USR1, " -- should send summary immediately!\n");
            call TRD_Timer.reset();
            call TRD_Timer.processed();
        } else if (should_suppress) { // my summary is sync'ed up with my neighbor's summary
            call TRD_Timer.suppress();
            if (m_state == TRD_S_INIT_READY) {
                m_state = TRD_S_STEADY;
                dbg(DBG_USR1, "   ====>>>> move to STEADY state >>>\n");
            }
        }
    }

    task void readMemory() {
        MetaListEntry* entry;
        uint16_t memloc;

        if (flash_busy != FLASH_IDLE)   // flash not initialized
            return;
        entry = metalist_getFirst(&m_recoverlist); // get first from recover list
        if (entry == NULL) { // == isEmpty(), nothing more to read/recover
            return;
        }

        if (!trd_table_getMemloc(&m_table, entry->origin, entry->seqno, &memloc)) {
            metalist_deleteFirst(&m_recoverlist);
            return;
        }

        // since we are over-writing flash_buf, we cannot use it for 'lastmeta'
        // packet re-broadcasting.
        if (m_state == TRD_S_FAST_PACKET)
            m_state = TRD_S_STEADY;
        lastmeta.origin = TRD_INVALID_ORIGIN;
        lastmeta.seqno = TRD_SEQNO_UNKNOWN;
        
        if (call TRD_Logger.read(memloc, flash_buf) == SUCCESS) {
            flash_busy = FLASH_BUSY;
        } else {
            post readMemory();
        }
    }

    command void TRD_State.requestReceived(TRD_RequestMsg *qmsg) {
        int i = 0;

        dbg(DBG_USR1, "REQUEST.receive --- (from %d, num %d)\n", qmsg->sender, qmsg->num_entries);

        if (flash_busy == FLASH_INIT) // flash not accessible
            return;

        while (i < qmsg->num_entries) {
            TRD_Metadata *meta = (TRD_Metadata *) &qmsg->metadata[i++];
            uint16_t req_seqno = meta->seqno;
            uint16_t req_origin = meta->origin;

            if (req_seqno == TRD_SEQNO_OLDEST) {
                req_seqno = trd_table_getOldestSeqno(&m_table, req_origin);
            }
            if ((req_seqno == TRD_SEQNO_UNKNOWN) || (req_seqno > TRD_SEQNO_LAST)) {
                break;
            }

            // PUT all of "req_seqno ~ last_seqno" into the list -jpaek
            while ((!metalist_isFull(&m_recoverlist)) &&
                    (trd_table_exist(&m_table, req_origin, req_seqno))) {
                metalist_insert(&m_recoverlist, req_origin, req_seqno);
                dbg(DBG_USR1, " -- inserting (%d:%d) into recover list\n", req_origin, req_seqno);
                req_seqno = trd_seqno_next(req_seqno);
            }
        }

        if (m_state == TRD_S_STEADY) {
            if (!metalist_isEmpty(&m_recoverlist)) {
                m_state = TRD_S_TX;
                dbg(DBG_USR1, "   ====>>>> move from STEADY to TX state >>>\n");
            }
        }
        // even if we are in RX state, proceed to reply to the request from others
        post readMemory();
    }

    event void TRD_Logger.writeDone(uint8_t *data, uint8_t size, result_t success) {
        flash_busy = FLASH_IDLE;
        post readMemory();
    }

    event void TRD_Logger.readDone(uint8_t* buffer, result_t success) {
        TRD_Msg *rmsg = (TRD_Msg *) buffer;
        int len = rmsg->length + offsetof(TRD_Msg, data);
        flash_busy = FLASH_IDLE;

        if (success == SUCCESS) {
            uint16_t req_seqno = rmsg->metadata.seqno;
            uint16_t req_origin = rmsg->metadata.origin;
            uint16_t age;
            trd_table_getAge(&m_table, req_origin, req_seqno, &age);
            rmsg->metadata.age = age;
            if (signal TRD_State.rebroadcastRequest(rmsg, len) == SUCCESS) {
                metalist_deleteFirst(&m_recoverlist);
                if (metalist_isEmpty(&m_recoverlist)) {
                    if (m_state == TRD_S_TX) {
                        m_state = TRD_S_STEADY;
                        dbg(DBG_USR1, "   ====>>>> move from TX to STEADY state >>>\n");
                    }
                } else
                    post readMemory();
            }
        }
    }

#if defined(PLATFORM_TMOTE)
    event void AgingTimer.fired() {
#else
    event result_t AgingTimer.fired() {
#endif
        if (m_state == TRD_S_INIT) {
#if defined(PLATFORM_TMOTE)
            uint32_t ct = call LocalTime.get();
#else
            uint32_t ct = call LocalTime.read();    // in ticks
            ct = call LocalTimeInfo.ticksToMs(ct);  // in milli sec
#endif
            ct = ct/(uint32_t)TRD_AGE_UNITTIME;               // in age-unit
            if (ct > TRD_AGE_IGNORE_OLD) {
                m_state = TRD_S_INIT_READY;
            }
        }
        trd_table_incrementAge(&m_table);
#if !defined(PLATFORM_TMOTE)
        return SUCCESS;
#endif
    }

    command void TRD_State.printTableEntry() {
        #ifdef PLATFORM_PC
            trd_table_printCacheEntry(&m_table);
        #endif
    }

#ifdef TRD_SEND_ENABLED
    command uint16_t TRD_State.getNextSeqno() {
        uint16_t age;
        uint16_t seqno = trd_table_getLastSeqno(&m_table, TOS_LOCAL_ADDRESS, &age);
        if (seqno == TRD_SEQNO_UNKNOWN)
            seqno = m_seqno;
        seqno = trd_seqno_next(seqno);
        m_seqno = seqno;
        return seqno;
    }
#endif

    event void TRD_Logger.initDone(result_t success) { 
        flash_busy = FLASH_IDLE;
        call TimerControl.start(); // start Trickle timer after flash initialization
    }

}


