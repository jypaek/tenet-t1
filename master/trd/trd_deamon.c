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
 * An independant application that can listens to TRD related packets
 * and participate in reliable dissemination forwarding.
 *
 * Embedded Networks Laboratory, University of Southern California
 * @date Nov/18/2007
 * @author Jeongyeup Paek
 **/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/time.h>
#include <unistd.h>
#include "sfsource.h"
#include "tosmsg.h"
#include "trd_interface.h"
#include "trd_misc.h"

int fd;
uint16_t LOCAL_ADDRESS;

int main(int argc, char **argv)
{
    if (argc != 4) {
        fprintf(stderr, "Usage: %s <host> <port> <LOCAL_ADDRESS>\n", argv[0]);
        exit(2);
    }
    fd = open_sf_source(argv[1], atoi(argv[2]));
    if (fd < 0) {
        fprintf(stderr, "Couldn't open serial forwarder at %s:%s\n", argv[1], argv[2]);
        exit(1);
    }
    LOCAL_ADDRESS = (uint16_t)atoi(argv[3]);

    printf("\n# TRD Deamon..........\n\n");
    printf("    - connected-to %s:%d\n", argv[1], atoi(argv[2]));
    printf("    - LOCAL_ADDRESS = %d\n", LOCAL_ADDRESS);
    printf("    - listens to trd-related packets, and \n");
    printf("      participate in reliable broadcasting(forwarding) \n\n");

    trd_init(fd, LOCAL_ADDRESS);

    for (;;) {
        fd_set rfds;
        int ret, maxfd = -1;
        struct timeval tv;

        FD_ZERO(&rfds);
        FD_SET(fd, &rfds);
        maxfd = fd;
        tv.tv_sec = 0; tv.tv_usec = 50000; // poll trickle timer every 50ms
        ret = select(maxfd + 1, &rfds, NULL, NULL, &tv);   // block

        if (ret > 0) {
            int len;
            const unsigned char *packet;

            packet = read_sf_packet(fd, &len);
            if (!packet) exit(0);

            if (is_trd_packet(len, (void *)packet)) {
                print_trd_packet(len, (void *)packet);
                trd_dump_raw(stderr, (void *)packet, len);
                trd_receive(len, (void *)packet);
            }
            fflush(stdout);
            free((void *)packet);
        } else  if (ret == 0) {
            polling_trd_timer();
        }
    }
}

void receive_trd(int sender, int len, unsigned char *msg) {
    printf("should send this packet to application\n");
}

