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
#include <sys/types.h>
#include <string.h>
#include <stddef.h>
#include "sfsource.h"
#include "tr_if.h"
#include "tenet.h"
#include "service.h"
#include "service_if.h"
#include "serviceAPI.h"

extern int tr_fd;
extern int tr_opened;

void print_ping_result(uint16_t tid, uint16_t addr, double rtt, uint16_t seqno);
void print_tracert_result(uint16_t tid, uint16_t dst, uint16_t i_node, int hops, double rtt, uint16_t seq);
void print_motetime_result(uint16_t tid, uint32_t time, uint32_t freq, uint16_t root, float skew, double rtt);
void print_rfpower_result(uint16_t tid, uint16_t rfpower);


service_handler_ping_t ping_handler = NULL;
service_handler_tracert_t tracert_handler = NULL;
service_handler_motetime_t motetime_handler = NULL;
service_handler_rfpower_t rfpower_handler = NULL;


void register_ping_service_handler(service_handler_ping_t handler) {
    ping_handler = handler;
}

void register_tracert_service_handler(service_handler_tracert_t handler) {
    tracert_handler = handler;
}

void register_motetime_service_handler(service_handler_motetime_t handler) {
    motetime_handler = handler;
}

void register_rfpower_service_handler(service_handler_rfpower_t handler) {
    rfpower_handler = handler;
}

int send_ping(uint16_t addr) {
    if (!tr_opened) open_transport();
    return tr_ping(tr_fd, addr);
}

int send_tracert(uint16_t addr) {
    if (!tr_opened) open_transport();
    return tr_tracert(tr_fd, addr);
}

void send_motetime_query(uint32_t offset) { //offset is in sec
    if (!tr_opened) open_transport();
    tr_request_motetime(tr_fd, offset);
}

void send_set_rfpower(uint16_t power) { // CC2420 rf power between 3 ~ 31
    if (!tr_opened) open_transport();
    tr_set_bs_rfpower(tr_fd, power);
}

void send_get_rfpower() {
    if (!tr_opened) open_transport();
    tr_get_bs_rfpower(tr_fd);
}

void signal_ping_result(uint16_t tid, uint16_t addr, int len, unsigned char *packet) {
    double rtt;
    uint16_t seqno;
    int ok;
    if (packet == NULL) return;
    
    if (ping_handler == NULL)
        ping_handler = &print_ping_result;
        
    ok = parse_ping_response(&rtt, &seqno, len, packet);

    if (ok >= 0)
        (*ping_handler)(tid, addr, rtt, seqno);
    return;
}

void signal_tracert_result(uint16_t tid, uint16_t addr, int len, unsigned char *packet) {
    // addr is the actual destination to the trace route command
    double rtt;
    uint16_t ret_node, seqno;
    int hop;
    int ok;
    if (packet == NULL) return;

    if (tracert_handler == NULL)
        tracert_handler = &print_tracert_result;
        
    ok = parse_tracert_response(&ret_node, &hop, &rtt, &seqno, len, packet);

    if (ok >= 0)
        (*tracert_handler)(tid, addr, ret_node, hop, rtt, seqno);
    return;
}

void signal_service_result(uint16_t tid, int len, unsigned char *packet) {
    // 'packet' must be in 'BaseStationSerivceMsg' format
    BaseStationServiceMsg *bsmsg = (BaseStationServiceMsg *) packet;
    int ok = 0;
    if (packet == NULL) return;

    if (bsmsg->type == BS_SERVICE_TIME) {
        double d_rtt;
        uint32_t motetime, freq;
        uint16_t root;
        float skew; 
        if (motetime_handler == NULL) motetime_handler = &print_motetime_result;

        // 'bsmsg->data' must be in 'timeResponseMsg' format
        ok = parse_motetime_response(&motetime, &freq, &root, &skew, &d_rtt, len, bsmsg->data);

        if (ok >= 0)
            (*motetime_handler)(tid, motetime, freq, root, skew, d_rtt);
    } 
    else if (bsmsg->type == BS_SERVICE_POWER) {
        uint16_t power;
        if (rfpower_handler == NULL) rfpower_handler = &print_rfpower_result;

        // 'bsmsg->data' must be in 'timeResponseMsg' format
        ok = parse_rfpower_response(&power, len, bsmsg->data);

        if (ok >= 0)
            (*rfpower_handler)(tid, power);
    }
    return;
}

void run_ping() {
    int addr;
    printf("Enter the <address> of the mote to ping: \n");
    scanf(" %d", &addr);
    send_ping((uint16_t)addr);
}

void run_tracert() {
    int addr;
    printf("Enter the <address> of the mote to trace route: \n");
    scanf(" %d", &addr);
    send_tracert((uint16_t)addr);
}

void run_motetime_query() {
    uint32_t sec;
    printf("\nEnter : <time-offset in sec> (0 means 'now') >> ");
    scanf(" %u", &sec);
#ifdef __CYGWIN__
    printf(" Issued a mote-world global time request for %lu sec after now!!\n", sec);
#else
    printf(" Issued a mote-world global time request for %u sec after now!!\n", sec);
#endif
    printf(" (Reply may not arrive if time is not synced)\n");
    send_motetime_query(sec);
}

void run_set_rfpower() {
    int power;
    printf("\nEnter : <CC2420 rf power> >> ");
    scanf(" %d", &power);
    printf(" You have set the RF power of the BaseStation mote to %d!!\n", power);
    send_set_rfpower((uint16_t)power);
}

void print_ping_result(uint16_t tid, uint16_t addr, double rtt, uint16_t seqno) {
    if (rtt < 0.0) {
        printf(" ping timeout!! (tid %d, addr %d)\n", tid, addr);
    } else {
        printf(" received ping ack (tid %d, addr %d),", tid, addr);
        if (addr != 65535)
            printf(" rtt = %1.3lf ms, seqno=%d\n", rtt, seqno);
    }
}

void print_tracert_result(uint16_t tid, uint16_t dst, uint16_t in_node, 
                          int hops, double rtt, uint16_t seqno) {
    if (rtt < 0.0) {
        printf(" tracert timeout!! (tid %d, addr %d)\n", tid, dst);
    } else {
        printf("  - %d hop to dst %d:  node %d (tid %d, seqno %d, rtt= %1.3lfms)\n",
                 hops, dst, in_node, tid, seqno, rtt);
    }
}

void print_motetime_result(uint16_t tid, uint32_t motetime, 
                           uint32_t freq, uint16_t root, float skew, double rtt) {
#ifdef __CYGWIN__
    printf("\n The requested moteworld global time is: %lu \n", motetime);
    printf("  (tid %d, localfreq %lu, root %d, skew %f, rtt= %1.3lfms)\n", 
                tid, freq, root, skew, rtt);
#else
    printf("\n The requested moteworld global time is: %u \n", motetime);
    printf("  (tid %d, localfreq %u, root %d, skew %f, rtt= %1.3lfms)\n", 
                tid, freq, root, skew, rtt);
#endif
}

void print_rfpower_result(uint16_t tid, uint16_t power) {
    printf("\n The RF power of BaseStation mote is: %d \n", power);
}

