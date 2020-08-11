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
 * $Revision: 1.14 $
 */

/**
 * @author Phil Buonadonna
 */


/**
 * NewQueuedSend is a modification of QueuedSend in tinyos-1.x/lib.
 * Performs link-level retransmissions.
 *
 * @author Jeongyeup Paek
 * @modified 2/5/2007
 **/

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
    }
}
implementation {
    components Main, 
               NewQueuedSendM,
               GenericComm as Comm,
        #if defined(PLATFORM_TELOSB) || defined(PLATFORM_MICAZ) || defined(PLATFORM_IMOTE2) || defined(PLATFORM_TMOTE)
               CC2420RadioC as RadioC,   // MicaZ/Telos
        #elif defined(PLATFORM_MICA2) || defined(PLATFORM_MICA2DOT)
               CC1000RadioC as RadioC,   // Mica2
        #elif defined(PLATFORM_EMSTAR)
               BRadioM as RadioC,
               //CC1000RadioIntM,
        #endif
#ifdef EMSTAR_NO_KERNEL
               EmTimerC, 
#else
               TimerC, 
#endif
               RandomLFSR;

    // You can think that,
    //  TimerC and GenericComm are automatically init/started here.
#ifdef EMSTAR_NO_KERNEL
    Main.StdControl -> EmTimerC;
#else
    Main.StdControl -> TimerC;
#endif

    /// provided interfaces ///////////////////////////////////
    StdControl = NewQueuedSendM;
    SendMsg = NewQueuedSendM;

    RetransmitControl = NewQueuedSendM;

    /// used interfaces ///////////////////////////////////////
    NewQueuedSendM.SubStdControl -> Comm;
    NewQueuedSendM.SubSendMsg -> Comm.SendMsg;

    NewQueuedSendM.Random -> RandomLFSR;
   

#if defined(PLATFORM_EMSTAR)
    //NewQueuedSendM.MacControl -> CC1000RadioIntM;
    NewQueuedSendM.ResendTimer -> EmTimerC.EmTimerI[unique("Timer")];
#else
    NewQueuedSendM.MacControl -> RadioC.MacControl;
    NewQueuedSendM.ResendTimer -> TimerC.Timer[unique("Timer")];
#endif
    // MicaZ/Telosb specific component (will not work on Mica2)
}

