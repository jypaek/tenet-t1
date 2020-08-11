// $Id: PXA27XDMAChannel.nc,v 1.5 2007/03/05 00:06:07 lnachman Exp $ 

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

includes DMA;

interface PXA27XDMAChannel 
{
  
  // this interface is intended to describe the high level functionality
  // of our DMA controller.  The commands exposed by this interface represent
  // all of the information normally required by the PXA27X's DMA controller.
  // However, it is left up to the underlying implementation whether to use
  // descriptor-based or non-descriptor-based channel commands
 


  /*************************************************************************
   * Management functions
   ************************************************************************/

  /**
   * request a DMA Channel
   *
   * @param peripheralID:  identifier of the peripheral that is requesting channel
   *                       See DMA.h for a valid list of peripheralID's
   *
   * @param priority:  OR'd list of acceptable priorities for this channel.  If 
   *                   only 1 priority level is acceptable, only 1 should be given.
   *		       If any priority is acceptable, all priorities should be OR'd
   *
   * @param permanent:  TRUE if the requesting component does not intend to ever
   *                     give up the allocated channel
   * @return SUCCESS always
   */
  command result_t requestChannel(DMAPeripheralID_t peripheralID, 
				  DMAPriority_t priority, bool permanent);
 
  
  /**
   * event informing the caller of requestChannel that a channel has been allocated
   *
   * @return SUCCESS always
   */
  event result_t requestChannelDone();

  /**
   * return the channel that had previously been allocated
   *
   * @return SUCCESS if channel was allocated, FAIL if there was no channel 
   *         already allocated
   */
  command result_t returnChannel();
  

  /*************************************************************************
   * Data Control/setup functions...see PXA27x developer's manual for specific
   * definitions of the terms used
   *
   * -All of these functions may be called before a channel is allocated
   * -Relevant info must be setup before run is called
   *
  ************************************************************************/
  
  /**
   * set the source address of the DMA operation
   *
   * @param val: The address that will be the source 
   *
   * @return FAIL if error, SUCCESS otherwise.
   */
 async command result_t setSourceAddr(uint32_t val);
  
 
   /**
   * set the target address of the DMA operation
   *
   * @param val: The address that will be the target 
   *
   * @return FAIL if error, SUCCESS otherwise.
   */
 async command result_t setTargetAddr(uint32_t val);
  
   /**
   * set whether the souce address should be incremented after each transfer of 
   *  width bytes
   *
   * @param enable: TRUE if it should increment, FALSE if it should not
   *
   * @return FAIL if error, SUCCESS otherwise.
   */
 command result_t enableSourceAddrIncrement(bool enable);
 
   /**
   * set whether the target address should be incremented after each transfer of 
   *  width bytes
   *
   * @param enable: TRUE if it should increment, FALSE if it should not
   *
   * @return FAIL if error, SUCCESS otherwise.
   */
 command result_t enableTargetAddrIncrement(bool enable);
 
  /**
   * set whether the source device controls the flow or not
   *
   * @param enable: TRUE if it should control, FALSE if it should not
   *
   * @return FAIL if error, SUCCESS otherwise.
   */
 command result_t enableSourceFlowControl(bool enable);
 
   /**
   * set whether the target device controls the flow or not
   *
   * @param enable: TRUE if it should control, FALSE if it should not
   *
   * @return FAIL if error, SUCCESS otherwise.
   */
 command result_t enableTargetFlowControl(bool enable);
  
  /**
   * set the max burst size allowable for this transfer.  This parameter needs to
   * be set appropriately based on the peripheral's FIFO depth.
   * 
   *
   * @param size: 8, 16, or 32 bytes encoded in a DMAMaxBurstSize_t
   *
   * @return FAIL if error, SUCCESS otherwise.
   */
 command result_t setMaxBurstSize(DMAMaxBurstSize_t size);
 
  /**
   * set the transfer length of the DMA operation.  The underlying component is
   * free to break up this length as it feels fit
   *
   * @param length: The length, in bytes, of the transaction 
   *
   * @return FAIL if error, SUCCESS otherwise.
   */
 async command result_t setTransferLength(uint16_t length);
 
  /**
   * set the width, in bytes, of each transfer.
   *
   * @param width: 0, 1, 2, or 4 bytes encoded in a DMATransferWidth_t. Note that
   * 0 has a special meaning. See the PXA27X developer's manual for details
   *
   * @return FAIL if error, SUCCESS otherwise.
   */
 command result_t setTransferWidth(DMATransferWidth_t width);
 
 
  /**
   * start the DMA transfer running.  All necessary parameters must have already
   * been set
   *
   * @param InterruptEn:  TRUE if the interrupt event should be sent when the
   * transfer has concluded
   *
   * @return FAIL if error, SUCCESS otherwise.
   */
 async command result_t run(DMAInterruptEnable_t interruptEn);

  /**
   * start the DMA transfer running.  All necessary parameters must have already
   * been set, but the last two parameters will override what's currently stored
   * internally.  The intent of this function is to allow for faster turn around
   * when DMA channels are being chained manually in IRQ context
   *
   * @param targetAddress: address of buffer that data should be transfered into
   * @param transferLength: number of bytes to transfer in this transaction
   *
   * @return FAIL if error, SUCCESS otherwise.
   */
 
 async command result_t preconfiguredRun(uint32_t targetAddress, 
					 uint16_t transferLength);
 
  /**
   * stop the DMA transfer prematurely
   *
   * @return FAIL if error, SUCCESS otherwise.
   */
 async command result_t stop();
  
  /**
   * event that indicates that the transfer has finished because the
   * number of bytes that were requested have been transfered.  The end
   * interrupt is the normal way to detect the normal stoppage of a channel,
   * not the stop interrupt
   *
   * @return SUCCESS
   */
  async event void endInterrupt(uint16_t numBytesSent);
  
  
  /**
   * event that indicates that an end of receive condition has occured on this
   * channel.  This is typically indicative of a timeout condition or transfer has finished because the
   * number of bytes that were requested have been transfered
   *
   * @param numBytesSent is the number of bytes sent before the EOR condition occured
   *
   * @return SUCCESS
   */

  async event void eorInterrupt(uint16_t numBytesSent);
  
  /**
   * event that indicates that a stop condition has occured on this
   * channel.  This is typically due to a request stop of the transfer
   * 
   * @param numBytesSent is the number of bytes sent before the STOP condition occured
   *
   * @return SUCCESS
   */
  
  async event void stopInterrupt(uint16_t numBytesSent);
  
    /**
   * event that indicates that the DMA transaction has started (i.e. descriptor is loaded)
   *
   * @return SUCCESS
   */
  
  async event void startInterrupt();
}
