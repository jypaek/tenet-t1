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
 *
 * @author Jeongyeup Paek (jpaek@usc.edu)
 *
 * @modified Mar/3/2009
 **/


#ifndef _FLASH_STORAGE_TASKLET_H_
#define _FLASH_STORAGE_TASKLET_H_

#if defined(PLATFORM_TELOSB) || defined(PLATFORM_TMOTE)
enum {
    FLASH_STORAGE_SIZE = 60000UL,
    VOL_ID11 = 11,
    BLOCK_ID11 = unique("StorageManager"),
};

#elif defined(PLATFORM_MICAZ) || defined(PLATFORM_MICA2) || defined(PLATFORM_MICA2DOT)
enum {
    FLASH_STORAGE_SIZE = 10000UL,
    TRD_BYTE_EEPROM_ID = unique("ByteEEPROM"),
};

#else // Unknown platform

#endif

#endif

