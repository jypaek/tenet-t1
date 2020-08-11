/*									tab:4
 *
 *
 * "Copyright (c) 2000-2002 The Regents of the University  of California.  
 * All rights reserved.
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose, without fee, and without written agreement is
 * hereby granted, provided that the above copyright notice, the following
 * two paragraphs and the author appear in all copies of this software.
 * 
 * IN NO EVENT SHALL THE UNIVERSITY OF CALIFORNIA BE LIABLE TO ANY PARTY FOR
 * DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES ARISING OUT
 * OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN IF THE UNIVERSITY OF
 * CALIFORNIA HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 * 
 * THE UNIVERSITY OF CALIFORNIA SPECIFICALLY DISCLAIMS ANY WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE.  THE SOFTWARE PROVIDED HEREUNDER IS
 * ON AN "AS IS" BASIS, AND THE UNIVERSITY OF CALIFORNIA HAS NO OBLIGATION TO
 * PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS."
 *
 */
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
/* @author Phil Buonadonna
 * @author Robbie Adler   
*/
includes trace;

module PXA27XUClockM {
  provides interface UClock;
  provides interface StdControl;
  uses interface PXA27XInterrupt as OSTIrq;
}


implementation
{
  /* This implementation of Clock uses the PXA27x OST Channel 6 and only 
   * supports the use of UTimerM. 
   */
#define USE_NEW_TIMER 1

  uint8_t gmScale;
  uint8_t gmInterval;
  uint8_t gmCounter;

  async event void OSTIrq.fired() {
    
#if !USE_NEW_TIMER
    bool fFireEvent = FALSE;
#endif
    if (OSSR & OIER_E6) {
      //trace("int");
      OSSR = (OIER_E6);  // Reset the Status register bit.
#if USE_NEW_TIMER
      signal UClock.fire();
#else
      atomic {
	gmCounter++;
	if (gmCounter >= gmInterval) {
	  gmCounter = 0;
	  fFireEvent = TRUE;
	}
      }
      if (fFireEvent) {
	signal UClock.fire();
      }
#endif
    }
  }

  command result_t StdControl.init() {
#if !USE_NEW_TIMER
    atomic {
      gmScale = DEFAULT_SCALE;
      gmInterval = DEFAULT_INTERVAL;
      gmCounter = 0;
    }
#endif
    /* Disable all clock interrupts */
    //OIER = 0x0UL;

    call OSTIrq.allocate();
    return SUCCESS;
  }

  command result_t StdControl.start() {
#if USE_NEW_TIMER
    //we want a simple match based timer...i.e. Not periodic, interrupt at match
    OMCR6 = (OMCR_C | OMCR_CRES(0x4));  // Resolution = 1us
    atomic {
      OIER |= (OIER_E6); // Enable the channel 6 interrupt
      OSCR6 = 0x1;  // start the  counter
    }
    call OSTIrq.enable(); //enable the main interrupt
#else
    uint8_t mInt, mScl;
    atomic {
      mInt = gmInterval;
      mScl = gmScale;
      gmCounter = 0;
    }

    OMCR6 = (OMCR_C | OMCR_P | OMCR_R | OMCR_CRES(0x1));  // Resolution = 1/32768th sec

    call UClock.setRate(mInt,mScl);

    atomic {
      OIER |= (OIER_E6); // Enable the interrupts
    }
    call OSTIrq.enable();
    //OSCR6 = 0x0UL;  // Start the counter
#endif
    
    return SUCCESS;
  }

  command result_t StdControl.stop() {

    atomic {
      OIER &= ~(OIER_E6); // Disable interrupts on channel 6
    }
    call OSTIrq.disable();
    OMCR6 = 0x0UL;  // Disable the counter..

    return SUCCESS;
  }


  async command result_t UClock.setRate(uint32_t interval, uint32_t scale) {
    // roughly translate mica's clock since it sits in the common interface 
    // directory.  Base on interfaces/Clock.h the following mapping is ~correct.
    
#if USE_NEW_TIMER
    //don't really want to do anything here.  For now, our low level clock will always be based on the LPO @ 1/32768th sec
    //all settings are determined in init/start
    call UClock.setInterval(interval);
#else
    uint32_t rate;

    atomic {
      gmScale = scale;
      gmInterval = interval;
      gmCounter = 0;
    }
    call OSTIrq.allocate();

    switch (scale) {
    case 0: rate =  (0 << 0); break;
    case 1: rate =  (1 << 0); break;
    case 2: rate =  (1 << 3); break;
    case 3: rate =  (1 << 5); break;
    case 4: rate =  (1 << 6); break;
    case 5: rate =  (1 << 7); break;
    case 6: rate =  (1 << 8); break;
    default: rate = 0;
    }

    // Set OS Timer Match Register 6 to the given rate
    OMCR6 = (OMCR_C | OMCR_P | OMCR_R | OMCR_CRES(0x1));  // Resolution = 1/32768th sec
    OSMR6 = rate;
    call OSTIrq.enable();
    atomic {
      OIER |= (OIER_E6); // Enable the interrupts
    }
    OSCR6 = 0x0UL;  // Start the counter
#endif
    return SUCCESS;
  }

  async command void UClock.setInterval(uint32_t value) {
#if USE_NEW_TIMER
    //In the future, we probably set to some number of microseconds based on val and how long it typically take to config...multiply by 32 for now
    OSMR6 = value;
    OSCR6 = 0x0;  // start the  counter
    
#endif    
    atomic {
      gmInterval = value;
    }
    return;
  }

  async command void UClock.setNextInterval(uint32_t value) {

  }

  async command uint32_t UClock.getInterval() {
   uint8_t ItvlVal;
    atomic {
      ItvlVal = gmInterval;
    }
    return ItvlVal;
  }

  async command uint32_t UClock.getScale() {
      return 0;
  }

  async command void UClock.setNextScale(uint32_t scale) {
      ;
  }

  async command result_t UClock.setIntervalAndScale(uint32_t interval, uint32_t scale) {
      return SUCCESS;
  }

  async command uint32_t UClock.readCounter() {
 #if USE_NEW_TIMER
    //need to return 0 due to a check in the upper layer
    return OSCR6;
    //return 0;
#else
    uint32_t CntrVal;
       
    atomic {
      CntrVal = gmCounter;
    }
    return CntrVal;
#endif

  }

  async command void UClock.setCounter(uint32_t n) {
      OSCR6 = n;
      return;
  }

  async command void UClock.intDisable() {
      ;
  }

  async command void UClock.intEnable() {
      ;
  }

  default async event result_t UClock.fire() {
      return SUCCESS;
  }

}
