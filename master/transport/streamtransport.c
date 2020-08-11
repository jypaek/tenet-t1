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
 * Master side code for StreamTransport.
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 2/5/2007
 **/

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <stddef.h>
#include "tosmsg.h"
#include "transport.h"
#include "routinglayer.h"
#include "streamtransport.h"
#include "sortedpacketlist.h"
#include "connectionlist.h"
#include "uint16list.h"
#include "tr_checksum.h"
#include "tr_packet.h"
#include "tr_seqno.h"
#include "timeval.h"


//#define LOG_STR_PACKET

//#define DEBUG_STR1  // enable debugging messages.
//#define DEBUG_STR2    // enable debugging messages.
//#define DEBUG_NACK    // enable debugging messages.
//#define DEBUG_D_QUEUE
// undefine this to disable debugging messages.


struct strclist {  // stream transport passive connection list
    connectionlist_t c;

    struct uint16list missingList;
    uint8_t state;
    uint8_t deletePending;
    int timeoutCount;
    uint16_t nextExpectedSeqNo;
    struct SortedPacketList plist;
};

/* Global variable */
struct strclist *m_strcs = NULL; // stream transport passive connection list
FILE *m_str_log_fptr = NULL;


enum { // state for each connection
    STR_C_S_PASSIVE = 1,
    STR_C_S_NACK_WAIT = 2,
    STR_C_S_FIN_NACK_WAIT = 3,
    STR_C_S_FINISHED = 4,
};


connectionlist_t *create_str_connection(uint16_t tid, uint16_t srcAddr, uint16_t seqno);
void delete_str_connection(connectionlist_t *c);
int STR_Timer_start(connectionlist_t *c, unsigned long int interval_ms);
void STR_Timer_stop(connectionlist_t *c);


void log_str_packet(connectionlist_t *c, uint16_t seqno, int retx) {
    struct strclist *cs = (struct strclist *)c;
    uint32_t time_ms;
    struct timeval curr;
    gettimeofday(&curr, NULL);
    time_ms = tv2ms(&curr);

    if (m_str_log_fptr == NULL)
        m_str_log_fptr = fopen("log_strt.out", "w");

#ifdef __CYGWIN__
    fprintf(m_str_log_fptr, "%lu ", time_ms);
#else
    fprintf(m_str_log_fptr, "%u ", time_ms);
#endif
    fprintf(m_str_log_fptr, "%d %d %d %d %d %.3f %.3f %.3f %d %d\n", 
                    c->tid, c->addr, seqno,
                    retx, 
                    c->lastRecvSeqNo,
                    c->goodput.Rcumm, 
                    c->pktrate.Ravg, 
                    c->loss_ali.Lavg,
                    cs->missingList.length,
                    cs->plist.length
                    );
    fflush(m_str_log_fptr);
}

/********************************************************/
/**  ACK ACK NACK.......               ******************/
/********************************************************/

void s_send_SYN_ACK(connectionlist_t *c) {
    int len = offsetof(TransportMsg, data);
    unsigned char *packet = (unsigned char *) malloc(len);
    TransportMsg *tmsg = (TransportMsg *) packet;

    tr_packet_setHeader(tmsg, c->tid, 0, STR_FLAG_SYN_ACK, 0);
    // set checksum after setting header and copying payload
    tmsg->checksum = tr_calculate_checksum(tmsg, 0);
    
    #ifdef DEBUG_STR2
        printf("[STR] send_SYN_ACK: to %d (tid=%d) \n", c->addr, c->tid);
    #endif
    write_routing_msg(packet, len, PROTOCOL_STREAM_TRANSPORT, c->addr, RT_DEFAULT_TTL);
    free((void *) packet);
}

void _s_send_FIN_ACK(uint16_t tid, uint16_t addr, uint16_t seqno) {
    int len = offsetof(TransportMsg, data);
    unsigned char *packet = (unsigned char *) malloc(len);
    TransportMsg *tmsg = (TransportMsg *) packet;

    tr_packet_setHeader(tmsg, tid, seqno, STR_FLAG_FIN_ACK, 0);
    // set checksum after setting header and copying payload
    tmsg->checksum = tr_calculate_checksum(tmsg, 0);

    #ifdef DEBUG_STR2
        printf("[STR] send_FIN_ACK: to %d (tid=%d)\n", addr, tid);
    #endif
    write_routing_msg(packet, len, PROTOCOL_STREAM_TRANSPORT, addr, RT_DEFAULT_TTL);
    free((void *) packet);
}

