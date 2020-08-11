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
 * Header file for sequence number related stuff in TRD.
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 8/26/2006
 **/


#ifndef _TRD_SEQNO_H_
#define _TRD_SEQNO_H_

#ifdef BUILDING_PC_SIDE
#include <sys/types.h>
#ifdef __CYGWIN__
#include <windows.h>
#include <io.h>
#else
#include <stdint.h>
#endif
#endif

enum {
    // TRD_ will use seqno FIRST ~ LAST
    // TRD_ will use seqno 1 ~ 5000
    TRD_SEQNO_UNKNOWN          = 0x0000,
    TRD_SEQNO_FIRST            = 0x0001, // 1
    TRD_SEQNO_LAST             = 0x1388, // 50000
    TRD_SEQNO_OLDEST           = 0xfffd,
    TRD_SEQNO_WRAP_WINDOW      = 0x10,   // 32
};

typedef uint8_t trd_class_t;

enum {
    TRD_CLASS_UNKNOWN  = 0x00,  // don't know
    TRD_CLASS_NEXT_NEW = 0x01,  // not in the cache, next one that we expect
    TRD_CLASS_NEWER    = 0x02,  // not in the cache, slightly newer
    TRD_CLASS_TOO_NEW  = 0x04,  // not in the cache, jump in seqno
    TRD_CLASS_IN_LAST  = 0x08,  // in the cache, lastest of what we have
    TRD_CLASS_IN_OLD   = 0x10,  // in the cache, but not the latest
    TRD_CLASS_TOO_OLD  = 0x20,  // not in the cache, lower than what we have
    TRD_CLASS_NULL     = 0x80,  // origin not known, FAIL to classify
};

uint16_t trd_seqno_next(uint16_t a);
uint16_t trd_seqno_add(uint16_t a, uint16_t b);
int trd_seqno_cmp(uint16_t a, uint16_t b);

#endif

