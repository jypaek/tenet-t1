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
 * This is part of the Pursuer Evasion Game.
 * It is the configuration file of Evader Application.
 * Sends packet periodically using low power radio.
 *
 */
//author@ Marcos Vieira <mvieira@usc.edu>

//includes EvaderMsg;
includes CountMsg;

configuration Evader{
}
implementation {
 components Main, EvaderM, TimerC, GenericCommPromiscuous as Comm,LedsC,TimeSyncC, TimeSyncDebuggerC, QueuedSend, RandomLFSR;

  Main.StdControl -> EvaderM;
  Main.StdControl -> TimerC;
  Main.StdControl -> QueuedSend;
  Main.StdControl -> Comm;
  Main.StdControl -> TimeSyncC;

  Main.StdControl -> TimeSyncDebuggerC;

  EvaderM.Timer ->TimerC.Timer[unique("Timer")];
  EvaderM.CommControl -> Comm;
  EvaderM.DataMsg -> QueuedSend.SendMsg[AM_COUNT_MSG];
  EvaderM.Leds -> LedsC;
  EvaderM.GlobalTime -> TimeSyncC;
  EvaderM.Random -> RandomLFSR;
}