void s_send_FIN_ACK(connectionlist_t *c) {
    _s_send_FIN_ACK(c->tid, c->addr, c->lastRecvSeqNo);
}

int send_NACK(connectionlist_t *c) {
    struct strclist *cs = (struct strclist *)c;
    int paylen = STR_NACK_MLIST_LEN * sizeof(uint16_t);
    int len = paylen + offsetof(TransportMsg, data);
    unsigned char *packet;
    unsigned char *payload;
    TransportMsg *tmsg;
    int i = 0;
    uint16_t mitem, voidSeq;
    
    if (u16list_isEmpty(&cs->missingList))
        return 0;

    packet = (unsigned char *) malloc(len);
    tmsg = (TransportMsg *) packet; 
    payload = tr_packet_getPayload(tmsg);
    
    #ifdef DEBUG_NACK
        printf("[STR] send_NACK: to %d, tid=%d, lastSeq=%d, #missing=%d, ",
                     c->addr, c->tid, c->lastRecvSeqNo, u16list_getLength(&cs->missingList));
        printf("[NACK]: ");
    #endif
    for (i = 0; i < STR_NACK_MLIST_LEN; i++) {
        if (i < cs->missingList.length) {
            mitem = (uint16_t)u16list_get_ith(&cs->missingList, i+1);
            if (tr_seqno_cmp(c->lastRecvSeqNo, tr_seqno_add(mitem, TR_VALID_RANGE)) >= 0) {
                voidSeq = u16list_delete(&cs->missingList, mitem);
                i--;
                continue;
            }
            #ifdef DEBUG_NACK
                printf("%d ", mitem);
            #endif
            memcpy(&payload[i*sizeof(uint16_t)], &mitem, sizeof(uint16_t)); 
        } else {
            payload[2*i] = 0;
            payload[2*i + 1] = 0;
        }       
    }
    #ifdef DEBUG_NACK
        printf("\n");
    #endif

    tr_packet_setHeader(tmsg, c->tid, c->lastRecvSeqNo, STR_FLAG_NACK, 0);
    // set checksum after setting header and copying payload
    tmsg->checksum = tr_calculate_checksum(tmsg, paylen);

    write_routing_msg(packet, len, PROTOCOL_STREAM_TRANSPORT, c->addr, RT_DEFAULT_TTL);

    free((void *)packet);   // free NACK packet
    return 1;
}


int detectMissingPacket(uint16_t seqno, connectionlist_t *c) {
    struct strclist *cs = (struct strclist *)c;
    int detect = 0;
    uint16_t lastSeqNo = c->lastRecvSeqNo;

    if (tr_seqno_cmp(seqno, tr_seqno_next(lastSeqNo)) > 0) {
        #ifdef DEBUG_NACK
            printf("[STR] Missing pkt detected, node %d, recv_seqno %d, last %d: ", 
                          c->addr, seqno, lastSeqNo);
        #endif
        do {
            lastSeqNo = tr_seqno_next(lastSeqNo);
            #ifdef DEBUG_NACK
                printf(" %d", lastSeqNo);
            #endif
            u16list_insert(&cs->missingList, lastSeqNo);
            c->totalLostPackets++;
            detect++;
        } while (tr_seqno_cmp(seqno, tr_seqno_next(lastSeqNo)) > 0);

        #ifdef DEBUG_NACK
            printf(" (total lost till now %lu, while getting %lu)\n", 
                    c->totalLostPackets, c->totalRecvPackets);
        #endif
        fflush(stdout);
    }
    return detect;
}


/***************************************************************/
/* Received packets at the PASSIVE end of a stream connection **/
/***************************************************************/

