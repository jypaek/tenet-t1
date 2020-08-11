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
/* @author Lama Nachman, Jonathan Huang
*/

includes trace;

module PXA27XSysTimeM {
  provides interface StdControl;
  provides interface SysTime64;
  uses interface PXA27XInterrupt as OSTIrq1;
  uses interface PXA27XInterrupt as OSTIrq2;
}


implementation
{
  
  // by ARM ARM, interrupts are disabled in ISR unless explicitly enabled
  norace uint32_t TimeHigh;

   void task wrapped() {
      trace(DBG_USR1, "Wrapped around %d\r\n",OSCR0);
   }

   command result_t StdControl.init() {
      call OSTIrq1.allocate();
      call OSTIrq2.allocate();
      return SUCCESS;
   }

   command result_t StdControl.start() {
      OSCR0 = 0x1;
      OSMR1 = 0;	// interrupt on wrap around, use Match register 1
      OIER |= OIER_E1;	// enable
      TimeHigh = 0;
      call OSTIrq1.enable();
      return SUCCESS;
   }

   command result_t StdControl.stop() {
      OIER &= ~(OIER_E1);
      call OSTIrq1.disable();
      return SUCCESS;
   }

   async command uint32_t SysTime64.getTime32() {
      uint32_t time;
      atomic {
         time = OSCR0;
      }
      return time;
   }

   async command result_t SysTime64.setAlarm(uint32_t val) {
       atomic {
           OSMR2 = val;         // interrupt on Match register 2
           OIER |= OIER_E2;     // enable match register 2
       }
       call OSTIrq2.enable();
       return SUCCESS;
   }

   async command result_t SysTime64.getTime64(uint32_t *tLow, uint32_t *tHigh) {
      atomic {
         *tLow = OSCR0;
         *tHigh = TimeHigh;
      }
      return SUCCESS;
   }

   async event void OSTIrq1.fired() {
      if (OSSR & OIER_E1) {
         // Wrap around condition
         OSSR |= OIER_E1;	// clear the status reg
         
         // Increment the time
         TimeHigh++;
         //post wrapped();
      }
   }

   async event void OSTIrq2.fired() {
       uint32_t val;
       //post wrapped();
      if (OSSR & OIER_E2) {
          // match register 2 value is reached
          OSSR |= OIER_E2; // clear the status reg
          OIER &= ~(OIER_E2); // disable match register 2 interrupt
          atomic { val = OSMR2; }
          signal SysTime64.alarmFired(val);
          call OSTIrq2.disable();
      }
   }
   
   default async event result_t SysTime64.alarmFired(uint32_t val) {return SUCCESS;}
}
