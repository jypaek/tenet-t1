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
 * Common header file for transport layer (ex, StreamTransport) pkt loggers.
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 2/5/2007
 **/

#ifndef _TR_LOGGER_MOTE_H_
#define _TR_LOGGER_MOTE_H_

#include "tr_seqno.h"

enum {
    TR_FLASH_INIT = 0x01,
    TR_FLASH_IDLE = 0x02,
    TR_FLASH_BUSY = 0x10,
};

struct eepromData {
    uint8_t cid;    // internal connection id, rather than the tid. (save search)
    uint8_t length;
    uint16_t seqno;
    uint8_t msg[TR_DATA_LENGTH];
};

enum {
    TR_FLASH_BYTES_PER_PKT = sizeof(struct eepromData),
    TR_FLASH_PKTS_PER_CON = 500,    // TR_MAX_SEQNO should be even-multiples (2,4,6,etc) of this.
    // If TELOSB, cannot exceed 64KB
    TR_FLASH_BYTES_PER_CON = TR_FLASH_BYTES_PER_PKT * TR_FLASH_PKTS_PER_CON,
};

struct bufferInfo {
    uint8_t ready;
    uint8_t currVol;  // primary(0) or secondary(1)
    uint8_t dirty0;
    uint8_t dirty1;
    uint16_t nextIndex;
};

enum {  // Logger initialization states within *LoggerTelosM
    S_MOUNT = 1,    // in the process of mounting, immediately after bootup.
    S_INIT,         // init state, erasing all volumes after mounting.
    S_IDLE,         // normal state
    S_ERASE_VOL,    // erasing one logical volume
};  

#endif

