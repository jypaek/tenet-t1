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
 * File for supplementary services that master transport provides.
 *
 * Master transport provides some services such as:
 * - network-layer ping : ping a mote
 * - network-layer trace route : trace route a mote
 * - mote-time query : ask for the FTSP-time-synchronized mote-world time.
 *
 * These services are optional, and are not main components of Tenet.
 * Ping and trace-route functionalities work only if TCMP is compiled and
 * enabled within motes.
 * - also, there must exist a route to that mote.
 * Mote-time query works only if FTSP is running on the BaseStation mote:
 * - it gets the time from the BaseStation mote.
 *
 * 'serviceAPI.*' sits on top of 'service_if.*' to provide some application
 * friendly API's. (at least that was the original purpose)
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 2/5/2007
 **/


#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include "tr_if.h"
#include "service_if.h"
#include "tosmsg.h"
#include "timeval.h"
#include "service.h"
#include "tcmp.h"

struct timeval ts_senttime; // for debugging purpose

/**
 * send ping to 'addr' through socket 'tr_fd';
 * (assumes a transport layer on the other side of tr_fd).
 **/
int tr_ping(int tr_fd, uint16_t addr) {
    int ok;
    ok = write_transport_msg(tr_fd, NULL, 0, TRANS_TYPE_PING, 0, addr);
    if (ok >= 0) {
        if (addr == 65535) {
            printf("WARNING: You have broadcasted(0xffff) a ping.\n");
            printf(" - Since ping rely on unicast routing, this will only ping 1-hop nodes\n");
        } else {
            printf(" You have pinged NODE %d\n", addr);
        }
    }
    return ok;
}

/**
 * send trace route to 'addr' through socket 'tr_fd';
 * (assumes a transport layer on the other side of tr_fd).
 **/
int tr_tracert(int tr_fd, uint16_t addr) {
    int ok;
    if (addr == 65535) {
        fprintf(stderr, " You CANNOT trace route a broadcast address.\n");
        return -1;
    }
    ok = write_transport_msg(tr_fd, NULL, 0, TRANS_TYPE_TRACERT, 0, addr);
    if (ok >= 0)
        printf(" You are attempting to trace-route NODE %d\n", addr);
    return ok;
}

int construct_motetime_query(unsigned char **ptr, uint32_t offset_sec) {
    /* 'type' and 'tid' are embedded in the messages (BaseStationServiceMsg)
       because the BaseStation does not implement any transport or routing layer.
        - 'tid' is required to return the value correctly to the intended client */
    int len = offsetof(BaseStationServiceMsg, data) + sizeof(bs_timeRequestMsg);
    unsigned char *packet = (unsigned char *) malloc(len);
    BaseStationServiceMsg *bsmsg = (BaseStationServiceMsg *) packet;
    bs_timeRequestMsg *tmsg = (bs_timeRequestMsg *) bsmsg->data;
    struct timeval curr;
    
    gettimeofday(&curr, NULL);
    memcpy(&ts_senttime, &curr, sizeof(struct timeval));
    
    bsmsg->tid = 0;
    bsmsg->type = BS_SERVICE_TIME;
    tmsg->time = (uint32_t) offset_sec;

    *ptr = packet;
    return len;
}

/**
 * send mote-world global time (FTSP time) request through socket 'tr_fd';
 * (assumes a transport layer on the other side of tr_fd).
 **/
int tr_request_motetime(int tr_fd, uint32_t offset_sec) {
    // 'tr_fd' should be the fd of the transport layer
    unsigned char *packet;
    int len, ok;
    len = construct_motetime_query(&packet, offset_sec);
    ok = write_transport_msg(tr_fd, packet, len, TRANS_TYPE_SERVICE, 0, TOS_BCAST_ADDR);
    free((void *)packet);
    return ok;
}

void request_motetime_to_sf(int sf_fd, uint16_t tid, int offset_sec) {
    unsigned char *packet;
    int len;
    len = construct_motetime_query(&packet, offset_sec);
    send_TOS_Msg(sf_fd, packet, len, AM_BS_SERVICE, TOS_BCAST_ADDR, 0x7d);
    free((void *)packet);
}

