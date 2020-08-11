/*									tab:4
 *  IMPORTANT: READ BEFORE DOWNLOADING, COPYING, INSTALLING OR USING.  By
 *  downloading, copying, installing or using the software you agree to
 *  this license.  If you do not agree to this license, do not download,
 *  install, copy or use the software.
 *
 *  Intel Open Source License 
 *
 *  Copyright (c) 2005 Intel Corporation 
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

/* @author Lama Nachman
*/

#include "PXA27XPowerModes.h"

module PXA27XPowerModesM {
  provides interface PXA27XPowerModes;
}


implementation
{

  void DisablePeripherals() {
    /*
     * TODO : Should have a better way of doing this. Start/Stop peripherals
     * using the stop function?
     */ 
    
    // Disable UARTs
    STIER &= ~IER_UUE;
    BTIER &= ~IER_UUE;
    FFIER &= ~IER_UUE;

    // Kill SPI ports
    SSCR0_1 &= ~SSCR0_SSE;
    SSCR0_2 &= ~SSCR0_SSE;
    SSCR0_3 &= ~SSCR0_SSE;

    // Disable USB Client
    UDCCR &= ~UDCCR_UDE;

    // Disable I2C (Standard & PWR)
    ICR &= ~ICR_IUE;
    PICR &= ~ICR_IUE;

    // Disable OS Timers
    OMCR4 &= ~(OMCR_CRES(7));
    OMCR5 &= ~(OMCR_CRES(7));
    OMCR6 &= ~(OMCR_CRES(7));
    OMCR7 &= ~(OMCR_CRES(7));
    OMCR8 &= ~(OMCR_CRES(7));
    OMCR9 &= ~(OMCR_CRES(7));
    OMCR10 &= ~(OMCR_CRES(7));
    OMCR11 &= ~(OMCR_CRES(7));
   
    // TODO : Do I2S, AC97, SDIO, USB host, MSL, etc
  }

  // TODO : This should be split to imote2/pxa specific sections

  void EnterDeepSleep() {

    DisablePeripherals();

    // Enable wakeup from PMIC (GPIO 1, R & F edges) and RTC
    /*
     * Enable wakeup from PMIC (GPIO 1, R & F edges) and RTC
     * TODO : get the desired wakeup sources from the caller
     */
    PWER = PWER_WERTC | PWER_WE1;	// only enable wakeup from RTC
    PRER |= PRER_RE1;
    PFER |= PFER_FE1;

#if 0	// Radio
    PWER |= PWER_WE0;
    PRER |= PRER_RE0;
    PFER |= PFER_FE0;
#endif

    // TODO: Set desired GPIO state

    // Set PSLR register to not retain state
    PSLR &= ~(PSLR_SL_R3 | PSLR_SL_R2 | PSLR_SL_R1 | PSLR_SL_R0);
    PSLR &= ~(PSLR_SL_PI(3));
  
    // Set minimum delay for PWR_DEL and SYS_DEL
    //PSLR &= ~(PSLR_SYS_DEL(0xf));
    //PSLR &= ~(PSLR_PWR_DEL(0xf));

    // Enable 32K OSC just in case it wasn't enabled
    OSCC |= OSCC_OON;

    // Disable linear regulator
    PCFR = PCFR & ~PCFR_L1_EN;

    // Disable the 13 MHz OSC and wait for status 
    PCFR = PCFR | PCFR_OPDE;
    while ((OSCC & OSCC_OOK) == 0);
    
    // Enable deep-sleep DC-DC convertor
    PCFR = PCFR | PCFR_DC_EN; 

    // Switch to deep sleep mode
    asm volatile (
                  "mcr p14, 0, %0, c7, c0, 0"
                  :
                  : "r" (7)
                  );  
    while(1);
  }

  command void PXA27XPowerModes.SwitchMode(uint8_t targetMode) {
    switch (targetMode) {
      case DEEP_SLEEP_MODE:
        // Shutdown all LDOs that are not controlled by the sleep signal
        EnterDeepSleep();
        break;
      default:
        break;
    }
  }
}
