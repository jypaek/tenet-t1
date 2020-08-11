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
 * TRD misc. functions
 * - check whether a packet is trd-related packet.
 * - print the content of trd related packets to stdout.
 *
 * Embedded Networks Laboratory, University of Southern California
 * @date Nov/18/2007
 * @author Jeongyeup Paek
 **/


#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <stddef.h>
#include "tosmsg.h"
#include "trd_misc.h"
#include "trd.h"
#include "trd_seqno.h"

void trd_dump_raw(FILE *fptr, unsigned char *packet, int len) {
    int i;
    uint8_t *packet_ptr = (uint8_t*) packet;
    for (i = 0; i < len; i++)
        fprintf(fptr, "%02x ", packet_ptr[i]);
    fprintf(fptr, "\n");
    fflush(fptr);
};

void print_trd_msg(int len, unsigned char *msg) {
    TRD_Msg *rmsg = (TRD_Msg *)msg;
    printf("trd_msg (origin %d, seqno %d, age %d, dlen %d, sender %d) ", 
                     nxs(rmsg->metadata.origin), nxs(rmsg->metadata.seqno), 
                     nxs(rmsg->metadata.age), rmsg->length, rmsg->sender);
    trd_dump_raw(stdout, rmsg->data, rmsg->length);
}

void print_trd_summary(int len, unsigned char *msg) {
    // take care of received summary
    TRD_SummaryMsg *smsg = (TRD_SummaryMsg *)msg;
    int i;
    printf("trd_summary (sender %d, num_entries %d) ",
                         smsg->sender, smsg->num_entries);
    for (i = 0; i < smsg->num_entries; i++) {
        TRD_Metadata *meta = &smsg->metadata[i];
        printf(" [%d:%d(%d)]", nxs(meta->origin), nxs(meta->seqno), nxs(meta->age));
    }
    printf("\n");
}

void print_trd_request(int len, unsigned char *msg, uint16_t dst) {
    TRD_RequestMsg *qmsg = (TRD_RequestMsg *)msg;
    int i;
    printf("trd_request (sender %d, num_entries %d, dst %d) ",
                         qmsg->sender, qmsg->num_entries, dst);

    for (i = 0; i < qmsg->num_entries; i++) {
        TRD_Metadata *meta = &qmsg->metadata[i];
        uint16_t req_seqno = nxs(meta->seqno);
        uint16_t req_origin = nxs(meta->origin);
        if (req_seqno == TRD_SEQNO_OLDEST) {
            printf(" [%d:oldest]", req_origin);
        } else if ((req_seqno == TRD_SEQNO_UNKNOWN) ||
                   (req_seqno > TRD_SEQNO_LAST)) {
            printf(" [%d:xx]", req_origin);
        } else {
            printf(" [%d:%d]", req_origin, req_seqno);
        }
    }
    printf("\n");
}

void print_trd_packet(int len, unsigned char *msg) {
    TOS_Msg *tosmsg = (TOS_Msg *)msg;
    TRD_ControlMsg *cmsg;
    len = len - offsetof(TOS_Msg, data);
    if ((len < 0) || (msg == NULL))
        return;
    switch(tosmsg->type) {
        case AM_TRD_MSG:
            print_trd_msg(len, (uint8_t *)tosmsg->data);
            break;
        case AM_TRD_CONTROL:
            cmsg = (TRD_ControlMsg *) tosmsg->data;
            if (cmsg->control_type == TRD_CONTROL_SUMMARY)  {
                print_trd_summary(len, (uint8_t *)tosmsg->data);
            } else if (cmsg->control_type == TRD_CONTROL_REQUEST) {
                print_trd_request(len, (uint8_t *)tosmsg->data, tosmsg->addr);
            }
            break;
        default:
            break;
    }
}

int is_trd_packet(int len, unsigned char *msg) {
    TOS_Msg *tosmsg = (TOS_Msg *)msg;
    if ((len < offsetof(TOS_Msg, data)) || (msg == NULL))
        return 0;
    switch(tosmsg->type) {
        case AM_TRD_MSG:
        case AM_TRD_CONTROL:
            return 1;
        default:
            break;
    }
    return 0;   // not trd packet
}

