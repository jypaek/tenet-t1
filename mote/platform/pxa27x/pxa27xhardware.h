// $Id: pxa27xhardware.h,v 1.9 2007/03/05 00:06:07 lnachman Exp $

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


/*
 *
 * Authors:   Philip Buonadonna, Josh Herbach, Robbie Adler
 *
 * Revised: 09/02/2005
 */

#ifndef PXA27X_HARDWARE_H
#define PXA27X_HARDWARE_H

#include "arm_defs.h"
#include "pxa27x_registers_def.h"



#define TOSH_ASSIGN_PIN(name, port, regbit) \
static inline void TOSH_SET_##name##_PIN() {GPSR(regbit) = GPIO_BIT(regbit);} \
static inline void TOSH_CLR_##name##_PIN() {GPCR(regbit) = GPIO_BIT(regbit);} \
static inline char TOSH_READ_##name##_PIN() {return ((GPLR(regbit) & GPIO_BIT(regbit)) != 0);} \
static inline void TOSH_MAKE_##name##_OUTPUT() {GPIO_SET_ALT_FUNC(regbit,0,GPIO_OUT);GPDR(regbit) |= GPIO_BIT(regbit);} \
static inline void TOSH_MAKE_##name##_INPUT() {GPIO_SET_ALT_FUNC(regbit,0,GPIO_IN);GPDR(regbit) &= ~(GPIO_BIT(regbit));}

#define TOSH_ASSIGN_OUTPUT_ONLY_PIN(name, port, regbit) \
static inline void TOSH_SET_##name##_PIN() {GPSR(regbit) = GPIO_BIT(regbit);} \
static inline void TOSH_CLR_##name##_PIN() {GPCR(regbit) = GPIO_BIT(regbit);} \
static inline void TOSH_MAKE_##name##_OUTPUT() {GPIO_SET_ALT_FUNC(regbit,0,GPIO_OUT);GPDR(regbit) |= GPIO_BIT(regbit);} 

// We need slightly different defs than SIGNAL, INTERRUPT
#define TOSH_SIGNAL(signame)					\
void signame() __attribute__ ((signal, spontaneous, C))

#define TOSH_INTERRUPT(signame)				\
void signame() __attribute__ ((interrupt, spontaneous, C))

// GPIO Interrupt Defines
#define TOSH_RISING_EDGE (1)
#define TOSH_FALLING_EDGE (2)
#define TOSH_BOTH_EDGE (3)

void TOSH_wait()
{
  asm volatile("nop");
  asm volatile("nop");
}

void TOSH_sleep()
{
#if 0
  // Place PXA into idle
  asm volatile (
		"mcr p14,0,%0,c7,c0,0"
		: 
		: "r" (1)
		);
#endif
}

/**
 * (Busy) wait <code>usec</code> microseconds
 */
inline void TOSH_uwait(uint16_t usec)
{
  uint32_t start,mark = usec;

  //in order to avoid having to reset OSCR0, we need to look at time differences
  
  start = OSCR0;
  mark <<= 2;
  mark *= 13;
  mark >>= 2;

  //OSCR0-start should work correctly due to nice properties of underflow
  while ( (OSCR0 - start) < mark);
}

inline uint32_t _pxa27x_clzui(uint32_t i) {
  uint32_t count;
  asm volatile ("clz %0,%1"
		: "=r" (count)
		: "r" (i)
		);
  return count;
}

typedef uint32_t __nesc_atomic_t;

#ifdef PROFILE_ATOMIC_TIME
volatile uint32_t currentAtomicExecutionTime __attribute__((C));
#endif

//NOTE...at the moment, these functions will ONLY disable the IRQ...FIQ is left alone
inline __nesc_atomic_t __nesc_atomic_start(void) __attribute__((spontaneous))
{
  uint32_t result = 0;
  uint32_t temp = 0;

  asm volatile (
		"mrs %0,CPSR\n\t"
		"orr %1,%2,%4\n\t"
		"msr CPSR_cf,%3"
		: "=r" (result) , "=r" (temp)
		: "0" (result) , "1" (temp) , "i" (ARM_CPSR_INT_MASK)
		);
  
#ifdef PROFILE_ATOMIC_TIME
  if(result & ARM_CPSR_BIT_I){
    //interrupts were already disabled
  }
  else{
    currentAtomicExecutionTime = OSCR0;
  }
#endif

  return result;
}

inline void __nesc_atomic_end(__nesc_atomic_t oldState) __attribute__((spontaneous))
{
#ifdef PROFILE_ATOMIC_TIME
  uint32_t localAtomicExecutionTime;
#endif
  uint32_t  statusReg = 0;
  //make sure that we only mess with the INT bit
  oldState &= ARM_CPSR_INT_MASK;
  
#ifdef PROFILE_ATOMIC_TIME
  if(oldState & ARM_CPSR_BIT_I){
    //interrupts were disabled
  }
  else{
    //interrupt were previously enabled
    localAtomicExecutionTime = OSCR0 - currentAtomicExecutionTime;
    assert(localAtomicExecutionTime < 325);
  }
#endif

  
  asm volatile (
		"mrs %0,CPSR\n\t"
		"bic %0, %1, %2\n\t"
		"orr %0, %1, %3\n\t"
		"msr CPSR_c, %1"
		: "=r" (statusReg)
		: "0" (statusReg),"i" (ARM_CPSR_INT_MASK), "r" (oldState)
		);

  return;
}


inline void __nesc_enable_interrupt() {
  //never enable FIQ interrupts

  uint32_t statusReg = 0;

  asm volatile (
	       "mrs %0,CPSR\n\t"
	       "bic %0,%1,#0x80\n\t"
	       "msr CPSR_c, %1"
	       : "=r" (statusReg)
	       : "0" (statusReg)
	       );
  return;
}

inline void __nesc_atomic_sleep()
{
  /* 
   * Atomically enable interrupts and sleep , 
   * LN : FOR NOW SLEEP IS DISABLED will be adding this functionality shortly
   */
  __nesc_enable_interrupt();
  return;
}

#endif //TOSH_HARDWARE_H
