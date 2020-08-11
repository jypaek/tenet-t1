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
 * Snoop(listen to) tenet-related packets over sf(serial forwarder)
 * and show packet header information on stdout.
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 2/17/2007
 **/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/time.h>
#include <time.h>
#include "sfsource.h"
#include "timeval.h"
#include "tosmsg.h"
#include "tosserial.h"
#include "trd_transportmsg.h"
#include "trd_fragmentmsg.h"
#include "trd.h"
#include "trd_misc.h"
#include "routinglayer.h"
#include "transport.h"
#include "TimeSyncMsg.h"
#include "MultiHop.h"
#include "tenet_task.h"
#include "nx.h"

extern int optind;
int c;
int fd;
serial_source src;
int fromsf = -1;
int timestamp = 0;
int payload = 0;
int len;
const unsigned char *packet;
TOS_Msg *tosmsg;

void print_trd_transport_msg(int len, unsigned char *msg);

void print_usage(char **argv) {
    printf("Usage: %s [-tp]   sf   <host> <port>\n", argv[0]);
    printf("Usage: %s [-tp] serial <dev> <baudrate>\n", argv[0]);
    printf("\nOptions:\n");
    printf(" -t :  print the timestamp (master time, in milliseconds)\n");
    printf(" -p :  print the payload of every packet\n");
    printf("\n");
    exit(1);
}

int main(int argc, char **argv)
{
    printf("\n# Tenet packet snoop..........\n\n");

    if ((argc < 3) || (argc > 5)) {
        print_usage(argv);
        exit(2);
    }
    while ((c = getopt(argc, argv, "tph")) != -1) {
        switch(c) {
            case 't':
                timestamp = 1;
                break;
            case 'p':
                payload = 1;
                break;
            case 'h':
            case '?':
            default:
                print_usage(argv);
        }
    }

    if (strncasecmp(argv[optind], "sf", 2) == 0) {
        fd = open_sf_source(argv[optind+1], atoi(argv[optind+2]));
        if (fd < 0) {
            fprintf(stderr, "Couldn't open serial forwarder at %s:%s\n", argv[optind+1], argv[optind+2]);
            exit(1);
        }
        printf("    - connected to serial forwarder at %s:%d\n", argv[optind+1], atoi(argv[optind+2]));
        fromsf = 1;
    } else if (strncasecmp(argv[optind], "serial", 2) == 0) {
        src = open_serial_source(argv[optind+1], atoi(argv[optind+2]), 0, stderr_serial_msg);
        if (!src) {   
            fprintf(stderr, "Couldn't open serial port at %s:%s\n", argv[optind+1], argv[optind+2]);
            exit(1);
        }
        printf("    - connected to serial port at %s:%d\n", argv[optind+1], atoi(argv[optind+2]));
        fromsf = 0;
    } else {
        print_usage(argv);
    }

    printf("    - should run on top of a TOSBase mote, or equivalent\n");
    printf("    - snoops any tenet related packets without participating in it.\n\n");


    for (;;) {
        /* read packet from serial or serial forwarder */
        if (fromsf == 1) {
            packet = read_sf_packet(fd, &len);
        } else {
            packet = read_serial_packet(src, &len);
        }

        tosmsg = (TOS_Msg *) packet;

        if (!packet)
            exit(0);

        if (timestamp) {
            time_t m_time = time(NULL);
            struct tm *tt = localtime(&m_time);
            printf("%02d:%02d:%02d ", tt->tm_hour, tt->tm_min, tt->tm_sec);
            //printf("%lu ", gettimeofday_ms());
        }

        if (tosmsg->type == AM_TRD_MSG) {
            print_trd_transport_msg(len, (uint8_t *)tosmsg->data);
        } else if (tosmsg->type == AM_TRD_CONTROL) {
            TRD_ControlMsg *cmsg = (TRD_ControlMsg *) tosmsg->data;
            if (cmsg->control_type == TRD_CONTROL_SUMMARY)  {
                print_trd_summary(len, (uint8_t *)tosmsg->data);
            } else if (cmsg->control_type == TRD_CONTROL_REQUEST) {
                print_trd_request(len, (uint8_t *)tosmsg->data, tosmsg->addr);
            } else {
                printf("bug?\n");
            }
        } else if (tosmsg->type == AM_TIMESYNCMSG) {
            TimeSyncMsg *ts = (TimeSyncMsg *)tosmsg->data;
            printf("timesync beacon (node %2d, root %2d, seq %d, senttime %u)\n",
                    nxs(ts->nodeID), nxs(ts->rootID), ts->seqNum, nxl(ts->sendingTime));
        } else if (tosmsg->type == AM_ROUTING_BEACON) {
            TOS_MHopMsg *tm = (TOS_MHopMsg *)tosmsg->data;
            BeaconMsg *bm = (BeaconMsg *)tm->data;
            printf("routing beacon (node %2d, parent %2d, cost %d, hop %d, seqno %d)\n",
                    tm->sourceaddr, bm->parent, bm->cost, bm->hopcount, tm->seqno);
        } else if (tosmsg->type == AM_TENET_ROUTING) {
            RoutingHdr *rt = (RoutingHdr *) tosmsg->data;
            uint8_t protocol = rt->protocol & PROTOCOL_MASK;
            uint8_t flag = rt->protocol & ~PROTOCOL_MASK;
            int transport = 0;
            TransportMsg *tr = (TransportMsg *)&tosmsg->data[sizeof(RoutingHdr)];
            
            printf("tenet unicast (src %2d, dst %2d, prev %2d, next %2d, ttl %2d, proto 0x%2X)",
                    rt->srcAddr, rt->dstAddr, rt->prevhop, tosmsg->addr, rt->ttl, protocol);
                    
            if (flag & PROTOCOL_UPLINK_BIT)
                printf(", up-tree");
            else if (flag & PROTOCOL_DOWNLINK_BIT)
                printf(", downtree");
            else
                printf(", unknown direction");
                
            if (protocol == PROTOCOL_PACKET_TRANSPORT) {
                printf(", packet transport");
                transport = 1;
            } else if (protocol == PROTOCOL_STREAM_TRANSPORT) {
                printf(", stream transport");
                transport = 1;
            } else if (protocol == PROTOCOL_TCMP) {
                printf(", tcmp debugging");
            } else if (protocol == PROTOCOL_CHILD_MSG) {
                printf(", children msg (routing helper)");
            } else if (protocol == PROTOCOL_RCR_TRANSPORT) {
                printf(", rcrt");
                transport = 1;
            } else {
                printf(", unknown transport");
            }

            if (transport) {
                printf(" (tid %d, seqno %d, flag 0x%02X) ", tr->tid, tr->seqno, tr->flag);
            }
            if (payload)
                fdump_packet(stdout, tr->data, tosmsg->length - sizeof(RoutingHdr) - offsetof(TransportMsg, data));
            else
                printf("\n");
        } else {
            printf("unidentified packet received... bug? are you using tenet?\n");
            if (payload)
                fdump_packet(stdout, (uint8_t *)packet, len);
        }
        fflush(stdout);
        free((void *)packet);
    }
}

