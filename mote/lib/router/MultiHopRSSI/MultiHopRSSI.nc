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

// Jeongyeup Paek (jpaek@enl.usc.edu)
// cleaned up some unused code
// modify the 'adjustRSSI' functions

#include "MultiHop.h"

module MultiHopRSSI {

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
    int16_t  gbCurrentLinkRssi;     // good to know, especially for field deployment
    uint8_t  gbCurrentHopCount;
    uint16_t gbCurrentMaster;       // added for Tenet
    uint8_t  gLastHeard;
    uint16_t gUpdateInterval;

    bool hold_parent;


    /****************************** 
     * 'adjustRSSI()' functions 
       have been modified based on the observations made in the following 
       two publications for CC2420 and CC1000, respectively.
       # "Understanding the Causes of Packet Delivery Success and 
          Failure in Dense Wireless Sensor Networks", 
         (Kannan Srinivasan et.al., Tech.Report SING-06-00), and
       # "Real-Time Deployment of Multihop Relays for Range Extension", 
         (Michael R. Souryal et.al., MobiSys'07)

     * Observations
       - RSSI vs. PRR curve has a sharp cliff.
       - RSSI has very small variance for any link over time.
         (< 1 dbm for short duration of time)
       - RSSI is a very good predictor of whether a link is high quality or not.

     * RSSI vs. PRR curve is divided into approximated line segments
       - level 1  : region where PRR > 95%
       - level 2  : region where PRR > 85%
       - level 3  : grey region
       - level 4  : beyond sensitivity

     * Rule of thumb
       - LinkEst(adjustRSSI value) of higher level link should be low enough
         such that it can always replace the link of lower level.
          (in the 'else' part of the ReceiveMsg.receive function)
         #ex> a link with -75 dbm must always replace link with -90 dbm
       - One low-level hop should be more expensive than two high-level hops.
         #ex> 0.95*0.95 > 0.85
       - We should avoid level-4 unless there are no other links.
         We would like to avoid level-3 also if we can.

     * Experiment results
       - The results were surprisingly good. Below table shows the packet
         delivery performance(PRR %) from TutorNet telosb testbed experiment.
         ("MRSSI+" is the modified MultihopRSSI)

         << 40 node experiment (3rd floor) >>

         rate       0.2     0.5     1.0     2.0  (pkt/s)
         ----------------------------------------------(power31)
         MLQI       92.8    92.8    91.6    84.9  (%)
         MRSSI      83.5    79.1    81.6    75.9  (%)
         MRSSI+     93.9    92.4    93.8    78.6  (%)
         ----------------------------------------------(power7)
         MLQI       95.1    95.3    87.9    63.9  (%)
         MRSSI      60.5    59.9    58.7    58.9  (%)
         MRSSI+     97.2    96.7    94.0    60.2  (%)


         << 30 node experiment (4th floor) >>

         rate       0.2     0.5     1.0     2.0  (pkt/s)
         ----------------------------------------------(power31)
         MLQI       94.2    91.9    94.2    90.7  (%)
         MRSSI      87.7    86.2    83.0    80.9  (%)
         MRSSI+     97.3    96.5    95.4    95.3  (%)
         ----------------------------------------------(power7)
         MLQI       92.3    91.5    88.9    80.5  (%)
         MRSSI      71.5    67.7    70.8    65.3  (%)
         MRSSI+     99.1    98.8    96.7    66.5  (%)

       - The results show that PRR performance is:  " MRSSI <  MLQI < MRSSI+ "
    *******************************/

#if defined(PLATFORM_TELOSB) || defined(PLATFORM_MICAZ) || defined(PLATFORM_IMOTE2)
    int16_t getRSSI(uint8_t val) {
        return (int16_t)((int8_t)val - 45);
    }

    uint16_t adjustRSSI(uint8_t val) {
        int16_t dbm = getRSSI(val);
        uint16_t result;
        if (dbm > -80)
            result = 0 - dbm;                   // 45 ~ 80
        else if (dbm > -85)
            result = 200 + ((-80 - dbm) << 2);  // 200 ~ 220
        else if (dbm > -95)
            result = 500 + ((-85 - dbm) << 4);  // 500 ~ 560
        else
            result = 10000 + ((-95 - dbm) << 7); // 10000 ~
        //return (uint16_t)((val - 60)&255);   // original version
        return result;
    }
#elif defined(PLATFORM_MICA2) || defined(PLATFORM_MICA2DOT)
    int16_t getRSSI(uint16_t val) {
        return (int16_t)(((-50.0 * 3.0 * (double)val)/1024.0) - 45.5);
    }

    uint16_t adjustRSSI(uint16_t val) {
        //double dbm = ((-50.0 * 3.0 * (double)Msg->strength)/1024.0) - 45.5;
        int16_t dbm = getRSSI(val);
        uint16_t result;
        if (dbm > -80)
            result = 0 - dbm;                   // 45 ~ 80
        else if (dbm > -90)
            result = 200 + ((-80 - dbm) << 2);  // 200 ~ 240
        else if (dbm > -95)
            result = 500 + ((-90 - dbm) << 4);  // 500 ~ 580
        else
            result = 10000 + ((-95 - dbm) << 7);// 10000 ~
        //return val;   // original version
        return result;
    }
#endif

    void giveupCurrentParent() {
        gbCurrentParent = TOS_BCAST_ADDR;
        gbCurrentParentCost = 0x7fff;
        gbCurrentLinkEst = 0x7fff;
        gbCurrentLinkRssi = 0x8000;
        gbCurrentHopCount = 0xff;
        gbCurrentMaster = TOS_BCAST_ADDR;
    }
    
    /* Our customization to MultiHopRSSI */

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
                gbCurrentLinkEst = adjustRSSI(Msg->strength);
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
            if ((((uint32_t) pRP->cost + (uint32_t) adjustRSSI(Msg->strength))
                        <
                 ((uint32_t) gbCurrentParentCost + (uint32_t) gbCurrentLinkEst)
                ) &&
                (pRP->parent != TOS_LOCAL_ADDRESS)) {
                gLastHeard = 0;
                if ((hold_parent == FALSE) || (gbCurrentParent == TOS_BCAST_ADDR)) {
                    gbCurrentParent = pMHMsg->sourceaddr;
                    gbCurrentParentCost = pRP->cost;
                    gbCurrentLinkEst = adjustRSSI(Msg->strength);
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
        call NeighborTable.addNeighbors(pMHMsg->sourceaddr, adjustRSSI(Msg->strength));
    #endif
        return Msg;
    }

    event result_t SendMsg.sendDone(TOS_MsgPtr pMsg, result_t success) {
        atomic msgBufBusy = FALSE;
        return SUCCESS;
    }

}

