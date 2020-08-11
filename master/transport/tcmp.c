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
 * File for TCMP functionalities: mote network-layer ping and trace-route
 * functionalities for mote-routing debugging purposes.
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 2/5/2007
 **/

#include <string.h>
#include <sys/time.h>
#include <stddef.h>
#include "transportmain.h"
#include "transport.h"
#include "tcmp.h"
#include "tidlist.h"
#include "tosmsg.h"
#include "routinglayer.h"
#include "timeval.h"

//#define DEBUG_TCMP

struct tcmplist *tcmps;

struct tcmplist *add_tcmp(uint16_t tid, uint16_t addr, int type);
void remove_tcmp(uint16_t tid, uint16_t addr);
struct tcmplist * find_tcmp(uint16_t tid, uint16_t addr);
struct tcmplist *find_tcmp_by_tid(uint16_t tid);
int TCMP_Timer_start(struct tcmplist *t, unsigned long int interval_ms);
int TCMP_Timer_fired(int user_id);

/*************************************************/
/***   TCMP reply PING/TRACERT with ACK   ********/
/*************************************************/

void send_PING_ACK(uint16_t tid, uint16_t addr, uint16_t seqno) {
    int len = offsetof(TransportMsg, data);
    unsigned char *packet = (unsigned char *) malloc(len); // freed locally
    TransportMsg *trmsg = (TransportMsg *) packet;
    int ttl = RT_DEFAULT_TTL;
    
    trmsg->tid = tid;
    trmsg->seqno = seqno;
    trmsg->flag = TCMP_FLAG_PING_ACK;

    #ifdef DEBUG_TCMP
        printf("--> send_PING_ACK: tid=%d, addr=%d, seqno=%d\n", tid, addr, seqno);
    #endif
    write_routing_msg(packet, len, PROTOCOL_TCMP, addr, ttl);
    free((void *) packet); // malloced locally
}

void send_TRACERT_ACK(uint16_t tid, uint16_t addr, uint16_t seqno) {
    int len = offsetof(TransportMsg, data);
    unsigned char *packet = (unsigned char *) malloc(len); // freed locally
    TransportMsg *trmsg = (TransportMsg *) packet;
    int ttl = RT_DEFAULT_TTL;
    
    trmsg->tid = tid;
    trmsg->seqno = seqno;
    trmsg->flag = TCMP_FLAG_TRACERT_ACK;

    #ifdef DEBUG_TCMP
        printf("--> send_TRACERT_ACK: tid=%d, addr=%d, seqno=%d\n", tid, addr, seqno);
    #endif
    write_routing_msg(packet, len, PROTOCOL_TCMP, addr, ttl);
    free((void *) packet); // malloced locally
}

/*************************************************/
/***   TCMP send PING / TRACERT     **************/
/*************************************************/

void TCMP_send_ping(uint16_t tid, uint16_t addr) {
    int len = offsetof(TransportMsg, data);
    unsigned char *packet = (unsigned char *) malloc(len); // freed locally
    TransportMsg *trmsg = (TransportMsg *) packet;
    struct tcmplist *t = find_tcmp(tid, addr);
    int ttl = RT_DEFAULT_TTL;
    struct timeval curr;
    
    if (t == NULL)
        t = add_tcmp(tid, addr, TCMP_FLAG_PING);
    else if (t->type != TCMP_FLAG_PING)
        printf(" something wrong happend in 'send_PING'\n");
    trmsg->tid = t->tid;
    trmsg->flag = t->type;
    trmsg->seqno = t->seqno;

    gettimeofday(&curr, NULL);
    copy_timeval(&t->sent_time, &curr);
    TCMP_Timer_start(t, TCMP_TIMEOUT);

    #ifdef DEBUG_TCMP
        printf(" --> send_PING: tid=%d, addr=%d, seqno=%d\n", tid, addr, t->seqno);
    #endif
    write_routing_msg(packet, len, PROTOCOL_TCMP, addr, ttl);
    free((void *) packet);  // malloced above locally
}

void TCMP_send_tracert(uint16_t tid, uint16_t addr) {
    int len = offsetof(TransportMsg, data);
    unsigned char *packet = (unsigned char *) malloc(len); // freed locally
    TransportMsg *trmsg = (TransportMsg *) packet;
    struct tcmplist *t = find_tcmp(tid, addr);
    struct timeval curr;

    if (t == NULL)
        t = add_tcmp(tid, addr, TCMP_FLAG_TRACERT);
    else if (t->type != TCMP_FLAG_TRACERT)
        printf(" something wrong happend in 'send_TRACERT'\n");
    trmsg->tid = tid;
    trmsg->flag = t->type;
    trmsg->seqno = t->seqno;

    gettimeofday(&curr, NULL);
    copy_timeval(&t->sent_time, &curr);
    TCMP_Timer_start(t, TCMP_TIMEOUT);

    #ifdef DEBUG_TCMP
        printf(" --> send_TRACERT: tid=%d, addr=%d, seqno=%d, ttl=%d\n",
                                   tid, addr, t->seqno, t->ttl);
    #endif
    write_routing_msg(packet, len, PROTOCOL_TCMP, addr, t->ttl);
    free((void *) packet); // malloced locally
}

