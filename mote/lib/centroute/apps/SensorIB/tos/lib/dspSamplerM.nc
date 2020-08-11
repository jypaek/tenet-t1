/*
 *
 * Copyright (c) 2003 The Regents of the University of California.  All 
 * rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 *
 * - Neither the name of the University nor the names of its
 *   contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS''
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
 * PARTICULAR  PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE REGENTS OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 *
 * Authors:   Mohammad Rahimi mhr@cens.ucla.edu
 * History:   created 01/06/2004
 *
 *
 *
 */


module dspSamplerM
{
  provides {
    interface StdControl as SamplerControl;
    interface SampleReply;
    interface SampleRequest;

    interface ADCReset;
  }
  uses interface StdControl as internalSamplerControl;
  uses interface Sample;
  uses interface ADCReset as internalADCReset;
}

implementation
{
  // Link through the ADCReset interface back to IBADC.
  command result_t ADCReset.reset() {
    call internalADCReset.reset();
    return SUCCESS;
  }
  
  command result_t SamplerControl.init() {
    call internalSamplerControl.init();
    return SUCCESS;
  }
  
  command result_t SamplerControl.start() {
    call internalSamplerControl.start();
    return SUCCESS;
  }
 
  command result_t SamplerControl.stop() {
    call internalSamplerControl.stop();
    return SUCCESS;
  }
  
  command int8_t SampleRequest.getSample(uint8_t channel,uint8_t channelType,uint16_t interval,uint8_t param) {
    return call  Sample.getSample(channel,channelType,interval,param);
  }
 
  command result_t SampleRequest.set_digital_output(uint8_t channel,uint8_t state) {
    return call  Sample.set_digital_output(channel,state);
  }

  command result_t SampleRequest.reTask(int8_t record,uint16_t interval) {
    return call  Sample.reTask(record,interval);
  }

  command result_t SampleRequest.stop(int8_t record) {
    return call  Sample.stop(record);
  }
  
  command uint8_t SampleRequest.availableSamplingRecords() {
    return call  Sample.availableSamplingRecords();
  }
    
  event result_t Sample.dataReady(int8_t samplerID,uint8_t channel,uint8_t channelType,uint16_t data) {
    return signal SampleReply.dataReady(samplerID,channel,channelType,data);
  }

  default event result_t SampleReply.dataReady(int8_t samplerID,uint8_t channel,uint8_t channelType,uint16_t data) {
    return SUCCESS;
  }

}
