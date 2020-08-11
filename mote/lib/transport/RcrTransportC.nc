/*
* "Copyright (c) 2006~2008 University of Southern California.
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
 * Configuration for RCRT (Rate-controlled Reliable Transport protocol)
 *
 * - centralized rate adaptation
 * - end-2-end reliable loss recovery
 * - centralized/end-2-end rate allocation
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified May/23/2008
 **/


#include "transport.h"
#include "rcrtransport.h"

configuration RcrTransportC {
    provides {
        interface StdControl;
        interface RcrtSend as Send;
    }
}
implementation {
    components Main
                , RcrTransportM 
                , RoutingLayerC
                , RtrLoggerC as Logger
                , TrPacketM
                , LocalTimeC
                , TimerC
            #ifdef RCRT_DEBUG
                , NewQueuedSend as QComm
                , GenericComm as Comm
            #endif
                ;

    Main.StdControl -> TimerC;

    StdControl = RcrTransportM;
    Send = RcrTransportM;

    RcrTransportM.RoutingSend -> RoutingLayerC.RoutingSend[PROTOCOL_RCR_TRANSPORT];
    RcrTransportM.RoutingReceive -> RoutingLayerC.RoutingReceive[PROTOCOL_RCR_TRANSPORT];

    RcrTransportM.LoggerControl -> Logger.StdControl;
    RcrTransportM.PktLogger -> Logger.PktLogger;

    RcrTransportM.TrPacket -> TrPacketM;
    RcrTransportM.LocalTime -> LocalTimeC;
    RcrTransportM.LocalTimeInfo -> LocalTimeC;

    RcrTransportM.RateControlTimer -> TimerC.Timer[unique("Timer")];
    RcrTransportM.SubTimer -> TimerC.Timer[unique("Timer")];
#ifdef RCRT_2_CON
    RcrTransportM.RateControlTimer2 -> TimerC.Timer[unique("Timer")];
    RcrTransportM.SubTimer2 -> TimerC.Timer[unique("Timer")];
#endif
    RcrTransportM.RetryTimer -> TimerC.Timer[unique("Timer")];
    
#ifdef RCRT_DEBUG
    RcrTransportM.DebugSend -> QComm.SendMsg[0x99];
    RcrTransportM.DebugReceive -> Comm.ReceiveMsg[0x99];
#endif
}

