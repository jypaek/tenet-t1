/*
* "Copyright (c) 2006~2009 University of Southern California.
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
 * Header file for RCRT: Rate-controlled Reliable Transport protocol.
 *
 * - centralized rate adaptation
 * - end-2-end reliable loss recovery
 * - centralized/end-2-end rate allocation
 *
 * @author Jeongyeup Paek (jpaek@usc.edu)
 * Embedded Networks Laboratory, University of Southern California
 * @modified Aug/2/2009
 **/


#ifndef _RCRT_H_
#define _RCRT_H_

#include "transport.h"
#include "tr_seqno.h"

#define RCRT_2_CON 1    // support 2 concurrent RCRT connections

typedef struct RcrTrMsg {
    uint16_t rate;
    uint16_t fid;
    uint32_t interval;  // ms time since last feedback
    uint8_t data[0];
} __attribute__ ((packed)) rcrt_msg_t;

typedef struct RcrTrFeedback {
    uint16_t rate;
    uint16_t fid;
    uint16_t rtt;
    uint16_t cack_seqno;
    uint16_t nack_len;
    uint16_t nacklist[0];
} __attribute__ ((packed)) rcrt_feedback_t;

/***************************************************
  Common enum's (Mote and Master)
***************************************************/
enum {
    RCRT_FLAG_DATA      = 0x01,
    RCRT_FLAG_SYN       = 0x02,
    RCRT_FLAG_FIN       = 0x04,
    RCRT_FLAG_FEEDBACK  = 0x08,
    RCRT_FLAG_RETX      = 0x20,
    RCRT_FLAG_ACK_REQ   = 0x40,

    RCRT_FLAG_DATA_RETX = 0x21,
    RCRT_FLAG_SYN_ACK   = 0x12,
    RCRT_FLAG_FIN_ACK   = 0x14,
    RCRT_FLAG_SYN_NACK  = 0x82,
};

enum {
    RCRT_SYN_TIMEOUT        = 2000,     // 2sec
    RCRT_FIN_TIMEOUT        = 20000UL,  // 20sec
    RCRT_FEEDBACK_TIMEOUT   = 5000,     // 5sec
    RCRT_MAX_RTT            = 10000,    // 10sec
    RCRT_CONNECTION_TIMEOUT = 60000UL,  // 1min
    RCRT_MAX_ALIVE_TIMEOUT  = 5,        // if nothing sent for this timeout, close connection
};

enum {
    RCRT_MAX_WINDOW = 50,           // this is outstanding packet window size
    RCRT_NACK_MLIST_LEN = 10        // The length of the missing list in a NACK packet
};

#ifndef BUILDING_PC_SIDE
#include "RtrLogger.h"
enum {
    RCRT_NUM_ACTIVE_CON = RCRT_NUM_VOLS, // number of concurrent connections supported.

    RCRT_MAX_TOKENS = 1,
    RCRT_RLIST_LEN = 10,      // The length of the to-recover packet list at the active end
    RCRT_MAX_NUM_RETX = 10,   // Maximum # of retx for SYN
    RCRT_DATA_LENGTH = TR_DATA_LENGTH - offsetof(rcrt_msg_t, data),
};
#endif

#ifdef BUILDING_PC_SIDE

/***************************************************
  Interface that the user MUST implement
 ***************************************************/

/* Receive packet will be signalled throuth this function.
   User of rcrtransport must implement this function */
void receive_rcrtransport(uint16_t tid, uint16_t src, int len, unsigned char *packet);

void rcrtransport_tid_delete_done(uint16_t tid);


/***************************************************
  Interfaces that should be used by the user
  of rc transport ('transport' in our case):
 ***************************************************/

/* On receiving a rc transport packet from mote cloud,
   pass it to this function. */
void rcrtransport_receive(int len, unsigned char *packet, uint16_t srcAddr);

void polling_rcrtransport_timer();

void rcrt_configure(int setting);

void rcrtransport_terminate();

int rcrtransport_delete_tid(uint16_t tid);

int rcrtransport_tid_is_alive(uint16_t tid);

#endif

#endif
