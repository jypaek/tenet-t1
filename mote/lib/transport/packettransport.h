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
 * Header file for packet transport (end-to-end ack-based reliable transport).
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 2/5/2007
 **/

#ifndef _PACKET_TRANSPORT_H_
#define _PACKET_TRANSPORT_H_

#include "transport.h"


/***************************************************
  Common enum's (Mote and Master)
***************************************************/
enum {
#if defined(PLATFORM_TELOSB) || defined (PLATFORM_TMOTE)
    PTR_NUM_ONESHOT = 7,   // Number of pending one-shots. Need this to maintain ACK timer.
#elif defined(PLATFORM_IMOTE2)
    PTR_NUM_ONESHOT = 10,
#elif defined(PLATFORM_MICAZ) || defined(PLATFORM_MICA2) || defined(PLATFORM_MICA2DOT) || defined(PLATFORM_EMSTAR)
    PTR_NUM_ONESHOT = 3,
#endif
    PTR_MAX_NUM_RETX = 5,   // Maximum # of end-to-end retx for sendOneShot packets.
};

enum {
    PTR_FLAG_SEND = 0x40,
    PTR_FLAG_ACK = 0x48,
    PTR_FLAG_NOACK_SEND = 0xff
};

enum {
    PTR_ACK_TIMEOUT = 3000,    // 3 sec, End-to-end ACK timeout
};


#ifdef BUILDING_PC_SIDE
/***************************************************
  Interfaces that the user MUST implement
***************************************************/

/* Receive packet will be signalled throuth this function.
   User of packettransport must implement this function */
void receive_packettransport(uint16_t tid, uint16_t addr, 
                             int len, unsigned char *packet);

void senddone_packettransport(uint16_t tid, uint16_t addr, 
                              int len, unsigned char *packet, int success);


/***************************************************
  Interfaces that should be used by the user
  of packet transport ('transport' in our case):
***************************************************/

/* On receiving a packet transport packet from mote cloud,
   pass it to this function. */
void packettransport_receive(int len, unsigned char *packet, uint16_t addr);

void packettransport_tid_delete_done(uint16_t tid);


/* Send an unicast packet to any node using 
   end-to-end ACK based packet transport */
int packettransport_send(uint16_t tid, uint16_t addr, uint8_t len, unsigned char* packet);

void polling_packettransport_timer();

void packettransport_terminate();

int packettransport_delete_tid(uint16_t tid);

int packettransport_tid_is_alive(uint16_t tid);

#endif

#endif

