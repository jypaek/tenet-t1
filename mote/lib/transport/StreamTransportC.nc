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
 * StreamTransport: NACK based end-to-end reliable transport protocol.
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 1/24/2007
 **/


#include "transport.h"
#include "streamtransport.h"

configuration StreamTransportC {
    provides {
        interface StdControl;
        interface ConnectionSend as Send;
    }
}
implementation {
    components Main
                , StreamTransportM
                , RoutingLayerC
                , StrLoggerC as Logger
                , TrPacketM
                , TimerC
                ;

    Main.StdControl -> TimerC;

    StdControl = StreamTransportM;
    Send = StreamTransportM;

    StreamTransportM.RoutingSend -> RoutingLayerC.RoutingSend[PROTOCOL_STREAM_TRANSPORT];
    StreamTransportM.RoutingReceive -> RoutingLayerC.RoutingReceive[PROTOCOL_STREAM_TRANSPORT];

    StreamTransportM.LoggerControl -> Logger.StdControl;
    StreamTransportM.PktLogger -> Logger.PktLogger;

    StreamTransportM.TrPacket -> TrPacketM;

    StreamTransportM.RetryTimer -> TimerC.Timer[unique("Timer")];
    StreamTransportM.SubTimer -> TimerC.Timer[unique("Timer")];
#ifdef STR_2_CON
    StreamTransportM.SubTimer2 -> TimerC.Timer[unique("Timer")];
#endif
}

