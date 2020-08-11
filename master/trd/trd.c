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
 * TRD (Tiered Reliable Dissemination) module.
 *
 * TRD is a generic dissemination protocol that reliably delivers
 * packets to all nodes that runs TRD.
 * This module takes care of sending and receiving all TRD related
 * packets via the link-layer.
 * TRD_State module maintains states so that it can decide when and
 * what to disseminated and receive.
 *
 * Embedded Networks Laboratory, University of Southern California
 * @date Nov/18/2007
 * @author Jeongyeup Paek
 **/


#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <stddef.h>
#include "trd.h"
#include "trd_state.h"
#include "trd_seqno.h"
#include "trd_checksum.h"
#include "tosmsg.h"
#include "timeval.h"
#include "trd_interface.h"
#include "trd_misc.h"

//#define DEBUG_TRD

int ms_fd = 0;
uint16_t TRD_LOCAL_ADDRESS;

int send_to_mote_cloud(int len, unsigned char *msg, uint8_t type, uint16_t addr);
int trd_receive_msg(int len, unsigned char *msg);
int trd_receive_summary(int len, unsigned char *msg);
int trd_receive_request(int len, unsigned char *msg);
int trd_receive_control(int len, unsigned char *msg);


void trd_init(int sf_fd, uint16_t local_addr) {
    ms_fd = sf_fd;
    TRD_LOCAL_ADDRESS = local_addr;
    trd_state_init();
}

int is_trd_sendReady() {
    return trd_state_sendReady();
}

void polling_trd_timer() {
    polling_trd_state_timer();
}

int trd_send(int len, unsigned char *msg) {
    unsigned char *packet;
    TRD_Msg *rmsg;
    uint16_t seqno;
    int ok;

    packet = malloc(len  + offsetof(TRD_Msg, data));
    rmsg = (TRD_Msg *) packet;

    memcpy(rmsg->data, msg, len);

    rmsg->metadata.origin = hxs(TOS_LOCAL_ADDRESS());
    seqno = trd_state_getNextSeqno();
    rmsg->metadata.seqno = hxs(seqno);
    rmsg->metadata.age = hxs(1);
    rmsg->length = len;
    rmsg->sender = TOS_LOCAL_ADDRESS();
    rmsg->checksum = 0x00;
    rmsg->checksum = trd_calculate_checksum(rmsg);
    
    len += offsetof(TRD_Msg, data);
    ok = send_to_mote_cloud(len, (uint8_t *) rmsg, AM_TRD_MSG, TOS_BCAST_ADDR);

    if (ok) {
        trd_state_newMsg(rmsg);
        #ifdef DEBUG_TRD
            printf("sending: ");
            print_trd_msg(len, (unsigned char *)rmsg);
        #endif
    }
    free((void *)packet);
    return seqno;
}

/* Assums that a TOS_Msg with (AM_type == TRD_*) will be passed */
int trd_receive(int len, unsigned char *msg) {
    TOS_Msg *tosmsg = (TOS_Msg *)msg;
    int ok;

    if (len < offsetof(TOS_Msg, data))
        return -1;
    len = len - offsetof(TOS_Msg, data);
    
    switch(tosmsg->type) {
        case AM_TRD_MSG:
            ok = trd_receive_msg(len, (uint8_t *)tosmsg->data);
            break;
        case AM_TRD_CONTROL:
            ok = trd_receive_control(len, (uint8_t *)tosmsg->data);
            break;
        default:
            return -1;  // not trd packet
    }
    return ok;
}

int trd_receive_msg(int len, unsigned char *msg) {
    TRD_Msg *rmsg = (TRD_Msg *)msg;
    int paylen = len - offsetof(TRD_Msg, data);
    int exlen = offsetof(TRD_Msg, data) + rmsg->length;
    if (paylen <= 0)
        return -1;
    if (len != exlen) {
        printf("wrong pkt length in trd_receive_msg (%d != %d)\n",
                    len, exlen);
        trd_dump_raw(stdout, msg, len);
        return -1;
    }
    if (trd_checksum_check(rmsg) < 0) {
        printf("TRD-M: invalid checksum (%X): \n", trd_calculate_checksum(rmsg));
        trd_dump_raw(stdout, msg, len);
        return -1;
    }
    #ifdef DEBUG_TRD
        printf("receive: ");
        print_trd_msg(len, (unsigned char *)rmsg);
    #endif
    // if new message,
    if (trd_state_newMsg(rmsg)) {
        receive_trd(nxs(rmsg->metadata.origin), paylen, rmsg->data);
        // need a seperate type for returning to the app....
    }
    return 1;
}

