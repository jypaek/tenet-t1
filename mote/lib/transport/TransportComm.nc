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
 * TransportComm: Configuration for Tenet Transport Layer with 
 *  - TRD (Tierd reliable dissemination),
 *  - PacketTransport,
 *  - StreamTransport, and
 *  - TCMP (ping & trace-route support).
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 8/21/2006
 **/


#include "transport.h"

configuration TransportComm {
    provides {
        interface TRD_Transport as TRD;

        interface TransportSend;
        interface TransportSend as TransportNoAckSend;
        interface PacketTransportReceive;
    #ifdef PTR_NOACK_RECEIVE_ENABLED
        interface PacketTransportReceive as PacketTransportNoAckReceive;
    #endif
        interface ConnectionSend;
    }
}
implementation {
    components  Main
                , TRD_TransportC
                , PacketTransportC
                , StreamTransportC
            #ifdef INCLUDE_TCMP
                , TCMPC
            #endif
                ;

/* TRD (Tierd reliable dissemination)
    - Task dissemination protocol in Tenet. */
    Main.StdControl -> TRD_TransportC.StdControl;
    TRD = TRD_TransportC;


/* Packet Transport
    - wired to 'SendPkt' element in Tenet. */
    Main.StdControl -> PacketTransportC.StdControl;
    TransportSend = PacketTransportC.Send;
    TransportNoAckSend = PacketTransportC.NoAckSend;
    PacketTransportReceive = PacketTransportC.Receive;
    #ifdef PTR_NOACK_RECEIVE_ENABLED
        /* Unicast-downlink is not usually used... at least not in Tenet */
        PacketTransportNoAckReceive = PacketTransportC.NoAckReceive;
    #endif


/* Stream Transport
    - wired to 'SendSTR' element in Tenet. */
    Main.StdControl -> StreamTransportC.StdControl;
    ConnectionSend = StreamTransportC;


#ifdef INCLUDE_TCMP
/* TCMP
    - hidden ping & trace_route support for debugging */
    Main.StdControl -> TCMPC;
#endif

}

