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
 * Header file for master transport binary.
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 2/5/2007
 **/


#ifndef _TRANSPORT_MAIN_H_
#define _TRANSPORT_MAIN_H_

#ifdef BUILDING_PC_SIDE
////////////////////////////////////////////////////////////////
/* BELOW is only for the Master(PC/Stargate) side compilation */
#include <stdlib.h>
#include "common.h"
#include <stddef.h>
#include <sys/time.h>

#define DEFAULT_ROUTER_HOST    "127.0.0.1"
#define DEFAULT_ROUTER_PORT    9999
#define DEFAULT_TRANSPORT_PORT 9998

uint16_t TOS_LOCAL_ADDRESS();   // ID of this node
int     get_router_fd();        // socket fd for the router below transport

int  tr_send_close_task(uint16_t tid, uint16_t addr);
void close_transport_connections(uint16_t tid);
#endif
///////////////////////////////////////////////////////////////


#endif

