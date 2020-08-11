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
 * This file maintains all information about all TRD dissemination 
 * activities in the network, at the master.
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
 * Embedded Networks Laboratory, University of Southern California
 * @date Nov/19/2007
 * @author Jeongyeup Paek (jpaek@enl.usc.edu)
 **/

#include <stddef.h>
#include <string.h>
#include "nx.h"
#include "tosmsg.h"
#include "timeval.h"
#include "trd_state.h"
#include "trd_seqno.h"
#include "trd_interface.h"

//#define DEBUG_TRD_STATE
#define DEBUG_TRD_INIT

uint8_t m_state;    // state of the system

TRD_Table m_table;  // summary table
TRD_Memory m_mem;   // packet storage (<-> Flash of a mote)

unsigned char lastpacket[200];
TRD_Metadata lastmeta;  // metadata of the last received trd packet
int m_fast_retx_count;  // fast retransmission count

struct timeval recover_alarm_time;
struct timeval aging_alarm_time;
struct timeval init_alarm_time;
struct timeval bootup_time;
int init_loop_cnt;
int init_done;

MetaList m_recoverlist;
MetaListEntry m_rlistbuf[2*TRD_RECOVER_LIST_SIZE]; //mem space for recoverlist

uint16_t m_seqno = TRD_SEQNO_UNKNOWN;

void read_memory();


/********************************************************/
void recovertimer_init() {
    recover_alarm_time.tv_sec = 0;
    recover_alarm_time.tv_usec = 0;
}
void recovertimer_start(unsigned long int interval_ms) {
    struct timeval curr;
    gettimeofday(&curr, NULL);
    add_ms_to_timeval(&curr, interval_ms, &recover_alarm_time);
}
void recovertimer_stop() {
    recovertimer_init();
}
void recovertimer_fired() {
    read_memory();
}
/********************************************************/
void inittimer_init() {
    init_alarm_time.tv_sec = 0;
    init_alarm_time.tv_usec = 0;
}
void inittimer_start(unsigned long int interval_ms) {
    struct timeval curr;
    gettimeofday(&curr, NULL);
    add_ms_to_timeval(&curr, interval_ms, &init_alarm_time);
}
void inittimer_stop() {
    inittimer_init();
}
void inittimer_fired() {
    inittimer_stop();
    if (m_state == TRD_S_DISCONNECTED) {
        #ifdef DEBUG_TRD_INIT
            printf("TRD not found any neighbor yet.\n");
            printf(" - If this takes too long, reset a neighbor mote or a master transport\n");
        #endif
        inittimer_start(20000); // boot time
        trd_timer_reset(); // reset timer
        if (init_loop_cnt++ >= 2) {
            #ifdef DEBUG_TRD_INIT
                printf("TRD timeout looking for neighbor. Let's try moving on..\n");
            #endif
            m_state = TRD_S_INIT_0;
        }
    } else if (m_state == TRD_S_INIT_0) {
        inittimer_start(4000);
        m_state = TRD_S_INIT;
        trd_timer_reset(); // reset timer
    } else if (m_state == TRD_S_INIT) {
        #ifdef DEBUG_TRD_INIT
            printf("TRD init-process, you may send tasks now.\n");
        #endif
        m_state = TRD_S_INIT_READY;
        inittimer_start(10000); // boot time
    } else if (m_state == TRD_S_INIT_READY) {
        #if defined(DEBUG_TRD_INIT) || defined(DEBUG_TRD_STATE)
            printf("TRD init-timeout, now in ready state.\n");
            trd_table_printCacheEntry(&m_table);
        #endif
        m_state = TRD_S_STEADY;
        init_done = 1;
    } else if (m_state & TRD_S_RX) {
        inittimer_start(1000);
    }
}
/********************************************************/
void agingtimer_init() {
    aging_alarm_time.tv_sec = 0;
    aging_alarm_time.tv_usec = 0;
}
void agingtimer_start(unsigned long int interval_ms) {
    struct timeval curr;
    gettimeofday(&curr, NULL);
    add_ms_to_timeval(&curr, interval_ms, &aging_alarm_time);
}
void agingtimer_stop() {
    agingtimer_init();
}
void agingtimer_fired(unsigned long int time_late_ms) {
    unsigned long int age_unittime = TRD_AGE_UNITTIME*1000/1024;
    agingtimer_start(age_unittime); // aging time
    do {
        trd_table_incrementAge(&m_table);
        if (time_late_ms > age_unittime) // must
            time_late_ms -= age_unittime;
    } while (time_late_ms > age_unittime);
}
/********************************************************/

