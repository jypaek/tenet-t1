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
 * Routing layer header file.
 *
 * Used by both the mote and the master routing layer and transport layer.
 *
 * @author Jeongyeup Paek
 * @author Omprakash Gnawali
 * Embedded Networks Laboratory, University of Southern California
 * @modified 1/24/2007
 **/


#ifndef _ROUTING_LAYER_H_
#define _ROUTING_LAYER_H_

#ifdef BUILDING_PC_SIDE
#include "common.h"
#endif

// Addr '0xffee' means invalid address.
// We cannot use '-1' or '0xffff' since this is braodcast address.
#define RT_INVALID_ADDR 0xffee

// We send children message to this address so that it is guaranteed
// to go to the best sink. If it is a valid address, this message
// will get routed to that source, not what we want.
#define RT_NON_EXISTENT_ADDR 0xffed
#define RT_ANY_MASTER_ADDR RT_NON_EXISTENT_ADDR

enum {
    AM_TENET_ROUTING= 0x77,     // AM type used for unicasts over routing tree in Tenet
    AM_ROUTING_BEACON = 0x01    // AM type for routing beacons
};

enum {
    PROTOCOL_PACKET_TRANSPORT = 0x10,
    PROTOCOL_STREAM_TRANSPORT = 0x20,
    PROTOCOL_RCR_TRANSPORT = 0x50,

    /* below two are not used usually */
    PROTOCOL_TCMP = 0x04,       // similar to ICMP; support for ping/tracert
    PROTOCOL_CHILD_MSG = 0x08,  // routing layer may send a packet to it's parent to update child state
    
    PROTOCOL_MASK = 0xfc,       // masking between protocol-type(above) and packet direction(below).
    
    PROTOCOL_UPLINK_BIT = 0x01,     // indicate that packet is going from mote(child) to master(parent).
    PROTOCOL_DOWNLINK_BIT = 0x02,   // indicate that packet is going from master(parent) to mote(child).
};

////////////////////////////////////////////////////////
// Addresses here (src & dst) are supposed to be 
// end-to-end addresses, not 1-hop sender & receiver.
////////////////////////////////////////////////////////
typedef struct RoutingHdr {
    uint16_t srcAddr;   // source address
    uint16_t dstAddr;   // destination address
    uint16_t prevhop;   // 1-hop sender of the packet
    uint8_t  ttl;       // time-to-live... routing layer will drop packet if ttl==0.
    uint8_t  protocol;  // describe transport layer protocol
} __attribute__ ((packed)) RoutingHdr;

enum {
    RT_DATA_LENGTH = TOSH_DATA_LENGTH - sizeof(RoutingHdr),
    RT_DEFAULT_TTL = 20,    // multihop deeper than 20-hops won't work
};

////////////////////////////////////////////////////////

#ifdef BUILDING_PC_SIDE
/**
 * read_routing_msg: takes the 'packet', and decapsulates the routing packet.
 * 'packet' should be in TOS_Msg format.
 * assumes that a 'routing msg' is encapsulated in 'packet'.
 * @return 'payload' part of the routing msg. 
 **/
void *read_routing_msg(int len, uint8_t *packet, int *paylen,
                       uint16_t *src, uint16_t *dst,
                       uint16_t *prevhop, uint8_t *protocol, uint8_t *ttl);

/** 
 * write_routing_msg: encapsulate 'payload' in a routing packet and send to 'addr'
 *
 **/
void write_routing_msg(uint8_t *payload, int len, uint8_t protocol, uint16_t addr, uint8_t ttl);
#endif

#endif // _ROUTING_LAYER_H_

