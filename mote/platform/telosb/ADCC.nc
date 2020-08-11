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
 * Obsolete, use ADCHILC/M instead.
 * Read ADC_README about how to use the provided interfaces, e.g.
 * ADCControl.bind has a slightly different meaning than before.
 * - Revision -------------------------------------------------------------
 * $Revision: 1.1 $
 * $Date: 2006-08-18 21:31:22 $
 * @author Vlado Handziski <handzisk@tkn.tu-berlin.de>
 * @author Jan Hauer <hauer@tkn.tu-berlin.de>
 * @author: Kevin Klues <klues@tkn.tu-berlin.de>
 * ========================================================================
 */
 
configuration ADCC
{
  provides {
    interface ADC[uint8_t port];
    interface ADCControl;
    interface StdControl;
  }
}
implementation
{
  components ADCM
#ifdef __msp430_have_adc12
    , MSP430ADC12C
#else
// need support for ADC10 msp430 devices, etc
#error ADCC: Compiling for an msp430 device that does not have ADC12
#endif
    ;
  
  ADC = ADCM.ADC;
  ADCControl = ADCM;
  StdControl = ADCM;
#ifdef __msp430_have_adc12
  StdControl = MSP430ADC12C;
  ADCM.MSP430ADC12Single -> MSP430ADC12C.MSP430ADC12Single[unique("MSP430ADC12")];
#endif
}
