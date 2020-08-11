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
 * TRD_Transport module that wraps-around the TRD module to provide tid.
 *
 * It adds 'tid' (transaction id) information into the header so that
 * Tenet transport layer can identify tasks.
 * Also, it supports fragmentation of dissemination packets through
 * TRD_Fragment module. Fragmentation is done at end-to-end level, and
 * TRD itself is not aware of the fragmentation that happens at higher layers. 
 * TRD is a generic dissemination protocol that reliably delivers
 * packets to all nodes that runs TRD.
 *
 *            APP
 *             |
 *       TRD_Transport
 *             |
 *       TRD_Fragment
 *             |
 *            TRD
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 9/25/2006
 **/


#include <stdlib.h>
#include <string.h>
#include <stddef.h>
#include "trd_state.h"
#include "trd_interface.h"
#include "trd_transport.h"
#include "trd_fragment.h"
#include "trd_misc.h"
#include "tosmsg.h"

int ignore_sendReady = 0;

void trd_transport_init(int fd, uint16_t local_addr) {
    trd_fragment_init();
    trd_init(fd, local_addr);
}

int trd_transport_send(uint16_t tid, int len, unsigned char *msg) {
    unsigned char *packet;
    TRD_TransportMsg *tmsg;
    uint16_t seqno;

    if (msg == NULL)
        return -21;
    if (len <= 0)
        return -22;
    if ((!trd_state_sendReady()) && (!ignore_sendReady))
        return -23;

    packet = malloc(len  + offsetof(TRD_TransportMsg, data));
    if (packet == NULL)
        return -24;
        
    tmsg = (TRD_TransportMsg *)packet;

    memcpy(tmsg->data, msg, len);
    len += offsetof(TRD_TransportMsg, data);

    tmsg->tid = hxs(tid);   // htons

    //seqno = trd_send(len, (uint8_t *) tmsg);
    seqno = trd_fragment_send(len, (uint8_t *) tmsg);

    free((void *)packet);
    return seqno;
}

/* Assumes that a TOS_Msg with (AM_type == TRD_*) will be passed */
int trd_transport_receive(int len, unsigned char *msg) {
    return trd_receive(len, msg);
}

int is_trd_transport_packet(int len, unsigned char *msg) {
    return is_trd_packet(len, msg);
}

int is_trd_transport_sendReady() {
    return trd_state_sendReady();
}

/* Assumes that receive_trd_transport function is implemented by user */
//void receive_trd(int sender, int len, unsigned char *msg) {
void receive_trd_fragment(uint16_t sender, int len, unsigned char *msg) {
    TRD_TransportMsg *tmsg = (TRD_TransportMsg *)msg;
    trd_dump_raw(stdout, msg, len);
    len -= offsetof(TRD_TransportMsg, data);
    receive_trd_transport(nxs(tmsg->tid), sender, len, tmsg->data);
}

void polling_trd_transport_timer() {
    polling_trd_timer();
}

void print_trd_transport_msg(int len, unsigned char *msg) {
    TRD_Msg *rmsg = (TRD_Msg *)msg;
    TRD_FragmentMsg *fmsg = (TRD_FragmentMsg *)rmsg->data;
    TRD_TransportMsg *tmsg = (TRD_TransportMsg *)fmsg->data;
    printf("trd_transport_msg (origin %d, seqno %d, age %d, dlen %d, sender %d)", 
                     rmsg->metadata.origin, rmsg->metadata.seqno, 
                     rmsg->metadata.age, rmsg->length, rmsg->sender);
    printf("(%d/%d, %d/%d)", fmsg->index, fmsg->tot_fragment, fmsg->length, fmsg->tot_bytes);
    printf("(tid %d)", nxs(tmsg->tid));
    trd_dump_raw(stdout, tmsg->data, rmsg->length - offsetof(TRD_TransportMsg, data));
}

void print_trd_transport_packet(int len, unsigned char *msg) {
    TOS_Msg *tosmsg = (TOS_Msg *)msg;
    TRD_ControlMsg *cmsg;
    
    len = len - offsetof(TOS_Msg, data);
    if ((len < 0) || (msg == NULL))
        return;

    switch(tosmsg->type) {
        case AM_TRD_MSG:
            print_trd_transport_msg(len, (uint8_t *)tosmsg->data);
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

