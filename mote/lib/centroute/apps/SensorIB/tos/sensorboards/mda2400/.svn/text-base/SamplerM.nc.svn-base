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
 * History:   created  08/14/2003
 * history:   modified 11/14/2003
 *
 *
 */

module SamplerM
{
  provides {
    interface StdControl as SamplerControl;
    interface Sample;
    // Used to reset the UartComm module if necessary
    interface ADCReset;
  }
  uses {     
    interface Leds;
    interface Timer as SamplerTimer;
    
    interface StdControl as DaqControl;
    interface Convert as ConvertDaq;
    // Interface to reset the ADC.
    interface ADCReset as internalADCReset;
  }
}
implementation
{
#include "sensorboard.h"
#define SCHEDULER_RESPONSE_TIME 100
//this means we have resolution of 0.1 sec
#define TIME_SCALE 100   
#define SAMPLER_ERROR -1                  
#define SAMPLER_OFFSET 1
//the sampler records are from 0-Max but we pass to outside world 0+SAMPLER_OFFSET to max+SAMPLER_OFFSET
//
#include "../../../../dse/tos/lib/StdDbg.h"

  void next_schedule();
  
  // main data structure 10 byte per record
  struct SampleRecords_s{
    uint8_t channel;              
    uint8_t channelType;         
    int16_t ticks_left;         // used for keeping the monostable timer 
    int16_t sampling_interval;  // Sampling interval set by command above, It is in second, SampleRecord in no use if set to zero.    
    uint8_t param;
  }__attribute__((packed)); 

  struct SampleRecords_s SampleRecord[MAX_SAMPLERECORD];
  uint8_t number_of_available_records;

  /*********************************************Parameter Setting Utility***********************************************/
#define SAMPLER_CHANNEL_ACTIVE_MARKER 0x01
#define CHANNEL_EVENT_MARKER 0x02

  //set of bitwise functions
#define  test_bit(var, bit)   ((var) & (1 <<(bit)))
  //if zero then return zero and if one not equal zero
#define  set_bit(var, bit)    ((var) |= (1 << (bit)))
#define  clr_bit(var, bit)    ((var) &= ~(1 << (bit)))

  /* This utility functions are for marking a record when it starts sampling. This enables mutiple call to a shared resource for different time interval */
  inline static result_t is_record_turn_active(uint8_t myParam) { 
    if (test_bit(myParam, SAMPLER_CHANNEL_ACTIVE_MARKER)) 
      return SUCCESS; 
    else 
      return FAIL; 
  }

  inline static uint8_t activate_record_turn(uint8_t myParam) { 
    set_bit(myParam, SAMPLER_CHANNEL_ACTIVE_MARKER); 
    return myParam; 
  }
  
  inline static uint8_t deactivate_record_turn(uint8_t myParam) { 
    clr_bit(myParam, SAMPLER_CHANNEL_ACTIVE_MARKER); 
    return myParam; 
  }
  
  /* This utility functions are for marking a record as event driven so that asynchronous logic can proceed. */
  inline static result_t is_channel_event_driven(uint8_t myParam) { 
    if (test_bit(myParam, CHANNEL_EVENT_MARKER)) 
      return SUCCESS; 
    else 
      return FAIL; 
  }

  inline static uint8_t make_channel_event_driven(uint8_t myParam) { 
    set_bit(myParam, CHANNEL_EVENT_MARKER); 
    return myParam; 
  }

  inline static uint8_t undo_make_channel_event_driven(uint8_t myParam) { 
    clr_bit(myParam, CHANNEL_EVENT_MARKER); 
    return myParam; 
  }
  
  /***************** Parameter Setting ********************/        
  // DAQ Channels
  static inline void setparam(uint8_t i, uint8_t param) {
    call ConvertDaq.setParam(param, SampleRecord[i].channel);
  }
  
  /************* Actual call of low level devices for sampling ***********/
  void sampleRecord(uint8_t i) {
    // mark it as it has a running sampling process
    SampleRecord[i].param = activate_record_turn(SampleRecord[i].param);  
    call ConvertDaq.getData(SampleRecord[i].channel);
  }
  
  /*
   * Link through to the ADCReset interface in DaqC.
   */
  command result_t ADCReset.reset() {
    call internalADCReset.reset();
    return SUCCESS;
  }
  
  /********************** StdControl Functions ********************/
  command result_t SamplerControl.init() {
    int i;
    number_of_available_records = MAX_SAMPLERECORD;
    call DaqControl.init();
    
    // Initialize the record array
    for(i = 0; i < MAX_SAMPLERECORD; i++) { 
      SampleRecord[i].sampling_interval = SAMPLE_RECORD_FREE;
      SampleRecord[i].channel           = NOT_USED;
      SampleRecord[i].channelType       = NOT_USED;
      SampleRecord[i].ticks_left        = 0xffff;
      SampleRecord[i].param             = 0x0;
    }

    return SUCCESS;
  }
  
  command result_t SamplerControl.start() {
    call DaqControl.start();
    next_schedule();  //initialization of the schedules
    return SUCCESS;
  }
  
  command result_t SamplerControl.stop() {
    call DaqControl.stop();
    return SUCCESS;
  }
  
  /********** Managment of Sampling Process ***********************/
  /* 
   * Use a simple linear search to find the first available sample record 
   * Return the location of the record if a free slot is found
   * Return SAMPLER_ERROR if full
   */
  static inline int8_t get_avilable_SampleRecord()
  {
    int8_t i;
    for (i = 0; i < MAX_SAMPLERECORD; i++) {
      if (SampleRecord[i].sampling_interval == SAMPLE_RECORD_FREE ) {
        return i;
      }
    }
    // not available SampleRecord
    return SAMPLER_ERROR; 
  }
  
  /** find the next channel which should be serviced **/ 
  void next_schedule(){
    int8_t i;
    // minimum time to ba called.we set it to 15Sec min so that if a new 
    // ..sampling request comes we reply with 15 sec delay.
    int16_t min = SCHEDULER_RESPONSE_TIME;   
    
    // find out any one who should be serviced before next 15 second.
    for(i = 0; i < MAX_SAMPLERECORD; i++) {
      if (is_channel_event_driven(SampleRecord[i].param) == FAIL) {
        if (SampleRecord[i].sampling_interval != SAMPLE_RECORD_FREE ) {
          if (SampleRecord[i].ticks_left < min) {
            min = SampleRecord[i].ticks_left;
          }
        }
      }
    }

    // set the next time accordingly
    for (i = 0; i < MAX_SAMPLERECORD; i++) { 
      if (is_channel_event_driven(SampleRecord[i].param) == FAIL && 
          SampleRecord[i].sampling_interval != SAMPLE_RECORD_FREE) {                
        SampleRecord[i].ticks_left = SampleRecord[i].ticks_left - min;
      }
    }

    // since timer gets input in milisecond and we get command in 0.1sec.
    min = min * TIME_SCALE;   

    // Start the timer to fire when the next sample is scheduled
    call SamplerTimer.start(TIMER_ONE_SHOT, min);
  }
  
  
  /** Main timer that keeps the next sampling time **/
  event result_t SamplerTimer.fired() {
    uint8_t i;
    // sample anyone which is supposed to be sampled
    for (i = 0; i < MAX_SAMPLERECORD; i++) { 
      if (is_channel_event_driven(SampleRecord[i].param) == FAIL) {
        if (SampleRecord[i].sampling_interval != SAMPLE_RECORD_FREE ) {
          if (SampleRecord[i].ticks_left == 0 ) {
            SampleRecord[i].ticks_left = SampleRecord[i].sampling_interval; 
            sampleRecord(i);
          }
        }
      }
    }      
    
    next_schedule(); // now see when timer should be fired for new samples
    return SUCCESS;
  }
  
    /******** Sampler Interface Implementation *********/
  command int8_t Sample.getSample(uint8_t channel, uint8_t channelType,
                                  uint16_t interval, uint8_t param) {
    int8_t i;
    // See if a record opening is available
    i = get_avilable_SampleRecord();
    // Nothing, return error
    if (i == SAMPLER_ERROR) 
      return SAMPLER_ERROR;
    
    // Initialize the record
    SampleRecord[i].channel           = channel;              
    SampleRecord[i].channelType       = channelType; 
    // Used for keeping the monostable timer 
    SampleRecord[i].ticks_left        = 0;           
    // Sampling interval set by command above, SampleRecord in no use if set to zero
    SampleRecord[i].sampling_interval = interval;    
    SampleRecord[i].param             = 0;

    // Set the channel parameter
    call ConvertDaq.setParam(SampleRecord[i].channel, param);
    
    number_of_available_records--;
    // Outside world Sampler ID starts from 1
    return i + SAMPLER_OFFSET;  
  }
  
  command result_t Sample.reTask(int8_t record, uint16_t interval) {
    record = record - SAMPLER_OFFSET;
    if (record < 0 || record > MAX_SAMPLERECORD) 
      return FAIL;
    SampleRecord[record].sampling_interval = interval;
    return SUCCESS;
  }
  
  command result_t Sample.stop(int8_t record) {
    record = record - SAMPLER_OFFSET;
    // Simple sanity checks
    if (record < 0 || record > MAX_SAMPLERECORD) 
      return FAIL;
    
    // we only increse if they have not stopped a record which was available already
    if (SampleRecord[record].sampling_interval != SAMPLE_RECORD_FREE) 
      number_of_available_records++;   

    // Clear the record for later use
    SampleRecord[record].sampling_interval = SAMPLE_RECORD_FREE;
    SampleRecord[record].channel           = NOT_USED;
    SampleRecord[record].channelType       = NOT_USED;

    return SUCCESS;
  }
  
  command uint8_t Sample.availableSamplingRecords() {
    return number_of_available_records;
  }
  
  /**********Result of the Events of Different Sensors**********/
  // Getting the sampler ID to pass it to upper layer as a unique primery key 
  // ..of underlying sampling process
  int8_t getID(uint8_t channelType, uint8_t channel) {
    int8_t i;
    // If channel is synchronously active (called)
    for (i = 0; i < MAX_SAMPLERECORD; i++) {
      if (SampleRecord[i].channel == channel && 
          SampleRecord[i].channelType == channelType) {
        // return if synchronous
        if (is_record_turn_active(SampleRecord[i].param) == SUCCESS) { 
          SampleRecord[i].param = deactivate_record_turn(SampleRecord[i].param); 
          return i + SAMPLER_OFFSET; 
        } 
        // else return if async
        else if (is_channel_event_driven(SampleRecord[i].param) == SUCCESS) {
          return i + SAMPLER_OFFSET;
        }
      }
    }
    
    // channel is not an active sampling process so send fail
    stddbg("channel type = %d, channel = %d ", channelType, channel);
    return SAMPLER_ERROR;
  }
  
  /*
   * Return converted data up.
   */
  event result_t ConvertDaq.dataReady(int32_t data, uint8_t port) {
    int8_t i = getID(DAQ, port); 
    int16_t down_sample = 0;

    // Down sample the 24 bit accuracy to 16 bits by right shifting 8 times
    // ..then casting to an int16 (thereby cutting off the least significant
    // ..8 bits)
    down_sample = (int16_t)(data >> 8);
    
    if (data != ADC_ERROR) {
      signal Sample.dataReady(i, DAQ, port, down_sample);
    }

    return SUCCESS; 
  }
  
  // not implemented
  command result_t Sample.set_digital_output(uint8_t channel,uint8_t state) {
    return SUCCESS;
  }

  default event result_t Sample.dataReady(int8_t samplerID, uint8_t channel, 
                                          uint8_t channelType, uint16_t data) { 
    return SUCCESS; 
  }
}
