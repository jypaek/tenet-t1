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
 * Define constants for stream transport packet logger.
 *
 * Packet size and wrap-around boundary must match with streamtransport.h
 * 'id' means the id of the logical volumes allocated for this Logger.
 * For telosB, 
 *  - there are 2 logical volumes, each with 4 physical volumes.
 *  - each volume has size of 64KB, and this must be less than
 *    the wrap-around boundary of each connection in StreamTransport
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 1/11/2007
 **/

#ifndef _STR_LOGGER_H_
#define _STR_LOGGER_H_

#include "streamtransport.h"

#if defined(PLATFORM_TELOSB) || defined(PLATFORM_TELOS)

#include "TrLoggerTelosbFlash.h"

enum {
#ifdef STR_2_CON
    STR_NUM_VOLS = 2,
    STR_NUM_REAL_VOLS = 4,
    
    STR_VOL_ID2 = VOL_ID4,
    STR_VOL_ID3 = VOL_ID5,

    STR_BLOCK_ID2 = unique("StorageManager"),
    STR_BLOCK_ID3 = unique("StorageManager"),
#else
    STR_NUM_VOLS = 1,
    STR_NUM_REAL_VOLS = 2,
#endif

    STR_VOL_ID0 = VOL_ID2,
    STR_VOL_ID1 = VOL_ID3,

    STR_BLOCK_ID0 = unique("StorageManager"),
    STR_BLOCK_ID1 = unique("StorageManager"),
};

#else

enum {
#ifdef STR_2_CON
    STR_NUM_VOLS = 2,
#else
    STR_NUM_VOLS = 1,
#endif
    STR_BYTE_EEPROM_ID = unique("ByteEEPROM")
};

#endif

#endif

