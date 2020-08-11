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
 * Transport layer checksum related functions.
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 8/27/2007
 **/

#ifndef _TR_CHECKSUM_C_
#define _TR_CHECKSUM_C_

#include "tr_checksum.h"


/**
 * calculate transport layer checksum.
 *
 * @return calculated checksum value.
 **/
uint8_t tr_calculate_checksum(TransportMsg *msg, uint8_t datalen) {
#ifdef TR_CHECKSUM
    uint8_t *ptr = (uint8_t *)msg;
    uint8_t i;
    uint8_t checksum = 0;
    for(i = 0; i < offsetof(TransportMsg, data) + datalen; i++)
        checksum += ptr[i];
    checksum -= msg->checksum;
    checksum = ~checksum;
    checksum += 1;
    return (uint8_t)(checksum & 0x00ff);
#else
    return 0xff;
#endif
}


/**
 * check whether the checksum value is correct.
 *
 * @return 1 if checksum is correct, 0 otherwise.
 **/
int tr_checksum_check(TransportMsg *msg, uint8_t len) {
#ifdef TR_CHECKSUM
    if (tr_calculate_checksum(msg, len) == msg->checksum)
        return 1;
    else if (msg->checksum == 0xff)
        return 1;
    return -1;
#else
    return 1;
#endif
}

#endif

