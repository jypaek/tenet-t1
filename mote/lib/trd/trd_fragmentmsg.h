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
 * Header file for fragmentation in TRD transport.
 *
 * Embedded Networks Laboratory, University of Southern California
 * @date Nov/19/2007
 * @author Jeongyeup Paek
 **/


#ifndef _TRD_FRAGMENTMSG_H_
#define _TRD_FRAGMENTMSG_H_

#ifdef BUILDING_PC_SIDE
#include "nx.h"
#endif

typedef nx_struct TRD_FragmentMsg {
    nx_uint8_t index;      // index of this fragment (starting from 0, to tot_fragment)
    nx_uint8_t tot_fragment;   // total number of fragments
    nx_uint8_t length;     // length of this 'data' field in this fragment
    nx_uint8_t pad;
    nx_uint16_t tot_bytes;  // total length of the fragmented packet
    nx_uint8_t data[0];
} TRD_FragmentMsg;

#endif

