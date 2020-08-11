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
 * sequence number related helper functions for transport layer.
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 2/5/2007
 **/

#ifndef _TR_SEQNO_C_
#define _TR_SEQNO_C_

#include "tr_seqno.h"

/**
 * calculate the difference in sequence number.
 * assumes that seq2 is newer than seq1, 
 * and performs seq2-seq1 considering wrap-around.
 **/
uint16_t tr_seqno_diff(uint16_t seq2, uint16_t seq1) {
    if (seq1 > seq2)
        return (TR_MAX_SEQNO + seq2 - seq1);
    return seq2 - seq1;
}

/**
 * calculate the next sequence number.
 **/
uint16_t tr_seqno_next(uint16_t seq) {
    if (seq >= TR_MAX_SEQNO)
        seq = TR_FIRST_SEQNO;
    else
        seq++;
    return seq;
}

/**
 * calculate the previous sequence number.
 **/
uint16_t tr_seqno_prev(uint16_t seq) {
    if (seq <= TR_FIRST_SEQNO)
        seq = TR_MAX_SEQNO;
    else
        seq--;
    return seq;
}

uint16_t tr_seqno_add(uint16_t a, uint16_t b) {
    uint16_t c;
    c = a + b;
    while (c > TR_MAX_SEQNO)
        c -= TR_MAX_SEQNO;
    if (c < TR_FIRST_SEQNO)
        c = TR_FIRST_SEQNO;
    return c;
}

/**
 * compare two sequence numbers.
 * @return -1 if a<b, 1 if a>b
 **/
int tr_seqno_cmp(uint16_t a, uint16_t b) {
    if (a == b) {
        return 0;
    } else if (a < b) {
        if ((b - a) <= TR_VALID_RANGE) {
            return -1;  // b is greater than a
        } else {
            uint16_t diff = tr_seqno_add(a, TR_MAX_SEQNO - b);
            if (diff < TR_VALID_RANGE)
                return 1;   // a is greater than b
        }
    } else { //if (b < a) {
        if ((a - b) <= TR_VALID_RANGE) {
            return 1;   // a is greater than b
        } else {
            uint16_t diff = tr_seqno_add(b, TR_MAX_SEQNO - a);
            if (diff < TR_VALID_RANGE)
                return -1;  // b is greater than a
        }
    }

    // This decision is uncertain since they are too far away from each other
    if (a < b) {
        return -1;  // b is greater than a
    } else { //if (b < a) {
        return 1;   // a is greater than b
    }
}

#endif

