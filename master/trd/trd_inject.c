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
 * An independant application that can inject and disseminate arbitrary 
 * packet into the network (for TRD testing purpose).
 * - this runs on top of sf, and sf should run on top of TOSBase mote
 *
 * Embedded Networks Laboratory, University of Southern California
 * @date Nov/18/2007
 * @author Jeongyeup Paek
 **/
 
#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <unistd.h>
#include <sys/time.h>
#include "sfsource.h"
#include "tosmsg.h"
#include "trd_interface.h"
#include "trd_misc.h"

int sf_fd;
uint16_t LOCAL_ADDRESS;

int sendReady = 0;

int send_packet(int len, unsigned char *packet) {
    int seqno;
    seqno = (int)trd_send(len, packet);
    if (seqno <= 0) {
        printf("send_packet: failed.\n");
    }
    printf("\n");
    printf("# Packet: ");
    trd_dump_raw(stdout, packet, len);
    printf("# ... has been sent to the sf with trd sequence number %d!!\n\n", seqno);
    return seqno;
}

int main(int argc, char **argv)
{
    if (argc < 4) {
        fprintf(stderr, " Usage: %s <host> <port> <LOCAL_ADDRESS>\n", argv[0]);
        exit(2);
    }
    sf_fd = open_sf_source(argv[1], atoi(argv[2]));
    if (sf_fd < 0) {
        fprintf(stderr, "Couldn't open serial forwarder at %s:%s\n",
            argv[1], argv[2]);
        exit(1);
    }
    LOCAL_ADDRESS = (uint16_t)atoi(argv[3]);

    printf("\n# TRD Inject..........\n");
    printf("#   - connected-to %s:%d\n", argv[1], atoi(argv[2]));
    printf("#   - LOCAL_ADDRESS = %d\n", LOCAL_ADDRESS);
    printf("#   - listens to trd-related packets, \n");
    printf("#     participate in reliable broadcasting, \n");
    printf("#     and inject packets into the network. \n\n");

    trd_init(sf_fd, LOCAL_ADDRESS);
    printf("# TRD initializing...\n");

    for (;;) {
        fd_set rfds;
        int ret;
        struct timeval tv;

        FD_ZERO(&rfds);
        FD_SET(sf_fd, &rfds);
        FD_SET(0, &rfds);
        tv.tv_sec = 0; tv.tv_usec = 50000; // poll trd timer every 50ms

        ret = select(sf_fd + 1, &rfds, NULL, NULL, &tv);   // block

        if ((!sendReady) && (is_trd_sendReady())) {
            sendReady = 1;
            printf("# Ready to send! (press 'ENTER' to inject msg)\n");
        }

        if (ret < 0) continue;
        if (ret == 0) {
            polling_trd_timer();
            continue;
        }

        if (FD_ISSET(sf_fd, &rfds)) {   // received a packet from the serial forwarder
            int len;
            const unsigned char *packet = read_sf_packet(sf_fd, &len);

            if (!packet) exit(0);

            if (is_trd_packet(len, (void *)packet)) {
                //print_trd_packet(len, (void *)packet);
                trd_receive(len, (void *)packet);
            }
            fflush(stdout);
            free((void *)packet);
        } 
        if (FD_ISSET(0, &rfds)) {
            int input, ok;
            int len = 0;
            unsigned char *buffer;

            if (!sendReady) {
                printf("# Not ready to send yet... press enter\n");
                getchar();
                continue;
            }
            buffer = (void *)malloc(128);
            printf("# Enter payload (each byte in Hex)('q' to finish)\n");
            printf("#  (ex> 00 01 02 aa bb ff 00 q) >>  ");
            while(len < 114) {
                ok = scanf(" %x", &input);
                if ((ok == 0) || (input > 255) || (input < 0)) {
                    char c[4];
                    ok = scanf(" %s", c);
                    break;
                }
                buffer[len++] = (uint8_t)input;
            }
            if (len > 0) {
                send_packet(len, buffer);
            }
            free(buffer);
        }
    }

}

void receive_trd(int sender, int len, unsigned char *msg) {
    printf("# Received TRD msg, should pass this packet to application >> \n");
    trd_dump_raw(stdout, msg, len);
}

