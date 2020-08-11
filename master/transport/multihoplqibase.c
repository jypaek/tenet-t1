/*
* "Copyright (c) 2006~2007 University of Southern California.
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
 * Send out MultihopLQI routing protocol beacons.
 *
 * This is an optional functionality at the master transport.
 * Default behavior is that the BaseStation mote send out MultihopLQI beacons
 * so that other motes can attach to that BaseStation. And the transport layer
 * has nothing to do with this mote routing.
 * But optionally, we can substitue the BaseStation mote with a TOSBase mote
 * (which does not have routing func.), and let this module send out the
 * routing beacons so that motes can behave identically.
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 2/5/2007
 **/

#include "transportmain.h"
#include "multihoplqibase.h"
#include "transport.h"
#include "timeval.h"
#include <sys/time.h>
#include <stdlib.h>

struct timeval multihoplqi_beacon_time;
int16_t gCurrentSeqNo = 0;
extern int packets_written;


void multihoplqi_beacon_timer_fired() {
    uint8_t length = offsetof(TOS_MHopMsg, data) + sizeof(BeaconMsg);
    unsigned char *packet = malloc(length);
    TOS_MHopMsg *pMHMsg = (TOS_MHopMsg *) packet;
    BeaconMsg *pRP = (BeaconMsg *)&pMHMsg->data[0];
    int rfd = get_router_fd();
    
    if (rfd == 0) {
        fprintf(stderr, "Downlink socket to the mote cloud not initialized\n");
        fprintf(stderr, " - fail to send MultihopLQI beacon packet\n");
        return;
    }

    pRP->parent = TOS_UART_ADDR;
    pRP->cost = 0;
    pMHMsg->sourceaddr = TOS_LOCAL_ADDRESS();
    pMHMsg->originaddr = TOS_LOCAL_ADDRESS();
    pRP->hopcount = 0;
    pMHMsg->seqno = gCurrentSeqNo++;

    packets_written++;
    send_TOS_Msg(rfd, packet, length, AM_ROUTING_BEACON, TOS_BCAST_ADDR, TOS_DEFAULT_GROUP);
    
}


/********************************************************/
/**  Timer functions for Passive Connections ************/
/********************************************************/

void multihoplqi_beacon_timer_start() {
    unsigned long int interval_ms = 1024*BEACON_PERIOD;
    struct timeval curr;
    gettimeofday(&curr, NULL);
    add_ms_to_timeval(&curr, interval_ms, &multihoplqi_beacon_time);
    return;
}

void polling_multihoplqi_beacon_timer() {
    struct timeval curr;
    gettimeofday(&curr, NULL);
    if (((multihoplqi_beacon_time.tv_sec > 0) || (multihoplqi_beacon_time.tv_usec > 0))
                && (compare_timeval(&multihoplqi_beacon_time, &curr) <= 0)) {
        multihoplqi_beacon_timer_fired();
        multihoplqi_beacon_timer_start();
    }
}


