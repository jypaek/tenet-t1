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


#ifndef _TCMP_H
#define _TCMP_H

#include "common.h"
#include <sys/time.h>

/* This msg is a 'payload' encapsulated in 'transport interface packet'
   which comes from transport layer to the application */
typedef struct PingMsg {
    uint32_t rtt_sec;
    uint32_t rtt_usec;
    uint16_t seqno;
    uint16_t node;
}  __attribute__ ((packed)) PingMsg;


// Below flags are the flags that are in the 'type' field of transport packet.
// TCMP module is also regarded as another transport layer
enum {
    TCMP_FLAG_PING = 0x10,
    TCMP_FLAG_PING_ACK = 0x18,

    TCMP_FLAG_TRACERT = 0x20,
    TCMP_FLAG_TRACERT_ACK = 0x28,
};

enum {
    TCMP_DEFAULT_NUM_PING = 5,
    TCMP_DEFAULT_NUM_TRACERT = 3,
    TCMP_TIMEOUT = 5000,   // in milli seconds..
};

struct tcmplist {
    struct tcmplist *next;  // linked list pointer
    uint8_t type;           // PING or TRACERT
    uint16_t tid;              // tid of this transactions
    uint16_t addr;          // destination address, usually the target mote
    uint16_t seqno;
    uint8_t ttl;
    struct timeval sent_time;
    struct timeval alarm_time;
};

void receive_TCMP_ping_ack(uint16_t tid, uint16_t addr, int len, unsigned char *msg);
void receive_TCMP_tracert_ack(uint16_t tid, uint16_t addr, int len, unsigned char *msg);

void TCMP_receive(int len, uint8_t *rtmsg, uint16_t srcAddr, uint16_t dstAddr, uint8_t ttl);
void TCMP_send_ping(uint16_t tid, uint16_t addr);
void TCMP_send_tracert(uint16_t tid, uint16_t addr);

void polling_tcmp_timer();
#endif

