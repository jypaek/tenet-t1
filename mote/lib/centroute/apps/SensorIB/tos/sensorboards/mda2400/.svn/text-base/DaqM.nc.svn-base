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
 * update at 11/14/2003 
 */
 // Sample.getSample()
 // * Provide on-board sensor readings
 // * Readings from ADC
 // * Configure parameters (excitation)

 // When calling returnSample()
 // * Sample Averaging
 // * Return data

module DaqM
{
  provides {
    interface StdControl as DaqControl;
    interface Convert;
    interface ADCReset;
  }

  uses interface UartCommI as UartComm;
  uses interface StdControl as UartControl;
  uses interface Timer as TimeoutTimer;
  uses interface Timer as PowerStabalizingTimer;
  uses interface Leds;
}

implementation
{
#include "sensorboard.h"
    
  /*Note:we do not do anything inside async part so all parts are synchronous and
    there is no synchronization hazard.Now ADC runs in the round-robin fashin so it
    is fair.*/
  
  char state;       /* current state of the DAQ request */
  int32_t value;   /* value of the incoming DAQ reading */
  int32_t total_value;
  uint8_t chan;
  uint8_t param[MAX_DAQ_CHANNELS];  /*we reserve last param for excitation of digital channels*/
  uint16_t adc_bitmap;
  int8_t byteCount;
  int8_t conversionNumber;

  //set of bitwise functions
#define  testbit(var, bit)   ((var) & (1 <<(bit)))      //if zero then return zero and if one not equal zero
#define  setbit(var, bit)    ((var) |= (1 << (bit)))
#define  clrbit(var, bit)    ((var) &= ~(1 << (bit)))
  
  
  result_t convert();
  
  /*
   * Lookup correct value to send to DAQ to obtain the requested voltage
   *
   * The formula is: (value + 1) * 5 / 256 = Voltage
   */
  void sendExcitationValue() {
    if (param[chan] & EXCITATION_25) {
      call UartComm.sendCommand(127);
    }
    
    if(param[chan] & EXCITATION_33) {
      call UartComm.sendCommand(168);
    }

    // The command is actually for 
    if (param[chan] & EXCITATION_50) {
      call UartComm.sendCommand(20);
    }
  }

  /*
   * Verify channel and check parameter to find voltage to set (if any)
   */
  void setExcitation() {
    // Only channels 6 and 7 can have a voltage
    switch (chan) {
    case 6:
      call UartComm.sendCommand(CHANNEL_SIX_SEND_VOLTAGE);
      sendExcitationValue();
      call UartComm.sendCommand(CHANNEL_SIX_ENABLE_VOLTAGE);
      break;
    case 7:
      call UartComm.sendCommand(CHANNEL_SEVEN_SEND_VOLTAGE);
      sendExcitationValue();
      call UartComm.sendCommand(CHANNEL_SEVEN_ENABLE_VOLTAGE);
      break;
      // Do nothing for other channels
    default:
    }
  }
  
  /*
   * Disable any enabled voltages by sending the channel specific disable
   * command to the DAQ.
   */
  void resetExcitation()
  {    
    // Only channels 6 and 7 can have a voltage
    switch (chan) {
    case 6:
      call UartComm.sendCommand(CHANNEL_SIX_DISABLE_VOLTAGE);
      break;
    case 7:
      //call UartComm.sendCommand(CHANNEL_SEVEN_DISABLE_VOLTAGE);
      break;
    default:
    }
    
    // Turn off the time out timer as the conversion finished.
    call TimeoutTimer.stop();
  }
  
  void setNumberOfConversions()
  {
    conversionNumber = 1;

    // Set the conversion number if we want to average readings
    if (param[chan] & AVERAGE_FOUR)
      conversionNumber = 4;
    if (param[chan] & AVERAGE_EIGHT)
      conversionNumber = 8;
    if (param[chan] & AVERAGE_SIXTEEN)
      conversionNumber = 16;

    return;
  }
  
  /* Used to reset this module and UartComm */
  command result_t ADCReset.reset() {
    // Return the ADC to an idle state.
    atomic {
      state      = IDLE;
      adc_bitmap = 0;
    }
    
    // Reset the Uart communications module
    call UartControl.stop();
    call UartControl.init();
    call UartControl.start();
    
    // Reset excitation settings
    resetExcitation();
    
    return SUCCESS;
  }
  
  command result_t DaqControl.init() {
    int i;
  
    atomic {
      state = IDLE;
      adc_bitmap = 0;
      for(i = 0; i < MAX_DAQ_CHANNELS; i++) 
        param[i] = 0x00;
    }
    
    // Init Uart communications
    call UartControl.init();
    
    return SUCCESS;
  }
  
  command result_t DaqControl.start() {
    call UartControl.start();
    return SUCCESS;
  }
  
  command result_t DaqControl.stop() {
    call UartControl.stop();
    return SUCCESS;
  }
  
  // Simple setter function for paramters 
  command result_t Convert.setParam(uint8_t channel, uint8_t mode) {
    // Make sure the channel exists.
    if (channel >= MAX_DAQ_CHANNELS)
      return FAIL;

    // All possible parameters are valid
    param[channel] = mode;
    return SUCCESS;
  }
  
  default event result_t Convert.dataReady(int32_t data, uint8_t channel) {
    return SUCCESS;
  }  
  
  task void adc_get_data()
  {
    uint8_t myIndex;
    uint8_t count;
    uint16_t my_bitmap;

    // That means the component is busy in a conversion process.  When 
    // ..conversion done either successfull or fail it is gauranteed that 
    // ..this task will be posted so we can safely return.     
    if (state != IDLE) 
      return; 

    // Initialize globals to start a reading
    state = START_CONVERSION_PROCESS; 
    value = 0;
    total_value = 0;
    byteCount = BYTES_PER_READING;
    
    // Now that the conversion process has started, we can start a timeout
    // ..timer controlling this process.  If it has taken too long, we will
    // ..reset the state back to IDLE.
    call TimeoutTimer.start(TIMER_ONE_SHOT, TIMEOUT_TIME);
    
    atomic { my_bitmap = adc_bitmap; }
    // it gaurantees a round robin fair scheduling of ADC conversions.
    count = 0;
    myIndex = chan + 1;
    
    if( myIndex >= MAX_DAQ_CHANNELS) 
      myIndex = 0;
    
    while(!testbit(my_bitmap,myIndex)) {
      myIndex++;

      if(myIndex >= MAX_DAQ_CHANNELS) 
        myIndex = 0;

      count++;

      // no one waiting for conversion
      if(count >= MAX_DAQ_CHANNELS) {
        state = IDLE; 
        return; 
      }   
    }
    
    // Channel to read
    chan = myIndex;
    
    // Setup the excitation voltage
    setExcitation();

    // Set the number of readings we want back from the DAQ
    setNumberOfConversions();
    
    // Wait a bit to stabilize voltage if needed
    if (param[chan] & DELAY_BEFORE_MEASUREMENT) {
      call PowerStabalizingTimer.start(TIMER_ONE_SHOT, VOLTAGE_STABLE_TIME);
    }
    else {
      convert();
    }
  }
  
  /*
   * Need to give a small delay to allow for voltage stabalization before
   * taking a reading.
   */
  event result_t PowerStabalizingTimer.fired() {
    return convert();
  }
  
  result_t convert() {
    uint8_t daq_command = 0;

    if (state == START_CONVERSION_PROCESS || state == CONTINUE_SAMPLE) {
      state = GET_SAMPLE;
      // Find command to sample channel, based on offset from read channel 0
      // ..command
      daq_command = SAMPLE_CHANNEL_ZERO + chan;
    }

    // Tell the DAQ to take a reading
    if (call UartComm.sendCommand(daq_command) == FAIL) {
        state = IDLE;
        post adc_get_data();
        resetExcitation();
        return FALSE;
    }
    
    return SUCCESS;
  }
  
  // get a single reading from id we
  command result_t Convert.getData(uint8_t channel) {      
    if (channel >= MAX_DAQ_CHANNELS)
      return FAIL;
    
    // Tell the bitmap we want a reading
    atomic {
      setbit(adc_bitmap, channel);
    }
    
    // Start reading from DAQ
    post adc_get_data();
  
    return SUCCESS;
  }
  
  // Timeout timer fired, reset the module.
  event result_t TimeoutTimer.fired() {
    return (call ADCReset.reset());
  }
  
  /*
   * Signalled when the DAQ returns a byte of data.  Since each result is 4
   * we need to combine the 1 byte data responses until we have all 4.  Pass
   * the final result up when we do.
   */
  event void UartComm.dataResponse(uint8_t data, result_t result) {
    // Oops, there was a problem.  Reset the state and signal an error up
    if (result == FAIL) {
      // Reset state
      state = IDLE;
      atomic { clrbit(adc_bitmap,chan); }
      resetExcitation();

      // Signal the error
      signal Convert.dataReady(ADC_ERROR, chan);
      
      // See if there's another conversion waiting
      post adc_get_data();

      return;
    }
    
    if (state == GET_SAMPLE) {
      byteCount--;
      // Check if we are waiting for more bytes to come in
      if (byteCount > 0) {
        // Add the byte into our 4 byte total
        value |= ((int32_t)data) << (byteCount * 8);
        // Wait for more data
        return;
      }
      // Have a complete reading, either return the data or ask for another
      // ..reading if we are averaging
      else {
        conversionNumber--;

        // No more conversions, return what we have.
        if (conversionNumber == 0) {
          state = IDLE;
          if (param[chan] & AVERAGE_SIXTEEN)
            value = ((total_value + 8) >> 4) & 0x0fff;
          else if (param[chan] & AVERAGE_EIGHT)
            value = ((total_value + 4) >> 3) & 0x0fff;
          else if (param[chan] & AVERAGE_FOUR)
            value = ((total_value + 2) >> 2) & 0x0fff;
          
          // Clear this channel from bitmap
          atomic { clrbit(adc_bitmap, chan); }
          post adc_get_data();
          // Pass the received data up
          signal Convert.dataReady(value, chan);
          resetExcitation();
        }
        // More conversions, add value to total_value and get more data
        else {
          state = CONTINUE_SAMPLE;
          total_value += value;
          value = 0;
          byteCount = BYTES_PER_READING;
          convert();
        }
      }
    }
  }
}