int trd_receive_summary(int len, unsigned char *msg) {
    TRD_SummaryMsg *smsg = (TRD_SummaryMsg *)msg;
    #ifdef DEBUG_TRD
        printf("receive: ");
        print_trd_summary(len, (unsigned char *)smsg);
    #endif
    trd_state_summaryReceived(smsg);
    return 1;
}

int trd_receive_request(int len, unsigned char *msg) {
    TRD_RequestMsg *qmsg = (TRD_RequestMsg *)msg;
    #ifdef DEBUG_TRD
        printf("receive: ");
        print_trd_request(len, (unsigned char *)qmsg);
    #endif
    trd_state_requestReceived(qmsg);
    return 1;
}

int trd_receive_control(int len, unsigned char *msg) {
    // take care of received summary
    TRD_ControlMsg *cmsg = (TRD_ControlMsg *)msg;
    int exlen;
    if (len < offsetof(TRD_ControlMsg, metadata))
        return -1;
    if (cmsg->num_entries >= 0) {
        exlen = offsetof(TRD_ControlMsg, metadata) + (cmsg->num_entries * sizeof(TRD_Metadata));
        if (len != exlen) {
            printf("wrong pkt length in trd_receive_control (%d != %d)\n",
                    len, exlen);
            trd_dump_raw(stdout, msg, len);
            return -1;
        }
    }
    if (trd_control_checksum_check(cmsg) < 0) {
        printf("TRD-C: invalid checksum (%X): \n", trd_control_calculate_checksum(cmsg));
        trd_dump_raw(stdout, msg, len);
        return -1;
    }
    if (cmsg->control_type == TRD_CONTROL_SUMMARY)
        return trd_receive_summary(len, msg);
    else if (cmsg->control_type == TRD_CONTROL_REQUEST)
        return trd_receive_request(len, msg);
    return 1;
}

int trd_send_control(int len, TRD_ControlMsg *cmsg, uint16_t toAddr) {
    cmsg->unused = 0x00;
    cmsg->checksum = 0x00;
    cmsg->checksum = trd_control_calculate_checksum(cmsg);

    send_to_mote_cloud(len, (uint8_t *)cmsg, AM_TRD_CONTROL, toAddr);
    return 1;
}

void trd_send_summary(int len, TRD_SummaryMsg *smsg) {
    smsg->control_type = TRD_CONTROL_SUMMARY;
    if (trd_send_control(len, (TRD_ControlMsg *)smsg, TOS_BCAST_ADDR)) {
        #ifdef DEBUG_TRD
            printf("sending: ");
            print_trd_summary(len, (unsigned char *)smsg);
        #endif
    }
}

void trd_send_request(int len, TRD_RequestMsg *qmsg, uint16_t toAddr) {
    qmsg->control_type = TRD_CONTROL_REQUEST;
    if (trd_send_control(len, (TRD_ControlMsg *)qmsg, toAddr)) {
        #ifdef DEBUG_TRD
            printf("sending: ");
            printf("(to %d) ", toAddr);
            print_trd_request(len, (unsigned char *)qmsg);
        #endif
    }
}

void trd_rebroadcast(int len, TRD_Msg *rmsg) {
    rmsg->sender = TOS_LOCAL_ADDRESS();
    rmsg->checksum = 0x00;
    rmsg->checksum = trd_calculate_checksum(rmsg);
    #ifdef DEBUG_TRD
        printf("rebroadcast: ");
        print_trd_msg(len, (unsigned char *)rmsg);
    #endif
    send_to_mote_cloud(len, (uint8_t *)rmsg, AM_TRD_MSG, TOS_BCAST_ADDR);
}

int send_to_mote_cloud(int len, unsigned char *msg, uint8_t type, uint16_t addr) {
    if (ms_fd == 0) {
        printf("TRD downlink socket to the mote cloud not initialized\n");
        printf(" - fail to send packet\n");
        return -1;
    }
    send_TOS_Msg(ms_fd, msg, len, type, addr, TOS_DEFAULT_GROUP);
    return 1;
}

int get_trd_motesock_fd() {
    return ms_fd;
}

uint16_t TOS_LOCAL_ADDRESS() {
    return TRD_LOCAL_ADDRESS;
}