void trd_state_init() {
    inittimer_init();
    recovertimer_init();
    agingtimer_init();
    gettimeofday(&bootup_time, NULL);

    m_state = TRD_S_DISCONNECTED;

    trd_table_init(&m_table);
    trd_timer_init();
    trd_memory_init(&m_mem);
    metalist_init(&m_recoverlist, m_rlistbuf, TRD_RECOVER_LIST_SIZE);

    //trd_state_printTableEntry();
    inittimer_start(10000);  // boot time
    agingtimer_start(TRD_AGE_UNITTIME*1000/1024); // aging time

    lastmeta.origin = TRD_INVALID_ORIGIN;
    lastmeta.seqno = TRD_SEQNO_UNKNOWN;
    init_loop_cnt = 0;
    init_done = 0;
}

int trd_state_sendReady() {
    //if ((m_state == TRD_S_DISCONNECTED) || // never received anything
    //    (m_state == TRD_S_INIT_0) ||       // not yet at least 4sec after out-of-disconnect
    //    (m_state == TRD_S_INIT))           // not yet 10sec after INIT_0
    if (init_done == 0)
        return 0;
    return 1;
}

uint16_t trd_state_getNextSeqno() {
    uint16_t age;
    uint16_t seqno = trd_table_getLastSeqno(&m_table, TOS_LOCAL_ADDRESS(), &age);
    if (seqno == TRD_SEQNO_UNKNOWN)
        seqno = m_seqno;
    seqno = trd_seqno_next(seqno);
    m_seqno = seqno;
    return seqno;
}

void print_packet_class(trd_class_t msg_class, uint16_t ori, uint16_t seq) {
    if (ori == TOS_LOCAL_ADDRESS())
        return;
    printf("MSG.receive ------------------------ (%d:%d)\n", ori, seq);
    switch (msg_class) {
        case TRD_CLASS_UNKNOWN: // unknown
            printf(" -> UNKNOWN pkt received, strange??????\n"); break;
        case TRD_CLASS_TOO_OLD: // too old... drop
            printf(" -> TOO OLD pkt, drop\n"); break;
        case TRD_CLASS_IN_OLD:  // in the cache, but I already have it
            printf(" -> IN OLD pkt, ignore\n"); break;
        case TRD_CLASS_IN_LAST: // last one in the cache, 
            printf(" -> IN LAST pkt, suppress????\n"); break;
        case TRD_CLASS_NEWER:
            printf(" -> NEWER pkt\n"); break;
        case TRD_CLASS_TOO_NEW:
            printf(" -> TOO NEW pkt\n"); break;
        case TRD_CLASS_NULL:        // ori not found in cache table -> add
            printf(" -> NEW, UNKNOWN pkt, insert\n"); break;
        case TRD_CLASS_NEXT_NEW:    // I was expecting this
            printf(" -> NEXT NEW pkt, insert\n"); break;
        default:
            break;
    }
}

