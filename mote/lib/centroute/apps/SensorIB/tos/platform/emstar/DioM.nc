/*
 *
 * Copyright (c) 2003 The Regents of the University of California.  All 
 * rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 *
 * - Neither the name of the University nor the names of its
 *   contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS''
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
 * PARTICULAR  PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE REGENTS OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 *
 * Authors:   Mohammad Rahimi mhr@cens.ucla.edu
 * History:   created 08/14/2003
 * History:   modified 11/14/2003
 *
 * driver for PCF8574APWR on mda300ca
 *
 */

module DioM {
  provides {
    interface StdControl;
    interface Dio[uint8_t channel];
  }
  uses {
    interface Leds;
  }
}

implementation {
  
  //Note we have no async code here so there is no possibility of any race condition
  
  uint8_t state;			//keep state of our State Machine 
  uint8_t lastInputValue;		// Last value read from the chip.
  uint8_t outputValue;			// intended value of the outputs
  uint8_t mode[8];			//keep track of the mode of each channel
  uint16_t count[8];			//we can count the number of pulses 
  
#define XOR(a,b)  ((a) & ~(b))|(~(a) & (b))
  
  //set of bitwise functions
#define  testbit(var, bit)   ((var) & (1 <<(bit)))    
  //if zero then return zero and if one not equal zero
#define  setbit(var, bit)    ((var) |= (1 << (bit)))
#define  clrbit(var, bit)    ((var) &= ~(1 << (bit)))
  
  //Interrupt definition
#define INT_ENABLE()  sbi(EIMSK , 4)
#define INT_DISABLE() cbi(EIMSK , 4)
  

  enum {GET_DATA, SET_OUTPUTS, IDLE , INIT};

  
  command result_t StdControl.init() {
	mode[0] = RISING_EDGE;
	mode[1] = RISING_EDGE;
	mode[2] = RISING_EDGE;
	mode[3] = RISING_EDGE;
	mode[4] = RISING_EDGE;
	mode[5] = RISING_EDGE;
	mode[6] = DIG_OUTPUT;
	mode[7] = DIG_OUTPUT;
	lastInputValue = 0xff;		// The chip comes up as 0xff try that as a first guess to the current value
	outputValue = 0x00;		// Start with outputs off.
	state = INIT;             
	return SUCCESS;
  }
    
    task void init_io()
      {
      }
    
    command result_t StdControl.start() {
      cbi(DDRE,4);            //Making INT pin input
      //cbi(EICRB,ISC40);       //Making INT sensitive to falling edge
      //sbi(EICRB,ISC41);
      //INT_ENABLE();           //probably bus is stable and now we are ready 
      post init_io();
      return SUCCESS;
    }
    
    command result_t StdControl.stop() {
     return SUCCESS;
    }

    command uint8_t Dio.getparam[uint8_t channel]()
      { 
        return mode[channel];
      }
    
    command result_t Dio.setparam[uint8_t channel](uint8_t modeToSet)
      {    
        //we only set INT flag if we set any channel to input otherwise we do not touch it.
        mode[channel]=modeToSet;
        if( ((modeToSet & RISING_EDGE) == 0) & ((modeToSet & FALLING_EDGE) == 0) ) mode[channel] |= RISING_EDGE;
        return SUCCESS;
      }
    
    // Drive the output pins to the intended value.
    // This has the bug that many calls will result in multiple tasks
    // in the queue when only one is necessary. The code will operate
    // properly but consumes more resources than necessary.
    task void setOutputs()
      {
      }
    
    command result_t Dio.Toggle[uint8_t channel]() {
      return SUCCESS;
    }
    
    command result_t Dio.high[uint8_t channel]()
      {
        return SUCCESS;
      }
    
    command result_t Dio.low[uint8_t channel]() {
      return SUCCESS;
    }
    
    command result_t Dio.getData[uint8_t channel]()
      {    
        return SUCCESS;
      } 
    
    default event result_t Dio.dataReady[uint8_t channel](uint16_t data) 
      {
        return SUCCESS;
      } 

    command result_t Dio.getValue[uint8_t channel]()
      {    
        return SUCCESS;
      } 
    

    default event result_t Dio.valueReady[uint8_t channel](bool data) 
      {
        return SUCCESS;
      } 

    task void read_io() {
    }
    
    
}
