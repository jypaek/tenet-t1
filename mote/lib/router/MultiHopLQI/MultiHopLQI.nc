/*									tab:4
 * "Copyright (c) 2000-2003 The Regents of the University  of California.  
 * All rights reserved.
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose, without fee, and without written agreement is
 * hereby granted, provided that the above copyright notice, the following
 * two paragraphs and the author appear in all copies of this software.
 * 
 * IN NO EVENT SHALL THE UNIVERSITY OF CALIFORNIA BE LIABLE TO ANY PARTY FOR
 * DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES ARISING OUT
 * OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN IF THE UNIVERSITY OF
 * CALIFORNIA HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 * 
 * THE UNIVERSITY OF CALIFORNIA SPECIFICALLY DISCLAIMS ANY WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE.  THE SOFTWARE PROVIDED HEREUNDER IS
 * ON AN "AS IS" BASIS, AND THE UNIVERSITY OF CALIFORNIA HAS NO OBLIGATION TO
 * PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS."
 *
 * Copyright (c) 2002-2003 Intel Corporation
 * All rights reserved.
 *
 * This file is distributed under the terms in the attached INTEL-LICENSE     
 * file. If you do not find these files, copies can be found by writing to
 * Intel Research Berkeley, 2150 Shattuck Avenue, Suite 1300, Berkeley, CA, 
 * 94704.  Attention:  Intel License Inquiry.
 */



/*
 * Authors:          Gilman Tolle
 */


// Omprakash Gnawali (om_p@enl.usc.edu)
// added RoutingTable interface
// added NeighborTable interface
// ifdef's for base station
// cleaned up some unused code

#include "MultiHop.h"

module MultiHopLQI {

    provides {
        interface StdControl;
        interface RoutingTable;
        interface RoutingChange;
        interface ParentControl;
    }

    uses {
        interface Timer;
        interface SendMsg;
        interface ReceiveMsg;
        interface Random;
        interface NeighborTable;
    }
}

