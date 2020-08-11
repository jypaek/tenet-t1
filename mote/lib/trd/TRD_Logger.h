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
 * Header file for TRD Packet Logger: TRD uses flash on the mote to
 * store all the received packet for reliable dissemination.
 * - For telosB, 
 *   - there is 1 logical volumes, each with 2 physical volumes.
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 2/26/2006
 **/



#include "trd.h"

#ifndef _TRD_LOGGER_H_
#define _TRD_LOGGER_H_

enum {
    TRD_FLASH_PKT_SIZE = TOSH_DATA_LENGTH
};


#if defined(PLATFORM_TELOSB) || defined(PLATFORM_TMOTE)
enum {
    TRD_FLASH_BYTES    = 60000UL,
    TRD_FLASH_NUM_PKTS = TRD_FLASH_BYTES/TRD_FLASH_PKT_SIZE,

    TRD_NUM_VOLS = 1,
    TRD_NUM_REAL_VOLS = 2,
    VOL_ID0 = 0,
    VOL_ID1 = 1,
    // Other VOL_ID's may be occupied by other transport
    BLOCK_ID0 = unique("StorageManager"),
    BLOCK_ID1 = unique("StorageManager"),

    FIRST_LINE_START = 0
};


#elif defined(PLATFORM_PC) // TOSSIM
#include "EEPROM.h"
enum {
    LINES_PER_PKT = (TRD_FLASH_PKT_SIZE - 1)/16 + 1,
    FLASH_NUM_LINES = 60000UL/16,
    FLASH_NUM_PKTS = FLASH_NUM_LINES/LINES_PER_PKT,
    FIRST_LINE_START = EEPROM_LOGGER_APPEND_START
};


#elif defined(PLATFORM_MICAZ) || defined(PLATFORM_MICA2) || defined(PLATFORM_MICA2DOT)
enum {
    TRD_FLASH_BYTES    = 10000UL,
    TRD_FLASH_NUM_PKTS = TRD_FLASH_BYTES/TRD_FLASH_PKT_SIZE,

    TRD_BYTE_EEPROM_ID = unique("ByteEEPROM"),
    FIRST_LINE_START = 0
};

#else // Unknown platform

#endif

#endif

