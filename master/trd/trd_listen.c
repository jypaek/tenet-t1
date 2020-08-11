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
 * An independant application that can listens to TRD related packets,
 * but does not participate in reliable dissemination forwarding.
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 2/25/2006
 **/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/time.h>
#include "sfsource.h"
#include "serialsource.h"
#include "tosmsg.h"
#include "trd_misc.h"


int fromsf = 0;
int fd;
serial_source src = 0;


static char *msgs[] = { 
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

void stderr_msg(serial_source_msg problem) {
    fprintf(stderr, "Note: %s\n", msgs[problem]);
}


int main(int argc, char **argv)
{
    if (argc != 4) {
        fprintf(stderr, "Usage: %s sf     <host>   <port>\n", argv[0]);
        fprintf(stderr, "Usage: %s serial <device> <baudrate>\n", argv[0]);
        exit(2);
    }
    if (strncmp(argv[1], "sf", 2) == 0) {
        fd = open_sf_source(argv[2], atoi(argv[3]));
        if (fd < 0) {
            fprintf(stderr, "Couldn't open serial forwarder at %s:%s\n", argv[2], argv[3]);
            exit(1);
        }
        fromsf = 1;
    }
    else {
        src = open_serial_source(argv[2], atoi(argv[3]), 0, stderr_msg);
        if (!src) {   
            fprintf(stderr, "Couldn't open serial port at %s:%s\n", argv[2], argv[3]);
            exit(1);
        }   
    }

    printf("\n# TRD Listen..........\n\n");
    printf("    - connected to serial (forwarder) at %s:%s\n", argv[2], argv[3]);
    printf("    - snoops any trd related packets without participating in it.\n\n");

    for (;;) {
        int len;
        unsigned char *packet;

        if (fromsf == 1) {
            packet = read_sf_packet(fd, &len);
        } else {
            packet = read_serial_packet(src, &len);
        }

        if (!packet) exit(0);

        if (is_trd_packet(len, (void *)packet)) {
            print_trd_packet(len, (void *)packet);
            //printf(">> ");
            //trd_dump_raw(stdout, (void *)packet, len);
        }
        fflush(stdout);
        free((void *)packet);
    }
}