int trd_state_newMsg(TRD_Msg *rmsg) {
    uint16_t origin;
    uint16_t seqno;
    trd_class_t msg_class;
    int len, ok, check_age = 0;
    uint16_t memloc;
    uint16_t age;

    if (rmsg == NULL) {
        printf("null packet error newMsg\n"); return -1;
    }
    if (m_state == TRD_S_DISCONNECTED) {
        #ifdef DEBUG_TRD_INIT
            printf("TRD connected to network, trying to initialize...\n");
        #endif
        m_state = TRD_S_INIT_0; // received on msg
        inittimer_start(4000); // 4 sec guard time
    }

    origin = nxs(rmsg->metadata.origin);
    seqno = nxs(rmsg->metadata.seqno);
    age = nxs(rmsg->metadata.age);
    len = rmsg->length + offsetof(TRD_Msg, data);
    msg_class = trd_table_classify(&m_table, origin, seqno, age);

    #ifdef DEBUG_TRD_STATE
        print_packet_class(msg_class, origin, seqno);
        fflush(stdout);
    #endif

    switch (msg_class) {
        case TRD_CLASS_UNKNOWN: // unknown
        case TRD_CLASS_TOO_OLD: // too old... drop
        case TRD_CLASS_IN_OLD:  // in the cache, but I already have it
            break;
        case TRD_CLASS_IN_LAST: // last one in the cache, 
            // not sure about this yet
            if ((origin == lastmeta.origin) && (lastmeta.origin != TRD_INVALID_ORIGIN) &&
                (seqno == lastmeta.seqno) && (lastmeta.seqno != TRD_SEQNO_UNKNOWN)) {
                if (m_state != TRD_S_FAST_PACKET)
                    trd_timer_suppress();   // suppress retx if received dup of last pkt
            }
            break;
        case TRD_CLASS_NEWER:   // slightly newer, missing packet detected
            trd_timer_reset(); // reset timer
            break;
        case TRD_CLASS_TOO_NEW: // too new to repair the holes.... 
            trd_table_removeNode(&m_table, origin);
            check_age = 1;
            // proceed below (add packet)
        case TRD_CLASS_NULL:        // origin not found in cache table -> add
            if (trd_table_isFull(&m_table)) {
                // origin cannot be TOS_LOCAL_ADDRESS... if it is, then we are in trouble
                trd_table_incrementAge(&m_table);
                break; // give-up this packet
            } // else proceed below (add packet)
            //if ((m_state == TRD_S_STEADY) && (age > TRD_AGE_IGNORE_OLD))
            //    break;
        case TRD_CLASS_NEXT_NEW:    // I was expecting this new packet!!
            memcpy(lastpacket, (uint8_t *)rmsg, len);
            lastmeta.origin = origin;
            lastmeta.seqno = seqno;

            ok = trd_memory_write(&m_mem, &memloc, (uint8_t *)rmsg, len);
            if (ok < 0) {
                printf("Fatal Error, write fail\n");
                return 0;
            }
            trd_table_insert(&m_table, origin, seqno, memloc, age);
            if (origin != TOS_LOCAL_ADDRESS()) // Different from mote-side.
                trd_rebroadcast(len, rmsg); // re-broadcast immediately, once
            trd_timer_reset(); // reset timer
            if (m_state == TRD_S_STEADY) {
                m_state = TRD_S_FAST_PACKET;
                m_fast_retx_count = TRD_FAST_RETX_COUNT;
                #ifdef DEBUG_TRD_STATE
                    printf("   >>>> move to FAST PACKET state >>>\n");
                #endif
            }
            // signal new packet as long as not in INIT
            if ((m_state & TRD_S_INIT) || (check_age)) {
                uint16_t ct_age;
                struct timeval ct;
                gettimeofday(&ct, NULL);
                subtract_timeval(&ct, &bootup_time, &ct);
                ct_age = ((uint16_t)(tv2ms(&ct)/TRD_AGE_UNITTIME)) + 1;
                if ((age < TRD_AGE_IGNORE_OLD) && (ct_age >= age)) {
                    m_state = TRD_S_INIT_READY;
                    if (origin != TOS_LOCAL_ADDRESS())
                        return 1;
                }
            //} else if ((m_state == TRD_S_STEADY) && (age > TRD_AGE_IGNORE_OLD)) {
            //    break;
            } else {
                if (origin != TOS_LOCAL_ADDRESS())
                    return 1;
            }
            break;
        default:
            break;
    }
    return 0;
}

