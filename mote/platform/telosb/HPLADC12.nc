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
 * Interface for controlling ADC12-functionality of MSP430.
 * - Revision -------------------------------------------------------------
 * $Revision: 1.1 $
 * $Date: 2006-08-18 21:31:22 $
 * @author: Jan Hauer (hauer@tkn.tu-berlin.de)
 * ========================================================================
 */
        
includes  MSP430ADC12;

interface HPLADC12
{
  async command void setControl0(adc12ctl0_t control0); 
  async command void setControl1(adc12ctl1_t control1);
  async command adc12ctl0_t getControl0(); 
  async command adc12ctl1_t getControl1(); 
  
  /* Sets ADC12CTL0 to control0 except it leaves REFON, REF2_5V unchanged */
  async command void setControl0_IgnoreRef(adc12ctl0_t control0); 
  
  async command void setMemControl(uint8_t idx, adc12memctl_t memControl); 
  async command adc12memctl_t getMemControl(uint8_t i); 
  async command uint16_t getMem(uint8_t i); 

  
  async command void setIEFlags(uint16_t mask); 
  async command uint16_t getIEFlags(); 
  
  async command void resetIFGs(); 
  async command uint16_t getIFGs(); 

  async event void memOverflow();
  async event void timeOverflow();
  async event void converted(uint8_t number);

  async command bool isBusy();
  /* ATTENTION: setConversionMode and setSHT etc. require ENC-flag to be reset! 
     (disableConversion) */
  async command void setConversionMode(uint8_t mode);
  async command void setSHT(uint8_t sht);
  async command void setMSC();
  async command void resetMSC();
  async command void setRefOn();
  async command void setRefOff();
  async command uint8_t getRefon();     // off if 0, else on
  async command void setRef1_5V();
  async command void setRef2_5V();
  async command uint8_t getRef2_5V();   // 1.5 V if 0, else 2.5 V
    
  async command void enableConversion();
  async command void disableConversion();
  async command void startConversion();
  async command void stopConversion();
  
  async command bool isInterruptPending();
  async command void off();
  async command void on();
}

