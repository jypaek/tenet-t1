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
 * Helper functions for sequence number manipulation in TRD.
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 8/26/2006
 **/

#include "trd_seqno.h"

uint16_t trd_seqno_next(uint16_t a) {
    if (a == TRD_SEQNO_UNKNOWN)
        a = TRD_SEQNO_FIRST;
    else if (a >= TRD_SEQNO_LAST)
        a = TRD_SEQNO_FIRST;
    else
        a++;
    return a;
}

uint16_t trd_seqno_add(uint16_t a, uint16_t b) {
    uint16_t c;
    c = a + b;
    while (c > TRD_SEQNO_LAST)
        c -= TRD_SEQNO_LAST;
    if (c < TRD_SEQNO_FIRST)
        c = TRD_SEQNO_FIRST;
    return c;
}

int trd_seqno_cmp(uint16_t a, uint16_t b) {
    if (a == b)
        return 0;

    else if ((b == TRD_SEQNO_OLDEST) || (b == TRD_SEQNO_UNKNOWN))
        return 1;   // a is greater than b
    else if ((a == TRD_SEQNO_OLDEST) || (a == TRD_SEQNO_UNKNOWN))
        return -1;  // b is greater than a

    while (a > TRD_SEQNO_LAST) a -= TRD_SEQNO_LAST;
    while (b > TRD_SEQNO_LAST) b -= TRD_SEQNO_LAST;
    //if (a < TRD_SEQNO_FIRST) a = TRD_SEQNO_FIRST;
    //if (b < TRD_SEQNO_FIRST) b = TRD_SEQNO_FIRST;

    if (a == b) {
        return 0;
    } else if (a < b) {
        if ((b - a) <= TRD_SEQNO_WRAP_WINDOW) {
            return -1;  // b is greater than a
        } else {
            uint16_t diff = trd_seqno_add(a, TRD_SEQNO_LAST - b);
            if (diff < TRD_SEQNO_WRAP_WINDOW)
                return 1;   // a is greater than b
        }
    } else { //if (b < a) {
        if ((a - b) <= TRD_SEQNO_WRAP_WINDOW) {
            return 1;   // a is greater than b
        } else {
            uint16_t diff = trd_seqno_add(b, TRD_SEQNO_LAST - a);
            if (diff < TRD_SEQNO_WRAP_WINDOW)
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

