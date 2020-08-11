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

/* @author Lama Nachman, Robbie Adler
*/


includes trace;
includes frequency;

module DVFSM {
  provides interface DVFS;
  provides interface BluSH_AppI as SwitchFreq;
  provides interface BluSH_AppI as GetFreq;
  uses interface PMIC;
}


implementation
{
#include "pmic.h"

  command result_t DVFS.SwitchCoreFreq(uint32_t coreFreq, uint32_t sysBusFreq) {
    /*
     * TODO : add all supported frequencies, for now support 13 & 104 only
     *        add core voltage switching to min value based on freq
     */
    
    uint32_t clkcfg;
    uint32_t cccr;
    
    switch (coreFreq) {
    case 13:
      if (sysBusFreq != 13) {
	return FAIL;
      }
      call PMIC.setCoreVoltage(B2R1_TRIM_P95_V);
      atomic {
	CCCR = CCCR_CPDIS | CCCR_A;
	asm volatile (
		      "mcr p14,0,%0,c6,c0,0\n\t"
		      :
		      : "r" (0x2)
		      );
	// check that core PLL was disabled
	while ((CCSR & CCSR_CPDIS_S) == 0);
      }
      return SUCCESS;
      
    case 104:
      if (sysBusFreq != 104) {
	return FAIL;
      }
      
      call PMIC.setCoreVoltage(B2R1_TRIM_P95_V);
      atomic {
	CCCR = CCCR_L(8) | CCCR_2N(2) | CCCR_A ; 
	asm volatile (
		      "mcr p14,0,%0,c6,c0,0\n\t"
		      :
		      : "r" (0xb)
		      );
	
	// wait until core pll locks
	while ((CCSR & CCSR_CPLCK) == 0);
      }
      
      return SUCCESS;
      
    case 208:
      switch(sysBusFreq){
      case 104:
	clkcfg = CLKCFG_T | CLKCFG_F;
	cccr = 0;
	if(call PMIC.setCoreVoltage(B2R1_TRIM_1P05_V) != SUCCESS){
	  //trace(DBG_TEMP,"Unable to Set Core Voltage to 1.05V required for 208MHz Core Frequency\r\n");
	  return FAIL;
	}
	
	break;
      case 208:
	clkcfg = CLKCFG_T | CLKCFG_B | CLKCFG_F;
	cccr = CCCR_A;
	if(call PMIC.setCoreVoltage(B2R1_TRIM_1P2_V) != SUCCESS){
	  //trace(DBG_TEMP,"Unable to Set Core Voltage to 1.2V required for 208MHz Core Frequency\r\n");
	  return FAIL;
	}

	break;
      default:
	  return FAIL;
      }
      
      
      
      atomic {
	CCCR = CCCR_L(16) | CCCR_2N(2) | cccr ; 
	asm volatile (
		      "mcr p14,0,%0,c6,c0,0\n\t"
		      :
		      : "r" (clkcfg)
		      );
	
	// wait until core pll locks
	while ((CCSR & CCSR_CPLCK) == 0);
      }
      
      return SUCCESS;
      
    case 416:
      if (sysBusFreq != 208) {
	trace(DBG_TEMP, "Fail bus freq %d\r\n", sysBusFreq);
	return FAIL;
      }
      
      if(call PMIC.setCoreVoltage(B2R1_TRIM_1P35_V) != SUCCESS){
	return FAIL;
      }
      
      clkcfg = CLKCFG_T | CLKCFG_B | CLKCFG_F;
      
      atomic {
	CCCR = CCCR_L(16) | CCCR_2N(4) | CCCR_A ; 
	asm volatile (
		      "mcr p14,0,%0,c6,c0,0\n\t"
		      :
		      : "r" (clkcfg)
		      );
	
	// wait until core pll locks
	while ((CCSR & CCSR_CPLCK) == 0);
      }
      return SUCCESS;
      
      
    default:
      return FAIL;
    }
  }

  command BluSH_result_t SwitchFreq.getName(char *buff, uint8_t len) {
     const char name[] = "SwitchFreq";
     strcpy(buff, name);
     return BLUSH_SUCCESS_DONE;
  }

  command BluSH_result_t SwitchFreq.callApp(char *cmdBuff, uint8_t cmdLen,
                                        char *resBuff, uint8_t resLen) {
     uint32_t target_freq;
     uint32_t t_bus_freq;

      if(strlen(cmdBuff) < 12) {
         sprintf(resBuff,"SwitchFreq <Target Freq in MHz>\r\n");
      } else {
         sscanf(cmdBuff,"SwitchFreq %d", &target_freq);
	 if (target_freq != 416) {
	   t_bus_freq = target_freq;
	 } else {
	   t_bus_freq = target_freq / 2;
	 }
         if (call DVFS.SwitchCoreFreq(target_freq, t_bus_freq) == SUCCESS) {
            sprintf(resBuff,"Switched to %3d [%3d] MHz successfully\r\n", target_freq, t_bus_freq);
         } else {
            sprintf(resBuff,"Failed to switch to %3d MHz\r\n", target_freq);
         }
      }

     return BLUSH_SUCCESS_DONE;
  }

  command BluSH_result_t GetFreq.getName(char *buff, uint8_t len) {
     const char name[] = "GetFreq";
     strcpy(buff, name);
     return BLUSH_SUCCESS_DONE;
  }

  command BluSH_result_t GetFreq.callApp(char *cmdBuff, uint8_t cmdLen,
					 char *resBuff, uint8_t resLen) {
    sprintf(resBuff,"Current Core/Bus Frequency = [%d/%d]\r\n",getSystemFrequency(), getSystemBusFrequency());
    return BLUSH_SUCCESS_DONE;
  }
}

