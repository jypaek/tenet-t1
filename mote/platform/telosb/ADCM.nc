/*
 * Copyright (c) 2004, Technische Universitaet Berlin
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without 
 * modification, are permitted provided that the following conditions 
 * are met:
 * - Redistributions of source code must retain the above copyright notice,
 *   this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright 
 *   notice, this list of conditions and the following disclaimer in the 
 *   documentation and/or other materials provided with the distribution.
 * - Neither the name of the Technische Universitaet Berlin nor the names 
 *   of its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS 
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT 
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT 
 * OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, 
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED 
 * TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, 
 * OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY 
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT 
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE 
 * USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * - Description ----------------------------------------------------------
 * Obsolete, use HIL interface (wrappers) instead.
 * nesC will issue a warning about bind() being called asynchronously,
 * which can be ignored.
 * - Revision -------------------------------------------------------------
 * $Revision: 1.1 $
 * $Date: 2006-08-18 21:31:22 $
 * @author Vlado Handziski <handzisk@tkn.tu-berlin.de>
 * @author Jan Hauer <hauer@tkn.tu-berlin.de>
 * @author: Kevin Klues <klues@tkn.tu-berlin.de>
 * ========================================================================
 */
includes MSP430ADC12;

module ADCM
{
  provides {
    interface ADC[uint8_t port];
    interface ADCControl;
    interface StdControl;
  }
  uses {
    interface MSP430ADC12Single;
  }
}

implementation
{

  enum
  {
    TOSH_ADC_PORTMAPSIZE = uniqueCount("ADCPort")
  };

  // member of TOSH_adc_portmap:
  // bit 0-3: inputChannel
  // bit 4-6: refVolt
  // bit 7: refVoltLevel
  norace uint8_t TOSH_adc_portmap[TOSH_ADC_PORTMAPSIZE];
  norace uint8_t samplingRate;
  norace bool continuousData;
  norace uint8_t owner;
  bool initialized;
  volatile bool busy;
  
  command result_t StdControl.init()
  { 
    call ADCControl.init();
    return SUCCESS;
  }
  
  command result_t StdControl.start()
  {
    return SUCCESS; 
  }
  
  command result_t StdControl.stop()
  {
    continuousData = FALSE;
    atomic busy = FALSE;
    return SUCCESS;
  }
  
  command result_t ADCControl.init() 
  {
    if (!initialized){
      samplingRate = 0xFF;  // max. sampling time (1024 ticks ADC12CLK)
      initialized = 1;
    } 
    return SUCCESS;
  }

  command result_t ADCControl.setSamplingRate(uint8_t rate) 
  {
    // Assumption: SMCLK runs at 1 MHz
    switch (rate){
      case (TOS_ADCSample3750ns): samplingRate = 0x00; break;
      case (TOS_ADCSample7500ns): samplingRate = 0x01; break;
      case (TOS_ADCSample15us):   samplingRate = 0x02; break;
      case (TOS_ADCSample30us):   samplingRate = 0x03; break;
      case (TOS_ADCSample60us):   samplingRate = 0x04; break;
      case (TOS_ADCSample120us):  samplingRate = 0x06; break;
      case (TOS_ADCSample240us):  samplingRate = 0x08; break;
      case (TOS_ADCSample480us):  samplingRate = 0x0A; break;
    }
    return SUCCESS;
  }

  command result_t ADCControl.bindPort(uint8_t port, uint8_t adcPort) 
  {  
    if (port < TOSH_ADC_PORTMAPSIZE){
      TOSH_adc_portmap[port] = adcPort;
      return SUCCESS;
    } else
      return FAIL;
  }

  result_t triggerConversion(uint8_t port){
    MSP430ADC12Settings_t settings;  
    settings.refVolt2_5 = (TOSH_adc_portmap[port] & 0x80) >> 7;
    settings.clockSourceSHT = SHT_SOURCE_SMCLK;
    settings.clockSourceSAMPCON = SAMPCON_SOURCE_SMCLK;
    settings.referenceVoltage = (TOSH_adc_portmap[port] & 0x70) >> 4;
    settings.clockDivSAMPCON = SAMPCON_CLOCK_DIV_1;
    settings.clockDivSHT = SHT_CLOCK_DIV_1;
    settings.inputChannel = TOSH_adc_portmap[port] & 0x0F;
    settings.sampleHoldTime = samplingRate;

    // this will create a nesC warning (async call), which
    // can be ignored. 
    if (call MSP430ADC12Single.bind(settings) == SUCCESS){
      if ((!continuousData && call MSP430ADC12Single.getData() != MSP430ADC12_FAIL)
          || (continuousData && call MSP430ADC12Single.getDataRepeat(0) != MSP430ADC12_FAIL)) {
        owner = port;
        return SUCCESS;
      }
    }
    atomic busy = FALSE;
    return FAIL;
  }
    
  async command result_t ADC.getData[uint8_t port]()
  {  
    bool oldBusy;
    if (port >= TOSH_ADC_PORTMAPSIZE)
      return FAIL;
    atomic {
      oldBusy = busy;
      busy = TRUE;
    } 
    if (!oldBusy){
      continuousData = FALSE;
      return triggerConversion(port);
    }
    return FAIL;  
  }


  async command result_t ADC.getContinuousData[uint8_t port]()
  {  
    bool oldBusy;
    if (port >= TOSH_ADC_PORTMAPSIZE)
      return FAIL;
    atomic {
      oldBusy = busy;
      busy = TRUE;
    }      
    if (!oldBusy){
      continuousData = TRUE;
      return triggerConversion(port);
    } else
      return FAIL;
  }

  default async event result_t ADC.dataReady[uint8_t num](uint16_t d){return SUCCESS;}

  async event result_t MSP430ADC12Single.dataReady(uint16_t d)
  {
    if (!continuousData){
      atomic busy = FALSE;
      return signal ADC.dataReady[owner](d);
    } else if (signal ADC.dataReady[owner](d) == FAIL){
        atomic busy = FALSE;
        return FAIL;
      }
    return SUCCESS;
  }
}

