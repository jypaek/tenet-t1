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
 * Header file for the transport layer, which defines the packet format.
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 2/5/2007
 **/


#ifndef _TRANSPORT_H_
#define _TRANSPORT_H_

#include "routinglayer.h"

typedef uint16_t tid_t;

typedef struct TransportMsg {
    // Transport Layer assumes that it has a routing layer below it,
    // which can provide end-to-end source and destination addresses of the packet.
    uint16_t tid;       // TID, transaction id
    uint16_t seqno;     // sequence number used at transport layer
    uint8_t flag;       // transport protocol dependant flag
    uint8_t checksum;   // transport layer checksum
    uint8_t data[0];
}  __attribute__ ((packed)) TransportMsg;

enum {
    TR_HDR_LEN = offsetof(TransportMsg, data),    // transport msg header len.
    TR_DATA_LENGTH = RT_DATA_LENGTH - TR_HDR_LEN, // transport msg payload len.
#if defined(PLATFORM_MICA2) || defined(PLATFORM_MICA2DOT)
    TR_RETRY_TIME = 50,             // internally used retry-after-fail time.
#else
    TR_RETRY_TIME = 10,             // internally used retry-after-fail time.
#endif
    CONNECTION_TIMER_INTERVAL = 50
};

#endif

