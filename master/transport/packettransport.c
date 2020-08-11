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
 * Master side code for PacketTransport.
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
#include "packettransport.h"
#include "tr_checksum.h"
#include "timeval.h"
#include "connectionlist.h"
#include "tr_packet.h"
#include "tr_seqno.h"

//#define DEBUG_PTR
//#define DEBUG_PTR_MORE
//#define DEBUG_CPTR
//#define LOG_PTR_PACKET

struct ptrclist {   // packet transport connection list
    connectionlist_t c;

    uint16_t sentSeqNo;
    uint8_t len;
    unsigned char *packet;  // added for retransmission
    int retxCount;
};

/* Global variable */
struct ptrclist *m_ptrcs;   // packet transport connection list
FILE *m_ptr_log_fptr;


int PTR_Timer_start(connectionlist_t *c, unsigned long int interval_ms);
void PTR_Timer_stop(connectionlist_t *c);
connectionlist_t *create_ptr_connection(uint16_t tid, uint16_t addr, uint16_t seqno);


void log_ptr_packet(connectionlist_t *c, uint16_t seqno) {
    uint32_t time_ms;
    struct timeval curr;
    gettimeofday(&curr, NULL);
    time_ms = tv2ms(&curr);

    if (m_ptr_log_fptr == NULL)
        m_ptr_log_fptr = fopen("log_pktt.out", "w");

#ifdef __CYGWIN__
    fprintf(m_ptr_log_fptr, "%lu ", time_ms);
#else
    fprintf(m_ptr_log_fptr, "%u ", time_ms);
#endif
    fprintf(m_ptr_log_fptr, "%d %d %d %d %d %.3f %.3f %.3f\n", 
                    c->tid, c->addr, seqno,
                    0,
                    c->lastRecvSeqNo,
                    c->goodput.Rcumm, 
                    c->pktrate.Ravg, 
                    c->loss_ali.Lavg
                    );
    fflush(m_ptr_log_fptr);
}



int ptr_detectMissingPacket(uint16_t seqno, connectionlist_t *c) {
    int detected = 0;
    uint16_t lastSeqNo = c->lastRecvSeqNo;
    
    if (tr_seqno_cmp(seqno, tr_seqno_next(lastSeqNo)) > 0) {
        #ifdef DEBUG_CPTR
            printf("[CPTR] Missing pkt detected, node %d, recv_seqno %d, last %d: ", 
                          c->addr, seqno, lastSeqNo);
        #endif
        do {
            lastSeqNo = tr_seqno_next(lastSeqNo);
            #ifdef DEBUG_CPTR
                printf(" %d", lastSeqNo);
            #endif
            c->totalLostPackets++;
            detected++;
        } while (tr_seqno_cmp(seqno, tr_seqno_next(lastSeqNo)) > 0);
        #ifdef DEBUG_CPTR
            printf(" (total lost till now %u, while getting %u)\n", 
                    c->totalLostPackets, c->totalRecvPackets);
        #endif
        fflush(stdout);
    }
    return detected;
}



/********************************************************/
/**  ACK ACK ACK.......                ******************/
/********************************************************/

void send_PTR_ACK(uint16_t tid, uint16_t addr, uint16_t seqno) {
    int len = offsetof(TransportMsg, data);
    unsigned char *packet = (unsigned char *)malloc(len);
    TransportMsg *tmsg = (TransportMsg *) packet;
    
    tr_packet_setHeader(tmsg, tid, seqno, PTR_FLAG_ACK, 0);
    // set checksum after setting header and copying payload
    tmsg->checksum = tr_calculate_checksum(tmsg, 0);

    #ifdef DEBUG_PTR
        printf("[PTR] send_ACK: tid=%d, addr=%d, seqno=%d (send to mote)\n",
                      tid, addr, seqno);
    #endif

    write_routing_msg(packet, len, PROTOCOL_PACKET_TRANSPORT, addr, RT_DEFAULT_TTL);

    free((void *) packet);
}


/********************************************************/
/**  SEND, RETX                        ******************/
/********************************************************/

int packettransport_send(uint16_t tid, uint16_t addr, uint8_t len, unsigned char *msg) {
    unsigned char *packet;
    TransportMsg *tmsg;
    connectionlist_t *c;
    struct ptrclist *cs;
    
    c = find_connection((connectionlist_t **)&m_ptrcs, tid, addr);
    if (c == NULL) c = create_ptr_connection(tid, addr, 0);
    if (c == NULL) return -1;
    cs = (struct ptrclist *)c;

    packet = malloc(len  + offsetof(TransportMsg, data));
    tmsg = (TransportMsg *) packet;
    memcpy(tmsg->data, msg, len);

    cs->len = len;
    cs->retxCount = 0;
    cs->packet = packet;            // this better be non-NULL !!

    // use next sequence number
    tr_packet_setHeader(tmsg, tid, ++cs->sentSeqNo, PTR_FLAG_SEND, 0);
    // set checksum after setting header and copying payload
    tmsg->checksum = tr_calculate_checksum(tmsg, len);

    len = len + offsetof(TransportMsg, data);

    write_routing_msg(packet, len, PROTOCOL_PACKET_TRANSPORT, addr, RT_DEFAULT_TTL);
    
    #ifdef DEBUG_PTR
        printf("[PTR] send: tid %d, addr %d, seqno %d, flag %#4x\n", 
                tmsg->tid, addr, tmsg->seqno, tmsg->flag);
    #endif
    PTR_Timer_start(c, PTR_ACK_TIMEOUT);

    return 1;
}