int send_summary(uint8_t ignore_old) {
    uint8_t msg[128];
    TRD_SummaryMsg *smsg = (TRD_SummaryMsg *) msg;
    uint8_t len;

    int result = trd_table_summarize(&m_table, smsg, &len, ignore_old);
    
    if ((m_state == TRD_S_DISCONNECTED) || (m_state & TRD_S_INIT)) {
        // We make the motes reply immeidately.
        smsg->num_entries = -1;
    } else if (!result || (len <= offsetof(TRD_SummaryMsg, metadata))) {
        // no summary to send...
        //if (m_state & TRD_S_INIT)
        //    smsg->num_entries = -1;
    }
    smsg->sender = TOS_LOCAL_ADDRESS();

    trd_send_summary(len, smsg);
    return 1;
}

int send_fast_packet() {
    TRD_Msg *rmsg = (TRD_Msg *) lastpacket;
    int len = rmsg->length + offsetof(TRD_Msg, data);

    trd_rebroadcast(len, rmsg); //REBROADCAST the packet

    if (m_fast_retx_count-- <= 0)
        m_state = TRD_S_STEADY;
    return 1;
}

int trd_timer_fired() {
    if (m_state == TRD_S_FAST_PACKET) {
        send_fast_packet();
    } else if (m_state & TRD_S_RX) {
        m_state &= ~TRD_S_RX;
    } else if (m_state == TRD_S_STEADY) {
        send_summary(1);
    } else if (m_state & TRD_S_INIT) {
        send_summary(1);
    } else if (m_state == TRD_S_DISCONNECTED) {
        send_summary(1);
    }
    trd_timer_processed();
    return 1;
}

