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
 * Authors:		Lama Nachman
 */


#include "PXA27XPowerManagement.h"
module PXA27XPowerManagementM
{
  provides {
    interface PXA27XPowerManagement ;
  }
}

implementation {

  async command result_t PXA27XPowerManagement.SwitchPowerMode(uint8_t TargetPowerMode)
  {
   
#if 0
    if (TargetPowerMode == DEEP_SLEEP_MODE) {

    /*
     * Deep sleep settings
     * For lowest power : 
     * 		a. Enable DC-DC coverter Set PCFR[DC_EN], clear PCFR[L1_EN]
     *          b. Turn off the 13MHz Osc PCFR[OPDE]
     */ 

      // TODO: Program SYS_DEL & PWR_DEL 
      
      // Enable the DC-DC converter for lowest power setting
      //PCFR = PCFR & (~PCFR_L1_EN);
      //PCFR = PCFR | PCFR_DC_EN;
      // PCFR = PCFR | PCFR_OPDE;

          // initiate the voltage change
      asm volatile (
		  "mcr p14,0,%0,c7,c0,0\n\t"
		  :
		  : "r" (0x7)
		  );
    }
#endif
  }
}
