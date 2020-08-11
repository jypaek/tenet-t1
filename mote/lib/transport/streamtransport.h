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
 * Header file for stream transport (end-to-end nack based reliable transport)
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 2/5/2007
 **/


#ifndef _STREAM_TRANSPORT_H_
#define _STREAM_TRANSPORT_H_

#include "transport.h"
#include "tr_seqno.h"


#define STR_2_CON 1     // support 2 concurrent stream transport connections


/***** Packet flags, used by both MASTERS and MOTES *****/
enum {
    STR_FLAG_DATA = 0x01,
    STR_FLAG_SYN = 0x02,
    STR_FLAG_FIN = 0x04,
    STR_FLAG_ACK = 0x08,
    STR_FLAG_NACK = 0x10,
    STR_FLAG_RETX = 0x20,

    STR_FLAG_DATA_RETX = 0x21,
    STR_FLAG_SYN_ACK = 0x0a,
    STR_FLAG_FIN_ACK = 0x0c,
};


/***** Protocol constants *****/
enum {
    /***** Used by both MASTERS and MOTES *****/
    STR_NACK_MLIST_LEN = 5,             // The length of the missing list in a NACK packet
};

#ifdef BUILDING_PC_SIDE
enum {
    /***** Used by MASTERS *****/
    STR_NACK_TIMEOUT = 3000,            // When to re-send NACK (ms)
    MAX_TIMEOUT_COUNT = 50,             // connection terminate after this * NACK_TIMEOUT
    STR_CONNECTION_TIMEOUT = 120000UL,  // terminate connection if nothing received for this time
#else
#include "StrLogger.h"
enum {
    /***** Used by MOTES *****/
    STR_SYN_TIMEOUT = 2000,     // retry sending SYN after 2sec
    STR_FIN_TIMEOUT = 3000,     // 5sec (will reset after 5*MAX_RETX)
    STR_NUM_ACTIVE_CON = STR_NUM_VOLS,  // number of concurrent connections supported
    STR_RLIST_LEN = 10,         // The length of the to-recover packet list at the active end
    STR_MAX_NUM_RETX = 5,       // Maximum # of retx for SYN
    STR_DATA_LENGTH = TR_DATA_LENGTH,
#endif
};



#ifdef BUILDING_PC_SIDE
/***************************************************
  Master(PC/Stargate) side
   - Interface that the user MUST implement
***************************************************/

/* Receive packet will be signalled throuth this function.
   User of streamtransport must implement this function */
void receive_streamtransport(uint16_t tid, uint16_t src, int len, unsigned char *packet);

void streamtransport_tid_delete_done(uint16_t tid);


/***************************************************
  Interfaces that should be used by the user
  of stream transport ('transport' in our case):
***************************************************/

/* On receiving a stream transport packet from mote cloud,
   pass it to this function. */
void streamtransport_receive(int len, unsigned char *packet, uint16_t srcAddr);

void polling_streamtransport_timer();

void streamtransport_terminate();

int streamtransport_delete_tid(uint16_t tid);

int streamtransport_tid_is_alive(uint16_t tid);

#endif

#endif

