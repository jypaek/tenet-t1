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
 * TRD (Tiered Reliable Dissemination) configuration file.
 *
 * TRD is a generic dissemination protocol that reliably delivers
 * packets to all nodes that runs TRD.
 * Currently, it is customized for Tenet: disseminations are initiated
 * only at the masters, and the motes only receive and forward packets.
 * (This is why TRD_Send interface is undefined to be excluded.)
 * TRD_State module maintains states so that it can decide when and
 * what to disseminated and receive.
 * It distinguishes packets from different sender (point of dissemination)
 * so that several senders (masters in Tenet) can disseminate packets
 * simultaneously.
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 8/21/2006
 **/


#include "trd.h"

configuration TRD_C {
    provides {
        interface TRD;          // receive TRD packets through this interface
    #ifdef TRD_SEND_ENABLED
        interface TRD_Send;     // disseminate packets through this interface
    #endif
    }
}
implementation {
    components TRD_M
               , TRD_StateC
               , GenericComm as Comm
            #ifndef TESTTRD    // not testing, but wiring to Tenet
               , NewQueuedSend as QComm
            #endif
               /* NOTE: Must remember that if any module in a mote uses
                  NewQueuedSend for SendMsg, then no module should use
                  GenericComm for SendMsg since NewQueuedSend sits 
                  on top of GenericComm->SendMsg using the whole 
                  parameterized interface.
                  Otherwise, you will have signalling span-out problem.
                  For ReceiveMsg, you should still use GenericComm */
               , Main
               ;

    TRD = TRD_M;
#ifdef TRD_SEND_ENABLED
    TRD_Send = TRD_M;
#endif

#ifndef TESTTRD    // not testing, but wiring to Tenet
    Main.StdControl -> QComm;
#else
    Main.StdControl -> Comm;
#endif

    TRD_M.TRD_State -> TRD_StateC;
    
    TRD_M.ReceiveTRD -> Comm.ReceiveMsg[AM_TRD_MSG];
    TRD_M.ReceiveControl -> Comm.ReceiveMsg[AM_TRD_CONTROL];

    TRD_M.SendTRD -> Comm.SendMsg[AM_TRD_MSG];
    TRD_M.SendControl -> Comm.SendMsg[AM_TRD_CONTROL];
}

