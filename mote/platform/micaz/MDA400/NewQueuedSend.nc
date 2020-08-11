/*                                  tab:4
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
 * Author: Phil Buonadonna
 * $Revision: 1.1 $
 */

/**
 * @author Phil Buonadonna
 */



/* NOTE:
   Must remember that if any module in a mote uses
   NewQueuedSend for SendMsg, then no module should use
   GenericComm for SendMsg since NewQueuedSend sits 
   on top of GenericComm->SendMsg using the whole 
   parameterized interface.
   Otherwise, you will have signalling span-out problem.
   For ReceiveMsg, you should still use GenericComm 
   - jpaek
*/
configuration NewQueuedSend {
    provides {
        interface StdControl;
        interface SendMsg[uint8_t typeid];
        interface RetransmitControl;
        //interface RetransmitDecision[uint8_t typeid];
    #ifdef TOKEN_BUCKET
        interface TokenBucket;
    #endif
    }
}
implementation {
    components Main, 
               NewQueuedSendM,
            #ifdef MDA400
               GenericCommSendVBwrapperC as Comm,
            #else
               GenericComm as Comm,
            #endif
               CC2420RadioC,   // MicaZ/Telos
               TimerC, RandomLFSR;

    // You can think that,
    //  TimerC and GenericComm are automatically init/started here.
    Main.StdControl -> TimerC;
    Main.StdControl -> Comm;

    /// provided interfaces ///////////////////////////////////
    StdControl = NewQueuedSendM.StdControl;
    SendMsg = NewQueuedSendM.SendMsg;

    RetransmitControl = NewQueuedSendM;
    //RetransmitDecision = NewQueuedSendM;
#ifdef TOKEN_BUCKET
    TokenBucket = NewQueuedSendM;
#endif

    /// used interfaces ///////////////////////////////////////
    NewQueuedSendM.SubStdControl -> Comm;
    NewQueuedSendM.SubSendMsg -> Comm.SendMsg;

    NewQueuedSendM.Random -> RandomLFSR;
    NewQueuedSendM.ResendTimer -> TimerC.Timer[unique("Timer")];
#ifdef TOKEN_BUCKET
    NewQueuedSendM.TokenTimer -> TimerC.Timer[unique("Timer")];
#endif

    NewQueuedSendM.MacControl -> CC2420RadioC.MacControl;
    // MicaZ/Telosb specific component (will not work on Mica2)
}

