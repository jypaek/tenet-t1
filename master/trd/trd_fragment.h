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
 * Header file for TRD fragmentation module that deals with fragmentation 
 * and re-assembly of TRD transport packets on the master.
 *
 * Fragmentation is done at end-to-end level, and underlying TRD module
 * is not aware of the fragmentation that happens at this layer. 
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
 * @modified 8/21/2006
 **/


#ifndef _TRD_FRAGMENT_H_
#define _TRD_FRAGMENT_H_

#include <sys/types.h>
#include "transport.h"
#include "trd_fragmentmsg.h"


/* User of TRD fragment  MUST implement the below function(s)  */

void receive_trd_fragment(uint16_t sender, int len, unsigned char *msg);


//////////////////////////////////////////////////////////////////////////////


/* Below functions are the interfaces that the user can use to
   access and interact with the trd system */

void trd_fragment_init();

/* send packet through trd network with fragmentation if size too big
    - returns the trd sequence number (>0) that was used for the packet.
    - returns -1 if failed to send */
int trd_fragment_send(int len, unsigned char *msg);


//////////////////////////////////////////////////////////////////////////////


#endif