void receive_str_msg(connectionlist_t *c, uint16_t seqno, int len, unsigned char *msg) {
    struct strclist *cs = (struct strclist *)c;
    unsigned char *packet = (unsigned char *) malloc(len);
    unsigned char *ptr;
    uint16_t tid = c->tid;
    uint16_t srcAddr = c->addr;

    memcpy(packet, msg, len);   // copy so that we can put it in the queue
    cs->timeoutCount = 0;

    #ifdef DEBUG_D_QUEUE
        printf("-->receive_str_msg: len=%d, tid=%d, srcAddr=%d, seq=%d\n",
                   len, tid, srcAddr, seqno);
    #endif

    // we will put it in the sorted list here................
    if (tr_seqno_cmp(seqno, cs->nextExpectedSeqNo) == 0) {
        receive_streamtransport(tid, srcAddr, len, packet);
        cs->nextExpectedSeqNo = tr_seqno_next(cs->nextExpectedSeqNo);

        free((void *)packet);
        // we must not return here... we must go to the 'while' loop!!
    } else if (tr_seqno_cmp(seqno, cs->nextExpectedSeqNo) < 0) {
        #ifdef DEBUG_D_QUEUE
            printf("[STR] unexpected seqno from %d(tid %d): recv %d, expect %d, drop\n",
                          srcAddr, tid, seqno, cs->nextExpectedSeqNo);
        #endif
        free((void *)packet);
    } else { // cannot dispatch yet since out-of-order (or missing) packets exist
        if (SPList_find(&cs->plist, seqno) < 0) {
            SPList_insert(&cs->plist, seqno, packet, len);
            #ifdef DEBUG_D_QUEUE
                printf("  ->inserting: seqno %d (tid %d, addr %d)(len %d)\n",seqno, tid, srcAddr, cs->plist.length);
            #endif
        } else {
            free((void *)packet);
        }
    }
    while (1) {
        int first, seq;
        first = SPList_getFirstValue(&cs->plist);    // seqno of head of queue
        if (first == -1) {
            break;
        } else if (tr_seqno_cmp(first, cs->nextExpectedSeqNo) == 0) { // next pkt to dispatch
            ptr = SPList_deleteFirstPacket(&cs->plist, &seq, &len);
            #ifdef DEBUG_D_QUEUE
                printf("  ->deleting: seqno %d (tid %d, addr %d)\n", first, tid, srcAddr);
            #endif
            receive_streamtransport(tid, srcAddr, len, ptr);

            cs->nextExpectedSeqNo = tr_seqno_next(cs->nextExpectedSeqNo);
            free((void *) ptr);
        } else if (tr_seqno_cmp(first, cs->nextExpectedSeqNo) < 0) { // something in the past
            ptr = SPList_deleteFirstPacket(&cs->plist, &seq, &len);
            #ifdef DEBUG_D_QUEUE
                printf("  ->dropping: seqno %d (tid %d, addr %d)\n", first, tid, srcAddr);
            #endif
            free((void *) ptr);
        } else if (tr_seqno_cmp(seqno, first) <= 0) {
            break;
        } else if (tr_seqno_cmp(seqno, tr_seqno_add(first, TR_VALID_RANGE)) >= 0) {
            ptr = SPList_deleteFirstPacket(&cs->plist, &seq, &len);
            #ifdef DEBUG_D_QUEUE
                printf("  ->forced deleting: seqno %d, last %d (tid %d, addr %d)\n", first, seqno, tid, srcAddr);
            #endif
            receive_streamtransport(tid, srcAddr, len, ptr);
            cs->nextExpectedSeqNo = tr_seqno_next(first);
            free((void *) ptr);
        } else {
            break;
        }
    }
}