void trd_state_summaryReceived(TRD_SummaryMsg *smsg) {
    int i;
    uint16_t reqseqno;
    uint8_t reqbuf[128];
    TRD_RequestMsg *reqmsg = (TRD_RequestMsg *)reqbuf;
    TRD_Metadata *reqmeta;
    uint8_t reqlen = offsetof(TRD_RequestMsg, metadata);
    uint16_t reqaddr;
    uint8_t should_send_summary_immediately = 0;
    uint8_t should_suppress = 0;

    if (smsg == NULL) {
        printf("smsg==NULL, segmentation fault\n"); return;
    }
    if (m_state == TRD_S_DISCONNECTED) {
        #ifdef DEBUG_TRD_INIT
            printf("TRD connected to network, trying to initialize...\n");
        #endif
        m_state = TRD_S_INIT_0;
        inittimer_start(4000); // 4 sec guard time
    }

    reqaddr = smsg->sender;     // no nx conversion for sender, yet
    reqmsg->num_entries = 0;
    reqmsg->sender = TOS_LOCAL_ADDRESS(); // no nx conversion for sender, yet

    if (smsg->num_entries < 0) {
        // this part is different from mote. mote will send summary immediately.
        smsg->num_entries = 0;
        if ((trd_table_numEntries(&m_table) > 0) && (m_state == TRD_S_STEADY))
            send_summary(0);
    } else if ((smsg->num_entries == 0) && 
            (trd_table_numEntries(&m_table) == 0) &&
            (m_state == TRD_S_STEADY)) {
        should_suppress = 1;
    }

    // This method does not do anything about those packets that
    // I have, but the sender of the summary doesn't
    for (i = 0; i < smsg->num_entries; i++) {
        TRD_Metadata *smeta = (TRD_Metadata *)&smsg->metadata[i];
        trd_class_t rclass = trd_table_classify(&m_table, nxs(smeta->origin), nxs(smeta->seqno), nxs(smeta->age));
        uint16_t age;

        switch(rclass) {
            case TRD_CLASS_IN_LAST:
                should_suppress = 1; // should suppress
                break;
            case TRD_CLASS_NEXT_NEW:
            case TRD_CLASS_NEWER:
                // should request for the new packet
                reqseqno = trd_table_getLastSeqno(&m_table, nxs(smeta->origin), &age);
                if ((trd_seqno_cmp(reqseqno, nxs(smeta->seqno)) < 0) &&
                       (reqmsg->num_entries < TRD_REQUEST_ENTRIES)) {
                    int jj = (int)reqmsg->num_entries++;
                    reqmeta = (TRD_Metadata *) &reqmsg->metadata[jj];
                    reqseqno = trd_seqno_next(reqseqno);
                    reqmeta->origin = smeta->origin;    // ntohhton
                    reqmeta->seqno = hxs(reqseqno);     // nx_uint16_t
                }
                break;
            case TRD_CLASS_TOO_NEW: // too new, migth not be able to repair
                // this means that I don't have the latest packets.
                // should request for the new packet, but how many????
                trd_table_removeNode(&m_table, nxs(smeta->origin));
                // giveup whatever I have, and restart this node entry!!
                //break;
            case TRD_CLASS_NULL:    // origin not known
                // if table is full, think about node eviction here!!!!! -jpaek TODO
            case TRD_CLASS_UNKNOWN: // seqno not known
                if (reqmsg->num_entries < TRD_REQUEST_ENTRIES) {
                    int jj = (int)reqmsg->num_entries++;
                    reqmeta = (TRD_Metadata *) &reqmsg->metadata[jj];
                    reqmeta->origin = smeta->origin;        // ntohhton
                    reqmeta->seqno = hxs(TRD_SEQNO_OLDEST); // want to retrieve ALL
                    // to recover ALL, get the oldest. then others will follow
                }
                break;
            case TRD_CLASS_IN_OLD:
            case TRD_CLASS_TOO_OLD: // remember: I am not old, but the summary is old
                // old should have priority over new!!!!!!!!
                should_send_summary_immediately = 1;
                break;
            default:
                break;
            //not in the node_cache.. should insert?
        }
    } // END for()

    if (trd_table_numEntries(&m_table) > smsg->num_entries) {
        if (!trd_table_ignoreSummary(&m_table, smsg))
            should_send_summary_immediately = 1;
    }

    if (reqmsg->num_entries > 0) {
        reqlen += sizeof(TRD_Metadata) * reqmsg->num_entries;

        if (!(m_state & TRD_S_RX)) {
            if (m_state & TRD_S_INIT)
                trd_send_request(reqlen, reqmsg, TOS_BCAST_ADDR);
            else
                trd_send_request(reqlen, reqmsg, reqaddr);

            if ((m_state == TRD_S_STEADY) || (m_state & TRD_S_INIT)) {
                uint32_t wait_time = reqmsg->num_entries * TRD_RX_WAIT_TIME;
                trd_timer_set(wait_time);
                m_state |= TRD_S_RX;
                #ifdef DEBUG_TRD_STATE
                    printf(" -- should req for new pkts! >>>> move to RX state >>>\n");
                #endif
            }
        }
        #ifdef DEBUG_TRD_STATE
        else // RX state
            printf(" -- should req for new pkts! But... already sent request\n");
        #endif

    } else if (should_send_summary_immediately) {
        #ifdef DEBUG_TRD_STATE
            printf(" -- compareSummary => should send summary immediately!\n");
        #endif
        send_summary(1); // diff
        trd_timer_reset();
        trd_timer_processed();
    } else if (should_suppress) {
        trd_timer_suppress();
        //if (m_state == TRD_S_INIT_READY) {
        if ((m_state == TRD_S_INIT_READY) && 
            (trd_table_numEntries(&m_table) > 0)) {
            m_state = TRD_S_STEADY;
            init_done = 1;
            #if defined(DEBUG_TRD_INIT) || defined(DEBUG_TRD_STATE)
                printf("TRD init-complete, now in steady state.\n");
                trd_table_printCacheEntry(&m_table);
                fflush(stdout);
            #endif
            inittimer_stop();// stop init timer
        }
    }
}

