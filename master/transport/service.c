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
 * Mote-time-request functionality in transport.
 *
 * When the application send a 'mote-time-request' to the transport,
 * the transport sends the command to the BaseStation mote by
 * composing a TIMEREQ command packet and sending it down to the BaseStation.
 * This is a module within transport, called by the transport layer
 * to send timesync request to the BaseStation mote,
 * and receive timesync response from the mote.
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 2/5/2007
 **/

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "transportmain.h"
#include "service.h"
#include "tosmsg.h"
#include "tidlist.h"
#include "service_if.h"
#include "transport.h"

void service_send_request(int rt_fd, uint16_t tid, int len, uint8_t* msg) {
    int length = offsetof(BaseStationServiceMsg,data);
    BaseStationServiceMsg *bsmsg = (BaseStationServiceMsg *) msg;
    
    bsmsg->tid = tid;

    if (bsmsg->type == BS_SERVICE_TIME) {
        bs_timeRequestMsg *tmsg = (bs_timeRequestMsg *) bsmsg->data;
        length += sizeof(bs_timeRequestMsg);
        if (len != length)
            fprintf(stderr, "error in service_send_request: len mismatch %d != %d\n", len, length);
        printf("[service] TIME_REQUEST: tid %d, offset %u\n", tid, tmsg->time);
        send_TOS_Msg(rt_fd, msg, len, AM_BS_SERVICE, TOS_LOCAL_ADDRESS(), TOS_DEFAULT_GROUP);
    }
    else if (bsmsg->type == BS_SERVICE_ID) {
        bs_idMsg *imsg = (bs_idMsg *) bsmsg->data;
        length += sizeof(bs_idMsg);
        if (len != length)
            fprintf(stderr, "error in service_send_request: len mismatch %d != %d\n", len, length);
        printf("[service] ID_REQUEST: tid %d, my_addr %d\n", tid, imsg->base_id);
        send_TOS_Msg(rt_fd, msg, len, AM_BS_SERVICE, TOS_LOCAL_ADDRESS(), TOS_DEFAULT_GROUP);
    }
    else if (bsmsg->type == BS_SERVICE_POWER) {
        bs_powerMsg *pmsg = (bs_powerMsg *) bsmsg->data;
        length += sizeof(bs_powerMsg);
        if (len != length)
            fprintf(stderr, "error in service_send_request: len mismatch %d != %d\n", len, length);
        if (pmsg->base_power == 0)
            printf("[service] POWER_GET_REQUEST: tid %d\n", tid);
        else
            printf("[service] POWER_SET_REQUEST: tid %d, set-to %d\n", tid, pmsg->base_power);
        send_TOS_Msg(rt_fd, msg, len, AM_BS_SERVICE, TOS_LOCAL_ADDRESS(), TOS_DEFAULT_GROUP);
    }
    fflush(stdout);
}

void base_id_request(int rt_fd) {
    int len = offsetof(BaseStationServiceMsg,data) + sizeof(bs_idMsg);
    uint8_t *packet = (uint8_t *)malloc(len);
    BaseStationServiceMsg *bsmsg = (BaseStationServiceMsg *) packet;
    bs_idMsg *imsg = (bs_idMsg *) bsmsg->data;
    bsmsg->tid = 0;
    bsmsg->type = BS_SERVICE_ID;
    imsg->base_id = TOS_LOCAL_ADDRESS();
    service_send_request(rt_fd, 0, len, packet);
    free((void *)packet);
}

void set_rfpower_request(int rt_fd, uint16_t power) {
    int len = offsetof(BaseStationServiceMsg,data) + sizeof(bs_powerMsg);
    uint8_t *packet = (uint8_t *)malloc(len);
    BaseStationServiceMsg *bsmsg = (BaseStationServiceMsg *) packet;
    bs_powerMsg *pmsg = (bs_powerMsg *) bsmsg->data;
    bsmsg->tid = 0;
    bsmsg->type = BS_SERVICE_POWER;
    pmsg->base_power = power;
    service_send_request(rt_fd, 0, len, packet);
    free((void *)packet);
}

void get_rfpower_request(int rt_fd) {
    set_rfpower_request(rt_fd, 0);
}

void service_receive_response(int len, uint8_t *packet) {
    BaseStationServiceMsg *bsmsg = (BaseStationServiceMsg *) packet;
    struct tid_list *t = tidlist_find_tid(bsmsg->tid);
    if (bsmsg->type == BS_SERVICE_TIME) {
        bs_timeResponseMsg *tmsg = (bs_timeResponseMsg *) bsmsg->data;
        printf("[service] TIME_RESPONSE: tid %d time %u (root %d)\n", bsmsg->tid, tmsg->time, tmsg->root);
        receive_service_response(bsmsg->tid, TOS_LOCAL_ADDRESS(), len, packet);
        if (t)
            tidlist_remove_tid(bsmsg->tid);
    }
    else if (bsmsg->type == BS_SERVICE_ID) {
        bs_idMsg *imsg = (bs_idMsg *) bsmsg->data;
        if (imsg->base_id != TOS_LOCAL_ADDRESS()) {
            fprintf(stderr, "\nPossible error? ");
            fprintf(stderr, "BaseStation mote address(%d) is not same as this tenet master address(%d).\n", 
                imsg->base_id, TOS_LOCAL_ADDRESS());
            fprintf(stderr, "Check please!!");
        } else {
            fprintf(stderr, "\nBaseStation address(%d) is same as tenet master address(%d).\n", 
                imsg->base_id, TOS_LOCAL_ADDRESS());
        }
    }
    else if (bsmsg->type == BS_SERVICE_POWER) {
        bs_powerMsg *pmsg = (bs_powerMsg *) bsmsg->data;
        printf("[service] BaseStation power is %d.\n", pmsg->base_power);
        receive_service_response(bsmsg->tid, TOS_LOCAL_ADDRESS(), len, packet);
        if (t)
            tidlist_remove_tid(bsmsg->tid);
    }
}

