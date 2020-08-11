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
 * Encapsulate/Decapsulate routing layer packet:
 * Prepend/Detach routing layer header to/from the packets going 
 * through the transport layer.
 *
 * Transport layer does not perform routing.
 * But the master-side tenet stack is designed in a way such that 
 * - the 'router' below the transport only does routing (forwarding)
 *   of TOS_Msg's by looking at the src/dst/prev/nexthop addresses
 *   in the packets, and
 * - the 'router' below the transport does not alter/modify the
 *   packet itself at all.
 * - Since the transport layer needs access to the src/dst information
 *   of the packets, and since the communication between the master-side
 *   transport layer and the routing layer is socket based (rather
 *   than function calls), those information must be passed between
 *   the two layers in a form of packets anyway.
 * - So, what we do here is that, when the master transport layer
 *   sends/receives a packet to/from the routing layer, transport 
 *   layer performs the encapsulation/decapsulation of routing 
 *   layer packets.
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 2/5/2007
 **/

#include "transportmain.h"
#include "tosmsg.h"
#include "routinglayer.h"
#include "transport.h"
#include "sfsource.h"
#include <string.h>
#include <stdlib.h>
#include <stdio.h>

extern int packets_written;

/**
 * Given 'packet' and 'len', where 'packet' is in routing layer packet format
 * encapsulated in tinyos-link-layer packet format,
 * (has TOS_Msg header, and also RoutingLayer header)
 * this function removes both headers and extracts the inner payload,
 * and returns the payload in [rtmsg, *paylen] in addition to 
 * all routing layer header information such as src/dst addresses.
 **/
void *read_routing_msg(int len, uint8_t *packet, int *paylen,
                       uint16_t *srcAddr, uint16_t *dstAddr,
                       uint16_t *prevhop, uint8_t *protocol, uint8_t *ttl) {
    TOS_Msg *tosmsg = (TOS_Msg *) packet;
    RoutingHdr *rt_header;
    uint8_t *rtmsg;

    if (!packet)
        return NULL;
    if (tosmsg->type != AM_TENET_ROUTING) {
        fprintf(stderr, "[read_routing_msg] Non-routing msg received\n");
        return NULL;
    }
    if ((len != (offsetof(TOS_Msg, data) + tosmsg->length)) 
            || (tosmsg->length < sizeof(RoutingHdr))
            || (len > 128)
            || (len < sizeof(RoutingHdr))) {
        fprintf(stderr, "[read_routing_msg] Error in packet lengths:");
        fprintf(stderr, " len=%d, msg->length=%d\n", len, tosmsg->length);
        fdump_packet(stderr, packet, len);
        return NULL;
    }

    rt_header = (RoutingHdr *) tosmsg->data;
    *srcAddr = rt_header->srcAddr;
    *dstAddr = rt_header->dstAddr;
    *prevhop = rt_header->prevhop;
    *protocol = rt_header->protocol;
    *ttl = rt_header->ttl;

    *paylen = len - sizeof(RoutingHdr) - offsetof(TOS_Msg, data);
    //rtmsg = malloc(*paylen);
    //memcpy(rtmsg, &tosmsg->data[sizeof(RoutingHdr)], *paylen); 
    rtmsg = (uint8_t *)&tosmsg->data[sizeof(RoutingHdr)];
    return rtmsg;
}


/**
 * Encapsulate 'msg' in routing layer packet format and 
 * send it out to 'send_TOS_Msg' function which will again
 * encapsulate the packet in TOS_Msg format and send it 
 * down to the routing layer.
 **/
void write_routing_msg(uint8_t *msg, int len, uint8_t protocol, uint16_t addr, uint8_t ttl) {
    uint8_t *packet;
    RoutingHdr *header;
    uint8_t type = AM_TENET_ROUTING;
    int rt_fd = get_router_fd();

    if (len <= 0)
        return;
    packet = malloc(len + sizeof(RoutingHdr));
    header = (RoutingHdr *) packet;
    memcpy(&packet[sizeof(RoutingHdr)], msg, len);
    header->srcAddr = (uint16_t) TOS_LOCAL_ADDRESS();
    header->dstAddr = (uint16_t) addr;
    header->prevhop = (uint16_t) TOS_LOCAL_ADDRESS();
    header->ttl = ttl;
    header->protocol = protocol | PROTOCOL_DOWNLINK_BIT;
    len += sizeof(RoutingHdr);

    packets_written++;
    send_TOS_Msg(rt_fd, packet, len, type, addr, TOS_DEFAULT_GROUP);
    free((void *)packet);
    return;
}

