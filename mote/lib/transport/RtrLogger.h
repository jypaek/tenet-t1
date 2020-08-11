/*
* "Copyright (c) 2006~2008 University of Southern California.
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
 * RCRT_Logger
 * - RcrTransport Packet Logger
 * - This interface is 'RcrTransport' specific.
 * - Packet size and wrap-around boundary must match with rctransport.h
 *
 * @author Jeongyeup Paek
 * @modified May/22/2008
 **/


#ifndef _RCRT_PKT_LOGGER_H
#define _RCRT_PKT_LOGGER_H

#include "rcrtransport.h"

#if defined(PLATFORM_TELOSB) || defined(PLATFORM_TELOS)

#include "TrLoggerTelosbFlash.h"

enum {
#ifdef RCRT_2_CON
    RCRT_NUM_VOLS = 2,
    RCRT_NUM_REAL_VOLS = 4,
    
    RCRT_VOL_ID2 = VOL_ID8,
    RCRT_VOL_ID3 = VOL_ID9,

    RCRT_BLOCK_ID2 = unique("StorageManager"),
    RCRT_BLOCK_ID3 = unique("StorageManager"),
#else
    RCRT_NUM_VOLS = 1,
    RCRT_NUM_REAL_VOLS = 2,
#endif

    RCRT_VOL_ID0 = VOL_ID6,
    RCRT_VOL_ID1 = VOL_ID7,

    RCRT_BLOCK_ID0 = unique("StorageManager"),
    RCRT_BLOCK_ID1 = unique("StorageManager"),
};

#else

enum {
#ifdef RCRT_2_CON
    RCRT_NUM_VOLS = 2,
#else
    RCRT_NUM_VOLS = 1,
#endif
    RCRT_BYTE_EEPROM_ID = unique("ByteEEPROM")
};

#endif

#endif