implementation {

    enum {
        BEACON_PERIOD        = 32,
        BEACON_TIMEOUT       = 8,
    };

    TOS_Msg msgBuf;
    bool msgBufBusy;

    uint16_t gbCurrentParent;
    uint16_t gbCurrentParentCost;
    uint16_t gbCurrentLinkEst;
    int16_t  gbCurrentLinkRssi;
    uint8_t  gbCurrentHopCount;
    uint16_t gbCurrentMaster;   // added for Tenet
    uint8_t  gLastHeard;
    uint16_t gUpdateInterval;

    bool hold_parent;

    uint16_t adjustLQI(uint8_t val) {
        uint16_t result = (80 - (val - 50));
        result = (((result * result) >> 3) * result) >> 3;
        return result;
    }

    // It's always good to have a way to know the rssi value
    // especially when you are doing real-world deployments.
    int16_t getRSSI(uint8_t val) {
        return (int16_t)((int8_t)val - 45);
    }

    void giveupCurrentParent() {
        gbCurrentParent = TOS_BCAST_ADDR;
        gbCurrentParentCost = 0x7fff;
        gbCurrentLinkEst = 0x7fff;
        gbCurrentLinkRssi = 0x8000;
        gbCurrentHopCount = 0xff;
        gbCurrentMaster = TOS_BCAST_ADDR;
    }
    
    /* Our customization to MultiHopLQI */

    command uint16_t RoutingTable.getParent() {
        return gbCurrentParent;
    }
    command uint8_t RoutingTable.getDepth() {
        return gbCurrentHopCount;
    }
    command uint16_t RoutingTable.getMaster() {
        return gbCurrentMaster;
    }
    command uint16_t RoutingTable.getLinkEst() {
        return gbCurrentLinkEst;
    }
    command int16_t RoutingTable.getLinkRssi() {
        return gbCurrentLinkRssi;
    }

    command void ParentControl.hold() {
        hold_parent = TRUE;
        if (gbCurrentParent != TOS_BCAST_ADDR)
            call Timer.stop();
    }
    command void ParentControl.unhold() {
        hold_parent = FALSE;
        call Timer.start(TIMER_ONE_SHOT, 1024 * gUpdateInterval + 1);
    }
    command void ParentControl.reset() {
        giveupCurrentParent();
        call ParentControl.unhold();
    }
    
    /*******/

    task void SendRouteTask() {
        TOS_MHopMsg *pMHMsg = (TOS_MHopMsg *) &msgBuf.data[0];
        BeaconMsg *pRP = (BeaconMsg *)&pMHMsg->data[0];
        uint8_t length = offsetof(TOS_MHopMsg,data) + sizeof(BeaconMsg);

        if (msgBufBusy) {
        #ifndef PLATFORM_PC
            post SendRouteTask();
        #endif
            return;
        }

        pRP->parent = gbCurrentParent;
        pRP->cost = gbCurrentParentCost + gbCurrentLinkEst;
        //pMHMsg->sourceaddr = pMHMsg->originaddr = TOS_LOCAL_ADDRESS;
        pMHMsg->sourceaddr = TOS_LOCAL_ADDRESS;
        pMHMsg->originaddr = gbCurrentMaster;   // modified for Tenet
        pRP->hopcount = gbCurrentHopCount;
        pMHMsg->seqno = 0;                      // unused for now

        if (call SendMsg.send(TOS_BCAST_ADDR, length, &msgBuf) == SUCCESS) {
            atomic msgBufBusy = TRUE;
        }
    }

    task void TimerTask() {
    #ifndef BASE_STATION
        uint8_t val;
        atomic val = ++gLastHeard;
        if ((val > BEACON_TIMEOUT) && (hold_parent == FALSE)) {
            giveupCurrentParent();
        }
    #endif
        post SendRouteTask();
    }

    command result_t StdControl.init() {
        gUpdateInterval = BEACON_PERIOD;
        atomic msgBufBusy = FALSE;

    #ifdef BASE_STATION
        gbCurrentParent = TOS_UART_ADDR;
        gbCurrentParentCost = 0;
        gbCurrentLinkEst = 0;
        gbCurrentHopCount = 0;
        gbCurrentMaster = TOS_LOCAL_ADDRESS;    // Tenet Master
    #else
        giveupCurrentParent();
    #endif
        hold_parent = FALSE;
        return SUCCESS;
    }

    command result_t StdControl.start() {
        gLastHeard = 0;
        call Timer.start(TIMER_ONE_SHOT, 
                call Random.rand() % (1024 * gUpdateInterval));
        return SUCCESS;
    }

    command result_t StdControl.stop() {
        call Timer.stop();
        return SUCCESS;
    }

    event result_t Timer.fired() {
        post TimerTask();
        call Timer.start(TIMER_ONE_SHOT, 1024 * gUpdateInterval + 1);
        return SUCCESS;
    }

    event TOS_MsgPtr ReceiveMsg.receive(TOS_MsgPtr Msg) {

    #ifndef BASE_STATION
        TOS_MHopMsg *pMHMsg = (TOS_MHopMsg *)&Msg->data[0];
        BeaconMsg *pRP = (BeaconMsg *)&pMHMsg->data[0];

        /* if the message is from my parent
           store the new link estimation */

        if (pMHMsg->sourceaddr == gbCurrentParent) {
            // try to prevent cycles
            if ((pRP->parent != TOS_LOCAL_ADDRESS) &&
                (pRP->parent != TOS_BCAST_ADDR)) {
                gLastHeard = 0;
                gbCurrentParentCost = pRP->cost;
                gbCurrentLinkEst = adjustLQI(Msg->lqi);
                gbCurrentLinkRssi = getRSSI(Msg->strength);
                gbCurrentHopCount = pRP->hopcount + 1;
                gbCurrentMaster = pMHMsg->originaddr;   // modified for Tenet
            }
            else if (hold_parent == FALSE) {
            //else {
                // either a routing loop, or my parent lost it's parent.
                // so, I lose my parent also.
                gLastHeard = 0;
                giveupCurrentParent();
            }
        } else {

            /* if the message is not from my parent, 
               compare the message's cost + link estimate to my current cost,
               switch if necessary */

            // make sure you don't pick a parent that creates a cycle
            if (((uint32_t) pRP->cost + (uint32_t) adjustLQI(Msg->lqi) 
                        <
                        ((uint32_t) gbCurrentParentCost + (uint32_t) gbCurrentLinkEst) -
                        (((uint32_t) gbCurrentParentCost + (uint32_t) gbCurrentLinkEst) >> 2)
                ) &&
                    (pRP->parent != TOS_LOCAL_ADDRESS)) {
                gLastHeard = 0;
                if ((hold_parent == FALSE) || (gbCurrentParent == TOS_BCAST_ADDR)) {
                    gbCurrentParent = pMHMsg->sourceaddr;
                    gbCurrentParentCost = pRP->cost;
                    gbCurrentLinkEst = adjustLQI(Msg->lqi);	
                    gbCurrentLinkRssi = getRSSI(Msg->strength);	
                    gbCurrentHopCount = pRP->hopcount + 1;
                    gbCurrentMaster = pMHMsg->originaddr;   // modified for Tenet
                    signal RoutingChange.parentChanged(gbCurrentParent);
                    if ((gbCurrentParent != TOS_BCAST_ADDR) && (hold_parent == TRUE))
                        call Timer.stop();
                }
            }
        }
	// Change for Tenet
        // update neighbors table 
        call NeighborTable.addNeighbors(pMHMsg->sourceaddr, Msg->lqi);
    #endif
        return Msg;
    }

    event result_t SendMsg.sendDone(TOS_MsgPtr pMsg, result_t success) {
        atomic msgBufBusy = FALSE;
        return SUCCESS;
    }

}

