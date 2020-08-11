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



#ifndef _SERVICE_IF_H_
#define _SERVICE_IF_H_

#include "common.h"
#include <sys/time.h>

/* "tr_fd" is the socket fd for the socket that is used by the application
   to connected to the transport layer. */

/**
 * send ping to 'addr' through socket 'tr_fd';
 * (assumes a transport layer on the other side of tr_fd).
 **/
int tr_ping(int tr_fd, uint16_t addr);

/**
 * send trace route to 'addr' through socket 'tr_fd';
 * (assumes a transport layer on the other side of tr_fd).
 **/
int tr_tracert(int tr_fd, uint16_t addr);

/**
 * send mote-world global time (FTSP time) request through socket 'tr_fd';
 * (assumes a transport layer on the other side of tr_fd).
 **/
int tr_request_motetime(int tr_fd, uint32_t offset_sec);

/**
 * send mote-world global time (FTSP time) request through socket 'sf_fd';
 * (assumes a serial forwarder on the other side of sf_fd).
 *
 * the main difference between this and the 'tr_request_motetime' function
 * is in how they format the packet before sending it down to the socket.
 **/
void tr_request_motetime_to_sf(int sf_fd, uint16_t tid, int offset_sec);

/**
 * Set the CC2420 radio RF-power of the BaseStation mote.
 * - this is not done in the form of a task, but it is done as a 
 *   special service that the master 'transport' component provides.
 */
int tr_set_bs_rfpower(int tr_fd, uint16_t power);
int tr_get_bs_rfpower(int tr_fd);

/**
 * once you get the response packet, parse the ping result.
 **/
int parse_ping_response(double *rtt, uint16_t *seqno, int len, unsigned char *packet);

/**
 * once you get the response packet, parse the trace route result.
 **/
int parse_tracert_response(uint16_t *ret_node, int *hop, double *rtt, uint16_t *seqno,
                           int len, unsigned char *packet);
                           
/** 
 * once you get the response packet, parse the mote-world time response.
 **/
int parse_motetime_response(uint32_t *motetime, uint32_t *freq, uint16_t *root, float *skew, 
                            double *d_rtt, int len, unsigned char *packet);

/** 
 * once you get the response packet, parse the rf power response.
 **/
int parse_rfpower_response(uint16_t *rfpower, int len, unsigned char *packet);

#endif

