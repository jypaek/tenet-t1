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
 * Header file for TRD_Transport module that wraps-around the 
 * TRD module to provide tid.
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


#ifndef _TRD_TRANSPORT_H_
#define _TRD_TRANSPORT_H_

#include <sys/types.h>
#include "transport.h"
#include "trd_transportmsg.h"


/* User of TRD system MUST implement the below function(s)  */

/* 1 */
void receive_trd_transport(uint16_t tid, uint16_t sender, int len, unsigned char *msg);


//////////////////////////////////////////////////////////////////////////////

/* User of TRD system MUST call the below function(s) appropriately */

/* initialized trd transport
    - @sf_fd : socket fd that can be used to send packets to the mote cloud.
               for us, it is usually the serial forwarder fd.
    - @local_addr : TOS_LOCAL_ADDRESS of this master node
*/
void trd_transport_init(int sf_fd, uint16_t local_addr);

/* use polling to run and check the trd_timer (trickle timer + alpha)
    - in the past, trd implemented it's own timing mechanism.
    - but now, we rely on external polling/triggering to run trd_timer
    - you must call this frequently enough (at least every 100ms) to run trd.
    - if you don't trickle timer does not run. */
void polling_trd_transport_timer();


//////////////////////////////////////////////////////////////////////////////

/* Below functions are the interfaces that the user can use to
   access and interact with the trd system */

/* send packet through trd network
    - returns the trd sequence number (>0) that was used for the packet.
    - returns -1 if failed to send */
int trd_transport_send(uint16_t tid, int len, unsigned char *msg);

/* upon receiving a packet, must check whether this is a trd packet
    - assumes that *msg is in TOS_Msg format
      (msg must be in TOS_Msg format)
    - checks the AM_type.
    - returns 1 if so, -1 otherwise */
int is_trd_transport_packet(int len, unsigned char *msg);

/* if msg is a trd packet, pass it to trd module
    - msg must be in TOS_Msg format, and be a trd-related packet
    - returns 1 if ok, otherwise -1 */
int trd_transport_receive(int len, unsigned char *msg);

/* is trd_transport ready to send packets?
    - returns 1 if yes.
    - returns 0 if not. (not synchronized with other nodes) */
int is_trd_transport_sendReady(void);

void print_trd_transport_packet(int len, unsigned char *msg);
void print_trd_transport_msg(int len, unsigned char *msg);
//////////////////////////////////////////////////////////////////////////////


#endif