void streamtransport_receive(int len, unsigned char *packet, uint16_t srcAddr) {
    // 'packet' is in TransportMsg format, without any routing or TOS tmsg.
    // 'len' is the size of the whole packet.
    TransportMsg *tmsg = (TransportMsg *) packet;
    connectionlist_t *c;
    struct strclist *cs;
    uint16_t voidSeq, seqno, tid;
    uint8_t flag;
    int missingCnt = 0;
    int newpkt = 0;

    fflush(stdout);
    if (packet == NULL) {
        printf("STR: null packet: ");
        return;
    }
    len =  len - (offsetof(TransportMsg, data));
    if (len < 0) {
        printf("STR: invalid length: ");
        return;
    }
    
    if (tr_checksum_check(tmsg, len) < 0) {
        printf("STR: invalid checksum (%X): ", tr_calculate_checksum(tmsg, len));
        fdump_packet(stdout, packet, len);
        return;
    }

    seqno = tr_packet_getSeqno(tmsg);
    tid = tr_packet_getTid(tmsg);
    flag = tr_packet_getFlag(tmsg);

    c = find_connection((connectionlist_t **)&m_strcs, tid, srcAddr);
    cs = (struct strclist *)c;
    
    switch (flag) {

        case (STR_FLAG_SYN):            /** SYN received **/
            if (c == NULL) {
                #ifdef DEBUG_STR2
                    printf("[STR] SYN received from node %d\n", srcAddr);
                #endif
                c = create_str_connection(tid, srcAddr, seqno);
                if (c == NULL)
                    return;
            } else { // not NULL
                #ifdef DEBUG_STR2
                    printf("[STR] Duplicate SYN received...\n");
                #endif
            }
            s_send_SYN_ACK(c);
            STR_Timer_start(c, STR_CONNECTION_TIMEOUT);
            break;

        case (STR_FLAG_FIN):            /** FIN received **/
            #ifdef DEBUG_STR1
                printf("[STR] FIN rcved from node %d, tid %d.", srcAddr, tid);
            #endif
            
            if (c == NULL) {
                _s_send_FIN_ACK(tid, srcAddr, seqno);
                return;
            }

            if (tr_seqno_cmp(seqno, c->lastRecvSeqNo) > 0) {
                missingCnt = detectMissingPacket(seqno, c);  // detect additional lost packets
                update_estimated_rate(c, missingCnt+1);
                update_connection_lossrate(c, seqno);
                c->lastRecvSeqNo = seqno;
            }
            
            if (u16list_isEmpty(&cs->missingList)) {  
                // We're done. No missing packets(received all). Send FIN ACK and go to FINISHED state.
                s_send_FIN_ACK(c);
                cs->state = STR_C_S_FINISHED;
                if (cs->deletePending && !streamtransport_tid_is_alive(tid))
                    streamtransport_tid_delete_done(tid);
                STR_Timer_start(c, STR_CONNECTION_TIMEOUT);
            } else {
                cs->timeoutCount = 0;
                send_NACK(c);
                cs->state = STR_C_S_FIN_NACK_WAIT;
                STR_Timer_start(c, STR_NACK_TIMEOUT);
                #ifdef DEBUG_STR1
                    printf(" %d missing packets left for node %d. must recover.\n",
                            u16list_getLength(&cs->missingList), srcAddr);
                #endif
            }
            break;

        case (STR_FLAG_DATA):        /** DATA packet received **/
        case (STR_FLAG_DATA_RETX):   /** Retransmitted packet received **/
            if (c == NULL)
                return;

            /* for every packet newer than the newest packet */
            if (tr_seqno_cmp(seqno, c->lastRecvSeqNo) > 0) {
                missingCnt = detectMissingPacket(seqno, c);
                update_estimated_rate(c, missingCnt+1);
                update_connection_lossrate(c, seqno);
                c->lastRecvSeqNo = seqno;
            }
                
            /* is it a new unique packet ? */
            if ((tr_seqno_cmp(seqno, cs->nextExpectedSeqNo) >= 0) &&    /* newer what I already got AND */
                (SPList_find(&cs->plist, seqno) < 0)) {                 /* not in the packet list yet */
                newpkt = 1;
            }
            
            #ifdef DEBUG_STR2
            if (newpkt) {
                if (flag & STR_FLAG_RETX)
                    printf("[STR] Retxed pkt received (tid %d, src %d, seqno %d)\n", tid, srcAddr, seqno);
                else
                    printf("[STR] STREAM pkt received (tid %d, src %d, seqno %d)\n", tid, srcAddr, seqno);
            } else {
                    printf("[STR] Dup pkt received (tid %d, node %2d, seqno %2d)\n", tid, srcAddr, seqno);
            }
            #endif

            /* if retransmitted packet, delete from missing list */
            if (flag & STR_FLAG_RETX) {
                voidSeq = u16list_delete(&cs->missingList, seqno);
            }

            /* dispatch(forward) to the application layer */
            receive_str_msg(c, seqno, len, tr_packet_getPayload(tmsg));
            
            /* for every unique packet, update information, and do rate control */
            if (newpkt) {
                c->totalRecvPackets++;
                update_connection_goodput(c);       /* update goodput */
                #ifdef LOG_STR_PACKET
                if (flag & STR_FLAG_RETX)  /* if retransmitted packet */
                    log_str_packet(c, seqno, 1);
                else
                    log_str_packet(c, seqno, 0);
                #endif
            }

            if (missingCnt > 0) {
                if (cs->state == STR_C_S_PASSIVE)
                    cs->state = STR_C_S_NACK_WAIT;
                send_NACK(c);
                STR_Timer_start(c, STR_NACK_TIMEOUT);
            } else if (u16list_isEmpty(&cs->missingList)) {
                // All missing pkts recved after FIN, scheduling FIN ACK
                if (cs->state == STR_C_S_FIN_NACK_WAIT) {
                    // We're done. No missing packets(received all). Send FIN ACK and go to FINISHED state.
                    s_send_FIN_ACK(c);
                    cs->state = STR_C_S_FINISHED;
                    if (cs->deletePending && !streamtransport_tid_is_alive(tid))
                        streamtransport_tid_delete_done(tid);
                    STR_Timer_start(c, STR_CONNECTION_TIMEOUT);
                } else if (cs->state == STR_C_S_NACK_WAIT) {
                    cs->state = STR_C_S_PASSIVE;
                    STR_Timer_start(c, STR_CONNECTION_TIMEOUT);
                }
            }
            break;

        default:
            #ifdef DEBUG_STR2
                printf("[STR] packet with unidentified flag received\n");
                fdump_packet(stdout, packet, len);
            #endif
            break;
    }// End of switch
    fflush(stdout);
}

 
/********************************************************/
/**  Timer functions for Passive Connections ************/
/********************************************************/

