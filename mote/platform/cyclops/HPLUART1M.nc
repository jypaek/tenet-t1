// $Id: HPLUART1M.nc,v 1.1 2007-07-03 00:57:48 jpaek Exp $

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
/*
 *
 * Authors:		Jason Hill, David Gay, Philip Levis, Phil Buonadonna
 * Date last modified:  $Revision: 1.1 $
 *
 */

// The hardware presentation layer. See hpl.h for the C side.
// Note: there's a separate C side (hpl.h) to get access to the avr macros

// The model is that HPL is stateless. If the desired interface is as stateless
// it can be implemented here (Clock, FlashBitSPI). Otherwise you should
// create a separate component


/**
 * @author Jason Hill
 * @author David Gay
 * @author Philip Levis
 * @author Phil Buonadonna
 */

module HPLUART1M {
  provides interface HPLUART as UART;

}
implementation
{
  command result_t UART.init() {

    // UART will run at:
    // 115kbps, N-8-1

    // 7.3728 MHz crystal oscillator
    outp(0,UBRR1H); 
    
    //outp(3,UBRR0L);     // 230.4 kbaud
    //outp(7,UBRR0L);     // 115.2 kbaud
    // outp(15, UBRR1L);  // 57.6 kbaud
    outp(47, UBRR1L);     // 19.2 kbaud
    // outp(95, UBRR1L);  // 9600 baud

    // Set UART double speed
    outp((1<<U2X),UCSR1A);

    // Set frame format: 8 data-bits, 1 stop-bit
    outp(((1 << UCSZ1) | (1 << UCSZ0)) , UCSR1C);

    // Enable reciever and transmitter and their interrupts
    outp(((1 << RXCIE) | (1 << TXCIE) | (1 << RXEN) | (1 << TXEN)) ,UCSR1B);


    return SUCCESS;
  }

  async command result_t UART.stop() {
    outp(0x00, UCSR1A);
    outp(0x00, UCSR1B);
    outp(0x00, UCSR1C);
    return SUCCESS;
  }

  default async event result_t UART.get(uint8_t data) { return SUCCESS; }
  TOSH_SIGNAL(SIG_UART1_RECV) {
    if (inp(UCSR1A) & (1 << RXC))
      signal UART.get(inp(UDR1));
  }

  default event result_t UART.putDone() { return SUCCESS; }
  TOSH_INTERRUPT(SIG_UART1_TRANS) {
    signal UART.putDone();
  }

  command async result_t UART.put(uint8_t data) {
    sbi(UCSR1A, TXC);
    outp(data, UDR1); 
    return SUCCESS;
  }
}
