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
 * RoutingLayer configuration file.
 *
 * Routing layerC:
 *  - Uses 'MultiHopLQI' as parent decision module.
 *    (uses 'MultiHopRSSI' for mica2, mica2dot)
 *  - Uses 'NewQueuedSend' as link layer.
 *  - 'RoutingLayerM' is the forwarding engine.
 *  - 'RoutingLayerM' maintains the children table.
 *  - 'NeighborM' maintains the neighbor table.
 *
 * @author Omprakash Gnawali
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 1/11/2006
 * @modified 1/31/2007 documents added.
 **/


#include "routinglayer.h"

configuration RoutingLayerC {
    provides {
        interface RoutingSend[uint8_t protocol];
        interface RoutingReceive[uint8_t protocol];
        interface RoutingTable;
        interface ChildrenTable;
        interface NeighborTable;
        interface ParentControl;
    }
}
implementation {
    components Main
               , RoutingLayerM              // packet forwarding module
            #ifdef STATIC_ROUTING
               , MultiHopHardcode as MultiHop    // routing decision module
            #elif defined (RSSI_ROUTER) || defined(PLATFORM_MICA2) || defined(PLATFORM_MICA2DOT)
               , MultiHopRSSI as MultiHop   // routing decision module
            #elif defined(PLATFORM_TELOSB) || defined(PLATFORM_MICAZ) || defined(PLATFORM_IMOTE2) || defined (PLATFORM_TMOTE)
               , MultiHopLQI as MultiHop    // routing decision module
            #endif
               , NewQueuedSend as QComm     // link layer (send)
               , GenericComm as Comm        // link layer (receive)
               , TimerC
               , RandomLFSR
               , ChildrenM
               , NeighborsM
               , LedsC
               ;

    RoutingSend = RoutingLayerM.Send;
    RoutingReceive = RoutingLayerM.Receive;

    RoutingTable = MultiHop;
    ChildrenTable = ChildrenM;
    NeighborTable = NeighborsM;
    ParentControl = MultiHop;

    Main.StdControl -> QComm;
    Main.StdControl -> TimerC;
    Main.StdControl -> RoutingLayerM;
    Main.StdControl -> MultiHop.StdControl;

    MultiHop.Timer -> TimerC.Timer[unique("Timer")];  
    MultiHop.SendMsg -> QComm.SendMsg[AM_ROUTING_BEACON];
    MultiHop.ReceiveMsg -> Comm.ReceiveMsg[AM_ROUTING_BEACON];
    MultiHop.Random -> RandomLFSR;
    MultiHop.NeighborTable-> NeighborsM;

    RoutingLayerM.RoutingTable -> MultiHop;
    RoutingLayerM.RoutingChange -> MultiHop;

    RoutingLayerM.ChildrenTable -> ChildrenM;
    RoutingLayerM.NeighborTable -> NeighborsM;

    RoutingLayerM.SubSendMsg -> QComm.SendMsg[AM_TENET_ROUTING];
    RoutingLayerM.SubReceiveMsg -> Comm.ReceiveMsg[AM_TENET_ROUTING];
    RoutingLayerM.RetryTimer -> TimerC.Timer[unique("Timer")];
    RoutingLayerM.AgingTimer -> TimerC.Timer[unique("Timer")];
    RoutingLayerM.Random -> RandomLFSR;
    RoutingLayerM.Leds -> LedsC;

}