int STR_Timer_start(connectionlist_t *c, unsigned long int interval_ms) {
    struct timeval curr;
    if (c == NULL)
        return 0;
    gettimeofday(&curr, NULL);
    add_ms_to_timeval(&curr, interval_ms, &c->alarm_time);
    return 1;
}

void STR_Timer_stop(connectionlist_t *c) {
    if (c == NULL)
        return;
    c->alarm_time.tv_sec = 0;
    c->alarm_time.tv_usec = 0;
    return;
}

int STR_Timer_fired(int user_id) {
    connectionlist_t *c = (connectionlist_t *)user_id;
    struct strclist *cs = (struct strclist *)c;
    
    if (cs->state == STR_C_S_FINISHED) {
        #ifdef DEBUG_STR2
            printf("[STR] Timer.fired: tid=%d FINISHED!!\n", c->tid);
        #endif
        // We're done. We can remove state... 
        // Delet if 'transportmain' already requested for it.
        //if (cs->deletePending)
            delete_str_connection(c);
        // else wait till 'transportmain' to request for it.
    } else if ((cs->state == STR_C_S_NACK_WAIT) ||
                (cs->state == STR_C_S_FIN_NACK_WAIT)) {
        cs->timeoutCount++;
        #ifdef DEBUG_NACK
            printf("[STR] Timer fired: [NACK/FIN_NACK]_WAIT: addr %d, tid %d (timeoutCnt %d)\n",
                            c->addr, c->tid, cs->timeoutCount);
        #endif
        if (cs->timeoutCount >= MAX_TIMEOUT_COUNT) {
            #ifdef DEBUG_NACK
                printf("[STR] TimeoutCnt > MAX_TIME_COUNT, terminating node %d, tid %d.\n", 
                                c->addr, c->tid);
                printf("   #num outstanding lost packets %d\n", u16list_getLength(&cs->missingList));
                printf("   #total num lost till now %lu\n", c->totalLostPackets);
                printf("   #total num received till now %lu\n", c->totalRecvPackets);
            #endif
            delete_str_connection(c);
        } else if (!u16list_isEmpty(&cs->missingList)) {
            send_NACK(c);
            STR_Timer_start(c, STR_NACK_TIMEOUT);
        } else {
            if (cs->state == STR_C_S_NACK_WAIT) {
                cs->state = STR_C_S_PASSIVE;
                STR_Timer_start(c, STR_CONNECTION_TIMEOUT);
            } else { //if (cs->state == STR_C_S_FIN_NACK_WAIT) {
                // We're done. No missing packets(received all). Send FIN ACK and go to FINISHED state.
                s_send_FIN_ACK(c);
                cs->state = STR_C_S_FINISHED;
                if (cs->deletePending && !streamtransport_tid_is_alive(c->tid))
                    streamtransport_tid_delete_done(c->tid);
                STR_Timer_start(c, STR_CONNECTION_TIMEOUT);
            }
        }
    } else if (cs->state == STR_C_S_PASSIVE) {
        if (cs->deletePending) {
            delete_str_connection(c);    // CONNECTION TIMEOUT EXPIRED... 
        #ifdef DEBUG_STR2
            printf("[STR] Timer.fired: PASSIVE tid=%d CLOSED!!\n", c->tid);
        #endif
        }
    }
    return user_id;
}