void retx_PTR(connectionlist_t *c) {
    struct ptrclist *cs = (struct ptrclist *)c;
    unsigned char *packet = cs->packet;
    TransportMsg *tmsg = (TransportMsg *) packet;
    int len = cs->len;
    
    // use same sequence number
    tr_packet_setHeader(tmsg, c->tid, cs->sentSeqNo, PTR_FLAG_SEND, 0);
    // set checksum after setting header and copying payload
    tmsg->checksum = tr_calculate_checksum(tmsg, len);

    len = len + offsetof(TransportMsg, data);

    write_routing_msg(packet, len, PROTOCOL_PACKET_TRANSPORT, c->addr, RT_DEFAULT_TTL);
    
    #ifdef DEBUG_PTR
        printf("[PTR] retransmitting: tid=%d, seqno=%d, flag=%#4x\n"
                    , tmsg->tid, tmsg->seqno, tmsg->flag);
    #endif
}

void send_PTR_Done(connectionlist_t *c, int success) {
    struct ptrclist *cs = (struct ptrclist *)c;
    unsigned char *packet = cs->packet;  // packet with Tr tmsg
    TransportMsg *tmsg = (TransportMsg *) packet;
    cs->packet = NULL;
    senddone_packettransport(c->tid, c->addr, cs->len, tmsg->data, success);
    free((void *) packet);  // free pkt that we malloced when received cmd.
}


/********************************************************/
/**  Received packet from Mote network  *****************/
/********************************************************/

void packettransport_receive(int len, unsigned char *packet, uint16_t addr) {
    // 'packet' is in TransportMsg format, without any routing or TOS msg.
    // 'len' is the size of the whole packet.
    TransportMsg *tmsg = (TransportMsg *) packet;
    connectionlist_t *c;
    uint16_t seqno, tid;
    uint8_t flag;
    int missingCnt;

    if (packet == NULL) {
        printf("PTR: null packet: ");
        return;
    }
    len =  len - (offsetof(TransportMsg, data));
    if (len < 0) {
        printf("PTR: invalid length: ");
        return;
    }
    if (tr_checksum_check(tmsg, len) < 0) {
        printf("PTR: invalid checksum (%X): ", tr_calculate_checksum(tmsg, len));
        fdump_packet(stdout, packet, len);
        return;
    }

    seqno = tr_packet_getSeqno(tmsg);
    tid = tr_packet_getTid(tmsg);
    flag = tr_packet_getFlag(tmsg);
    c = find_connection((connectionlist_t **)&m_ptrcs, tid, addr);

    switch (flag) {

        case (PTR_FLAG_ACK): /** ACK received **/           
            if (c == NULL) {
                #ifdef DEBUG_PTR_MORE
                    printf("[PTR] unexpected ACK received\n");
                #endif
            } else {
                #ifdef DEBUG_PTR
                    printf("[PTR] packettransport ACK received (tid %d, addr %d)\n", tid, addr);
                #endif
                PTR_Timer_stop(c);
                send_PTR_Done(c, 1);    // reset & free here.
            }
            break;

        case (PTR_FLAG_SEND): /** packet received **/           
        case (PTR_FLAG_NOACK_SEND):
            if (c == NULL)
                c = create_ptr_connection(tid, addr, seqno);
            #ifdef DEBUG_PTR
            if (flag == PTR_FLAG_SEND)
                printf("[PTR] packettransport msg ");
            else
                printf("[PTR] best-effort     msg ");
            printf("rcved (tid %d, addr %d, flag %x, seqno %d, len %d)\n", tid, addr, flag, seqno, len);
            #endif

            if (tr_seqno_cmp(seqno, c->lastRecvSeqNo) > 0) {
                missingCnt = ptr_detectMissingPacket(seqno, c);
                /* update average packet inter-arrival time, given last arrival time */
                update_estimated_rate(c, missingCnt+1);
                update_connection_lossrate(c, seqno);
                update_connection_goodput(c);
                c->lastRecvSeqNo = seqno;
                c->totalRecvPackets++;
            }

            if (flag == PTR_FLAG_SEND)
                send_PTR_ACK(tid, addr, seqno);
            
            #ifdef LOG_PTR_PACKET
                log_ptr_packet(c, seqno);
            #endif
            receive_packettransport(tid, addr, len, tmsg->data);

        default:
            #ifdef DEBUG_PTR_MORE
                printf("[PTR] Received packet with unidentified flag %x\n", flag);
                fdump_packet(stdout, packet, len);
            #endif
            break;
    }// End of switch
    return;
}