/*************************************************/
/***   TCMP received packet from router   ********/
/*************************************************/

void receive_PING_ACK(uint16_t tid, uint16_t addr, uint16_t seqno) {
    struct tcmplist *t = find_tcmp(tid, addr);
    unsigned char *packet;
    PingMsg *pmsg;
    struct timeval curr, rtt;

    if (t == NULL)
        return;
    if ((seqno != t->seqno) && (t->addr != TOS_BCAST_ADDR)) {
        #ifdef DEBUG_TCMP
            printf("received PING_ACK with unexpected seqno... dropping\n");
        #endif
        return;
    } else {

        gettimeofday(&curr, NULL);
        subtract_timeval(&curr, &t->sent_time, &rtt);
        if (rtt.tv_sec >= ((TCMP_TIMEOUT/1000) - 1)) {
            rtt.tv_sec = -1;    // meaning.. timeout!!
            rtt.tv_usec = 0;
        }
        if (addr == TOS_BCAST_ADDR) {
            rtt.tv_sec = -1;    // meaning.. timeout!!
            rtt.tv_usec = 0;
        }
        if ((t->addr != TOS_BCAST_ADDR) || (rtt.tv_sec != -1)) {
            // not broadcast, or not timeout
            packet = malloc(sizeof(PingMsg)); // freed locally
            pmsg = (PingMsg *) packet;
            pmsg->rtt_sec = rtt.tv_sec;
            pmsg->rtt_usec = rtt.tv_usec;
            pmsg->seqno = t->seqno++;
            pmsg->node = addr;

            receive_TCMP_ping_ack(tid, addr, sizeof(PingMsg), (void *)packet);

            free((void *)packet); // malloced locally
        }
    }
    
    if (t->addr == TOS_BCAST_ADDR) {
        if (rtt.tv_sec != -1) // broadcast, but not timeout
            return; // wait until timeout
        else // (broadcast & timeout)
            seqno = TCMP_DEFAULT_NUM_PING;// don't send any more
    }

    if (seqno < TCMP_DEFAULT_NUM_PING) {
        TCMP_send_ping(tid, t->addr);    // t->addr and addr might differ(can be broadcast address)
    } else {
        remove_tcmp(tid, t->addr);
        tidlist_remove_tid(tid);
    }
}

void receive_TRACERT_ACK(uint16_t tid, uint16_t addr, uint16_t seqno) {
    struct tcmplist *t = find_tcmp_by_tid(tid);// because addr is not the dst
    uint16_t actualDstAddr;
    unsigned char *packet;
    PingMsg *pmsg;
    struct timeval curr, rtt;

    if (t == NULL)
        return;
    if (seqno != t->seqno) {
        #ifdef DEBUG_TCMP
            printf("received TRACERT_ACK with unexpected seqno... dropping\n");
        #endif
        return;
    }

    gettimeofday(&curr, NULL);
    subtract_timeval(&curr, &t->sent_time, &rtt);
    if (rtt.tv_sec >= ((TCMP_TIMEOUT/1000) - 1)) {
        rtt.tv_sec = -1;    // meaning.. timeout!!
        rtt.tv_usec = 0;
    }

    packet = malloc(sizeof(PingMsg));
    pmsg = (PingMsg *) packet;
    pmsg->rtt_sec = rtt.tv_sec;
    pmsg->rtt_usec = rtt.tv_usec;
    pmsg->seqno = t->seqno++;
    pmsg->node = addr; // intermediate node
    actualDstAddr = t->addr; // trace route destination

    receive_TCMP_tracert_ack(tid, actualDstAddr, sizeof(PingMsg), (void *)packet);

    free((void *)packet);

    if (seqno < (TCMP_DEFAULT_NUM_TRACERT * t->ttl)) {
        TCMP_send_tracert(tid, actualDstAddr);
    } else if (addr != actualDstAddr) {
        t->ttl++;
        TCMP_send_tracert(tid, actualDstAddr);
    } else {
        remove_tcmp(tid, actualDstAddr);
        tidlist_remove_tid(tid);
    }
}

