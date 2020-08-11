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
//includes CentTree;
#include "PktTypes.h"

configuration TreeLeaf
{
#ifdef USE_ROUTE_ADAPTATION
        provides interface RoutingI;
#endif
}
implementation
{
  components Main,
            PktQueueC,
            CentTreeC,
            TreeLeafM;

  Main.StdControl -> TreeLeafM.StdControl;
  Main.StdControl -> PktQueueC.StdControl;
  Main.StdControl -> CentTreeC.StdControl;

  TreeLeafM.PktQ -> PktQueueC.PktQueueI[unique("PktQueueI")];
  TreeLeafM.CentTreeCtrlI -> CentTreeC;
  TreeLeafM.TreeSend -> CentTreeC.CentTreeSendI[CR_TYPE_DATAREL];
  TreeLeafM.TreeSendStatus -> CentTreeC.CentTreeSendStatusI[CR_TYPE_DATAREL];
  TreeLeafM.TreeRecv -> CentTreeC.CentTreeRecvI[CR_TYPE_DATAREL];
#ifdef USE_ROUTE_ADAPTATION
  RoutingI = TreeLeafM.RoutingI;
#endif
}