void print_trd_transport_msg(int len, unsigned char *msg) {
    TRD_Msg *rmsg = (TRD_Msg *)msg;
    TRD_FragmentMsg *fmsg = (TRD_FragmentMsg *)rmsg->data;
    TRD_TransportMsg *tmsg = (TRD_TransportMsg *)fmsg->data;
    task_msg_t *t = (task_msg_t *)tmsg->data;

    printf("trd dissemination msg (origin %2d, seqno %d, age %d, dlen %d, sender %2d) ", 
                     nxs(rmsg->metadata.origin), nxs(rmsg->metadata.seqno), 
                     nxs(rmsg->metadata.age), rmsg->length, rmsg->sender);
    printf("(%d/%d,%d/%d) ", fmsg->index, fmsg->tot_fragment, fmsg->length, nxs(fmsg->tot_bytes));
    if (fmsg->index == 1) {
        printf("(tid %d) ", nxs(tmsg->tid));
        if (nxs(t->type) == TASK_INSTALL) {
            printf("TASK INSTALL, ");
            if (payload)
            fdump_packet(stdout, t->data, fmsg->length - offsetof(TRD_TransportMsg, data) - offsetof(task_msg_t, data));
            else printf("\n");
        } else if (nxs(t->type) == TASK_DELETE) {
            printf("TASK DELETE\n");
        } else {
            if (payload)
            fdump_packet(stdout, tmsg->data, fmsg->length - offsetof(TRD_TransportMsg, data));
            else printf("\n");
        }
    } else {
        if (payload)
        fdump_packet(stdout, tmsg->data, fmsg->length - offsetof(TRD_TransportMsg, data));
        else printf("\n");
    }
}

