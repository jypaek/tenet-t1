/*                                    tab:4
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
 *
 * Authors:        Jason Hill, David Gay, Philip Levis
 * Date last modified:  6/25/02
 *
 */

/**
 * @author Jason Hill
 * @author David Gay
 * @author Philip Levis
 */

/**
 * Tenet Base Station
 *
 * Ths module provides TOSBase-like functionality but does not modify
 * the address field while forwarding packets from the radio to the
 * UART.  It also receives all packets from the UART (regardless of
 * the destination address) and forwards it to the radio. It
 * accomplishes this by using the radio and UART modules explicitly
 * depending on the interface to be used for packet transmission as
 * opposed to using the address field to determine the interface for
 * packet transmission (like in TOSBase). 
 *
 * LED status:
 * RED Toggle - Message dropped due to radio/uart queue overflow
 * GREEN Toggle - Message forwarded from uart to radio
 * YELLOW Toggle - Message forwarded from radio to uart
 * 
 **/


#include "BaseStation.h"
#include "routinglayer.h"

configuration BaseStation {
}
implementation {

    components Main
            , BaseStationM
            , NewQueuedSend as QComm
            , GenericComm as Comm
            , UARTForwardComm as UARTComm
        #ifdef BS_SERVICE
            , ServiceM
        #endif
        #if defined(RSSI_ROUTER) || defined(PLATFORM_MICA2) || defined(PLATFORM_MICA2DOT)
            , MultiHopRSSI as MultiHop   // routing decision module
        #elif defined(PLATFORM_TELOSB) || defined(PLATFORM_MICAZ) || defined(PLATFORM_IMOTE2)
            , MultiHopLQI as MultiHop    // routing decision module
        #endif
            , TimerC
            , RandomLFSR
            , LocalTimeC
        #ifdef GLOBAL_TIME
            , TimeSyncC
        #endif
        #if defined(PLATFORM_TELOSB) || defined(PLATFORM_MICAZ) || defined(PLATFORM_IMOTE2)
            , CC2420RadioC as RadioC
        #elif defined(PLATFORM_MICA2) || defined(PLATFORM_MICA2DOT)
            , CC1000RadioC as RadioC
        #endif
            , LedsC
            ;


    Main.StdControl -> BaseStationM;
#ifdef GLOBAL_TIME
    Main.StdControl -> TimeSyncC;
#endif

    Main.StdControl -> MultiHop.StdControl;
    MultiHop.Timer -> TimerC.Timer[unique("Timer")];  
    MultiHop.Random -> RandomLFSR;
    MultiHop.SendMsg -> QComm.SendMsg[AM_ROUTING_BEACON];
    MultiHop.ReceiveMsg -> Comm.ReceiveMsg[AM_ROUTING_BEACON];

    // Use UardForwardComm directly for UART send
    BaseStationM.UARTControl -> UARTComm;
    BaseStationM.UARTSend -> UARTComm.SendMsgAll;
    BaseStationM.UARTReceive -> UARTComm.ReceiveMsgAll;// hack around papameterized interface

    // Use NewQueuedSend for Radio send
    BaseStationM.RadioControl -> QComm;
    BaseStationM.RadioSend -> QComm.SendMsgAll;    // hack around parameterized interface
    BaseStationM.RadioReceive -> Comm.ReceiveMsgRadioAll;// hack around parameterized interface

    BaseStationM.Leds -> LedsC;

#ifdef BS_SERVICE
    Main.StdControl -> ServiceM;
    ServiceM.ServiceResponseSend -> QComm.SendMsg[AM_BS_SERVICE];
    ServiceM.ServiceRequestReceive -> Comm.ReceiveMsg[AM_BS_SERVICE];

#ifdef GLOBAL_TIME
    ServiceM.GlobalTime -> TimeSyncC;
    ServiceM.LocalTime -> LocalTimeC;
    ServiceM.LocalTimeInfo -> LocalTimeC;
#ifdef TIMESYNC_HELPER
    ServiceM.TimeSyncInfo -> TimeSyncC;
#endif
#endif
    ServiceM.RadioControl -> RadioC;
#endif // BS_SERVICE
}

