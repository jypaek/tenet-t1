// $Id: PXA27XHPLDMAM.nc,v 1.3 2005/09/19 20:48:06 radler Exp $ 

/*									tab:4
 *  IMPORTANT: READ BEFORE DOWNLOADING, COPYING, INSTALLING OR USING.  By
 *  downloading, copying, installing or using the software you agree to
 *  this license.  If you do not agree to this license, do not download,
 *  install, copy or use the software.
 *
 *  Intel Open Source License 
 *
 *  Copyright (c) 2002 Intel Corporation 
 *  All rights reserved. 
 *  Redistribution and use in source and binary forms, with or without
 *  modification, are permitted provided that the following conditions are
 *  met:
 * 
 *	Redistributions of source code must retain the above copyright
 *  notice, this list of conditions and the following disclaimer.
 *	Redistributions in binary form must reproduce the above copyright
 *  notice, this list of conditions and the following disclaimer in the
 *  documentation and/or other materials provided with the distribution.
 *      Neither the name of the Intel Corporation nor the names of its
 *  contributors may be used to endorse or promote products derived from
 *  this software without specific prior written permission.
 *  
 *  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 *  ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 *  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
 *  PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE INTEL OR ITS
 *  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 *  EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 *  PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 *  PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 *  LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 *  NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 *  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 * 
 * 
 */
/*
 *
 * Authors:		Phil Buonadonna
 */


module PXA27XHPLDMAM
{
  provides {
    interface PXA27XHPLDMA;
    //    interface PXA27XDMAExtReq[uint8_t pin];
  }
}

implementation
{

  async command void PXA27XHPLDMA.setByteAlignment(uint32_t channel, bool enable) 
  {
    if (channel < 32) {
      if (enable) {
	DALGN |= (1 << channel);
      }
      else {
	DALGN &= ~(1 << channel);
      }
    }
    return;
  }

  async command void PXA27XHPLDMA.mapChannel(uint32_t channel,uint16_t peripheralID){
    if(channel < 32){
      DRCMR(peripheralID) = DRCMR_CHLNUM(channel) | DRCMR_MAPVLD;
    }
    return;
  }
  async command void PXA27XHPLDMA.unmapChannel(uint32_t channel){
    if(channel < 32){
      DRCMR(channel) = 0;
    }
  }
  
  async command void PXA27XHPLDMA.setDCSR(uint32_t channel,uint32_t val) {
    if (channel < 32) {
      DCSR(channel) = val;
    }
    return;
  }

  async command uint32_t PXA27XHPLDMA.getDCSR(uint32_t channel) {
    uint32_t val;
    if (channel < 32) {
      val = DCSR(channel);
      return val;
    }
    return 0;
  }

  async command void PXA27XHPLDMA.setDCMD(uint32_t channel, uint32_t val) {
    if (channel < 32) {
      DCMD(channel) = val;
    }
    return;
  }

  async command uint32_t PXA27XHPLDMA.getDCMD(uint32_t channel) {
    uint32_t val;
    if (channel < 32) {
      val = DCMD(channel);
      return val;
    }
    return 0;
  }

  async command void PXA27XHPLDMA.setDDADR(uint32_t channel ,uint32_t val) {
    if (channel < 32) {
      DDADR(channel) = val;
    }
    return;
  }

  async command uint32_t PXA27XHPLDMA.getDDADR(uint32_t channel) {
    uint32_t val;
    if (channel < 32) {
      val = DDADR(channel);
      return val;
    }
    return 0;
  }

  async command void PXA27XHPLDMA.setDSADR(uint32_t channel, uint32_t val){
    if (channel < 32) {
      DSADR(channel) = val;
    }
    return;
  }

  async command uint32_t PXA27XHPLDMA.getDSADR(uint32_t channel) {
    uint32_t val;
    if (channel < 32) {
      val = DSADR(channel);
      return val;
    }
    return 0;
  }

  async command void PXA27XHPLDMA.setDTADR(uint32_t channel, uint32_t val) {
    if (channel < 32) {
      DTADR(channel) = val;
    }
    return;
  }

  async command uint32_t PXA27XHPLDMA.getDTADR(uint32_t channel) {
    uint32_t val;
    if (channel < 32) {
      val = DTADR(channel);
      return val;
    }
    return 0;
  }

#if 0
  //we don't expose any of the external DMA pins, so no sense in exposing this.  However, there's also no sense in deleting it...
  async command uint8_t PXA27XDMAExtReq.getDREQPend[uint8_t pin]() 
  {
    uint8_t val;
    if (pin < 3) {
      atomic val = (DRQSR(pin) & 0x1F);
    }
    return val;
  }

  async command void PXA27XDMAExtReq.clearDREQPend[uint8_t pin]()
  {
    if (pin < 3) {
      atomic DRQSR(pin) = DRQSR_CLR;
    }
    return;
  }
#endif

  async command uint32_t PXA27XHPLDMA.getDPCSR()
  {
    return DPCSR;
  }

  async command void PXA27XHPLDMA.setDPCSR(uint32_t val)
  {
    DPCSR = val;
    return;
  }
}
