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
/*
 *
 * Authors:		Jason Hill, David Gay, Philip Levis
 * Date last modified:  6/25/02
 *
 */

// The hardware presentation layer. See hpl.h for the C side.
// Note: there's a separate C side (hpl.h) to get access to the avr macros

// The model is that HPL is stateless. If the desired interface is as stateless
// it can be implemented here (Clock, FlashBitSPI). Otherwise you should
// create a separate component

includes MMU;
includes queue;
includes trace;

module HPLInitM {
  provides command result_t init();
  uses interface DVFS;
}

implementation
{

  queue_t paramtaskQueue __attribute__ ((C));
  
  command result_t init() {
    CKEN = (CKEN_CKEN22 | CKEN_CKEN20 | CKEN_CKEN15 | CKEN_CKEN9);
    OSCC = (OSCC_OON);
    
    while ((OSCC & OSCC_OOK) == 0);
    
    TOSH_SET_PIN_DIRECTIONS();
    initqueue(&paramtaskQueue,defaultQueueSize);
    
#if 1
    //initialize the memory controller
     //PXA27x MemConttroller 1st tier initialization.See 6.4.10 for details
     SA1110 = SA1110_SXSTACK(1);
     MSC0 = MSC0 | (1<<3) | (1<<15) | 2 ;
     MSC1 = MSC1 | (1<<3);
     MSC2 = MSC2 | (1<<3);
     
     //PXA27x MemController 2nd tier initialization.See 6.4.10 for details
     MECR =0; //no PC Card is present and 1 card slot
     /*
	 MCMEM0;
	 MCMEM1;
	 MCATT0;
	 MCATT1	 MCIO0;
	 MCIO1;
     */
     
     //PXA27x MemController 3rd tier initialization.See 6.4.10 for details
     //FLYCNFG
     
     //PXA27x MemController 4th tier initialization.See 6.4.10 for details
     MDCNFG = 0x0B002BCC; //should be 0x0B002BCD, but we want it disabled.
     //MDREFR;
     
     //PXA27x MemController 5th tier initialization.See 6.4.10 for details
     //SXCNFG = SXCNFG_SXEN0 | SXCNFG_SXCL0(4) | SXCNFG_SXTP0(3);
         
      //initialize the MMU
     initMMU();
     enableICache();
     initSyncFlash();
     enableDCache();
#endif
     
#if defined(SYSTEM_CORE_FREQUENCY) && defined(SYSTEM_BUS_FREQUENCY)
     if(call DVFS.SwitchCoreFreq(SYSTEM_CORE_FREQUENCY, SYSTEM_BUS_FREQUENCY) !=  SUCCESS){
       //set to default value of 13:13
       call DVFS.SwitchCoreFreq(13, 13);
       //currently, we can't print out anything because we haven necessarily enabled the UART...leave this as a comment...
       //trace(DBG_TEMP, "Unable to set Core/Bus frequency to [%d/%d]\r\n",SYSTEM_CORE_FREQUENCY, SYSTEM_BUS_FREQUENCY);
     }
#else
     //PLACE PXA27X into 13 MHz mode
     call DVFS.SwitchCoreFreq(13, 13);
#endif
           
      return SUCCESS;
  }
}

