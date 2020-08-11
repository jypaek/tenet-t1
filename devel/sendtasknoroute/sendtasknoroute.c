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
 * 'sendtasknoroute' sends a task to the network.
 *
 *
 * @author Jeongyeup Paek
 *
 * @modified Mar/12/2007
 **/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include "tenet_task.h"
#include "tosmsg.h"
#include "tosserial.h"
#include "sfsource.h"
#include "serialsource.h"
#include "task_construct.h"

int sf_fd;              // serial forwarder socket fd
serial_source src = 0;  // serial port source
int fromsf = -1;        // whether we are connecting to sf or serial

uint16_t MY_ADDR = 1;
int MY_TID = 10;

void print_usage() {
    printf("Send a task command to the network. \n");
    printf("Usage: \n");
    printf("      sendtasknoroute [-hs] sf     [host] [port]     \"string to task\" \n");
    printf("      sendtasknoroute [-hs] serial [dev]  [baudrate] \"string to task\" \n");
    printf("Options: \n");
    printf("  h : display this help message.\n");
    exit(1);
}

void send_close_task() {
    int len = offsetof(link_hdr_t, data) + offsetof(task_msg_t, data);
    unsigned char *packet = (unsigned char *) malloc(len);
    link_hdr_t *lPkt = (link_hdr_t *) packet;
    task_msg_t *tMsg = (task_msg_t *) lPkt->data;
   
    printf("closing tid %d\n", MY_TID);

    lPkt->tid = MY_TID;
    lPkt->src = MY_ADDR;
    tMsg->type = TASK_DELETE; // DELETE @ mote/lit/tenet_task.h
    tMsg->numElements = 0;

    if (fromsf == 1)
        send_TOS_Msg(sf_fd, packet, len, 0x07, 0xffff, 0x7d);
    else
        send_TOS_Msg_serial(src, packet, len, 0x07, 0xffff, 0x7d);

    free((void *)packet);
}

void sig_int_handler(int signo) {
    send_close_task();
    exit(0);
}

void send_task(char *task_string) {
    unsigned char packet[300];
    link_hdr_t *lPkt = (link_hdr_t *) packet;
    int len, i;

    lPkt->tid = MY_TID;
    lPkt->src = MY_ADDR;
    len = construct_task(lPkt->data, task_string);  // construct a task packet
    if (len < 0) {
        fprintf(stderr,"task description error!! \n");
        return;
    }
    len += offsetof(link_hdr_t, data);

    printf("Task string ....... : %s\n", task_string);
    printf("Task packet length  : %d\n", len);
    printf("Task packet         : ");
    for (i = 0; i < len; i++) printf("%02x ", lPkt->data[i]);
    printf("\n");

    if (fromsf == 1)
        send_TOS_Msg(sf_fd, packet, len, 0x07, 0xffff, 0x7d);
    else
        send_TOS_Msg_serial(src, packet, len, 0x07, 0xffff, 0x7d);
}

int main(int argc, char **argv){
    char task_string[500];
    int c;
    int simple = 0;

    if(signal(SIGINT, sig_int_handler) == SIG_ERR)
        fprintf(stderr, "Warning: failed to set SINGINT handler");

    /* parse option line */
    while ((c = getopt(argc, argv, "hs")) != -1) {
        switch (c) {
            case 's':
                simple = 1; break;
            case 'h':
            default:
                print_usage();
                exit(1);
        }
    }

    if (optind + 4 > argc) {
        print_usage();
    }

    if (strncasecmp(argv[optind], "sf", 2) == 0) {
        sf_fd = open_sf_source(argv[optind+1], atoi(argv[optind+2]));
        if (sf_fd < 0) {
            fprintf(stderr, "Couldn't open serial forwarder at %s:%s\n", argv[optind+1], argv[optind+2]);
            exit(1);
        }
        fromsf = 1;
    } else if (strncasecmp(argv[optind], "serial", 2) == 0) {
        src = open_serial_source(argv[optind+1], atoi(argv[optind+2]), 0, stderr_serial_msg);
        if (!src) {   
            fprintf(stderr, "Couldn't open serial port at %s:%s\n", argv[optind+1], argv[optind+2]);
            exit(1);
        }
        fromsf = 0;
    }
    optind += 3;

    /* either one of 'sf' or 'serial' must have been selected */
    if (fromsf < 0)
        print_usage();

    printf("string: %s\n", argv[optind]);

    /* get string input */
    if (optind < argc) {
        strcpy(task_string, argv[optind]);
    } else {
        print_usage();
    }

    send_task(task_string);

    /* receive response packets */
    while(1) {
        unsigned char *packet;
        TOS_Msg *tosmsg;
        int len;

        /* read packet from serial or serial forwarder */
        if (fromsf == 1) {
            packet = read_sf_packet(sf_fd, &len);
        } else {
            packet = read_serial_packet(src, &len);
        }

        if (!packet) exit(0);

        tosmsg = (TOS_Msg *) packet;

        if (tosmsg->type == 0x07) {
            link_hdr_t *lmsg = (link_hdr_t *) tosmsg->data;
            unsigned char *payload = lmsg->data;
            unsigned char *nextptr = payload;
            int offset = 0;
            int l = tosmsg->length - offsetof(link_hdr_t, data);

            while (offset < l) {
                attr_t *attr = (attr_t *)nextptr;
                int i, data;

                printf("%d ", attr->type);
                for (i = 0; i < attr->length; i += 2) {
                    if (i == (attr->length - 1))
                        data = (uint16_t) *((uint8_t*)&attr->value[i]); // take care of odd number bytes
                    else
                        data = (uint16_t) *((uint16_t*)&attr->value[i]);

                    printf("%d ", data);
                }
                printf("\n ");
                offset += offsetof(attr_t, value) + attr->length;
                nextptr = payload + offset;
            }
        } else {
            int i;
            printf("Unknown: ");
            for (i = 0; i < len; i++) printf("%02x ", packet[i]);
            printf("\n");
        }
        fflush(stdout);
        free((void *)packet);
    }
    return 0;
}

