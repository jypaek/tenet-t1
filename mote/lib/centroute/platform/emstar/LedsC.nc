// $Id: LedsC.nc,v 1.1 2007-11-17 00:55:24 karenyc Exp $

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
 * Authors:		Jason Hill, David Gay, Philip Levis
 * Date last modified:  6/2/03
 *
 */

/**
 * @author Jason Hill
 * @author David Gay
 * @author Philip Levis
 */

/* EmTOS modifications by Thanos Stathopoulos */

module LedsC {
  provides interface Leds;
}
implementation
{
  uint8_t ledsOn;

  enum {
    RED_BIT = 1,
    GREEN_BIT = 2,
    YELLOW_BIT = 4
  };

  
  async command result_t Leds.init() {
    atomic {
      ledsOn = 0;
      dbg(DBG_BOOT, "LEDS: initialized.\n");
      call Leds.redOff();
      call Leds.yellowOff();
      call Leds.greenOff();
	  emtos_init_leds();
    }
    return SUCCESS;
  }

  async command result_t Leds.redOn() {
//    printf("LEDS: Red on.\n");
    atomic {
      ledsOn |= RED_BIT;
	  emtos_set_led(RED, ON);
    }

    return SUCCESS;
  }

  async command result_t Leds.redOff() {
//    printf("LEDS: Red off.\n");
     atomic {
       ledsOn &= ~RED_BIT;
		emtos_set_led(RED, OFF);
     }
     return SUCCESS;
  }

  async command result_t Leds.redToggle() {
    result_t rval;
    atomic {
      if (ledsOn & RED_BIT)
	rval = call Leds.redOff();
      else
	rval = call Leds.redOn();
    }
    return rval;
  }

  async command result_t Leds.greenOn() {
//    printf("LEDS: Green on.\n");
    atomic {
      ledsOn |= GREEN_BIT;
	  emtos_set_led(GREEN, ON);
    }
    return SUCCESS;
  }

  async command result_t Leds.greenOff() {
//    printf("LEDS: Green off.\n");
    atomic {
      ledsOn &= ~GREEN_BIT;
	  emtos_set_led(GREEN, OFF);
    }
    return SUCCESS;
  }

  async command result_t Leds.greenToggle() {
    result_t rval;
    atomic {
      if (ledsOn & GREEN_BIT)
	rval = call Leds.greenOff();
      else
	rval = call Leds.greenOn();
    }
    return rval;
  }

  async command result_t Leds.yellowOn() {
//    printf("LEDS: Yellow on.\n");
    atomic {
      ledsOn |= YELLOW_BIT;
	  emtos_set_led(YELLOW, ON);
    }
    return SUCCESS;
  }

  async command result_t Leds.yellowOff() {
//    printf("LEDS: Yellow off.\n");
    atomic {
      ledsOn &= ~YELLOW_BIT;
	  emtos_set_led(YELLOW, OFF);
    }
    return SUCCESS;
  }

  async command result_t Leds.yellowToggle() {
    result_t rval;
    atomic {
      if (ledsOn & YELLOW_BIT)
	rval = call Leds.yellowOff();
      else
	rval = call Leds.yellowOn();
    }
    return rval;
  }
  
  async command uint8_t Leds.get() {
    uint8_t rval;
    atomic {
      rval = ledsOn;
    }
    return rval;
  }
  
  async command result_t Leds.set(uint8_t ledsNum) {
    atomic {
      ledsOn = (ledsNum & 0x7);
    }
    return SUCCESS;
  }

}
