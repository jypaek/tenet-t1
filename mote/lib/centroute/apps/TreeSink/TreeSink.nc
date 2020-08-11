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
////////////////////////////////////////////////////////////////////////////
includes CentTree;

configuration TreeSink
{
}
implementation
{
  components Main,
            PktQueueC,
//            PktQueue_RnpC as PktQueueC,
            TimerC,
//            BeaconerC,        
#ifdef EMSTAR_NO_KERNEL
	    EmSocketC,
#else
            EmPdServerC,
	    EmStatusServerC,
#endif
            CentTreeC,
            TreeSinkM;

  Main.StdControl -> TreeSinkM.StdControl;
//  Main.StdControl -> BeaconerC.StdControl;
  Main.StdControl -> PktQueueC.StdControl;
  Main.StdControl -> TimerC.StdControl;
  Main.StdControl -> CentTreeC.StdControl;
#ifdef EMSTAR_NO_KERNEL
  Main.StdControl -> EmSocketC.StdControl;
#else
  Main.StdControl -> EmStatusServerC.StdControl;
  Main.StdControl -> EmPdServerC.StdControl;
#endif

//  TreeSinkM.TreeSend -> CentTreeC.CentTreeSendI[15];
  TreeSinkM.CentTreeCtrlI -> CentTreeC;
  TreeSinkM.TreeSinkI -> CentTreeC.CentTreeSinkI;

#ifdef EMSTAR_NO_KERNEL
  TreeSinkM.TreePd -> 
      EmSocketC.EmSocketI[unique("EmPdServerI")];
#else
  TreeSinkM.TreePd -> 
      EmPdServerC.EmPdServerI[unique("EmPdServerI")];
#endif

}
