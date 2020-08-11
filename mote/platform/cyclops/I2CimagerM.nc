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
/*
 *
 * Authors:		Joe Polastre, Rob Szewczyk
 * Date last modified:  7/18/02
 * modified:    Mohammad Rahimi, mhr@cens.ucla.edu
 * Date:        05/15/04
 *
 */

#define I2C_DELAY  20     // increased from 5 [RLB 3/18/05]

module I2CimagerM
{
  provides {
    interface StdControl;
    interface I2C;
  }
  uses interface Leds;
}
implementation
{
  // global variables
  char state;           	// maintain the state of the current process
  char local_data;		// data to be read/written
  result_t result;

  // define constants for state
  enum {READ_DATA=1, WRITE_DATA, SEND_START, SEND_END};

  // wait when triggering the clock
  void wait() {
    asm volatile  ("nop" ::);
  }

  // hardware pin functions
  // PORTD pin 6 is Imagaer Clock
  // PORTD pin 7 is Imagaer DATA
#define SET_CLOCK()         sbi(PORTD, 6)
#define CLEAR_CLOCK()       cbi(PORTD, 6)
#define MAKE_CLOCK_OUTPUT() sbi(DDRD, 6) 
#define MAKE_CLOCK_INPUT()  cbi(DDRD, 6)

#define SET_DATA()          sbi(PORTD, 7)
#define CLEAR_DATA()        cbi(PORTD, 7)
#define MAKE_DATA_OUTPUT()  sbi(DDRD, 7) 
#define MAKE_DATA_INPUT()   cbi(DDRD, 7) 
#define GET_DATA()  ((inp(PIND) & 0x80) >> 7)

// deactivate hardware timer (can interfere with PORTD pin 7)
#define TIMER2_OFF()  outp(0x00, TCCR2)

    void pulse_clock() 
    {
        TOSH_uwait(I2C_DELAY);   
        SET_CLOCK();
        TOSH_uwait(I2C_DELAY);
        CLEAR_CLOCK();
    }

  char read_bit() 
    {
        uint8_t i;
        MAKE_DATA_INPUT();
        TOSH_uwait(I2C_DELAY);
        SET_CLOCK();
        TOSH_uwait(I2C_DELAY);
        i = GET_DATA();
        CLEAR_CLOCK();
        return (i);
    }
  
  char i2c_read(){
      uint8_t data = 0;
      uint8_t i = 0;
      for(i = 0; i < 8; i ++)
      {
          data = (data << 1) & 0xfe;
          if(read_bit() == 1)
              data |= 0x1;
      }
      return data;
  }
  
  char i2c_write(char c) { 
      uint8_t i;
      MAKE_DATA_OUTPUT();
      for(i = 0; i < 8; i ++){
          if(c & 0x80){
              SET_DATA();
          }else{
              CLEAR_DATA();
          }
          pulse_clock();
          c = c << 1;
      }
      i = read_bit();	
      return i == 0;
  } 

  void i2c_start() {
	SET_DATA();
	SET_CLOCK();
	MAKE_DATA_OUTPUT();
	TOSH_uwait(I2C_DELAY);
	CLEAR_DATA();
	TOSH_uwait(I2C_DELAY);
	CLEAR_CLOCK();
  }

  void i2c_ack() {
	MAKE_DATA_OUTPUT();
	CLEAR_DATA();
	pulse_clock();
  }

  void i2c_nack() {
	MAKE_DATA_OUTPUT();
	SET_DATA();
	pulse_clock();
  }

  void i2c_end() {
	MAKE_DATA_OUTPUT();
	CLEAR_DATA();
  	TOSH_uwait(I2C_DELAY);
	SET_CLOCK();
	TOSH_uwait(I2C_DELAY);
	SET_DATA();
  }

  task void I2C_task(){
    uint8_t current_state = state;
    state = 0;
    if((current_state & 0xf) == READ_DATA){
        signal I2C.readDone(i2c_read());
        if (current_state & 0xf0) 
            i2c_ack();
        else
            i2c_nack();
    }else if(current_state == WRITE_DATA){
	    signal I2C.writeDone(i2c_write(local_data));
    }else if(current_state == SEND_START){
	    i2c_start();
	    signal I2C.sendStartDone();
    }else if(current_state == SEND_END){
	    i2c_end();
	    signal I2C.sendEndDone();
    }
  }

  command result_t StdControl.init() {
    SET_CLOCK();
    SET_DATA();
    MAKE_CLOCK_OUTPUT();
    MAKE_DATA_OUTPUT();
    state = 0;
    local_data = 0;
    return SUCCESS;
  }

  command result_t StdControl.start() {
    return SUCCESS;
  }

  command result_t StdControl.stop() {
    return SUCCESS;
  }

    command result_t I2C.sendStart() 
    {      
        if (state != 0) 
            return FAIL;
        state = SEND_START;
        post I2C_task();
        return SUCCESS;
    }
    
    command result_t I2C.sendEnd() 
    {
        if (state != 0) 
            return FAIL;
        state = SEND_END;
        post I2C_task();
        return SUCCESS;
    }
    
    command result_t I2C.read(bool ack) 
    {
        if (state != 0) 
            return FAIL;
        state = READ_DATA;
        if (ack) 
            state |= 0x10;
        post I2C_task();
        return SUCCESS;
    }
    
    command result_t I2C.write(char data) 
    {
        if(state != 0)
            return FAIL;
        state = WRITE_DATA;
        local_data = data;
        post I2C_task();
        return SUCCESS;
    }

  default event result_t I2C.sendStartDone() {
    return SUCCESS;
  }

  default event result_t I2C.sendEndDone() {
    return SUCCESS;
  }

  default event result_t I2C.readDone(char data) {
    return SUCCESS;
  }

  default event result_t I2C.writeDone(bool success) {
    return SUCCESS;
  }
  
}
