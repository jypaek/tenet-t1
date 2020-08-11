// $Id: hardware.h,v 1.4 2007-08-15 03:43:34 jpaek Exp $

/*									tab:4
 * "Copyright (c) 2000-2003 The Regents of the University  of California.  
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
 * Copyright (c) 2002-2003 Intel Corporation
 * All rights reserved.
 *
 * This file is distributed under the terms in the attached INTEL-LICENSE     
 * file. If you do not find these files, copies can be found by writing to
 * Intel Research Berkeley, 2150 Shattuck Avenue, Suite 1300, Berkeley, CA, 
 * 94704.  Attention:  Intel License Inquiry.
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
 *      Neither the name of the Intel Corporation nor the names of itsCYCLOPS
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
 * $Id: hardware.h,v 1.4 2007-08-15 03:43:34 jpaek Exp $
 *
 */

#ifndef TOSH_HARDWARE_H
#define TOSH_HARDWARE_H

#ifndef TOSH_HARDWARE_MICA2
#define TOSH_HARDWARE_MICA2
#endif // tosh hardware

#define TOSH_NEW_AVRLIBC // mica128 requires avrlibc v. 20021209 or greater
#include <avrhardware.h>
//#include <CC1000Const.h>

// avrlibc may define ADC as a 16-bit register read.  This collides with the nesc
// ADC interface name
uint16_t inline getADC() {
  return inw(ADC);
}
#undef ADC
#define TOSH_CYCLE_TIME_NS 136

// each nop is 1 clock cycle
// 1 clock cycle on mica2 == 136ns
void inline TOSH_wait_250ns() {
      asm volatile  ("nop" ::);
      asm volatile  ("nop" ::);
}

void inline TOSH_uwait(int u_sec) {
    while (u_sec > 0) {
      asm volatile  ("nop" ::);
      asm volatile  ("nop" ::);
      asm volatile  ("nop" ::);
      asm volatile  ("nop" ::);
      asm volatile  ("nop" ::);
      asm volatile  ("nop" ::);
      asm volatile  ("nop" ::);
      asm volatile  ("nop" ::);
      u_sec--;
    }
}



// LED assignments
TOSH_ASSIGN_PIN(RED_LED, F, 0);
TOSH_ASSIGN_PIN(GREEN_LED, F, 1);
TOSH_ASSIGN_PIN(YELLOW_LED, F, 2);
TOSH_ASSIGN_PIN(AMBER_LED, F, 3);
TOSH_ASSIGN_PIN(INSTRUMENTATION_AMPLIFIER_SHUTDOWN, B, 4);

// TRIG for interrupting cyclpos
TOSH_ASSIGN_PIN(TRIG, E, 4);

// cpld control assignments
TOSH_ASSIGN_PIN(CPLD_H0, E, 5);
TOSH_ASSIGN_PIN(CPLD_H1, E, 6);
TOSH_ASSIGN_PIN(CPLD_H2, E, 7);

// spibus assignments 
TOSH_ASSIGN_PIN(MOSI,  B, 2);
TOSH_ASSIGN_PIN(MISO,  B, 3);
TOSH_ASSIGN_PIN(SPI_SCK,  B, 1);

// imager i2c bus assignments
TOSH_ASSIGN_PIN(I2C_BUS_IMAGER_SCL, D, 6);
TOSH_ASSIGN_PIN(I2C_BUS_IMAGER_SDA, D, 7);

// i2c bus assignments
#define HARDWARE_I2C
TOSH_ASSIGN_PIN(I2C_BUS1_SCL, D, 0);
TOSH_ASSIGN_PIN(I2C_BUS1_SDA, D, 1);

//annoying second level of indirection because the mica2 and mica2dot
//do not have the same pins aliased by I2C_BUS1
TOSH_ALIAS_PIN(I2C_HW1_SCL, I2C_BUS1_SCL);
TOSH_ALIAS_PIN(I2C_HW1_SDA, I2C_BUS1_SDA);

// uart assignments
TOSH_ASSIGN_PIN(UART_RXD0, E, 0);
TOSH_ASSIGN_PIN(UART_TXD0, E, 1);
//TOSH_ASSIGN_PIN(UART_XCK0, E, 2)  //cyclops uses uart in asynchronous mode

TOSH_ASSIGN_PIN(UART_RXD1, D, 2);
TOSH_ASSIGN_PIN(UART_TXD1, D, 3);
//TOSH_ASSIGN_PIN(UART_XCK1, D, 5); //cyclops uses uart in asynchronous mode

void TOSH_SET_PIN_DIRECTIONS(void)
{
  /*  outp(0x00, DDRA);
  outp(0x00, DDRB);
  outp(0x00, DDRD);
  outp(0x02, DDRE);
  outp(0x02, PORTE);
  */

  /**
   * We are not going to use UART0 for communicating with the host mote.
   * We will use I2C instead.
   * Since UART0 of cyclops can interfere with UART1/FLASH of host mote,
   * we disable it (make it input) here.
   * - Jeongyeup (jpaek@enl.usc.edu)
   **/
  outp(0x00, UCSR0A);
  outp(0x00, UCSR0B);
  outp(0x00, UCSR0C);
  TOSH_MAKE_UART_RXD0_INPUT();
  TOSH_MAKE_UART_TXD0_INPUT();

  TOSH_MAKE_RED_LED_OUTPUT();
  TOSH_MAKE_YELLOW_LED_OUTPUT();
  TOSH_MAKE_GREEN_LED_OUTPUT();
  TOSH_MAKE_AMBER_LED_OUTPUT();

  TOSH_SET_RED_LED_PIN();
  TOSH_SET_YELLOW_LED_PIN();
  TOSH_SET_GREEN_LED_PIN();
  TOSH_SET_AMBER_LED_PIN();

  TOSH_MAKE_MISO_INPUT();

  //This is important so that Led component works gracefully
  TOSH_MAKE_INSTRUMENTATION_AMPLIFIER_SHUTDOWN_OUTPUT(); 
  TOSH_CLR_INSTRUMENTATION_AMPLIFIER_SHUTDOWN_PIN();
}

enum {
  TOSH_ADC_PORTMAPSIZE = 12
};

#endif //TOSH_HARDWARE_H




