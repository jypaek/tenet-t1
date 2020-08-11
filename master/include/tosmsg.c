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
 * Functions for sending TOS_Msg packets to a socket.
 *
 * When given a payload, 'send_TOS_Msg' function
 * frames the payload to be in TOS_Msg packet format, and sends it out.
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 2/5/2007
 **/

#include "tosmsg.h"
#include "sfsource.h"
#include "sys/time.h"
#include <stdio.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>

#ifdef LOG_OUTGOING 
extern FILE *outfptr;
#endif

void fdump_packet(FILE *fptr, unsigned char *packet, int len) {
    int i;
    uint8_t *packet_ptr = (uint8_t*) packet;
    for (i = 0; i < len; i++) {
        fprintf(fptr, "%02x ", packet_ptr[i]);
    }
    fprintf(fptr, "\n");
    fflush(fptr);
};

void send_TOS_Msg(int fd, const void *data, int len, uint8_t type, uint16_t addr, uint8_t group) {
    // Here, the 'len' should mean the 'data' length, without the TOS_Msg header
    // 'data' is the payload that which a new TOS_Msg header will be prepended to
    int length = len + offsetof(TOS_Msg, data);
    unsigned char *packet = (unsigned char *) malloc(length);
    TOS_Msg *msg = (TOS_Msg *)packet;
    int ok;
    #ifdef LOG_OUTGOING 
        struct timeval tv;
    #endif

    if (data != NULL)
        memcpy(msg->data, data, len);

    msg->addr = addr;
    msg->type = type;
    msg->group = group;
    msg->length = (uint8_t) len;

    ok = write_sf_packet(fd, packet, length);
    if (ok < 0) {
        fprintf(stderr, "Note: send to socket error in tosmsg.c\n");
        exit(2);
    } else if (ok > 0)
        fprintf(stderr, "Note: write failed in tosmsg.c\n");

    #ifdef DEBUG_SEND_TOS_MSG
        printf("send_TOS_Msg: ");
        printf("addr %d, len %d, type %d, group %x, data: ", addr, len, type, group);
        fdump_packet(stdout, (unsigned char*)data, len);
    #endif
    #ifdef LOG_OUTGOING 
        gettimeofday(&tv, NULL);
        fprintf(outfptr, "%06ld.%03ld ",tv.tv_sec, tv.tv_usec/1000);
        fdump_packet(outfptr, packet, len);
    #endif

    free((void *)packet);
}

