/**
 * "Copyright (c) 2006~2009 University of Southern California.
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
 **/

/**
 * Test Application for TRD (tiered-reliable dissemination)
 *
 * @author Jeongyeup Paek (jpaek@usc.edu)
 * @modified Feb/16/2009
 **/

#include "testtrd.h"

configuration TestTRD {

}
implementation {
    components TestTRDM as App, Main,
               TRD_C,
               GenericComm as Comm,
               TimerC;

    Main.StdControl -> App.StdControl;
    Main.StdControl -> TimerC;
    Main.StdControl -> Comm;

    App.Timer -> TimerC.Timer[unique("Timer")];

    App.TRD -> TRD_C;
#ifdef TRD_SEND_ENABLED
    App.TRD_Send -> TRD_C.TRD_Send;
#endif

    App.UartSendMsg -> Comm.SendMsg[AM_TEST_TRD];
}

