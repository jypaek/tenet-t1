
/**
 *
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 2/5/2007
 **/

#define INCLUDE_STR
#define INCLUDE_RCR

#include "AM.h"
#include "transport.h"

configuration TestTransport {

}
implementation {
    components Main
                , TestTransportM
                , TRD_TransportC
                , PacketTransportC
            #ifdef INCLUDE_STR
                , StreamTransportC
            #endif
            #ifdef INCLUDE_RCR
                , RcrTransportC
            #endif
            #ifdef INCLUDE_TCMP
                , TCMPC
            #endif
                , LocalTimeC
                , NewQueuedSend
                , TimerC
                , LedsC
                , RoutingLayerC
                ;

    Main.StdControl -> TestTransportM;
    Main.StdControl -> PacketTransportC;
#ifdef INCLUDE_TCMP
    /* TCMP - hidden ping & trace_route support */
    Main.StdControl -> TCMPC;
#endif

    TestTransportM.PktTrSend -> PacketTransportC.Send;
    TestTransportM.PktTrNoAckSend -> PacketTransportC.NoAckSend;
    TestTransportM.PacketTransportReceive -> PacketTransportC.Receive;
    
    TestTransportM.TRD_Transport -> TRD_TransportC;
#ifdef INCLUDE_STR
    Main.StdControl -> StreamTransportC;
    TestTransportM.StreamTransportSend -> StreamTransportC;
#endif
#ifdef INCLUDE_RCR
    Main.StdControl -> RcrTransportC;
    TestTransportM.RcrTransportSend -> RcrTransportC;
#endif
    
    TestTransportM.TaskTimer1 -> TimerC.Timer[unique("Timer")];
    TestTransportM.TaskTimer2 -> TimerC.Timer[unique("Timer")];
    TestTransportM.StateTimer -> TimerC.Timer[unique("Timer")];
    TestTransportM.LocalTime -> LocalTimeC;
    TestTransportM.LocalTimeInfo -> LocalTimeC;
    TestTransportM.Leds -> LedsC;
    TestTransportM.ParentControl -> RoutingLayerC;
    TestTransportM.RoutingTable -> RoutingLayerC;
    TestTransportM.RetransmitControl -> NewQueuedSend;
}