/**
 * Set the CC2420 radio RF-power of the BaseStation mote.
 * - this is not done in the form of a task, but it is done as a 
 *   special service that the master 'transport' component provides.
 */
int tr_set_bs_rfpower(int tr_fd, uint16_t power) {
    // 'tr_fd' should be the fd of the transport layer
    int len = offsetof(BaseStationServiceMsg, data) + sizeof(bs_powerMsg);
    unsigned char *packet = (unsigned char *) malloc(len);
    BaseStationServiceMsg *bsmsg = (BaseStationServiceMsg *) packet;
    bs_powerMsg *pmsg = (bs_powerMsg *) bsmsg->data;
    int ok;
    
    bsmsg->tid = 0;
    bsmsg->type = BS_SERVICE_POWER;
    pmsg->base_power = power;

    ok = write_transport_msg(tr_fd, packet, len, TRANS_TYPE_SERVICE, 0, TOS_BCAST_ADDR);
    free((void *)packet);
    return ok;
}

int tr_get_bs_rfpower(int tr_fd) {
    return tr_set_bs_rfpower(tr_fd, 0);
}

int parse_ping_response(double *rtt, uint16_t *seqno, int len, unsigned char *packet) {
    PingMsg *pmsg = (PingMsg *)packet;  // packet must be in PingMsg format
    if ((packet == NULL) || ((unsigned int)len < sizeof(PingMsg)))
        return -1;
    if (pmsg->rtt_sec == (uint32_t) -1)
        *rtt = -1.0;
    else
        *rtt = (double)((pmsg->rtt_sec*1000.0) + (pmsg->rtt_usec/1000.0));
    *seqno = pmsg->seqno;
    return 1;
}

int parse_tracert_response(uint16_t *ret_node, int *hop, double *rtt, uint16_t *seqno,
                           int len, unsigned char *packet) {
    PingMsg *pmsg = (PingMsg *)packet;  // packet must be in PingMsg format
    if ((packet == NULL) || ((unsigned int)len < sizeof(PingMsg)))
        return -1;
    if (pmsg->rtt_sec == (uint32_t) -1)
        *rtt = -1.0;
    else
        *rtt = (double)((pmsg->rtt_sec*1000.0) + (pmsg->rtt_usec/1000.0));
    *ret_node = pmsg->node;
    *hop = ((pmsg->seqno - 1)/TCMP_DEFAULT_NUM_TRACERT) + 1;
    *seqno = pmsg->seqno;
    return 1;
}

int parse_motetime_response(uint32_t *motetime, uint32_t *freq, uint16_t *root, float *skew, 
                            double *d_rtt, int len, unsigned char *packet) {
    // 'packet' must be in 'bs_timeResponseMsg' format
    bs_timeResponseMsg *tmsg = (bs_timeResponseMsg *) packet;
    struct timeval curr, rtt;
    if ((packet == NULL) || 
        ((unsigned int)len < offsetof(BaseStationServiceMsg, data) + sizeof(bs_timeResponseMsg))) {
        fprintf(stderr, "error in parse_motetime_response\n");
        return -1;
    }
    gettimeofday(&curr, NULL);
    subtract_timeval(&curr, &ts_senttime, &rtt);
    *d_rtt = (double)((rtt.tv_sec*1000.0) + (rtt.tv_usec/1000.0));
    *motetime = tmsg->time;
    *freq = tmsg->localfreq;
    *root = tmsg->root;
    *skew = tmsg->skew;
    return 1;
}

int parse_rfpower_response(uint16_t *rfpower, int len, unsigned char *packet) {
    // 'packet' must be in 'bs_timeResponseMsg' format
    bs_powerMsg *pmsg = (bs_powerMsg *) packet;
    if ((packet == NULL) || 
        ((unsigned int)len < offsetof(BaseStationServiceMsg, data) + sizeof(bs_powerMsg))) {
        fprintf(stderr, "error in parse_rfpower_response\n");
        return -1;
    }
    *rfpower = pmsg->base_power;
    return 1;
}


