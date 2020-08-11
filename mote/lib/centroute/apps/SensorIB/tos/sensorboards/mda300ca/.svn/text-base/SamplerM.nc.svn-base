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
    provides interface StdControl as SamplerControl;
    provides interface Sample;
    provides command result_t PlugPlay();

    provides interface ADCReset;
uses {
  // Interface to reset the ADC.
  interface ADCReset as internalADCReset;
      
      interface Leds;
#ifdef EMSTAR_NO_KERNEL
      interface EmTimerI as SamplerTimer;
      //interface Timer as SamplerTimer;
#else
      interface Timer as SamplerTimer;
#endif

      //analog channels
      interface StdControl as IBADCcontrol;
      interface ADConvert as ADC0;
      interface ADConvert as ADC1;
      interface ADConvert as ADC2;
      interface ADConvert as ADC3;
      interface ADConvert as ADC4;
      interface ADConvert as ADC5;
      interface ADConvert as ADC6;
      interface ADConvert as ADC7;
      interface ADConvert as ADC8;
      interface ADConvert as ADC9;
      interface ADConvert as ADC10;
      interface ADConvert as ADC11;
      interface ADConvert as ADC12;
      interface ADConvert as ADC13;
      //ADC parameters
      interface SetParam as SetParam0;
      interface SetParam as SetParam1;
      interface SetParam as SetParam2;
      interface SetParam as SetParam3;
      interface SetParam as SetParam4;
      interface SetParam as SetParam5;
      interface SetParam as SetParam6;
      interface SetParam as SetParam7;
      interface SetParam as SetParam8;
      interface SetParam as SetParam9;
      interface SetParam as SetParam10;
      interface SetParam as SetParam11;
      interface SetParam as SetParam12;
      interface SetParam as SetParam13;

      //health channels temp,humidity,voltage
      interface StdControl as BatteryControl;
      interface ADConvert as Battery;
      interface StdControl as TempHumControl;
      interface ADConvert as Temp;
      interface ADConvert as Hum;

      //digital and relay channels
      interface StdControl as DioControl;
      interface Dio as Dio0;
      interface Dio as Dio1;
      interface Dio as Dio2;
      interface Dio as Dio3;
      interface Dio as Dio4;
      interface Dio as Dio5;

      //counter channels
      interface StdControl as CounterControl;
      interface Dio as Counter;
      
      command result_t Plugged();
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
#include "StdDbg.h"

  void next_schedule();

  //main data structure 10 byte per recorde
  struct SampleRecords_s{
    uint8_t channel;              
    uint8_t channelType;         
    int16_t ticks_left;         //used for keeping the monostable timer 
    int16_t sampling_interval;  //Sampling interval set by command above, It is in second, SampleRecord in no use if set to zero.    
    uint8_t param;
  }__attribute__((packed)); 
  struct SampleRecords_s SampleRecord[MAX_SAMPLERECORD];
  uint8_t number_of_available_records;

  /*********************************************Parameter Setting Utility*************************************************/
#define SAMPLER_CHANNEL_ACTIVE_MARKER 0x01
#define CHANNEL_EVENT_MARKER 0x02

//set of bitwise functions
#define  test_bit(var, bit)   ((var) & (1 <<(bit)))
//if zero then return zero and if one not equal zero
#define  set_bit(var, bit)    ((var) |= (1 << (bit)))
#define  clr_bit(var, bit)    ((var) &= ~(1 << (bit)))

  /* This utility functions are for marking a record when it starts sampling. This enables mutiple call to a shared resource for different time interval */  
  inline static result_t is_record_turn_active(uint8_t myParam) { if(test_bit(myParam,SAMPLER_CHANNEL_ACTIVE_MARKER)) return SUCCESS; else return FAIL; }
  inline static uint8_t activate_record_turn(uint8_t myParam) { set_bit(myParam,SAMPLER_CHANNEL_ACTIVE_MARKER); return myParam; }
  inline static uint8_t deactivate_record_turn(uint8_t myParam) { clr_bit(myParam,SAMPLER_CHANNEL_ACTIVE_MARKER); return myParam; }

  /* This utility functions are for marking a record as event driven so that asynchronous logic can proceed. */
  inline static result_t is_channel_event_driven(uint8_t myParam) { if(test_bit(myParam,CHANNEL_EVENT_MARKER)) return SUCCESS; else return FAIL; }
  inline static uint8_t make_channel_event_driven(uint8_t myParam) { set_bit(myParam,CHANNEL_EVENT_MARKER); return myParam; }
  inline static uint8_t undo_make_channel_event_driven(uint8_t myParam) { clr_bit(myParam,CHANNEL_EVENT_MARKER); return myParam; }

  /***********************************************Parameter Setting*******************************************************/        
  //analog channels
  static inline void setparam_analog(uint8_t i,uint8_t param)
    {
      switch(SampleRecord[i].channel){
      case 0:  call SetParam0.setParam(param);  break;
      case 1:  call SetParam1.setParam(param);  break;
      case 2:  call SetParam2.setParam(param);  break;
      case 3:  call SetParam3.setParam(param);  break;
      case 4:  call SetParam4.setParam(param);  break;
      case 5:  call SetParam5.setParam(param);  break;
      case 6:  call SetParam6.setParam(param);  break;
      case 7:  call SetParam7.setParam(param);  break;
      case 8:  call SetParam8.setParam(param);  break;
      case 9:  call SetParam9.setParam(param);  break;
      case 10: call SetParam10.setParam(param); break;
      case 11: call SetParam11.setParam(param); break;
      case 12: call SetParam12.setParam(param); break;
      case 13: call SetParam13.setParam(param); break;
      default:
      }
      return;
    }
  //digital channels
  static inline void setparam_digital(int8_t i,uint8_t param)
    {
      switch(SampleRecord[i].channel){
      case 0:  call Dio0.setparam(param);  break;
      case 1:  call Dio1.setparam(param);  break;
      case 2:  call Dio2.setparam(param);  break;
      case 3:  call Dio3.setparam(param);  break;
      case 4:  call Dio4.setparam(param);  break;
      case 5:  call Dio5.setparam(param);  break;
      default:
      }
      return;
    }
  //counter channel
  static inline void setparam_counter(int8_t i,uint8_t param)
    {
      call Counter.setparam(param);
      return;
    }
  
  /*******************************************Actual call of low level devices for sampling***********************************/
    void sampleRecord(uint8_t i)
      {
        SampleRecord[i].param = activate_record_turn(SampleRecord[i].param);  //mark it as it has a running sampling process
        switch (SampleRecord[i].channelType){
        case ANALOG:
          switch (SampleRecord[i].channel){
          case 0:  call ADC0.getData();  break;
          case 1:  call ADC1.getData();  break;
          case 2:  call ADC2.getData();  break;
          case 3:  call ADC3.getData();  break;
          case 4:  call ADC4.getData();  break;
          case 5:  call ADC5.getData();  break;
          case 6:  call ADC6.getData();  break;
          case 7:  call ADC7.getData();  break;
          case 8:  call ADC8.getData();  break;
          case 9:  call ADC9.getData();  break;
          case 10: call ADC10.getData(); break;
          case 11: call ADC11.getData(); break;
          case 12: call ADC12.getData(); break;
          case 13: call ADC13.getData(); break;
          default:
          }
          break;
        case DIGITAL:
          switch (SampleRecord[i].channel){
          case 0: call Dio0.getData(); break;
          case 1: call Dio1.getData(); break;
          case 2: call Dio2.getData(); break;
          case 3: call Dio3.getData(); break;
          case 4: call Dio4.getData(); break;
          case 5: call Dio5.getData(); break;
          default:
          }
          break;
        case BATTERY:
          call Battery.getData();
          break;
        case TEMPERATURE:
          call Temp.getData();
          break;
        case HUMIDITY:
          call Hum.getData();                
          break;
        case COUNTER:
          call Counter.getData();
          break;
        default:
        }
      }

    /*
     * Link through to the ADCReset interface in IBADC.
     */
    command result_t ADCReset.reset() {
      call internalADCReset.reset();
      return SUCCESS;
    }
    
    /*************************************Init, Start , Stop ***********************************************************/
    command result_t SamplerControl.init() {
      int i;
      number_of_available_records=MAX_SAMPLERECORD;
      call CounterControl.init();
      call DioControl.init();
      call IBADCcontrol.init();
      call BatteryControl.init();
      call TempHumControl.init();
      for(i=0;i<MAX_SAMPLERECORD;i++){ 
        SampleRecord[i].sampling_interval=SAMPLE_RECORD_FREE;
        SampleRecord[i].channel=NOT_USED;
        SampleRecord[i].channelType=NOT_USED;
        SampleRecord[i].ticks_left=0xffff;
        SampleRecord[i].param=0x0;
      }
      return SUCCESS;
    }
    
    command result_t SamplerControl.start() {
      call CounterControl.start();
      call DioControl.start();
      call IBADCcontrol.start();
      call BatteryControl.start();
    call TempHumControl.start();
      call CounterControl.start();
      next_schedule();  //initialization of the schedules

      dbg(DBG_USR3, "Starting samplerm!\n");

      return SUCCESS;
    }
 
    command result_t SamplerControl.stop() {
      call CounterControl.stop();
      call DioControl.stop();
      call IBADCcontrol.stop();
      call BatteryControl.stop();
      call TempHumControl.stop();
      return SUCCESS;
    }
        
    /***********************Managment of Sampling Process***********************************************************/
    /**return available sampling record**/
    static inline int8_t get_avilable_SampleRecord()
      {
        int8_t i;
        for(i=0;i<MAX_SAMPLERECORD;i++) if( SampleRecord[i].sampling_interval == SAMPLE_RECORD_FREE ) return i;
        return SAMPLER_ERROR; //not available SampleRecord
      }
    
    /**find the next channel which should be serviced**/ 
    void next_schedule(){
        int8_t i;
        int16_t min=SCHEDULER_RESPONSE_TIME;   //minimum time to ba called.we set it to 15Sec min so that if a new sampling request comes we reply with 15 sec delay.

        for(i=0;i<MAX_SAMPLERECORD;i++) //find out any one who should be serviced before next 15 second.
          {
            if(is_channel_event_driven(SampleRecord[i].param) == FAIL)
              {
                if( SampleRecord[i].sampling_interval != SAMPLE_RECORD_FREE )
                  {
                    if(SampleRecord[i].ticks_left < min) min = SampleRecord[i].ticks_left;
                  }
              }
          }
        for(i=0;i<MAX_SAMPLERECORD;i++) //set the next time accordingly
          {
            if(is_channel_event_driven(SampleRecord[i].param) == FAIL)
              {                
                if( SampleRecord[i].sampling_interval != SAMPLE_RECORD_FREE )
                  {
                    SampleRecord[i].ticks_left = SampleRecord[i].ticks_left-min;
                  }
              }
          }
        min=min * TIME_SCALE ;   //since timer gets input in milisecond and we get command in 0.1sec.
	dbg(DBG_USR3, "Setting sample timer!\n");

        if (call SamplerTimer.start(TIMER_ONE_SHOT , min) == FAIL)
	 {
      	   dbg(DBG_ERROR, "Oh noes, couldn't start sampler timer!\n");
    	 }
    }

    
    /**Main timer that keeps the next sampling time**/
    event result_t SamplerTimer.fired() {
      uint8_t i;
      
      dbg(DBG_USR3, "Sample timer fired!\n");

      for(i=0;i<MAX_SAMPLERECORD;i++) //sample anyone which is supposed to be sampled
        {
          if(is_channel_event_driven(SampleRecord[i].param) == FAIL)
            {                              
              if( SampleRecord[i].sampling_interval != SAMPLE_RECORD_FREE )
                {
                  if(SampleRecord[i].ticks_left == 0 ) 
                    {
                      SampleRecord[i].ticks_left = SampleRecord[i].sampling_interval; 
                      sampleRecord(i);
                    }
                }
            }
        }      
      next_schedule(); //now see when timer should be fired for new samples
      return SUCCESS;
    }
    
    /***************************************************Sampler Interface Implementation****************************************/
    command result_t Sample.set_digital_output(uint8_t channel,uint8_t state)
      {            
      }
    
    command int8_t Sample.getSample(uint8_t channel,uint8_t channelType,uint16_t interval,uint8_t param)
      {
        int8_t i;
        i=get_avilable_SampleRecord();
        if(i==SAMPLER_ERROR) return i;
        SampleRecord[i].channel=channel;              
        SampleRecord[i].channelType=channelType;         
        SampleRecord[i].ticks_left=0;                //used for keeping the monostable timer 
        SampleRecord[i].sampling_interval=interval;  //Sampling interval set by command above,SampleRecord in no use if set to zero
        SampleRecord[i].param =0;
        if(SampleRecord[i].channelType == DIGITAL ) 
          { 
            setparam_digital(i,param);
            if( param & EVENT ) 
              {              
                SampleRecord[i].param = make_channel_event_driven(SampleRecord[i].param);  //mark it as it is event based
              }
          }
        if(SampleRecord[i].channelType == COUNTER ) 
          {
            setparam_counter(i,param);
            if( param & EVENT )
              {
                SampleRecord[i].param = make_channel_event_driven(SampleRecord[i].param);  //mark it as it is event based
              }
          }
        if(SampleRecord[i].channelType == ANALOG ) 
          {
            setparam_analog(i,param);
          }
        number_of_available_records--;
        return i+SAMPLER_OFFSET;  //outside world Sampler ID starts from 1            
      }
    
    command result_t Sample.reTask(int8_t record,uint16_t interval)
      {
        record = record - SAMPLER_OFFSET;
        if(record<0 || record>MAX_SAMPLERECORD) return FAIL;
        SampleRecord[record].sampling_interval=interval;
        return SUCCESS;
      }
    
    command result_t Sample.stop(int8_t record)
      {
        record = record - SAMPLER_OFFSET;
        if(record<0 || record>MAX_SAMPLERECORD) return FAIL;
        if(SampleRecord[record].sampling_interval!= SAMPLE_RECORD_FREE)
          {
            number_of_available_records++;   //we only increse if they have not stopped a record which was available already
          }
        SampleRecord[record].sampling_interval= SAMPLE_RECORD_FREE;
        SampleRecord[record].channel=NOT_USED;
        SampleRecord[record].channelType=NOT_USED;
        return SUCCESS;
      }
    
    command uint8_t Sample.availableSamplingRecords()
      {
        return number_of_available_records;
      }
    
    /**************************************Result of the Events of Different Sensors********************************************/   
    //getting the sampler ID to pass it to upper layer as a unique primery key of underlying sampling process
    int8_t getID(uint8_t chnnelType,uint8_t channel) {
      int8_t i;
      /*If channel is synchronously active (called)*/
      for(i=0;i<MAX_SAMPLERECORD;i++)
        {
          if(SampleRecord[i].channel==channel && SampleRecord[i].channelType==chnnelType)
            {
            if (is_record_turn_active(SampleRecord[i].param)==SUCCESS) 
              { 
                SampleRecord[i].param = deactivate_record_turn(SampleRecord[i].param); 
                return i+SAMPLER_OFFSET; 
              } //return if synchronous
            else if(is_channel_event_driven(SampleRecord[i].param)==SUCCESS)
              {
                return i+SAMPLER_OFFSET;                                                                       //else return if async
              }
            }
        }
      //channel is not an active sampling process so send fail
      stddbg("channel type = %d, channel = %d ", chnnelType, channel);
      return SAMPLER_ERROR;
    }
    
    //analog channels
    event result_t ADC0.dataReady(uint16_t data)
      { 
        int8_t i;
        while( 1 )
          {
            i = getID(ANALOG,0);
            if( i == SAMPLER_ERROR )
              {
                break;
              }
            if(data != ADC_ERROR)
              {
                signal Sample.dataReady(i,0,ANALOG,data);
              }
          }
        return SUCCESS;
      }

    event result_t ADC1.dataReady(uint16_t data)
      { 
        int8_t i;
        while( 1 )
          {
            i = getID(ANALOG,1);
            if( i == SAMPLER_ERROR )
              {
                break;
              }
            if(data != ADC_ERROR)
              {
                signal Sample.dataReady(i,1,ANALOG,data);
              }
          }
        return SUCCESS;
      }
    event result_t ADC2.dataReady(uint16_t data)
      { 
        int8_t i;
        while( 1 )
          {
            i = getID(ANALOG,2);
            if( i == SAMPLER_ERROR )
              {
                break;
              }
            if(data != ADC_ERROR)
              {
                signal Sample.dataReady(i,2,ANALOG,data);
              }
          }
        return SUCCESS;
      }
    event result_t ADC3.dataReady(uint16_t data)
      { 
        int8_t i;
        while( 1 )
          {
            i = getID(ANALOG,3);
            if( i == SAMPLER_ERROR )
              {
                break;
              }
            if(data != ADC_ERROR)
              {
                signal Sample.dataReady(i,3,ANALOG,data);
              }
          }
        return SUCCESS;
      }
    event result_t ADC4.dataReady(uint16_t data)
      { 
        int8_t i;
        while( 1 )
          {
            i = getID(ANALOG,4);
            if( i == SAMPLER_ERROR )
              {
                break;
              }
            if(data != ADC_ERROR)
              {
                signal Sample.dataReady(i,4,ANALOG,data);
              }
          }
        return SUCCESS;
      }
    event result_t ADC5.dataReady(uint16_t data)
      { 
        int8_t i;
        while( 1 )
          {
            i = getID(ANALOG,5);
            if( i == SAMPLER_ERROR )
              {
                break;
              }
            if(data != ADC_ERROR)
              {
                signal Sample.dataReady(i,5,ANALOG,data);
              }
          }
        return SUCCESS;
      }
    event result_t ADC6.dataReady(uint16_t data)
      { 
        int8_t i;
        while( 1 )
          {
            i = getID(ANALOG,6);
            if( i == SAMPLER_ERROR )
              {
                break;
              }
            if(data != ADC_ERROR)
              {
                signal Sample.dataReady(i,6,ANALOG,data);
              }
          }
        return SUCCESS;
      }
    event result_t ADC7.dataReady(uint16_t data)
      { 
        int8_t i;
        while( 1 )
          {
            i = getID(ANALOG,7);
            if( i == SAMPLER_ERROR )
              {
                break;
              }
            if(data != ADC_ERROR)
              {
                signal Sample.dataReady(i,7,ANALOG,data);
              }
          }
        return SUCCESS;
      }
    event result_t ADC8.dataReady(uint16_t data)
      { 
        int8_t i;
        while( 1 )
          {
            i = getID(ANALOG,8);
            if( i == SAMPLER_ERROR )
              {
                break;
              }
            if(data != ADC_ERROR)
              {
                signal Sample.dataReady(i,8,ANALOG,data);
              }
          }
        return SUCCESS;
      }

    event result_t ADC9.dataReady(uint16_t data)
      { 
        int8_t i;
        while( 1 )
          {
            i = getID(ANALOG,9);
            if( i == SAMPLER_ERROR )
              {
                break;
              }
            if(data != ADC_ERROR)
              {
                signal Sample.dataReady(i,9,ANALOG,data);
              }
          }
        return SUCCESS;
      }
    event result_t ADC10.dataReady(uint16_t data)
      { 
        int8_t i;
        while( 1 )
          {
            i = getID(ANALOG,10);
            if( i == SAMPLER_ERROR )
              {
                break;
              }
            if(data != ADC_ERROR)
              {
                signal Sample.dataReady(i,10,ANALOG,data);
              }
          }
        return SUCCESS;
      }
    event result_t ADC11.dataReady(uint16_t data)
      { 
        int8_t i;
        while( 1 )
          {
            i = getID(ANALOG,11);
            if( i == SAMPLER_ERROR )
              {
                break;
              }
            if(data != ADC_ERROR)
              {
                signal Sample.dataReady(i,11,ANALOG,data);
              }
          }
        return SUCCESS;
      }
    event result_t ADC12.dataReady(uint16_t data)
      { 
        int8_t i;
        while( 1 )
          {
            i = getID(ANALOG,12);
            if( i == SAMPLER_ERROR )
              {
                break;
              }
            if(data != ADC_ERROR)
              {
                signal Sample.dataReady(i,12,ANALOG,data);
              }
          }
        return SUCCESS;
      }

    event result_t ADC13.dataReady(uint16_t data)
      { 
        int8_t i;
        while( 1 )
          {
            i = getID(ANALOG,13);
            if( i == SAMPLER_ERROR )
              {
                break;
              }
            if(data != ADC_ERROR)
              {
                signal Sample.dataReady(i,13,ANALOG,data);
              }
          }
        return SUCCESS;
      }

    /*
    event result_t ADC0.dataReady(uint16_t data) { int8_t i=getID(ANALOG,0); if(data != ADC_ERROR) signal Sample.dataReady(i,0,ANALOG,data);  return SUCCESS; }
    event result_t ADC1.dataReady(uint16_t data) { int8_t i=getID(ANALOG,1); if(data != ADC_ERROR) signal Sample.dataReady(i,1,ANALOG,data);  return SUCCESS; }
    event result_t ADC2.dataReady(uint16_t data) { int8_t i=getID(ANALOG,2); if(data != ADC_ERROR) signal Sample.dataReady(i,2,ANALOG,data);  return SUCCESS; }
    event result_t ADC3.dataReady(uint16_t data) { int8_t i=getID(ANALOG,3); if(data != ADC_ERROR) signal Sample.dataReady(i,3,ANALOG,data);  return SUCCESS; }
    event result_t ADC4.dataReady(uint16_t data) { int8_t i=getID(ANALOG,4); if(data != ADC_ERROR) signal Sample.dataReady(i,4,ANALOG,data);  return SUCCESS; }
    event result_t ADC5.dataReady(uint16_t data) { int8_t i=getID(ANALOG,5); if(data != ADC_ERROR) signal Sample.dataReady(i,5,ANALOG,data);  return SUCCESS; }
    event result_t ADC6.dataReady(uint16_t data) { int8_t i=getID(ANALOG,6); if(data != ADC_ERROR) signal Sample.dataReady(i,6,ANALOG,data);  return SUCCESS; }
    event result_t ADC7.dataReady(uint16_t data) { int8_t i=getID(ANALOG,7); if(data != ADC_ERROR) signal Sample.dataReady(i,7,ANALOG,data);  return SUCCESS; }
    event result_t ADC8.dataReady(uint16_t data) { int8_t i=getID(ANALOG,8); if(data != ADC_ERROR) signal Sample.dataReady(i,8,ANALOG,data);  return SUCCESS; }
    event result_t ADC9.dataReady(uint16_t data) { int8_t i=getID(ANALOG,9); if(data != ADC_ERROR) signal Sample.dataReady(i,9,ANALOG,data);  return SUCCESS; }
    event result_t ADC10.dataReady(uint16_t data){ int8_t i=getID(ANALOG,10); if(data != ADC_ERROR) signal Sample.dataReady(i,10,ANALOG,data); return SUCCESS; }
    event result_t ADC11.dataReady(uint16_t data){ int8_t i=getID(ANALOG,11); if(data != ADC_ERROR) signal Sample.dataReady(i,11,ANALOG,data); return SUCCESS; }
    event result_t ADC12.dataReady(uint16_t data){ int8_t i=getID(ANALOG,12); if(data != ADC_ERROR) signal Sample.dataReady(i,12,ANALOG,data); return SUCCESS; }
    event result_t ADC13.dataReady(uint16_t data){ int8_t i=getID(ANALOG,13); if(data != ADC_ERROR) signal Sample.dataReady(i,13,ANALOG,data); return SUCCESS; }
    */


    //miscelanous channels
    event result_t Battery.dataReady(uint16_t data)
      { 
        int8_t i;
        while( 1 )
          {
            i = getID(BATTERY,0);
            if( i == SAMPLER_ERROR )
              {
                break;
              }
            if(data != ADC_ERROR)
              {
                signal Sample.dataReady(i,0,BATTERY,data);
              }
          }
        return SUCCESS;
      }

    event result_t Temp.dataReady(uint16_t data)
      { 
        int8_t i;
        while( 1 )
          {
            i = getID(TEMPERATURE,0);
            if( i == SAMPLER_ERROR )
              {
                break;
              }
            if(data != ADC_ERROR)
              {
                signal Sample.dataReady(i,0,TEMPERATURE,data);
              }
          }
        return SUCCESS;
      }

    event result_t Hum.dataReady(uint16_t data)
      { 
        int8_t i;
        while( 1 )
          {
            i = getID(HUMIDITY,0);
            if( i == SAMPLER_ERROR )
              {
                break;
              }
            if(data != ADC_ERROR)
              {
                signal Sample.dataReady(i,0,HUMIDITY,data);
              }
          }
        return SUCCESS;
      }

    event result_t Counter.dataReady(uint16_t data)
      { 
        int8_t i;
        while( 1 )
          {
            i = getID(COUNTER,0);
            if( i == SAMPLER_ERROR )
              {
                break;
              }
            if(data != ADC_ERROR)
              {
                signal Sample.dataReady(i,0,COUNTER,data);
              }
          }
        return SUCCESS;
      }

    /*
    event result_t Battery.dataReady(uint16_t data) { int8_t i=getID(BATTERY,0);  signal Sample.dataReady(i,0,BATTERY,data); return SUCCESS; }
    event result_t Temp.dataReady(uint16_t data) { int8_t i=getID(TEMPERATURE,0); signal Sample.dataReady(i,0,TEMPERATURE,data); return SUCCESS; }
    event result_t Hum.dataReady(uint16_t data) { int8_t i=getID(HUMIDITY,0);     signal Sample.dataReady(i,0,HUMIDITY,data); return SUCCESS; }
    event result_t Counter.dataReady(uint16_t data) { int8_t i=getID(COUNTER,0);  signal Sample.dataReady(i,0,COUNTER,data); return SUCCESS; }
    */

    //digital channels
    event result_t Dio0.dataReady(uint16_t data)
      { 
        int8_t i;
        while( 1 )
          {
            i = getID(DIGITAL,0);
            if( i == SAMPLER_ERROR )
              {
                break;
              }
            if(data != ADC_ERROR)
              {
                signal Sample.dataReady(i,0,DIGITAL,data);
              }
          }
        return SUCCESS;
      }


    event result_t Dio1.dataReady(uint16_t data)
      { 
        int8_t i;
        while( 1 )
          {
            i = getID(DIGITAL,1);
            if( i == SAMPLER_ERROR )
              {
                break;
              }
            if(data != ADC_ERROR)
              {
                signal Sample.dataReady(i,1,DIGITAL,data);
              }
          }
        return SUCCESS;
      }


    event result_t Dio2.dataReady(uint16_t data)
      { 
        int8_t i;
        while( 1 )
          {
            i = getID(DIGITAL,2);
            if( i == SAMPLER_ERROR )
              {
                break;
              }
            if(data != ADC_ERROR)
              {
                signal Sample.dataReady(i,2,DIGITAL,data);
              }
          }
        return SUCCESS;
      }


    event result_t Dio3.dataReady(uint16_t data)
      { 
        int8_t i;
        while( 1 )
          {
            i = getID(DIGITAL,3);
            if( i == SAMPLER_ERROR )
              {
                break;
              }
            if(data != ADC_ERROR)
              {
                signal Sample.dataReady(i,3,DIGITAL,data);
              }
          }
        return SUCCESS;
      }


    event result_t Dio4.dataReady(uint16_t data)
      { 
        int8_t i;
        while( 1 )
          {
            i = getID(DIGITAL,4);
            if( i == SAMPLER_ERROR )
              {
                break;
              }
            if(data != ADC_ERROR)
              {
                signal Sample.dataReady(i,4,DIGITAL,data);
              }
          }
        return SUCCESS;
      }


    event result_t Dio5.dataReady(uint16_t data)
      { 
        int8_t i;
        while( 1 )
          {
            i = getID(DIGITAL,5);
            if( i == SAMPLER_ERROR )
              {
                break;
              }
            if(data != ADC_ERROR)
              {
                signal Sample.dataReady(i,5,DIGITAL,data);
              }
          }
        return SUCCESS;
      }


    /*
    event result_t Dio0.dataReady(uint16_t data) { int8_t i=getID(DIGITAL,0); signal Sample.dataReady(i,0,DIGITAL,data); return SUCCESS; }
    event result_t Dio1.dataReady(uint16_t data) { int8_t i=getID(DIGITAL,1); signal Sample.dataReady(i,1,DIGITAL,data); return SUCCESS; }
    event result_t Dio2.dataReady(uint16_t data) { int8_t i=getID(DIGITAL,2); signal Sample.dataReady(i,2,DIGITAL,data); return SUCCESS; }
    event result_t Dio3.dataReady(uint16_t data) { int8_t i=getID(DIGITAL,3); signal Sample.dataReady(i,3,DIGITAL,data); return SUCCESS; }
    event result_t Dio4.dataReady(uint16_t data) { int8_t i=getID(DIGITAL,4); signal Sample.dataReady(i,4,DIGITAL,data); return SUCCESS; }
    event result_t Dio5.dataReady(uint16_t data) { int8_t i=getID(DIGITAL,5); signal Sample.dataReady(i,5,DIGITAL,data); return SUCCESS; }
    */
    

    /********************************************Events that are not particularly handeled**************************************/
    event result_t Dio0.dataOverflow() { return SUCCESS; }
    event result_t Dio1.dataOverflow() { return SUCCESS; }
    event result_t Dio2.dataOverflow() { return SUCCESS; }
    event result_t Dio3.dataOverflow() { return SUCCESS; }
    event result_t Dio4.dataOverflow() { return SUCCESS; }
    event result_t Dio5.dataOverflow() { return SUCCESS; }
    event result_t Dio0.valueReady(bool data) { return SUCCESS; } 
    event result_t Dio1.valueReady(bool data) { return SUCCESS; }  
    event result_t Dio2.valueReady(bool data) { return SUCCESS; } 
    event result_t Dio3.valueReady(bool data) { return SUCCESS; } 
    event result_t Dio4.valueReady(bool data) { return SUCCESS; } 
    event result_t Dio5.valueReady(bool data) { return SUCCESS; } 
    event result_t Counter.dataOverflow() { return SUCCESS; }
    event result_t Counter.valueReady(bool data) { return SUCCESS; } 
    default event result_t Sample.dataReady(int8_t samplerID,uint8_t channel,uint8_t channelType,uint16_t data) { return SUCCESS; }

   /********************************************Automatic detection if the mda300ca present or not******************************/
    command result_t PlugPlay() { return call Plugged(); }
}