void read_memory() {
    MetaListEntry *entry;
    unsigned char* packet = NULL;
    TRD_Msg *rmsg;
    uint16_t memloc;
    int len;
    uint16_t age;

    entry = metalist_getFirst(&m_recoverlist);
    if (entry == NULL) { // == isEmpty(), nothing more to read/recover
        recovertimer_stop();
        return;
    }
        
    if (!trd_table_getMemloc(&m_table, entry->origin, entry->seqno, &memloc)) {
        printf("cannot find memloc!! %d:%d\n", entry->origin, entry->seqno);
        metalist_deleteFirst(&m_recoverlist);
        return;
    }

    packet = trd_memory_read(&m_mem, memloc, &len);
    if (packet == NULL) {
        printf("readMemory error!!\n");
        metalist_deleteFirst(&m_recoverlist);
        return;
    }

    rmsg = (TRD_Msg *) packet;
    len = rmsg->length + offsetof(TRD_Msg, data);
    trd_table_getAge(&m_table, nxs(rmsg->metadata.origin), nxs(rmsg->metadata.seqno), &age);
    rmsg->metadata.age = hxs(age);

    #ifdef DEBUG_TRD_STATE
        printf("=>read done: (size %d, dlen %d) (%d:%d)\n", len, rmsg->length, 
                     nxs(rmsg->metadata.origin), nxs(rmsg->metadata.seqno));
        fflush(stdout);
    #endif

    metalist_deleteFirst(&m_recoverlist);
    
    trd_rebroadcast(len, rmsg);
    
    if (metalist_isEmpty(&m_recoverlist)) {
        if (m_state == TRD_S_TX) {
            m_state = TRD_S_STEADY;
            #ifdef DEBUG_TRD_STATE
                printf("   >>>> move from TX to STEADY state >>>\n");
            #endif
        }
        recovertimer_stop(); // nothing more to read!!
    }
    recovertimer_start(TRD_RETRY_TIME); // read next from mem
}

void trd_state_requestReceived(TRD_RequestMsg *qmsg) {
    int i = 0;

    while (i < qmsg->num_entries) {
        TRD_Metadata *meta;
        uint16_t req_seqno, req_origin;

        meta = (TRD_Metadata *) &qmsg->metadata[i++];
        req_seqno = nxs(meta->seqno);
        req_origin = nxs(meta->origin);

        if (req_seqno == TRD_SEQNO_OLDEST) {
            req_seqno = trd_table_getOldestSeqno(&m_table, req_origin);
            #ifdef DEBUG_TRD_STATE
                printf(" oldest seqno in my table: %d:%d\n", req_origin, req_seqno);
            #endif
        } 
        if ((req_seqno == TRD_SEQNO_UNKNOWN) || (req_seqno > TRD_SEQNO_LAST)) {
            break;
        }

        // PUT all of "req_seqno ~ last_seqno" into the list -jpaek
        while ((!metalist_isFull(&m_recoverlist)) &&
               (trd_table_exist(&m_table, req_origin, req_seqno))) {
            metalist_insert(&m_recoverlist, req_origin, req_seqno);
            #ifdef DEBUG_TRD_STATE
            if (!metalist_isInList(&m_recoverlist, req_origin, req_seqno))
                printf(" --inserting (%d:%d) into recoverlist\n", req_origin, req_seqno);
            #endif
            req_seqno = trd_seqno_next(req_seqno);
        }
    }

    if (m_state == TRD_S_STEADY) {
        if (!metalist_isEmpty(&m_recoverlist)) {
            m_state = TRD_S_TX;
            #ifdef DEBUG_TRD_STATE
                printf("   >>>> move from STEADY to TX state >>>\n");
            #endif
        }
    }
    read_memory();
    recovertimer_start(TRD_RETRY_TIME);
}

void trd_state_printTableEntry() {
    trd_timer_printCacheEntry();
    trd_table_printCacheEntry(&m_table);
}

void polling_trd_state_timer() {
    struct timeval curr;
    gettimeofday(&curr, NULL);

    poll_trickle_timer();

    if (((init_alarm_time.tv_sec > 0) || (init_alarm_time.tv_usec > 0))
            && (compare_timeval(&init_alarm_time, &curr) <= 0)) {
        inittimer_fired();
    }
    if (((recover_alarm_time.tv_sec > 0) || (recover_alarm_time.tv_usec > 0))
            && (compare_timeval(&recover_alarm_time, &curr) <= 0)) {
        recovertimer_fired();
    }
    if (((aging_alarm_time.tv_sec > 0) || (aging_alarm_time.tv_usec > 0))
            && (compare_timeval(&aging_alarm_time, &curr) <= 0)) {
        struct timeval diff;
        unsigned long int diff_ms;
        subtract_timeval(&curr, &aging_alarm_time, &diff);
        diff_ms = tv2ms(&diff);
        agingtimer_fired(diff_ms);
    }
}

