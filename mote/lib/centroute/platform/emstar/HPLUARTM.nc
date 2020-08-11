// $Id: HPLUARTM.nc,v 1.1 2007-11-17 00:55:24 karenyc Exp $

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
 * Date last modified:  6/25/02
 *
 */

/**
 * @author Jason Hill
 * @author David Gay
 * @author Philip Levis
 */

includes HPLConstants;

module HPLUARTM {
  provides interface HPLUART;
  provides interface StdControl;
  uses {
#ifdef EMSTAR_NO_KERNEL
	interface EmSocketI;
#else
        interface EmPdServerI;
#endif
  }
}

implementation {

  command result_t StdControl.init()
  {
    return SUCCESS;
  }

  command result_t StdControl.start()
  {
#ifndef EMSTAR_NO_KERNEL
    call EmPdServerI.Init(emtos_name_nosim("serial",NULL));
#endif
    return SUCCESS;
  }

  command result_t StdControl.stop()
  {
    return SUCCESS;
  }

  async command result_t HPLUART.init() {
    return SUCCESS;
  }

  async command result_t HPLUART.stop() {
    return SUCCESS;
  }

  uint8_t byte;

  void task uartDone()
  {
#ifdef EMSTAR_NO_KERNEL
    call EmSocketI.ReceiveMsg(&(byte), 1);
#else
    call EmPdServerI.ReceiveMsg(&(byte), 1);
#endif 
    signal HPLUART.putDone();
  }

  async command result_t HPLUART.put(uint8_t data) {
    atomic { byte = data; }
    post uartDone();
    return SUCCESS;
  }

  void hack(uint8_t data) { 
    atomic signal HPLUART.get(data); 
  }

#ifdef EMSTAR_NO_KERNEL
  event result_t EmSocketI.SendMsg(void *msg, int16_t length)
  {
    atomic {
      void emtos_uart_spoolme(void *, int, void (*)(uint8_t));
      emtos_uart_spoolme(msg, length, hack);
    }
    return 0;
  }
#else	
  event int EmPdServerI.SendMsg(void *msg, int16_t length)
  {
    atomic {
      void emtos_uart_spoolme(void *, int, void (*)(uint8_t));
      emtos_uart_spoolme(msg, length, hack);
    }
    return 0;
  }
#endif

}
