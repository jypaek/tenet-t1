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
 * TRD interface for disseminating packets and receiving disseminated 
 * packets at the master.
 *
 * NOTE: Currently, Tenet master does NOT use this interface directly.
 *       Instead, Tenet transport uses 'trd_transport.h' interface.
 *
 * Embedded Networks Laboratory, University of Southern California
 * @date Nov/18/2007
 * @author Jeongyeup Paek
 **/


#ifndef _TRD_INTERFACE_H_
#define _TRD_INTERFACE_H_

#include <sys/types.h>
#include "trd.h"

/* User of TRD system must implement the below function(s) */

/* 1 */
void receive_trd(int sender, int len, unsigned char *msg);


//////////////////////////////////////////////////////////////////////////////

/* User of TRD system MUST call the below function(s) appropriately */

/* initialize trd
    - @sf_fd : socket fd that can be used to send packets to the mote cloud.
               for us, it is usually the serial forwarder fd.
    - @local_addr : TOS_LOCAL_ADDRESS of this master node
*/
void trd_init(int sf_fd, uint16_t local_adr);

/* use polling to run and check the trd_timer (trickle timer + alpha)
    - in the past, trd implemented it's own timing mechanism.
    - but now, we rely on external polling/triggering to run trd_timer
    - you must call this frequently enough (at least every 100ms) to run trd.
    - if you don't trickle timer does not run. */
void polling_trd_timer();


//////////////////////////////////////////////////////////////////////////////

/* Below functions are the interfaces that the user can use to
   access and interact with the trd system */

/* send a trd msg */
int trd_send(int len, unsigned char *msg);

/* received a trd msg. pass it to trd module and perform necessary action */
int trd_receive(int len, unsigned char *msg);

/* check whether initialization is done and we're ready to send */
int is_trd_sendReady();


//////////////////////////////////////////

/* Below functions are used internally by trd module.
   - user should not call them directly */
void trd_send_summary(int len, TRD_SummaryMsg *smsg);
void trd_send_request(int len, TRD_RequestMsg *qmsg, uint16_t toAddr);
void trd_rebroadcast(int len, TRD_Msg *rmsg);

int get_trd_motesock_fd();
uint16_t TOS_LOCAL_ADDRESS();

#endif

