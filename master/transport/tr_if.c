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
 * Interface between the application and the transport: 
 * format(encapsulate/decapsulate) packets in appropriate way so that
 * the application and the transport layer can communicate with each other.
 * 
 * Applications can use functions below to send commands/packets to
 * the transport layer, and read/understand the packets that the transport
 * layer has sent to the application.
 * 
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 2/5/2007
 **/

#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <string.h>
#include <stddef.h>
#include "trsource.h"
#include "tosmsg.h"
#include "tr_if.h"
#include "serviceAPI.h"


//////////////////////////////////////////////////////////////////////////
/**
 * removing the transport <-> app interface header.
 **/
void *read_transport_msg(int tr_fd, int *len, uint8_t *tr_type, uint16_t *tid, uint16_t *addr, void **payload) {
    int len2;
    unsigned char *packet = (unsigned char *)read_tr_packet(tr_fd, &len2); // free at bottom
    tr_if_msg_t *tifMsg = (tr_if_msg_t *) packet;
    int datalen = len2 - offsetof(tr_if_msg_t, data);

    if (!packet)
        return NULL;
    if (datalen < 0) {
        printf("datalen < 0.... must be a bug\n");
        free((void *)packet);
        return NULL;
    }

    *payload = tifMsg->data;
    *len = datalen;
    *tr_type = tifMsg->type;
    *tid = tifMsg->tid;
    *addr = tifMsg->addr;
    return packet;
}

/**
 * prepending the transport <-> app interface header.
 **/
int write_transport_msg(int tr_fd, uint8_t *msg, int len, int tr_type, uint16_t tid, uint16_t addr) {
    // 'msg' is what you want to send to the mote, above transport layer.
    // 'msg' should be the payload of transport layer packet.
    uint8_t *packet;
    tr_if_msg_t *tifMsg;
    int ok;

    packet = (uint8_t *)malloc(len + offsetof(tr_if_msg_t, data));

    tifMsg = (tr_if_msg_t *) packet;
    tifMsg->type = tr_type;
    tifMsg->tid = tid;
    tifMsg->addr = addr;    
    if ((len > 0) && (msg))
        memcpy((uint8_t *)tifMsg->data, msg, len);
    len = len + offsetof(tr_if_msg_t, data);

    ok = write_tr_packet(tr_fd, packet, len);
    //dump_packet(packet, len);
    if (ok < 0) {
        fprintf(stderr, "Note: possible socket error within write_transport_msg\n");
        exit(2);
    }
    if (ok > 0)
        fprintf(stderr, "Note: write failed within write_transport_msg\n");
    free((void *)packet);
    return ok;
}


//////////////////////////////////////////////////////////////////////////
/**
 * testing...
 **/

int tr_listen(int tr_fd) {
    return write_transport_msg(tr_fd, NULL, 0, TRANS_TYPE_SNOOP, 0, 0);
}

//////////////////////////////////////////////////////////////////////////
/**
 * API that application(tenet tasking libarary) can use to send packet
 **/

int tr_send_task_uni(int tr_fd, uint16_t addr, int len, uint8_t *packet) {
    int ok;
    int s_tid;

    ok = write_transport_msg(tr_fd, packet, len, TRANS_TYPE_TASK, 0, addr);
    if (ok > 0)
        return -2;
       
    while (1) {
        int r_len;
        uint16_t r_addr, r_tid;
        uint8_t r_type;
        void *payload;
        unsigned char *r_packet;
        
        r_packet = (unsigned char*)read_transport_msg(tr_fd, &r_len, &r_type, &r_tid, &r_addr, &payload);
        if (r_packet) {
            free((void *)r_packet);
            if (r_type == TRANS_TYPE_CMD_NACK) {    // send task failed
                s_tid = -1;
                break;
            } 
            else if (r_type == TRANS_TYPE_CMD_ACK) {// send task success
                s_tid = r_tid;
                break;
            }
            else if (r_type == TRANS_TYPE_CMD_RETURN) { // don't know yet. wait for acknowledgement.
                s_tid = r_tid;
                break;
            }
        }
    }
    return s_tid;
}

int tr_close_task_uni(int tr_fd, uint16_t tid, uint16_t addr) {
    return write_transport_msg(tr_fd, NULL, 0, TRANS_TYPE_CLOSE, tid, addr);
}

// USE tid=0 to automatically assign tid for a task
int tr_send_task(int tr_fd, int len, uint8_t *packet) {
    return tr_send_task_uni(tr_fd, TOS_BCAST_ADDR, len, packet);
}
int tr_close_task(int tr_fd, uint16_t tid) {
    return tr_close_task_uni(tr_fd, tid, TOS_BCAST_ADDR);
}


