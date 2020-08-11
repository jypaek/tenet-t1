// $Id: HumidityProtocolM.nc,v 1.1 2006-10-26 18:33:00 mvieira Exp $
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
 * @author Mohammad Rahmim
 * @author Joe Polastre
 */

module HumidityProtocolM {
  provides {
    interface StdControl;
    interface ADC as TempSensor;
    interface ADC as HumSensor;
    interface ADCError as HumError;
    interface ADCError as TempError;
  }
  uses {
    interface Leds;
    interface Timer;
    interface MSP430Interrupt as SensirionInterrupt;
  }

}
implementation {


  //states
  enum {READY=0, TEMP_MEASUREMENT=1, HUM_MEASUREMENT=2, POWER_OFF};

  norace uint8_t state;
  uint8_t timeout;
  uint8_t errornum;
  uint16_t data;
  norace bool humerror,temperror;


  task void signalHumError() {
    uint8_t _error;
    atomic _error = errornum;
    signal HumError.error(_error);
  }

  task void signalTempError() {
    uint8_t _error;
    atomic _error = errornum;
    signal TempError.error(_error);
  }

  static inline void HUMIDITY_INT_ENABLE() {
    atomic {
      HUMIDITY_MAKE_DATA_INPUT();
      HUMIDITY_SET_DATA();
      call SensirionInterrupt.disable();
      call SensirionInterrupt.clear();
      call SensirionInterrupt.edge(FALSE);
      call SensirionInterrupt.enable();
    }
  }

  static inline void HUMIDITY_INT_DISABLE() {
    call SensirionInterrupt.disable();
  }

  static inline void  ack()
  {
    HUMIDITY_MAKE_DATA_OUTPUT();
    HUMIDITY_CLEAR_DATA();
    TOSH_wait_250ns();
    HUMIDITY_SET_CLOCK();
    TOSH_wait_250ns();
    HUMIDITY_CLEAR_CLOCK();
    HUMIDITY_MAKE_DATA_INPUT();
    HUMIDITY_SET_DATA();
  }

  static inline void initseq()
  { 
    HUMIDITY_MAKE_DATA_OUTPUT();
    HUMIDITY_SET_DATA();
    HUMIDITY_CLEAR_CLOCK();   
    TOSH_wait_250ns();         
    HUMIDITY_SET_CLOCK();
    TOSH_wait_250ns();
    HUMIDITY_CLEAR_DATA();
    TOSH_wait_250ns();
    HUMIDITY_CLEAR_CLOCK();
    TOSH_wait_250ns();
    HUMIDITY_SET_CLOCK();
    TOSH_wait_250ns(); 
    HUMIDITY_SET_DATA();
    TOSH_wait_250ns(); 
    HUMIDITY_CLEAR_CLOCK();
  }

  static inline void reset()
  {
    int i;
    HUMIDITY_MAKE_DATA_OUTPUT();
    HUMIDITY_SET_DATA();
    HUMIDITY_CLEAR_CLOCK();
    for (i=0;i<9;i++) {
      HUMIDITY_SET_CLOCK();
      TOSH_wait_250ns();
      HUMIDITY_CLEAR_CLOCK();
    }
  }

  task void startTimeoutTimer() {
    call Timer.start(TIMER_REPEAT, HUMIDITY_TIMEOUT_MS);
  }

  static inline char processCommand(int cmd)
  {
    int i;
    int CMD = cmd;
    cmd &= 0x1f;
    HUMIDITY_INT_DISABLE();
    reset();           
    initseq();        //sending the init sequence
    for(i=0;i<8;i++){
      if(cmd & 0x80) HUMIDITY_SET_DATA();
      else HUMIDITY_CLEAR_DATA();
      cmd = cmd << 1 ;
      HUMIDITY_SET_CLOCK();
      TOSH_wait_250ns();              
      TOSH_wait_250ns();              
      HUMIDITY_CLEAR_CLOCK();        
    }
    HUMIDITY_MAKE_DATA_INPUT();
    HUMIDITY_SET_DATA();
    TOSH_wait_250ns();
    HUMIDITY_SET_CLOCK();
    TOSH_wait_250ns();
    if(HUMIDITY_GET_DATA()) 
    { 
      atomic {
	reset(); 
	errornum = 2;
      }
      if ((CMD == TOSH_HUMIDITY_ADDR) && (humerror == TRUE))
        post signalHumError();
      else if ((CMD == TOSH_HUMIDTEMP_ADDR) && (temperror == TRUE))
        post signalTempError();
      return 0; 
    }
    TOSH_wait_250ns();
//      call Leds.yellowOn();
    HUMIDITY_CLEAR_CLOCK();
    HUMIDITY_INT_ENABLE();
    if((CMD == TOSH_HUMIDITY_ADDR) || (CMD == TOSH_HUMIDTEMP_ADDR) ){
      if ((CMD == TOSH_HUMIDITY_ADDR) && (humerror == TRUE)) {
        atomic timeout = 0;
	post startTimeoutTimer();
      }
      else if ((CMD == TOSH_HUMIDTEMP_ADDR) && (temperror == TRUE)) {
        atomic timeout = 0;
	post startTimeoutTimer();
      }
    }
    return 1;
  }

  command result_t StdControl.init() {
    humerror = FALSE;
    humerror = TRUE;
    temperror = FALSE;
    state = POWER_OFF;
    return SUCCESS;
  }

  command result_t StdControl.start() {
    atomic {
      state=READY;
      HUMIDITY_MAKE_CLOCK_OUTPUT();
      HUMIDITY_CLEAR_CLOCK();
      HUMIDITY_MAKE_DATA_INPUT();
      HUMIDITY_SET_DATA();
      HUMIDITY_INT_DISABLE();
      reset();
      processCommand(TOSH_HUMIDITY_RESET);
    }
    return SUCCESS;
  }

  command result_t StdControl.stop() {
    atomic {
      state = POWER_OFF;
      HUMIDITY_CLEAR_CLOCK();
      HUMIDITY_MAKE_CLOCK_INPUT();
      HUMIDITY_CLEAR_DATA();
      HUMIDITY_MAKE_DATA_INPUT();
    }
    return SUCCESS;
  }

  default async event result_t TempSensor.dataReady(uint16_t tempData) 
  {
    return SUCCESS;
  }


  default async event result_t HumSensor.dataReady(uint16_t humData) 
  {
    return SUCCESS;
  }


  task void readSensor()
  {
    uint8_t _state, i;

    atomic {
      _state = state;
      data=0; 
    }

    call Timer.stop();

    for(i=0;i<8;i++){
      HUMIDITY_SET_CLOCK();   
      TOSH_wait_250ns();
      if (HUMIDITY_GET_DATA())
        data |= 1;
      data = data << 1;
      HUMIDITY_CLEAR_CLOCK();
    }
    ack();
    for(i=0;i<8;i++){
      HUMIDITY_SET_CLOCK();   
      TOSH_wait_250ns();
      if (HUMIDITY_GET_DATA())
        data |= 1;
      //the last byte of data should not be shifted
      if(i!=7) data = data << 1;  
      HUMIDITY_CLEAR_CLOCK();
    }
    ack();
    for(i=0;i<8;i++){
      HUMIDITY_SET_CLOCK();   
      TOSH_wait_250ns();
      HUMIDITY_CLEAR_CLOCK();
    }
    // nack with high as it should be for the CRC ack
    HUMIDITY_MAKE_DATA_OUTPUT();
    HUMIDITY_SET_DATA();          
    TOSH_wait_250ns();
    HUMIDITY_SET_CLOCK();
    TOSH_wait_250ns();
    HUMIDITY_CLEAR_CLOCK();

    if(_state==TEMP_MEASUREMENT){
      /* let the PC do the calculation *****
      temp=data;
      t= (((float)(temp) )*0.98-3840)/100;
      temp= (int16_t) t; 
      if(temp > 100 ) temp=100;
      if(temp < -40 ) temp=-40;
      signal TempSensor.dataReady(temp);
      ****/
      signal TempSensor.dataReady(data);
    }
    else if(_state==HUM_MEASUREMENT) {
      /* let the PC do the calculation *****
      hum=data;
      h= 0.0405 * (float) (hum) - 4 - (float)(hum) * (float)(hum)*0.0000028;
      h= (t-25) * (0.01 + 0.00128 * hum) + h;
      hum= (int16_t) h;
      if(hum > 100 ) hum=100;
      if(hum < 0 ) hum=0;
      signal HumSensor.dataReady(hum);
      ****/
      signal HumSensor.dataReady(data);
    }
    atomic state=READY;
  }

#ifndef PLATFORM_PC
  async event void SensirionInterrupt.fired()
  {
    HUMIDITY_INT_DISABLE();
    post readSensor();
    return;
  }
#endif

  // no such thing
  async command result_t TempSensor.getContinuousData() {
    return FAIL;
  }

  // no such thing
  async command result_t HumSensor.getContinuousData() {
    return FAIL;
  }

  async command result_t TempSensor.getData()
  {
    atomic {
      if(state != READY ){
	reset();
      }
      state=TEMP_MEASUREMENT;
    }
    processCommand(TOSH_HUMIDTEMP_ADDR);
    return SUCCESS;
  }

  async command result_t HumSensor.getData()
  {
    atomic {
      if(state != READY ){
	reset();
      }
      state=HUM_MEASUREMENT;
    }
    processCommand(TOSH_HUMIDITY_ADDR);
    return SUCCESS;
  }

  command result_t HumError.enable() {
    result_t res = FAIL;

    atomic {
      if (humerror == FALSE) {
	humerror = TRUE;
	res = SUCCESS;
      }
    }

    return res;
  }

  command result_t TempError.enable() {
    result_t res = FAIL;

    atomic {
      if (temperror == FALSE) {
	temperror = TRUE;
	res = SUCCESS;
      }
    }

    return res;
  }

  command result_t HumError.disable() {
    result_t res = FAIL;

    atomic {
      if (humerror == TRUE) {
	humerror = FALSE;
        res = SUCCESS;
      }
    }

    return res;
  }

  command result_t TempError.disable() {
    result_t res = FAIL;

    atomic {
      if (temperror == TRUE) {
	temperror = FALSE;
	res = SUCCESS;
      }
    }

    return res;
  }

  event result_t Timer.fired() {
    uint8_t _state, _time;
    atomic {
      _state = state;
      timeout++;
      _time = timeout;
    }
    if (_time > HUMIDITY_TIMEOUT_TRIES) {
      if ((_state == HUM_MEASUREMENT) && (humerror == TRUE)) {
        call Timer.stop();
	atomic {
	  HUMIDITY_INT_DISABLE();
	  state = READY;
	  errornum = 1;
	}
        post signalHumError();
      }
      else if ((_state == TEMP_MEASUREMENT) && (temperror == TRUE)) {
        call Timer.stop();
	atomic {
	  HUMIDITY_INT_DISABLE();
	  state = READY;
	  errornum = 1;
	}
        post signalTempError();
      }
    }
    return SUCCESS;
  }

  default event result_t HumError.error(uint8_t token) { return SUCCESS; }

  default event result_t TempError.error(uint8_t token) { return SUCCESS; }

}
