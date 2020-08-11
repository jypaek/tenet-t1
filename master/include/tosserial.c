/*
* "Copyright (c) 2006~2008 University of Southern California.
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
 * Functions for sending TOS_Msg packets to serial port
 *
 * @modified Feb/25/2008
 * @author Jeongyeup Paek (jpaek@enl.usc.edu)
 *
 * Embedded Networks Laboratory, University of Southern California
 **/

#include "tosmsg.h"
#include "serialsource.h"
#include "sys/time.h"
#include <stdio.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>


/************************************************************************************/
/* for directly connecting to serial port instead of going through serial forwarder */

static char *serial_err_msgs[] = { 
  "unknown_packet_type",
  "ack_timeout" ,
  "sync"        ,
  "too_long"    ,   
  "too_short"   ,   
  "bad_sync"    ,   
  "bad_crc"     ,   
  "closed"      ,   
  "no_memory"   ,   
  "unix_error"
};
void stderr_serial_msg(serial_source_msg problem) {
    fprintf(stderr, "Note: %s\n", serial_err_msgs[problem]);
}

void send_TOS_Msg_serial(serial_source src, const void *data, int len, uint8_t type, uint16_t addr, uint8_t group) {
    int length = len + offsetof(TOS_Msg, data);
    unsigned char *packet = (unsigned char *) malloc(length);
    TOS_Msg *msg = (TOS_Msg *)packet;
    int ok;

    if (data != NULL)
        memcpy(msg->data, data, len);

    msg->addr = addr;
    msg->type = type;
    msg->group = group;
    msg->length = (uint8_t) len;

    ok = write_serial_packet(src, packet, length);

    if (ok < 0) {
        fprintf(stderr, "Note: send to socket error in tosmsg.c\n");
        exit(2);
    } else if (ok > 0)
        fprintf(stderr, "Note: write failed in tosmsg.c\n");

    free((void *)packet);
}