void TCMP_receive(int len, uint8_t *packet, uint16_t src, uint16_t dst, uint8_t ttl) {
    TransportMsg *trmsg = (TransportMsg *) packet;
    uint8_t flag = trmsg->flag;
    uint16_t tid = trmsg->tid;
    uint16_t seqno = trmsg->seqno;

    switch (flag) {

        case TCMP_FLAG_PING:
            send_PING_ACK(tid, src, seqno);
            break;

        case TCMP_FLAG_PING_ACK:
            if (dst != TOS_LOCAL_ADDRESS())
                printf("Can ping arrive at non-destined node?\n");
            else
                receive_PING_ACK(tid, src, seqno);
            break;

        case TCMP_FLAG_TRACERT:
            if (ttl != 0)
                printf(" [TCMP_receive] ttl != 0\n");
            send_TRACERT_ACK(tid, src, seqno);
            break;

        case TCMP_FLAG_TRACERT_ACK:
            if (dst != TOS_LOCAL_ADDRESS())
                printf("Can tracert ack arrive at non-destined node?\n");
            else
                receive_TRACERT_ACK(tid, src, seqno);
            break;
    }
}


/*************************************************/
/***    TCMP list related functions   ************/
/*************************************************/

void print_all_tcmps() {
    #ifdef DEBUG_TCMP
        struct tcmplist *t;
        for (t = tcmps; t; t = t->next) {
            if (t->type == TCMP_FLAG_PING)
                printf("[tcmplist]: type=PING, tid=%d, addr=%d\n", t->tid, t->addr);
            else if (t->type == TCMP_FLAG_TRACERT)
                printf("[tcmplist]: type=TRACERT, tid=%d, addr=%d\n", t->tid, t->addr);
        }
    #endif
}

struct tcmplist *add_tcmp(uint16_t tid, uint16_t addr, int type) {
    struct tcmplist *t = malloc(sizeof *t);
    t->next = tcmps;
    tcmps = t;
    t->type = type;
    t->tid = tid;
    t->addr = addr;
    t->seqno = 1;
    t->ttl = 1;
    t->alarm_time.tv_sec = 0;
    t->alarm_time.tv_usec = 0;
    print_all_tcmps();
    return t;
}

void rem_tcmp(struct tcmplist **t) {
    struct tcmplist *dead = *t;
    *t = dead->next;
    free(dead);
    print_all_tcmps();
}

struct tcmplist **_find_tcmp(uint16_t tid, uint16_t addr) {
    struct tcmplist **t;
    for (t = &tcmps; *t; ) {
        if (((*t)->tid == tid) && 
                (((*t)->addr == addr) ||
                ((*t)->addr == TOS_BCAST_ADDR) || (addr == TOS_BCAST_ADDR)))
            return t;
        else
            t = &((*t)->next);
    }
    return NULL;    // Error, not found
}

struct tcmplist *find_tcmp(uint16_t tid, uint16_t addr) {
    struct tcmplist **t;
    t = _find_tcmp(tid, addr);
    if (t)
        return (*t);
    return NULL;    // Error, not found
}

struct tcmplist *find_tcmp_by_tid(uint16_t tid) {
    return find_tcmp(tid, TOS_BCAST_ADDR);
}

void remove_tcmp(uint16_t tid, uint16_t addr) {
    struct tcmplist **t;
    t = _find_tcmp(tid, addr);
    if (t)
        rem_tcmp(t);
}

/********************************************************/
/**  Timer functions for TCMP Connections    ************/
/********************************************************/

int TCMP_Timer_start(struct tcmplist *c, unsigned long int interval_ms) {
    struct timeval curr;
    if (c == NULL)
        return 0;
    gettimeofday(&curr, NULL);
    add_ms_to_timeval(&curr, interval_ms, &c->alarm_time);
    return 1;
}

void TCMP_Timer_stop(struct tcmplist *c) {
    if (c == NULL)
        return;
    c->alarm_time.tv_sec = 0;
    c->alarm_time.tv_usec = 0;
    return;
}

int TCMP_Timer_fired(int user_id) {
    struct tcmplist *t = (struct tcmplist *)user_id;
    #ifdef DEBUG_TCMP
        printf("TCMP_Timerfired, ACK TimeOut...");
        printf(" (tid=%d, addr=%d, seqno=%d)\n", t->tid, t->addr, t->seqno);
    #endif
    if (t == NULL) {
        fprintf(stderr, "pointer error in TCMP_Timer_fired\n");
        return -1;
    }
    if (t->type == TCMP_FLAG_PING)
        receive_PING_ACK(t->tid, t->addr, t->seqno);
    else if (t->type == TCMP_FLAG_TRACERT)
        receive_TRACERT_ACK(t->tid, t->addr, t->seqno);
    return 1;
}

void polling_tcmp_timer() {
    struct tcmplist *c;
    struct timeval curr;
    gettimeofday(&curr, NULL);

    for (c = tcmps; c; c = c->next) {
        if (((c->alarm_time.tv_sec > 0) || (c->alarm_time.tv_usec > 0))
                && (compare_timeval(&c->alarm_time, &curr) <= 0)) {
            TCMP_Timer_fired((int)c);
            break;
        }
    }
}

