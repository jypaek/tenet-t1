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
 * PacketTransport: Simple end-to-end ACK based Reliable Transport Protocol.
 *
 * A fixed number of end-to-end retransmissions will be performed based on
 * end-to-end acknowledgement. No windowing, and hence a bit slow.
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 2/6/2006
 **/


#include "transport.h"

configuration PacketTransportC {
    provides {
        interface StdControl;
        interface TransportSend as Send;
        interface PacketTransportReceive as Receive;
        interface TransportSend as NoAckSend;
    }
}
implementation {
    components Main
                , PacketTransportM
#ifdef USE_ROUTE_ADAPTATION
		, RouteToAppC
                , CentTreeC
#else
                , RoutingLayerC
#endif
                , TrPacketM
#ifdef EMSTAR_NO_KERNEL
                , EmTimerC
#else
                , TimerC
#endif
                ;
#ifdef EMSTAR_NO_KERNEL
    Main.StdControl -> EmTimerC;
#else
    Main.StdControl -> TimerC;
#endif

    StdControl = PacketTransportM;
    Send = PacketTransportM.Send;
    Receive = PacketTransportM.Receive;
    NoAckSend = PacketTransportM.NoAckSend;

#ifdef USE_ROUTE_ADAPTATION
    PacketTransportM.RoutingSend -> RouteToAppC.RoutingSend[PROTOCOL_PACKET_TRANSPORT];
    PacketTransportM.RoutingReceive -> RouteToAppC.RoutingReceive[PROTOCOL_PACKET_TRANSPORT];
    PacketTransportM.RoutingTable -> CentTreeC;
#else
    PacketTransportM.RoutingSend -> RoutingLayerC.RoutingSend[PROTOCOL_PACKET_TRANSPORT];
    PacketTransportM.RoutingReceive -> RoutingLayerC.RoutingReceive[PROTOCOL_PACKET_TRANSPORT];
    PacketTransportM.RoutingTable -> RoutingLayerC;
#endif
    PacketTransportM.TrPacket -> TrPacketM;

#ifdef EMSTAR_NO_KERNEL
    PacketTransportM.SubTimer -> EmTimerC.EmTimerI[unique("Timer")];
    PacketTransportM.RetryTimer -> EmTimerC.EmTimerI[unique("Timer")];
#else    
    PacketTransportM.SubTimer -> TimerC.Timer[unique("Timer")];
    PacketTransportM.RetryTimer -> TimerC.Timer[unique("Timer")];
#endif
}

