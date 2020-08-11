// $Id: hardware.c,v 1.1 2007-09-11 01:36:13 karenyc Exp $

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
 * Authors:             Philip Levis
 * Description:         Implementation of NIDO hardware emulation.
 * Date:                September 24, 2001
 *
 */

#include "dbg.h"
//#include "RADIO.h"

norace struct {
  char status_register;  // SREG
  char register_A;
  char register_B;
  char register_C;
  char register_D;
  char register_E;
  char register_default;
} TOSH_pc_hardware;

void init_hardware() {
  int i;
  for (i = 1; i < 1; i++) {
    tos_state.current_node = i;
    TOSH_pc_hardware.status_register = 0xff;
  }
}

short set_io_bit(char port, char bit) {
  char* register_ptr;
  switch(port) {
  case PORTA:
    register_ptr = &TOSH_pc_hardware.register_A;
    break;

  case PORTB:
    register_ptr = &TOSH_pc_hardware.register_B;
    break;

  case PORTC:
    register_ptr = &TOSH_pc_hardware.register_C;
    break;
    
  case PORTD:
    register_ptr = &TOSH_pc_hardware.register_D;
    break;
    
  case PORTE:
    register_ptr = &TOSH_pc_hardware.register_E;
    break;
    
  case SREG:
    register_ptr = &TOSH_pc_hardware.status_register;
    break;

  default:
    register_ptr = &TOSH_pc_hardware.register_default;
    break;
  }
  
  dbg(DBG_HARD, "Set bit %i of port %u\n", (int)bit, port);

  *register_ptr = (*register_ptr |= (0x1 << bit));

  return *register_ptr;
}

short clear_io_bit(char port, char bit) {
  dbg(DBG_HARD, "Clear bit %i of port %u\n", (int)bit, port);
  return 0xff;
}

char inp_emulate(char port) {
  switch(port) {
  case SREG:
    //dbg(DBG_HARD, "inp(SREG)\n");
    return TOSH_pc_hardware.status_register;
  case TCNT0:
    //dbg(DBG_HARD, "inp(TCNT0)\n");
    return 0;

  default:
    dbg(DBG_HARD, "inp(%u)\n", port);
    return 0xff;
  }
}

#ifdef RADIO_GET_BIT_RATE
char TOS_COMMAND(RADIO_GET_BIT_RATE)();
#endif

short inw_emulate(char port) {
  switch(port) {
    //case TCNT1L:
    //#ifdef RADIO_GET_BIT_RATE
    //return TOS_CALL_COMMAND(RADIO_GET_BIT_RATE)();
    //#endif
  default:
    dbg(DBG_HARD, "inw(%u)\n", port);
    return 0xffff;
  }
}

char outp_emulate(char val, char port) {
  dbg(DBG_HARD, "outp(0x%x, %u)\n", val, port);
  return 0xff;
}

short cli(void) {
  TOSH_pc_hardware.status_register &= 0x7f;
  return 0xff;
}

short sei(void) {
  TOSH_pc_hardware.status_register |= 0x80;
  return 0xff;
}
