////////////////////////////////////////////////////////////////////////////
//
// CENS
//
// Copyright (c) 2006 The Regents of the University of California.  All
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
// Contents: 
//
// Purpose: An interface between the Centroute routing layer and the
// tenet transport and application layers
//
////////////////////////////////////////////////////////////////////////////

configuration RouteToAppC
{
  provides interface StdControl;
  provides interface RoutingSend[uint8_t protocol];
  provides interface RoutingReceive[uint8_t protocol];
  
}
implementation
{

components
  Main,
  TreeLeaf,
  RouteToAppM;

  StdControl = RouteToAppM.StdControl;
  RoutingSend = RouteToAppM.Send;
  RoutingReceive = RouteToAppM.Receive;
  
  RouteToAppM.RoutingI -> TreeLeaf.RoutingI;
}
