/**
 * "Copyright (c) 2006-2009 University of Southern California.
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
 * @modified Feb/16/2008
 * @author Jeongyeup Paek (jpaek@usc.edu)
 **/

#include "TestCyclopsMsg.h"

configuration TestCyclopsHost { }
implementation {
    components Main
                , TestCyclopsHostM
                , hostNeuron
                , GenericComm as Comm
                , TimerC
                , LedsC 
                ;

    Main.StdControl -> TimerC;
    Main.StdControl -> TestCyclopsHostM;
    Main.StdControl -> Comm;
    
    TestCyclopsHostM.Leds -> LedsC;
    
    TestCyclopsHostM.SendMsg -> Comm.SendMsg[AM_QUERY_CYCLOPS];
    TestCyclopsHostM.ReceiveMsg -> Comm.ReceiveMsg[AM_QUERY_CYCLOPS];
  
    TestCyclopsHostM.neuronControl -> hostNeuron;
    TestCyclopsHostM.neuronH -> hostNeuron;
}

