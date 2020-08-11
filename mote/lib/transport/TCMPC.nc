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
 * TCMP: Tenet Control Message Protocol for Ping and Trace-route
 *
 * This is used for debugging purposes, and can be en/dis-abled at compile time.
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 1/24/2007
 **/


#include "routinglayer.h"

configuration TCMPC {
    provides {
        interface StdControl;
    }
}
implementation {
    components Main
               , TCMPM 
               , RoutingLayerC
            #ifdef PLATFORM_PC // avoid infinite loop in TOSSIM
               , TimerC
               , RandomLFSR
            #endif
               ;

#ifdef PLATFORM_PC // avoid infinite loop in TOSSIM
    Main.StdControl -> TimerC;
#endif

    StdControl = TCMPM;
    TCMPM.RoutingTable -> RoutingLayerC.RoutingTable;
    TCMPM.RoutingSend -> RoutingLayerC.RoutingSend[PROTOCOL_TCMP];
    TCMPM.RoutingReceive -> RoutingLayerC.RoutingReceive[PROTOCOL_TCMP];
#ifdef PLATFORM_PC // avoid infinite loop in TOSSIM
    TCMPM.Timer -> TimerC.Timer[unique("Timer")];
    TCMPM.Random -> RandomLFSR;
#endif
}


