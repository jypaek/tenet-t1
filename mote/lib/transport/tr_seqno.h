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
 * Header file for transport layer sequence numbers.
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 2/5/2007
 **/
 
#ifndef _TR_SEQNO_H_
#define _TR_SEQNO_H_

#ifdef BUILDING_PC_SIDE
#include "common.h"
#endif

enum {
    TR_FIRST_SEQNO = 1,
    TR_MAX_SEQNO = 50000U,  // should be multiples of 2*TR_FLASH_PKTS_PER_CON
    TR_VALID_RANGE = 200,   // of the difference between any two seqno that are compared
};

uint16_t tr_seqno_diff(uint16_t seq2, uint16_t seq1);
uint16_t tr_seqno_next(uint16_t seq);
uint16_t tr_seqno_prev(uint16_t seq);
uint16_t tr_seqno_add(uint16_t a, uint16_t b);
int tr_seqno_cmp(uint16_t a, uint16_t b);

#endif

