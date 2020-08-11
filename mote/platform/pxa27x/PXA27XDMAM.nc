// $Id: PXA27XDMAM.nc,v 1.5 2007/03/05 00:06:07 lnachman Exp $ 

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

/**
 *
 * @author Robbie Adler
 **/

includes GlobalUtil;

module PXA27XDMAM
{
  provides {
    interface PXA27XDMAChannel[uint8_t channel];
    interface StdControl;
}

  uses {
    interface PXA27XInterrupt as Interrupt;
  }
}

implementation
{

#include "paramtask.h"

#ifdef ASSERT_IRQ_TIME
  extern uint32_t currentIRQExecutionTime __attribute__((C));
#endif


  /************
Implementation Notes:

Current thinking is to use the unique("") construct combined with a request, requestDone 
mechanism to allow more than the 32 possible channels to at least be supported.
  ********/

  /*******************
The following belong in a header file, but I can't put it where I want it due to the way that nesc currently
handles included files
***********/

  typedef struct {
    uint32_t DDADR;
    uint32_t DSADR;
    uint32_t DTADR;
    uint32_t DCMD;
  } DMADescriptor_t;

  typedef struct {
    bool channelValid;
    uint8_t realChannel;
    DMAPeripheralID_t peripheralID;
    uint16_t length;
  } DMAChannelInfo_t;
  
  typedef struct {
    uint8_t virtualChannel;
    bool inUse;
    bool permanent;
  } ChannelMapItem_t;
  
#define NUMDMACHANNELS uniqueCount("DMAChannel")
  
  //need to figure out how to align each entry on a 16 byte boundary if we're going to use
  //the descriptor based mode. 
  DMADescriptor_t mDescriptorArray[NUMDMACHANNELS];
norace  DMAChannelInfo_t mChannelArray[NUMDMACHANNELS];

  ChannelMapItem_t  mPriorityMap[32];
 
  bool gInitialized = FALSE;
    
  command result_t StdControl.init(){
    
    int i;
    if(gInitialized == FALSE){
      atomic{
	for(i=0; i<NUMDMACHANNELS; i++){
	  mChannelArray[i].channelValid = FALSE;
	}
      }
      call Interrupt.allocate();
      gInitialized = TRUE;
    }
    
    return SUCCESS;
  }

  command result_t StdControl.start(){
    
    call Interrupt.enable();
    
    return SUCCESS;
  }

  command result_t StdControl.stop(){
    call Interrupt.disable();
    return SUCCESS;
  }
  
  
  void postRequestChannelDone(uint32_t arg){
    uint8_t channel = (uint8_t)arg;
    signal PXA27XDMAChannel.requestChannelDone[channel]();
  }
  DEFINE_PARAMTASK(postRequestChannelDone);


  command result_t PXA27XDMAChannel.requestChannel[uint8_t channel](DMAPeripheralID_t peripheralID, 
								    DMAPriority_t priority, 
								    bool permanent){
    
    //want to allow a device to request multiple priority level so that it can get 
    //the highest possible available.
    uint32_t i, realChannel;
    bool foundChannel = FALSE;
    atomic{
      if(mChannelArray[channel].channelValid ==TRUE){
	foundChannel = TRUE;
      }
      
      if(foundChannel == FALSE && (priority & DMA_Priority1)){
	for(i=0; i<7; i++){
	  realChannel = (i < 4)? i: i+12;
	  if(mPriorityMap[realChannel].inUse == FALSE){
	    //found a channel to use!
	    mPriorityMap[realChannel].inUse = TRUE;
	    mPriorityMap[realChannel].virtualChannel = channel;
	    mPriorityMap[realChannel].permanent = permanent;
	    mChannelArray[channel].channelValid = TRUE;
	    mChannelArray[channel].realChannel = realChannel;
	    mChannelArray[channel].peripheralID = peripheralID;
	    foundChannel = TRUE;
	    break;
	  }
	}
      }
      if((foundChannel == FALSE) && (priority & DMA_Priority2)){
	for(i=0; i<7; i++){
	  realChannel = (i < 4)? i+4: i+16;
	  if(mPriorityMap[realChannel].inUse == FALSE){
	    //found a channel to use!
	    mPriorityMap[realChannel].inUse = TRUE;
	    mPriorityMap[realChannel].virtualChannel = channel;
	    mPriorityMap[realChannel].permanent = permanent;
	    mChannelArray[channel].channelValid = TRUE;
	    mChannelArray[channel].realChannel = realChannel;
	    mChannelArray[channel].peripheralID = peripheralID;
	    foundChannel = TRUE;
	    break;
	  }
	}
      }
      if((foundChannel == FALSE) && (priority & DMA_Priority3)){
	for(i=0; i<7; i++){
	  realChannel = (i < 4)? i+8: i+20;
	  if(mPriorityMap[realChannel].inUse == FALSE){
	    //found a channel to use!
	    mPriorityMap[realChannel].inUse = TRUE;
	    mPriorityMap[realChannel].virtualChannel = channel;
	    mPriorityMap[realChannel].permanent = permanent;
	    mChannelArray[channel].channelValid = TRUE;
	    mChannelArray[channel].realChannel = realChannel;
	    mChannelArray[channel].peripheralID = peripheralID;
	    foundChannel = TRUE;
	    break;
	  } 
	}
      }
      if((foundChannel == FALSE) && (priority & DMA_Priority4)){
	for(i=0; i<7; i++){
	  realChannel = (i < 4)? i+12: i+24;
	  if(mPriorityMap[realChannel].inUse == FALSE){
	    //found a channel to use!
	    mPriorityMap[realChannel].inUse = TRUE;
	    mPriorityMap[realChannel].virtualChannel = channel; 
	    mPriorityMap[realChannel].permanent = permanent;
	    mChannelArray[channel].channelValid = TRUE;
	    mChannelArray[channel].realChannel = realChannel;
	    mChannelArray[channel].peripheralID = peripheralID;
	    foundChannel = TRUE;
	    break;
	  }
	}
      }
    }
    if(foundChannel == TRUE){
      POST_PARAMTASK(postRequestChannelDone, channel);
    }
    //if we didn't find a channel, we will need to rerun this function once we finish with a channel
    //we will deal with this case later
    return SUCCESS; 
  }
  
  command result_t PXA27XDMAChannel.returnChannel[uint8_t channel](){
    uint32_t realChannel;
    atomic{
      realChannel = mChannelArray[channel].realChannel;
      mChannelArray[channel].channelValid = FALSE;
      mPriorityMap[realChannel].inUse = FALSE;
    }
    return SUCCESS;
  }
  
  default event result_t PXA27XDMAChannel.requestChannelDone[uint8_t channel](){
    return FAIL;
  }
  
  async command result_t PXA27XDMAChannel.setSourceAddr[uint8_t channel](uint32_t val){
    atomic{
      mDescriptorArray[channel].DSADR = val;
    }
    return SUCCESS;
  }

  async command result_t PXA27XDMAChannel.setTargetAddr[uint8_t channel](uint32_t val){
    atomic{
      mDescriptorArray[channel].DTADR = val;
    }
    return SUCCESS;
  }
  
  command result_t PXA27XDMAChannel.enableSourceAddrIncrement[uint8_t channel](bool enable){
    atomic{
      mDescriptorArray[channel].DCMD = (enable == TRUE) ? mDescriptorArray[channel].DCMD | DCMD_INCSRCADDR : mDescriptorArray[channel].DCMD & ~DCMD_INCSRCADDR;
    }
    return SUCCESS;
  }
  command result_t PXA27XDMAChannel.enableTargetAddrIncrement[uint8_t channel](bool enable){
     atomic{
      mDescriptorArray[channel].DCMD = (enable == TRUE) ? mDescriptorArray[channel].DCMD | DCMD_INCTRGADDR : mDescriptorArray[channel].DCMD & ~DCMD_INCTRGADDR;
     }
     return SUCCESS;
  }

  command result_t PXA27XDMAChannel.enableSourceFlowControl[uint8_t channel](bool enable){
    atomic{
      mDescriptorArray[channel].DCMD = (enable == TRUE) ? mDescriptorArray[channel].DCMD | DCMD_FLOWSRC : mDescriptorArray[channel].DCMD & ~DCMD_FLOWSRC;
    }
    return SUCCESS;
  }
  
  command result_t PXA27XDMAChannel.enableTargetFlowControl[uint8_t channel](bool enable){
    atomic{
      mDescriptorArray[channel].DCMD = (enable == TRUE) ? mDescriptorArray[channel].DCMD | DCMD_FLOWTRG : mDescriptorArray[channel].DCMD & ~DCMD_FLOWTRG;
    } 
    return SUCCESS;
  }
  
  command result_t PXA27XDMAChannel.setMaxBurstSize[uint8_t channel](DMAMaxBurstSize_t size){
    if(size >= DMA_8ByteBurst && size <= DMA_32ByteBurst){
      atomic{
	//clear it out since otherwise |'ing doesn't work so well
	mDescriptorArray[channel].DCMD &= ~DCMD_MAXSIZE;  
	mDescriptorArray[channel].DCMD |= DCMD_SIZE(size); 
	  }
      return SUCCESS;
    }
    return FAIL;
  }
  
  async command result_t PXA27XDMAChannel.setTransferLength[uint8_t channel](uint16_t length){
    if(length > 8191){
      //PXA27X allows only a max length of 8k-1 bytes
      return FAIL;
    }
    atomic{
      mChannelArray[channel].length = length;
      //clear it out since otherwise |'ing doesn't work so well
      mDescriptorArray[channel].DCMD &= ~DCMD_MAXLEN; 
      mDescriptorArray[channel].DCMD |= DCMD_LEN(length); 
    }
    return SUCCESS;
  }
  
  command result_t PXA27XDMAChannel.setTransferWidth[uint8_t channel](DMATransferWidth_t width){
    if(width >= DMA_NonPeripheralWidth && width <= DMA_4ByteWidth){
      atomic{
	//clear it out since otherwise |'ing doesn't work so well
	mDescriptorArray[channel].DCMD &= ~DCMD_MAXWIDTH; 
	mDescriptorArray[channel].DCMD |= DCMD_WIDTH(width);
	  }
      return SUCCESS;
    }
    return FAIL;
  }
  
  async command result_t PXA27XDMAChannel.preconfiguredRun[uint8_t channel](uint32_t targetAddress, 
									    uint16_t transferLength){
    
    uint8_t realChannel;
    
    atomic{
      realChannel= mChannelArray[channel].realChannel;
      
      //clear it out since otherwise |'ing doesn't work so well
      DCMD(realChannel) = (DCMD(realChannel) & ~DCMD_MAXLEN) | DCMD_LEN(transferLength);
      DTADR(realChannel) = targetAddress;
      DCSR(realChannel) |=  DCSR_RUN;
    }
    return SUCCESS;
    
  }
 

  async command result_t PXA27XDMAChannel.run[uint8_t channel](DMAInterruptEnable_t interruptEn){
    uint8_t realChannel;
    uint32_t width;
    uint32_t DCSRinterrupts, DCMDinterrupts;

    atomic{
      realChannel= mChannelArray[channel].realChannel;
      width = (mDescriptorArray[channel].DCMD >> 14) & 0x3;
     
      DRCMR(mChannelArray[channel].peripheralID) = DRCMR_CHLNUM(realChannel) | DRCMR_MAPVLD;
      if(width){
	DALGN |= (1 << realChannel);
      }
      else{
	DALGN &= ~(1 << realChannel);
      }
      
      DCSR(realChannel) = DCSR_NODESCFETCH;
      //EORIRQEN and STOPIRQEN live in DCSR
      DCSRinterrupts = ((interruptEn & DMA_EORINTEN)? (DCSR_EORIRQEN | DCSR_EORSTOPEN): 0) | ((interruptEn & DMA_STOPINTEN)? DCSR_STOPIRQEN: 0);
      
      //ENDIRQEN and STARTIRQEN live in DCMD
      DCMDinterrupts = ((interruptEn & DMA_ENDINTEN)? DCMD_ENDIRQEN: 0) | ((interruptEn & DMA_STARTINTEN)? DCMD_STARTIRQEN: 0);
      
      DCMD(realChannel) = mDescriptorArray[channel].DCMD | DCMDinterrupts;
      
      DSADR(realChannel) =  mDescriptorArray[channel].DSADR;
      DTADR(realChannel) = mDescriptorArray[channel].DTADR;
      DCSR(realChannel) =  DCSR_RUN | DCSR_NODESCFETCH | DCSRinterrupts;
    }
    return SUCCESS;
  }

  async command result_t PXA27XDMAChannel.stop[uint8_t channel](){
    uint8_t realChannel, virtualChannel;
    uint16_t bytesSent;
    atomic{
      realChannel = mChannelArray[channel].realChannel;
      
      //enable the interrupt
      DCSR(realChannel) |= DCSR_STOPIRQEN;
      DCSR(realChannel) &= ~DCSR_RUN;
    }
    return SUCCESS;
  }

  default async event void PXA27XDMAChannel.stopInterrupt[uint8_t channel](uint16_t numBytesSent) {
    return;
  }
  
  default async event void PXA27XDMAChannel.startInterrupt[uint8_t channel]() {
    return;
  }
  
  default async event void PXA27XDMAChannel.eorInterrupt[uint8_t channel](uint16_t numBytesSent) {
    return;
  }
  
  default async event void PXA27XDMAChannel.endInterrupt[uint8_t channel](uint16_t numByteSent)  {
    return;
  }
  
  //this is a shared variable in IRQ context...it is protect by the HW
  norace volatile uint32_t globalDMAVirtualChannelHandled __attribute__((C));
  
  async event void Interrupt.fired()
  {
    uint32_t IntReg;
    uint32_t realChannel, virtualChannel,status, update, dcmd;
    uint16_t currentLength;
    
    IntReg = DINT;
    
    //ARM guarantees that interrupts are disabled in interrupt context unless they are
    //explicitly reenabled.
    realChannel = 31 - _pxa27x_clzui(IntReg);
    virtualChannel = mPriorityMap[realChannel].virtualChannel;
    currentLength = mChannelArray[virtualChannel].length;
    
    status = DCSR(realChannel);
    dcmd = DCMD(realChannel);
        
    update = (status & 0xFFA00000) | DCSR_MASKRUN;

    if(status & DCSR_BUSERRINTR){
      //we should signal that an error occured and handle appropriately
      DCSR(realChannel) = update | DCSR_BUSERRINTR;
    }
    
    if(status & DCSR_STARTINTR){
      //always need to clear this
      DCSR(realChannel) = update | DCSR_STARTINTR;
      if(dcmd & DCMD_STARTIRQEN){
	//if we requested an interrupt, we should signal
	signal PXA27XDMAChannel.startInterrupt[virtualChannel](); 
      }
    }
    
    //stop irqen must be cleared if set before channel can be restarted
    if(status & (DCSR_STOPINTR | DCSR_STOPIRQEN)){
      DCSR(realChannel) = update & DCSR_STOPIRQEN;
      signal PXA27XDMAChannel.stopInterrupt[virtualChannel](currentLength-DCMD_LEN(DCMD(realChannel))); 
    }

    if(status & (DCSR_RASINTR | DCSR_RASIRQEN)){
      DCSR(realChannel) = update | DCSR_RASINTR;
    }

    if(status & DCSR_EORINT){
      //always need to clear this.
      DCSR(realChannel) = update | DCSR_EORINT;
      if(status & DCSR_EORIRQEN){
	//if we had requested an interrupt, we should signal
	signal PXA27XDMAChannel.eorInterrupt[virtualChannel](currentLength-DCMD_LEN(DCMD(realChannel))); 
      }
    }

    if(status & DCSR_ENDINTR){
      //we always need to clear this
      DCSR(realChannel) = update | DCSR_ENDINTR;
      if(dcmd & DCMD_ENDIRQEN){
      	//if we had requested that this interrupt us, we should signal
	signal PXA27XDMAChannel.endInterrupt[virtualChannel](currentLength); 
      }
    }

    globalDMAVirtualChannelHandled = virtualChannel;
     
    return;
  }


}

