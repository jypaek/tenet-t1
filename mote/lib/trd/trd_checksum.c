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
 * TRD checksum related functions.
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 8/27/2007
 **/

#ifndef _TRD_CHECKSUM_C_
#define _TRD_CHECKSUM_C_

#ifdef BUILDING_PC_SIDE
#include <stddef.h>
#endif
#include "trd_checksum.h"


/**
 * calculate trd checksum.
 *
 * @return calculated checksum value.
 **/

uint8_t trd_calculate_checksum(TRD_Msg *msg) {
#ifdef TRD_CHECKSUM
    uint8_t *ptr = (uint8_t *)msg;
    uint8_t len = offsetof(TRD_Msg, data) + msg->length;
    uint16_t checksum = 0;
    uint8_t i;
    for(i = 0; i < len; i++)
        checksum += ptr[i];
    checksum -= msg->checksum;
    checksum = ~checksum;
    checksum += 1;
    return (uint8_t)(checksum & 0x00ff);
#else
    return 0xff;
#endif
}

uint8_t trd_control_calculate_checksum(TRD_ControlMsg *msg) {
#ifdef TRD_CHECKSUM
    uint8_t *ptr = (uint8_t *)msg;
    uint8_t len = offsetof(TRD_ControlMsg, metadata) + (msg->num_entries * sizeof(TRD_Metadata));
    uint16_t checksum = 0;
    uint8_t i;
    for(i = 0; i < len; i++)
        checksum += ptr[i];
    checksum -= msg->checksum;
    checksum = ~checksum;
    checksum += 1;
    return (uint8_t)(checksum & 0x00ff);
#else
    return 0xff;
#endif
}

int trd_checksum_check(TRD_Msg *msg) {
#ifdef TRD_CHECKSUM
    if (trd_calculate_checksum(msg) == msg->checksum)
        return 1;
    else if (msg->checksum == 0xff)
        return 1;
    return -1;
#else
    return 1;
#endif
}

int trd_control_checksum_check(TRD_ControlMsg *msg) {
#ifdef TRD_CHECKSUM
    if (trd_control_calculate_checksum(msg) == msg->checksum)
        return 1;
    else if (msg->checksum == 0xff)
        return 1;
    return -1;
#else
    return 1;
#endif
}

#endif

