// $Id: VoltageM.nc,v 1.1 2007-11-17 00:55:24 karenyc Exp $

/*								        tab:2
 *
 *
 * "Copyright (c) 2000-2005 The Regents of the University  of California.  
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

/**
 * Module for measuring supply voltage (Vcc) on mica2. Value returned
 * by dataReady() is in millivolts.
 *
 * @author Jonathan Hui <jwhui@cs.berkeley.edu>
 */

module VoltageM {
  provides {
    interface ADC as Voltage;
    interface StdControl;
  }
  uses {
    interface ADC;
    interface ADCControl;
  }
}

implementation {

  enum {
    ERROR_VOLTAGE = 0xffff,
  };

  enum {
    S_IDLE,
    S_GET_DATA,
  };

  uint8_t state;
  uint16_t voltage;

  command result_t StdControl.init() {
    atomic state = S_IDLE;
    return SUCCESS;
  }

  command result_t StdControl.start() {
    result_t result;
    result = call ADCControl.init();
    result = rcombine(call ADCControl.bindPort(TOS_ADC_VOLTAGE_PORT,
					       TOSH_ACTUAL_VOLTAGE_PORT),
		      result);
    return result;
  }

  command result_t StdControl.stop() {
    return SUCCESS;
  }

  void signalReady(uint16_t v) {
    atomic state = S_IDLE;
    signal Voltage.dataReady(v);
  }

  task void signalReadyTask() {
    uint32_t tmpVoltage;
    // Vbatt = (Vref*ADC_FS/ADC_Count)
    atomic {
      tmpVoltage = (uint32_t)1223*1024;
      tmpVoltage /= voltage;
    }
    signalReady(tmpVoltage);
  }

  async command result_t Voltage.getData() {

    uint8_t tmpState;

    atomic tmpState = state;

    if (tmpState != S_IDLE)
      return FAIL;

    //TOSH_MAKE_BAT_MON_OUTPUT();
    //TOSH_SET_BAT_MON_PIN();
    
    if (call ADC.getData() == FAIL)
      return FAIL;
    
    atomic state = S_GET_DATA;

    return SUCCESS;

  }
  
  /*
   * Not supported.
   */
  async command result_t Voltage.getContinuousData() {
    return FAIL;
  }

  async event result_t ADC.dataReady(uint16_t data) {
    
    //TOSH_CLR_BAT_MON_PIN();
    atomic voltage = data;

    if (post signalReadyTask() == FAIL)
      signalReady(ERROR_VOLTAGE);

    return SUCCESS;

  }

}
