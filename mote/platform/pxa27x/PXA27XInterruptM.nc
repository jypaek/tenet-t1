// $Id: PXA27XInterruptM.nc,v 1.6 2007/03/05 00:06:07 lnachman Exp $ 

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
 * Authors:		Phil Buonadonna, Josh Herbach, Robbie Adler
 *
 * Revised: 11/27/2006
 */
includes profile;

module PXA27XInterruptM
{
  provides {
    interface PXA27XInterrupt as PXA27XIrq[uint8_t id];
    interface PXA27XInterrupt as PXA27XFiq[uint8_t id];
  }
}

implementation {

  /* Core PXA27X interrupt dispatch vectors */
  /* DO NOT change the name of these functions */
  
#if defined(ASSERT_IRQ_TIME) || defined(PROFILE_IRQ_TIME)
  uint32_t currentIRQExecutionTime __attribute__((C));
#endif

#ifdef PROFILE_IRQ_TIME
 
  ///since these are global, they will be initialized to 0 by the compiler for us..for now, we will only do the first 32 interrupts
  uint32_t IRQTimeInfo1[32] __attribute__((C));
  uint32_t IRQTimeInfo2[32] __attribute__ ((C));
  uint32_t *pCurrentIRQTimeInfo __attribute__((C)) = IRQTimeInfo1;
  
#endif


  void hplarmv_dabort() __attribute__ ((interrupt ("ABORT"), spontaneous, C)){
    
    uint32_t fault_status, fault_address;
    uint32_t oldsp;

    asm volatile (
		  " mrc p15,0,r1,C5,C0,0               \n"
		  " mov r2, %0                         \n"
		  " str r1,[r2]                        \n"
		  :
		  : "r" (&fault_status)
		  : "r1", "r2"
		  );

    asm volatile (
		  " mrc p15,0,r1,C6,C0,0               \n"
		  " mov r2, %0                         \n"
		  " str r1,[r2]                        \n"
		  :
		  : "r" (&fault_address)
		  : "r1", "r2"
		  );
    
    // we will assume that we came from SVC mode
    asm volatile (
		  "mov	r0, #0xD3\n\t"     // ARM_CPSR_MODE_SVC,(0x13) | 0xC0			
		  "msr	CPSR_c, R0\n\t"    //change back to SVC mode
		  "mov  r0 , %0\n\t"       //load the address of our output variable into r1
		  "str  sp, [r0]\n\t"      //store the current sp into address pointed to by r1
		  "mov	r0, #0xD7\n\t"     // ARM_CPSR_MODE_ABT,(0x17) | 0xc0
		  "msr	CPSR_c, R0\n\t"    //change back to ABT mode
		  :
		  : "r" (&oldsp) 
		  : "r0"
		  );
    
    fault_status = ( (fault_status & 0x400)>> 6) | (fault_status & 0xF);
    printFatalErrorMsgHex("Data Abort Exception.  [Fault Status, Fault Addr, SVC_SP] = ",3,fault_status, fault_address, oldsp);
    return;
  }

  void hplarmv_pabort() __attribute__ ((interrupt ("ABORT"), spontaneous, C)){
    
    uint32_t fault_status, fault_address;

    asm volatile (
		  " mrc p15,0,r1,C5,C0,0               \n"
		  " mov r2, %0                         \n"
		  " str r1,[r2]                        \n"
		  :
		  : "r" (&fault_status)
		  : "r1", "r2"
		  );

    asm volatile (
		  " mrc p15,0,r1,C6,C0,0               \n"
		  " mov r2, %0                         \n"
		  " str r1,[r2]                        \n"
		  :
		  : "r" (&fault_address)
		  : "r1", "r2"
		  );
    
    fault_status = ( (fault_status & 0x400)>> 6) | (fault_status & 0xF);
    printFatalErrorMsgHex("Prefetch Abort Exception.  [Fault Status, Fault Addr] = ",2,fault_status, fault_address);
    return;
  }

  extern norace volatile uint32_t globalDMAVirtualChannelHandled __attribute__((C));
  
  
  void hplarmv_irq() __attribute__ ((interrupt ("IRQ"), spontaneous, C)) {
    
    uint32_t IRQPending;
    
    IRQPending = ICHP;  // Determine which interrupt to service
    IRQPending >>= 16;  // Right justify to the IRQ portion

    while (IRQPending & (1 << 15)) {
      uint8_t PeripheralID = (IRQPending & 0x3f); // Get rid of the Valid bit
#if defined(ASSERT_IRQ_TIME) || defined(PROFILE_IRQ_TIME) 
      uint32_t localExecutionTime;
      currentIRQExecutionTime = OSCR0;
#endif

      signal PXA27XIrq.fired[PeripheralID]();     // Handler is responsible for clearing interrupt

#if  defined(ASSERT_IRQ_TIME) || defined(PROFILE_IRQ_TIME)
      localExecutionTime = OSCR0-currentIRQExecutionTime;

#ifdef PROFILE_IRQ_TIME
      if(localExecutionTime > pCurrentIRQTimeInfo[PeripheralID]){
	pCurrentIRQTimeInfo[PeripheralID] = localExecutionTime;
      }
#endif
      
#ifdef ASSERT_IRQ_TIME
      if(localExecutionTime > IRQ_TIME_LIMIT){
	switch (PeripheralID){
	case 25:
	  if(globalDMAVirtualChannelHandled > 1){
	    printFatalErrorMsg("DMA Interrupt Handler took longer than IRQ_TIME_LIMIT. [virtualChanel, startTime, runTime ] = ",
			       3,
			       globalDMAVirtualChannelHandled, 
			       currentIRQExecutionTime,
			       localExecutionTime);
	  }	    
	  break;
	case 10:
	  //ignore for now
	  break;
	default:
	  printFatalErrorMsg("Interrupt Handler took longer than IRQ_TIME_LIMIT. [PeripheralID, startTime, runTime ] = ",
			     3,
			     PeripheralID, 
			     currentIRQExecutionTime,
			     localExecutionTime);
	}
      }
#endif
#endif


      IRQPending = ICHP;  // Determine which interrupt to service
      IRQPending >>= 16;  // Right justify to the IRQ portion
    }
    return;
  }
  
  void hplarmv_fiq() __attribute__ ((interrupt ("FIQ"), spontaneous, C)) {
    
    uint32_t FIQPending;
    
    FIQPending = ICHP;   // Determine which interrupt to service
    FIQPending &= 0xFF;  // Mask off the IRQ portion

    while (FIQPending & (1 << 15)) {
      uint8_t PeripheralID = (FIQPending & 0x3f); // Get rid of the Valid bit
      signal PXA27XFiq.fired[PeripheralID]();	  // Handler is responsible for clearing interrupt
      FIQPending = ICHP;
      FIQPending &= 0xFF;
    }

    return;
  } 

  static uint8_t usedPriorities = 0;

  /* Helper functions */
  /* NOTE: Read-back of all register writes is necessary to ensure the data latches */

  result_t allocate(uint8_t id, bool level, uint8_t priority)
  {
    uint32_t tmp;
    result_t result = FAIL;

    atomic{
      uint8_t i;
      if(usedPriorities == 0){//assumed that the table will have some entries
	uint8_t PriorityTable[40], DuplicateTable[40];
	for(i = 0; i < 40; i++){
	  DuplicateTable[i] = PriorityTable[i] = 0xFF;
	}
	
	for(i = 0; i < 40; i++)
	  if(TOSH_IRP_TABLE[i] != 0xff){
	    if(PriorityTable[TOSH_IRP_TABLE[i]] != 0xFF)/*duplicate priorities
							  in the table, mark 
							  for later fixing*/
	      DuplicateTable[i] = PriorityTable[TOSH_IRP_TABLE[i]];
	    else
	      PriorityTable[TOSH_IRP_TABLE[i]] = i;
	  }
	
	//compress table
	for(i = 0; i < 40; i++){
	  if(PriorityTable[i] != 0xff){
	    PriorityTable[usedPriorities] = PriorityTable[i];
	    if(i != usedPriorities)
	      PriorityTable[i] = 0xFF;
	    usedPriorities++;
	  }
	}

	for(i = 0; i < 40; i++)
	  if(DuplicateTable[i] != 0xFF){
	    uint8_t j, ExtraTable[40];
	    for(j = 0; DuplicateTable[i] != PriorityTable[j]; j++);
	    memcpy(ExtraTable + j + 1, PriorityTable + j, usedPriorities - j);
	    memcpy(PriorityTable + j + 1, ExtraTable + j + 1, 
		   usedPriorities - j);
	    PriorityTable[j] = i;
	    usedPriorities++;
	  }

	for(i = 0; i < usedPriorities; i++){
	  IPR(i) = (IPR_VAL | PriorityTable[i]);
	  tmp = IPR(i);
	}
      }

      if (id < 34){
	if(priority == 0xff){
	  priority = usedPriorities;
	  usedPriorities++;
	  IPR(priority) = (IPR_VAL | (id));
	  tmp = IPR(priority);
	}
	if (level) {
	  ICLR_REG(id) |= INTERRUPT_BIT(id);
	  tmp = ICLR_REG(id);
	} 
	
	result = SUCCESS;
      }
    }
    return result;
  }
  
  void enable(uint8_t id)
  {
    uint32_t tmp;
    atomic {
      if (id < 34) {
	ICMR_REG(id) |= INTERRUPT_BIT(id);
	tmp = ICMR_REG(id);
      }
    }
    return;
  }

  void disable(uint8_t id)
  {
    uint32_t tmp;
    atomic {
      if (id < 34) {
	ICMR_REG(id) &= ~(INTERRUPT_BIT(id));
	tmp = ICMR_REG(id);
      }
    }
    return;
  }

  /* Interface implementation */

  async command result_t PXA27XIrq.allocate[uint8_t id]()
  {
    return allocate(id, FALSE, TOSH_IRP_TABLE[id]);
  }

  async command void PXA27XIrq.enable[uint8_t id]()
  {
    enable(id);
    return;
  }

  async command void PXA27XIrq.disable[uint8_t id]()
  {
    disable(id);
    return;
  }

  async command result_t PXA27XFiq.allocate[uint8_t id]() 
  {
    return allocate(id, TRUE, TOSH_IRP_TABLE[id]);
  }

  async command void PXA27XFiq.enable[uint8_t id]()
  {
    enable(id);
    return;
  }

  async command void PXA27XFiq.disable[uint8_t id]()
  {
    disable(id);
    return;
  }

  default async event void PXA27XIrq.fired[uint8_t id]() 
  {
    return;
  }

  default async event void PXA27XFiq.fired[uint8_t id]() 
  {
    return;
  }

}
