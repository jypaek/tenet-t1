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
 * Header file for service functionality in transport.
 *
 * When the application send a 'mote-time-request' to the transport,
 * the transport sends the command to the BaseStation mote by
 * composing a TIMEREQ command packet and sending it down to the BaseStation.
 * This is a module within transport, called by the transport layer
 * to send timesync request to the BaseStation mote,
 * and receive timesync response from the mote.
 *
 * Same for RF-power set/get request and response.
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 2/5/2007
 **/

#ifndef _SERVICE_H_
#define _SERVICE_H_

#include "common.h"
#include "BaseStation.h"


/**
 * send service (timesync, id, rfpower) request to the base station
 **/
void service_send_request(int rt_fd, uint16_t tid, int len, uint8_t* msg);

void base_id_request(int rt_fd);
void set_rfpower_request(int rt_fd, uint16_t power);
void get_rfpower_request(int rt_fd);

/**
 * received service (timesync, id, rfpower) response from the base station
 **/
void service_receive_response(int len, uint8_t *packet);

/**
 * this must be implemented by the user of this module.
 **/
void receive_service_response(uint16_t tid, uint16_t addr, int len, unsigned char *msg);

#endif

