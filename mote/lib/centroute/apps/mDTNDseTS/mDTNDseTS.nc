////////////////////////////////////////////////////////////////////////////
//
// CENS
//
// Copyright (c) 2003 The Regents of the University of California.  All
// rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions
// are met:
//
// - Redistributions of source code must retain the above copyright
//   notice, this list of conditions and the following disclaimer.
//
// - Neither the name of the University nor the names of its
//   contributors may be used to endorse or promote products derived
//   from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS''
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
// THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
// PARTICULAR  PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE REGENTS OR
// CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
// EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
// PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
// PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
// OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// Contents: This file contains the interface for the data buffer used in
//
// Purpose: The purpose of this functionality is to cache sensor readings
//
////////////////////////////////////////////////////////////////////////////

includes MultihopTypes;
includes protocols;
#ifdef USE_SYMPATHY
includes Sympathy;
#endif

configuration mDTNDseTS
{

}
implementation
{

components
  Main,
  MyLedsC,
#ifdef EMSTAR_NO_KERNEL
  EmTimerC,
#else
  TimerC,
#endif
  ESS_mDTNC,
  DseC,
#ifdef USE_DELUGE
  DelugeC,
#endif
  mDTNDseM,
#ifndef USE_CENTROUTE
  MultihopTree,
#endif // USE_CENTROUTE
  TimeSynchM,
  HPLPowerManagementM,
  EssSysTimeC,
  RandomLFSR,
#ifdef USE_SYMPATHY
  SReturnStateM,
#endif
#ifdef TIMESYNC_DEBUG
  EmStatusServerC,
#endif
  CC1000ControlM,
  ResetCountC,
  CC1000RadioIntM;

#ifdef USE_DELUGE
  Main.StdControl -> DelugeC;
#endif
  Main.StdControl -> mDTNDseM.StdControl;

#ifndef USE_CENTROUTE
  Main.StdControl -> MultihopTree.StdControl;
#endif // USE_CENTROUTE
  Main.StdControl -> ESS_mDTNC.StdControl;
  
  Main.StdControl -> TimeSynchM.StdControl;
#ifdef TIMESYNC_DEBUG
  Main.StdControl -> EmStatusServerC.StdControl;
#endif


  // Control radio power.
  mDTNDseM.CC1000Control -> CC1000ControlM;

  mDTNDseM.ResetCountI -> ResetCountC;

  //dse wiring
  mDTNDseM.mDTNSendI -> ESS_mDTNC.mDTNSendI[MULTIHOP_DSE];
  mDTNDseM.mDTNRecvI -> ESS_mDTNC.mDTNRecvI[MULTIHOP_DSE];

  mDTNDseM.Leds -> MyLedsC;

#ifdef USE_SYMPATHY
  mDTNDseM.ProvideCompMetrics -> SReturnStateM.ProvideCompMetrics[SCOMP_STATS2];
#endif

  mDTNDseM.QeAcceptQueryI -> DseC;
  mDTNDseM.ChAcceptCmdI -> DseC;
  mDTNDseM.EssSysTimeI -> EssSysTimeC.EssSysTimeI;
#ifdef EMSTAR_NO_KERNEL
  mDTNDseM.JitterTimer -> EmTimerC.EmTimerI[unique("Timer")];
  mDTNDseM.LedsTimer -> EmTimerC.EmTimerI[unique("Timer")];
#else
  mDTNDseM.JitterTimer -> TimerC.Timer[unique("Timer")];
  mDTNDseM.LedsTimer -> TimerC.Timer[unique("Timer")];
#endif
  mDTNDseM.Random -> RandomLFSR;
  mDTNDseM.SetListeningMode -> CC1000RadioIntM.SetListeningMode;
  mDTNDseM.SetTransmitMode -> CC1000RadioIntM.SetTransmitMode;
#if defined(TOSH_HARDWARE_MICA2DOT) || defined(TOSH_HARDWARE_MICA2)
  mDTNDseM.enableHPLPowerM -> HPLPowerManagementM.Enable;  
#endif

  //timesync wiring
  TimeSynchM.mDTNRecvI ->ESS_mDTNC.mDTNRecvI[TIMESYNC_APP];
  TimeSynchM.Leds -> MyLedsC.Leds;
  TimeSynchM.EssSysTimeI -> EssSysTimeC.EssSysTimeI;
#ifdef USE_SYMPATHY
  TimeSynchM.ProvideCompMetrics -> SReturnStateM.ProvideCompMetrics[SCOMP_STATS5];
#endif 

#ifndef PLATFORM_EMSTAR
  TimeSynchM.RadioReceiveCoordinator -> CC1000RadioIntM.RadioReceiveCoordinator;
  //TimeSynchM.RadioSendCoordinator -> CC1000RadioIntM.RadioSendCoordinator;
#endif
#ifdef TIMESYNC_DEBUG
  TimeSynchM.EmStatusServerI -> EmStatusServerC.EmStatusServerI[unique("EmStatusServerI")];
#endif
}
