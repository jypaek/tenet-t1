// $Id: HumidityM.nc,v 1.1 2006-10-26 18:33:00 mvieira Exp $
/*									tab:4
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
 * Copyright (c) 2002-2003 Intel Corporation
 * All rights reserved.
 *
 * This file is distributed under the terms in the attached INTEL-LICENSE     
 * file. If you do not find these files, copies can be found by writing to
 * Intel Research Berkeley, 2150 Shattuck Avenue, Suite 1300, Berkeley, CA, 
 * 94704.  Attention:  Intel License Inquiry.
 */
/**
 * @author Joe Polastre
 */
includes Humidity;

module HumidityM {
  provides {
    interface ADC as Humidity;
    interface ADC as Temperature;
    interface SplitControl;
    interface ADCError as HumidityError;
    interface ADCError as TemperatureError;
  }
  uses {
    interface ADC as HumSensor;
    interface ADC as TempSensor;
    interface ADCError as HumError;
    interface ADCError as TempError;
    interface StdControl as SensorControl;
    interface StdControl as BusControl;

    interface StdControl as TimerControl;
    interface Timer;
  }
}
implementation {

  norace uint8_t state;
  uint8_t id;

  norace uint16_t adcdata;

  enum { IDLE = 0, WARM_UP, POWER_OFF, SAMPLE, 
         HUMIDITY, HUMIDITY_TEMP, WAIT_FOR_BUS };

  task void initDone() {
    signal SplitControl.initDone();
  }

  task void startDone() {
    signal SplitControl.startDone();
  }

  task void stopDone() {
    signal SplitControl.stopDone();
  }

  task void humDone() {
    bool sig = FALSE;
    atomic {
      if (state == SAMPLE) {
	state = IDLE;
	sig = TRUE;
      }
    }

    if (sig) {
      call SensorControl.stop();
      signal Humidity.dataReady(adcdata);
    }
  }

  task void tempDone() {
    bool sig = FALSE;
    atomic {
      if (state == SAMPLE) {
	state = IDLE;
	sig = TRUE;
      }
    }

    if (sig) {
      call SensorControl.stop();
      signal Temperature.dataReady(adcdata);
    }
  }

  command result_t SplitControl.init() {
    state = POWER_OFF;
    call TimerControl.init();
    call SensorControl.init();
    post initDone();
    return SUCCESS;
  }

  command result_t SplitControl.start() {
    // turn the sensor on
    call TimerControl.start();
    atomic {
      HUMIDITY_MAKE_PWR_OUTPUT();
      HUMIDITY_SET_PWR();
      state = WARM_UP;
    }
    call Timer.start(TIMER_ONE_SHOT, 80);
    return SUCCESS;
  }

  command result_t SplitControl.stop() {
    atomic state = POWER_OFF;
    // turn the sensor off
    call SensorControl.stop();
    HUMIDITY_CLEAR_PWR();
    post stopDone();
    return SUCCESS;
  }

  event result_t Timer.fired() {
    uint8_t _state = IDLE;
    atomic {
      if (state == WARM_UP) {
	state = IDLE;
	post startDone();
      }
      else if (state == SAMPLE) {
	if (id == HUMIDITY) {
	  _state = HUMIDITY;
	}
	else if (id == HUMIDITY_TEMP)
	  _state = HUMIDITY_TEMP;
      }
    }

    if (_state == HUMIDITY) 
      return call HumSensor.getData();
    else if (_state == HUMIDITY_TEMP)
      return call TempSensor.getData();
    return SUCCESS;
  }

  // no such thing
  async command result_t Humidity.getContinuousData() {
    return FAIL;
  }

  // no such thing
  async command result_t Temperature.getContinuousData() {
    return FAIL;
  }

  task void startSensor() {
    call SensorControl.start();
    call Timer.start(TIMER_ONE_SHOT, 11);
  }

  async command result_t Humidity.getData() {
    result_t res = FAIL;

    atomic {
      if (state == IDLE) {
	state = SAMPLE;
	id = HUMIDITY;
	res = SUCCESS;
      }
    }

    if (res == SUCCESS)
      return post startSensor();
    return res;
  }

  async command result_t Temperature.getData() {
    result_t res = FAIL;

    atomic {
      if (state == IDLE) {
	state = SAMPLE;
	id = HUMIDITY_TEMP;
	res = SUCCESS;
      }
    }

    if (res == SUCCESS)
      return post startSensor();
    return res;
  }

  default async event result_t Humidity.dataReady(uint16_t data)
  {
    return SUCCESS;
  }

  default async event result_t Temperature.dataReady(uint16_t data)
  {
    return SUCCESS;
  }

  async event result_t TempSensor.dataReady(uint16_t data) {
    adcdata = data;
    if (!post tempDone()) {
      atomic state = IDLE;
      signal Temperature.dataReady(data);
    }
    return SUCCESS;
  }

  async event result_t HumSensor.dataReady(uint16_t data) {
    adcdata = data;
    if (!post humDone()) {
      atomic state = IDLE;
      signal Humidity.dataReady(data);
    }
    return SUCCESS;
  }

  command result_t HumidityError.enable() {
    return call HumError.enable();
  }

  command result_t HumidityError.disable() {
    return call HumError.disable();
  }

  command result_t TemperatureError.enable() {
    return call TempError.enable();
  }

  command result_t TemperatureError.disable() {
    return call TempError.disable();
  }

  event result_t HumError.error(uint8_t token) {
    atomic state = IDLE;
    call SensorControl.stop();
    return signal HumidityError.error(token);
  }

  event result_t TempError.error(uint8_t token) {
    atomic state = IDLE;
    call SensorControl.stop();
    return signal TemperatureError.error(token);
  }

  default event result_t HumidityError.error(uint8_t token) { return SUCCESS; }

  default event result_t TemperatureError.error(uint8_t token) { return SUCCESS; }

}

