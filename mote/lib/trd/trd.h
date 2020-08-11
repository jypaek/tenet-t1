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
 * TRD (Tiered Reliable Dissemination) header file.
 *
 * TRD is a generic dissemination protocol that reliably delivers
 * packets to all nodes that runs TRD.
 *
 * TRD_Msg contains the actual packets that are disseminated.
 * TRD_ControlMsg are for TRD control packets, either TRD summary
 * or TRD request, used for reliable dissemination.
 *
 * Embedded Networks Laboratory, University of Southern California
 * @date Nov/19/2007
 * @author Jeongyeup Paek
 **/


#ifndef _TRD_H_
#define _TRD_H_

#ifdef BUILDING_PC_SIDE
#include <sys/types.h>
#ifdef __CYGWIN__
#include <windows.h>
#include <io.h>
#else
#include <stdint.h>
#endif
#include "nx.h"
#endif

/**
 * AM types used for TRD dissemination.
 **/
enum {
    AM_TRD_MSG     = 0x75,
    AM_TRD_CONTROL = 0x73,
};

enum {
#if defined(PLATFORM_MICAZ) || defined(PLATFORM_MICA2) || defined(PLATFORM_MICA2DOT)
    TRD_NODE_ENTRIES           = 2,
    TRD_CACHE_ENTRIES_PER_NODE = 5,
#else
    TRD_NODE_ENTRIES           = 5,
    TRD_CACHE_ENTRIES_PER_NODE = 5,
#endif

    TRD_INVALID_INDEX          = -1,

    TRD_RECOVER_LIST_SIZE      = TRD_CACHE_ENTRIES_PER_NODE,

    TRD_RETRY_TIME             = 100,
    TRD_RX_WAIT_TIME           = 200,
};


/**
 * TRD_Metadata contains metadata of a dissemination packet.
 * This is included in every TRD dissemination packet header.
 * A table of this is used in TRD_State to maintain record
 * of all the dissemination activity in the network.
 * A list of this is used in TRD summary packets to communicate
 * information between nodes.
 **/
typedef nx_struct TRD_Metadata {
    nx_uint16_t origin;     // origin (sender) of this dissemination packet
    nx_uint16_t seqno;      // per-sender sequence number of this dissemination packet
    nx_uint16_t age;        // age of this dissemination packet
} __attribute__((packed)) TRD_Metadata;


/**
 * TRD_Msg contains the actual packets that are disseminated.
 **/
typedef nx_struct TRD_Msg {
    // The whole size = length + offsetof(TRD_Msg, data)
    TRD_Metadata metadata;
    nxle_uint16_t sender;
    nx_uint8_t length;    // length of the 'data'. 
    nx_uint8_t checksum;
    nx_uint8_t data[0];
} __attribute__((packed)) TRD_Msg;


/**
 * control type in TRD_ControlMsg.control_type: either SUMMARY/REQUEST.
 **/
typedef enum {
    TRD_CONTROL_SUMMARY   = 0xcc,
    TRD_CONTROL_REQUEST   = 0xdd,
} trd_control_type_t;


/**
 * TRD_ControlMsg are for TRD control packets, either TRD summary
 * or TRD request, used for reliable dissemination.
 **/
typedef nx_struct TRD_ControlMsg {
    nxle_uint16_t sender;
    nx_int8_t num_entries; // in senders whole summary
    nx_uint8_t control_type;
    nx_uint8_t unused;
    nx_uint8_t checksum;
    TRD_Metadata metadata[0];
} __attribute__((packed)) TRD_ControlMsg;

typedef TRD_ControlMsg TRD_SummaryMsg;
typedef TRD_ControlMsg TRD_RequestMsg;

enum {
    TRD_REQUEST_ENTRIES = TRD_NODE_ENTRIES,
    TRD_SUMMARY_ENTRIES = TRD_NODE_ENTRIES
};

#endif

