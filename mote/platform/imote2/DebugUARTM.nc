// $Id: DebugUARTM.nc,v 1.2 2007/03/04 23:51:29 lnachman Exp $

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
 * Date last modified:  5/27/03
 *
 *  5/27/03    pal      Added atomic sections for safety.
 *
 */

/**
 * @author Jason Hill
 * @author David Gay
 * @author Philip Levis
 */


module DebugUARTM {
  provides {
    interface ByteComm;
    interface StdControl as Control;
  }
  uses {
    interface HPLUART;
  }
}
implementation 
{
  bool state;

  command result_t Control.init() {
    dbg(DBG_BOOT, "UART initialized\n");
    atomic {
      state = FALSE;
    }
    return SUCCESS;
  }

  command result_t Control.start() {
    return call HPLUART.init();
  }

  command result_t Control.stop() {
      
    return call HPLUART.stop();
  }
    
  async event result_t HPLUART.get(uint8_t data) {
    // Changed SRM 7.8.02 -- No reason to clear state just because
    // we received some data, I think...

    //    state = FALSE;
    signal ByteComm.rxByteReady(data, FALSE, 0);
    dbg(DBG_UART, "signal: state %d\n", state);
    return SUCCESS;
  }

  async event result_t HPLUART.putDone() {
    bool oldState;
    
    atomic {
      dbg(DBG_UART, "intr: state %d\n", state);
      oldState = state;
      state = FALSE;
    }

    /* Note that the state transition/event signalling is not atomic.
       It is possible, after state has been set to FALSE, that
       someone calls txByte before txDone is signalled. The event
       handler therefore may not be able to transmit. Sharing
       the byte level can be very tricky, unless we assure non-preemptiveness
       or have client ids. The UART implementation is non-preemptive,
       but is not assuredly so. -pal*/
    if (oldState) {
      signal ByteComm.txDone();
      signal ByteComm.txByteReady(TRUE);
    }  
    return SUCCESS;
  }

  async command result_t ByteComm.txByte(uint8_t data) {
    bool oldState;
    
    dbg(DBG_UART, "UART_write_Byte_inlet %x\n", data);

    atomic {
      oldState = state;
      state = TRUE;
    }
    if (oldState) 
      return FAIL;

    call HPLUART.put(data);

    return SUCCESS;
  }

}
