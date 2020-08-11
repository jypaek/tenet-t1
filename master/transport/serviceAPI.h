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
 * Header file for supplementary services that master transport provides.
 *
 * Master transport provides some services such as:
 * - network-layer ping : ping a mote
 * - network-layer trace route : trace route a mote
 * - mote-time query : ask for the FTSP-time-synchronized mote-world time.
 *
 * These services are optional, and are not main components of Tenet.
 * Ping and trace-route functionalities work only if TCMP is compiled and
 * enabled within motes.
 * - also, there must exist a route to that mote.
 * Mote-time query works only if FTSP is running on the BaseStation mote:
 * - it gets the time from the BaseStation mote.
 *
 * 'serviceAPI.*' sits on top of 'service_if.*' to provide some application
 * friendly API's. (at least that was the original purpose)
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 2/5/2007
 **/

#ifndef _SERVICE_API_H_
#define _SERVICE_API_H_

#include "common.h"


typedef void (*service_handler_ping_t)(uint16_t, uint16_t, double, uint16_t);
typedef void (*service_handler_tracert_t)(uint16_t, uint16_t, uint16_t, int, double, uint16_t);
typedef void (*service_handler_motetime_t)(uint16_t, uint32_t, uint32_t, uint16_t, float, double);
typedef void (*service_handler_rfpower_t)(uint16_t, uint16_t);


/* user can implement their own functions to handle the responses:
    - ping ack,
    - tracert ack, and
    - motetime query result
   if the user wants this, should implement the function and register it */
void register_ping_service_handler(service_handler_ping_t handler);
void register_tracert_service_handler(service_handler_tracert_t handler);
void register_motetime_service_handler(service_handler_motetime_t handler);
void register_rfpower_service_handler(service_handler_rfpower_t handler);


int send_ping(uint16_t addr);
int send_tracert(uint16_t addr);
void send_motetime_query(uint32_t offset);
void send_set_rfpower(uint16_t power);
void send_get_rfpower();


/* User functions which includes supplementary printf's/scanf's
   The functions ask the user for the arguments */
void run_ping();
void run_tracert();
void run_motetime_query();
void run_set_rfpower();
void run_get_rfpower();

                           
/* Below should not be used by the application.
   Below are for the use by taskingAPI.c */
void signal_ping_result(uint16_t tid, uint16_t addr, int len, unsigned char *packet);
void signal_tracert_result(uint16_t tid, uint16_t addr, int len, unsigned char *packet);
void signal_service_result(uint16_t tid, int len, unsigned char *packet);


#endif

