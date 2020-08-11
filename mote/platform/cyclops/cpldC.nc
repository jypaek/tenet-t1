////////////////////////////////////////////////////////////////////////////
// 
// CENS 
// Agilent
//
// Copyright (c) 2003 The Regents of the University of California.  All 
// rights reserved.
//
// Copyright (c) 2003 Agilent Corporation 
// rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions
// are met:
//
// - Redistributions of source code must retain the above copyright
//   notice, this list of conditions and the following disclaimer.
//
// - Neither the name of the University nor Agilent Corporation nor 
//   the names of its contributors may be used to endorse or promote 
//   products derived from this software without specific prior written 
//   permission.
//
// THIS SOFTWARE IS PROVIDED BY THE REGENTS , AGILENT CORPORATION AND 
// CONTRIBUTORS ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, 
// BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS 
// FOR A PARTICULAR  PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE REGENTS OR
// AGILENT CORPORATION OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, 
// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT 
// NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, 
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
// OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// Contents: This file contains wiring of cpldM component.
//          
//
////////////////////////////////////////////////////////////////////////////
//
// $Header
//
// $Log: not supported by cvs2svn $
// Revision 1.2  2007-03-15 20:02:06  jhicks
// Parameterized the CPLD download code to allow multiple modules to access
// and receive their correct signals
//
// Revision 1.1  2005/04/14 23:08:05  local
// initial check in
//
// Revision 1.3  2004/08/26 20:10:02  rick
// 8/26/04 RLB: implemented: 1) 150 mS delay before signal in RUN_CAMERA mode
//                           2) signal on interrupt for self-completing modes
//
// Revision 1.2  2004/08/25 00:03:06  rick
// 8/24/04 RLB: all potential sources of contention have been removed. Capture and transfer modes have not been tested yet.
//
// Revision 1.1  2004/06/15 00:36:02  mhr
// creating a cpld configuration for cpldM to have access to other components like LedsC
//
// Revision 1.2  2004/05/28 18:58:32  mhr
// com stack removed since was not necessary
//
// Revision 1.1  2004/05/06 20:24:50  mhr
// initial check in
//
//
// Authors : 
//           Mohammad Rahimi mhr@cens.ucla.edu 
//           Rick Baer       rick_baer@agilent.com 
//
////////////////////////////////////////////////////////////////////////////


configuration cpldC {
  provides {
    interface StdControl as cpldControl;
    interface cpld[uint8_t id];
  }
 }
implementation {
    components cpldM,LedsC,TimerC;

    cpldControl=cpldM;
    cpld=cpldM;
    
    cpldM.Leds -> LedsC.Leds;

    cpldM.Timer -> TimerC.Timer[unique("Timer")];
}