void polling_streamtransport_timer() {
    connectionlist_t *c;
    struct timeval curr;
    gettimeofday(&curr, NULL);

    for (c = (connectionlist_t *)m_strcs; c; c = c->next) {
        if (((c->alarm_time.tv_sec > 0) || (c->alarm_time.tv_usec > 0))
                && (compare_timeval(&c->alarm_time, &curr) <= 0)) {
            STR_Timer_fired((int)c);
            break;
        }
    }
}


/********************************************************/
/**  connection functions            ********************/
/********************************************************/

void print_all_strc() {
    printf("[strclist]\n");
    print_all_connections((connectionlist_t **)&m_strcs);
}

connectionlist_t *create_str_connection(uint16_t tid, uint16_t srcAddr, uint16_t seqno) {
    struct strclist *cs;
    connectionlist_t *c;
    
    c = find_connection((connectionlist_t **)&m_strcs, tid, srcAddr);
    if (c == NULL) {
        cs = malloc(sizeof(struct strclist));   // must be sizeof strclist
        c = (connectionlist_t *)cs;
    }

    #ifdef DEBUG_STR1
        printf("[STR] Creating new stream connections (tid %d, addr %d)!!\n", tid, srcAddr);
    #endif

    add_connection((connectionlist_t **)&m_strcs, c, tid, srcAddr);

    c->connection_type = PROTOCOL_STREAM_TRANSPORT;
    c->lastRecvSeqNo = seqno;
    
    cs = (struct strclist *)c;
    cs->state = STR_C_S_PASSIVE;
    cs->deletePending = 0;
    cs->timeoutCount = 0;
    cs->nextExpectedSeqNo = seqno + 1;
    u16list_init(&cs->missingList);
    SPList_init(&cs->plist); // must init.....

    #ifdef DEBUG_STR1
        print_all_strc();
    #endif
    return c;
}

void _delete_strc(connectionlist_t **c) {
    connectionlist_t *d;
    struct strclist *cs = (struct strclist *)(*c);
    if ((c == NULL) || ((*c) == NULL))
        return;
    SPList_clearList(&(cs->plist));    // don't forget these!!
    u16list_clearList(&(cs->missingList));

    d = (*c)->next;
    (*c)->next = NULL;
    *c = d;
    free(cs);
}

void delete_str_connection(connectionlist_t *c) {
    connectionlist_t **d;
    if (c == NULL)
        return;
    d = _find_connection((connectionlist_t **)&m_strcs, c->tid, c->addr);
    _delete_strc(d);
}

void streamtransport_terminate() {
    connectionlist_t **c;
    for (c = (connectionlist_t **)&m_strcs; *c; )
        _delete_strc(c);
    if (m_str_log_fptr) {
        fflush(m_str_log_fptr);
        fclose(m_str_log_fptr);
    }
}

int streamtransport_delete_tid(uint16_t tid) {
    connectionlist_t **c;
    int result = 0; // if there is no matching tid, will return 0.
    
    for (c = (connectionlist_t **)&m_strcs; *c; ) {
        struct strclist *cs = (struct strclist *)(*c);
        if ((*c)->tid == tid) {
            if (result == 0)    // if there is at least one matching tid,
                result = 1;     // will return 1 as long as nothing is pending.
                
            if (cs->state == STR_C_S_FINISHED)
                _delete_strc(c);
            else {
                cs->deletePending = 1;
                result = -1;    // at least one connection is not finished.
                // transportmain can expect/wait for streamtransport_tid_delete_done();
                c = &((*c)->next);
            }
        } else {
            c = &((*c)->next);
        }
    }
    return result;
}

int streamtransport_tid_is_alive(uint16_t tid) {
    connectionlist_t *c;
    for (c = (connectionlist_t *)m_strcs; c; ) {
        struct strclist *cs = (struct strclist *)c;
        // if there exist a matching tid, and if that connection is not finished
        if ((c->tid == tid) && (cs->state != STR_C_S_FINISHED))
            return 1;
        c = c->next;
    }
    return 0;
}

