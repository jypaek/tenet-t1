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
 * Header file for TRD state module that maintains all information about 
 * all TRD dissemination activities in the network, at the master.
 *
 * TRD is a generic dissemination protocol that reliably delivers
 * packets to all nodes that runs TRD.
 * TRD_State module maintains states so that it can decide when and
 * what to disseminated and receive.
 *
 * This module decides:
 * - whether a received packet is new or not,
 * - whether it should send out a summary of current table or not,
 * - whether to respond to a recovery request or not,
 * - whether to rebroadcast a dissemination packet or not,
 * - etc.
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 2/25/2006
 **/

#ifndef _TRD_STATE_H_
#define _TRD_STATE_H_

#include "trd.h"
#include "trd_metalist.h"
#include "trd_table.h"
#include "trd_timer.h"
#include "trd_memory.h"
#include "timeval.h"

enum {
    TRD_S_DISCONNECTED         = 0x00, // boot up, never received anything
    TRD_S_INIT_0               = 0x11, // received at least one summary or msg
    TRD_S_INIT                 = 0x01, // 20 sec after INIT_0
    TRD_S_INIT_READY           = 0x21, // received at least one new msg
    TRD_S_STEADY               = 0x02,
    TRD_S_RX                   = 0x04,
    TRD_S_TX                   = 0x08,
    TRD_S_FAST_PACKET          = 0x10,
                
    TRD_FAST_RETX_COUNT        = 1,
};


void trd_state_init();
uint16_t trd_state_getNextSeqno();
int trd_state_newMsg(TRD_Msg *rmsg);
void trd_state_summaryReceived(TRD_SummaryMsg *smsg);
void trd_state_requestReceived(TRD_RequestMsg *qmsg);
void trd_state_printTableEntry();
int trd_state_sendReady();

int trd_timer_fired();

void polling_trd_state_timer();

#endif