/********************************************************/
/**  Timer functions for Passive Connections ************/
/********************************************************/

int PTR_Timer_start(connectionlist_t *c, unsigned long int interval_ms) {
    struct timeval curr;
    if (c == NULL)
        return 0;
    gettimeofday(&curr, NULL);
    add_ms_to_timeval(&curr, interval_ms, &c->alarm_time);
    return 1;
}

void PTR_Timer_stop(connectionlist_t *c) {
    if (c == NULL)
        return;
    c->alarm_time.tv_sec = 0;
    c->alarm_time.tv_usec = 0;
    return;
}

int PTR_Timer_fired(int user_id) {
    connectionlist_t *c = (connectionlist_t *)user_id;
    struct ptrclist *cs = (struct ptrclist *)c;
    if (!c)
        return -1;
    if (cs->retxCount < PTR_MAX_NUM_RETX) {
        #ifdef DEBUG_PTR
            printf("[PTR] Timer fired, ACK timeout. Let's retx");
            printf(" (tid %d, addr %d)\n", c->tid, c->addr);
        #endif
        cs->retxCount++;
        retx_PTR(c);
        PTR_Timer_start(c, PTR_ACK_TIMEOUT);
    } else {
        #ifdef DEBUG_PTR
            printf("[PTR] Timer fired, ACK timeout. giveup retx.");
            printf(" (tid %d, addr %d)\n", c->tid, c->addr);
        #endif
        send_PTR_Done(c, 0);
    }
    return 1;
}

void polling_packettransport_timer() {
    connectionlist_t *c;
    struct timeval curr;
    gettimeofday(&curr, NULL);

    for (c = (connectionlist_t *)m_ptrcs; c; c = c->next) {
        if (((c->alarm_time.tv_sec > 0) || (c->alarm_time.tv_usec > 0))
                && (compare_timeval(&c->alarm_time, &curr) <= 0)) {
            PTR_Timer_fired((int)c);
            break;
        }
    }
}

/********************************************************/
/**  ptrclist (PTR connection) functions   **************/
/********************************************************/

void print_all_ptrc() {
    printf("[ptrclist]\n");
    print_all_connections((connectionlist_t **)&m_ptrcs);
}

connectionlist_t *create_ptr_connection(uint16_t tid, uint16_t addr, uint16_t seqno) {
    struct ptrclist *cs;
    connectionlist_t *c;
    
    c = find_connection((connectionlist_t **)&m_ptrcs, tid, addr);
    if (c == NULL) {
        cs = malloc(sizeof(struct ptrclist));   // must be size of ptrclist
        c = (connectionlist_t *)cs;
    }
    
    add_connection((connectionlist_t **)&m_ptrcs, c, tid, addr);
    
    c->connection_type = PROTOCOL_PACKET_TRANSPORT;
    c->lastRecvSeqNo = seqno;
    
    cs = (struct ptrclist *)c;
    cs->sentSeqNo = 0;
    cs->retxCount = 0;
    cs->packet = NULL;  // will be NULL for recv connections, and non-NULL for send connections.

    #ifdef DEBUG_CPTR
        printf("[PTR] Creating new pkt connections (tid %d, addr %d)!!\n", tid, addr);
        print_all_ptrc();
    #endif
    return c;
}

void _delete_ptrc(connectionlist_t **c) {
    connectionlist_t *d;
    struct ptrclist *cs = (struct ptrclist *)(*c);
    if ((c == NULL) || ((*c) == NULL))
        return;
    d = (*c)->next;
    (*c)->next = NULL;
    *c = d;
    free(cs);
}

void packettransport_terminate() {
    connectionlist_t **c;
    for (c = (connectionlist_t **)&m_ptrcs; *c; )
        _delete_ptrc(c);
    fflush(m_ptr_log_fptr);
    fclose(m_ptr_log_fptr);
}

int packettransport_delete_tid(uint16_t tid) {
    connectionlist_t **c;
    int result = 0; // if there is no matching tid, will return 0.
    
    for (c = (connectionlist_t **)&m_ptrcs; *c; ) {
        if ((*c)->tid == tid) {
            result = 1;
            _delete_ptrc(c);
        #ifdef DEBUG_CPTR
            printf("[PTR] delete pkt connection (tid %d, addr %d)!!\n", tid, addr);
        #endif
        } else {
            c = &((*c)->next);
        }
    }
    return result;
}

int packettransport_tid_is_alive(uint16_t tid) {
    connectionlist_t *c;
    for (c = (connectionlist_t *)m_ptrcs; c; ) {
        if (c->tid == tid)
            return 1;
        c = c->next;
    }
    return 0;
}

