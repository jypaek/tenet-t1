/* ex: set tabstop=8 expandtab shiftwidth=2 softtabstop=2: */

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
 *
 *
 * driver for ADS7828EB on mda300ca
 *
 */

includes tos_emstar;

module IBADCM
{
  provides {
    interface StdControl;
    interface ADConvert[uint8_t port];
    interface SetParam[uint8_t port];
    interface Power as EXCITATION25;
    interface Power as EXCITATION33;
    interface Power as EXCITATION50;
    interface ADCReset;
  }
  uses interface Leds;
#ifdef EMSTAR_NO_KERNEL
  uses interface EmTimerI as PowerStabalizingTimer;
#else
  uses interface Timer as PowerStabalizingTimer;
#endif
  uses interface StdControl as SwitchControl;
  uses interface Switch;
}
implementation
{
#include "sensorboard.h"
  enum {IDLE, PICK_CHANNEL, GET_SAMPLE, CONTINUE_SAMPLE , START_CONVERSION_PROCESS};
  
#define VOLTAGE_STABLE_TIME 200  
//Time it takes for the supply voltage to be stable enough
#define MAX_ANALOG_CHNNELS 13
#define MAX_CHANNELS MAX_ANALOG_CHNNELS + 1 
//The last channel is not an analog channel but we keep it only for the sake of exciation.


    /*Note:we do not do anything inside async part so all parts are synchronous and
      there is no synchronization hazard.Now ADC runs in the round-robin fashin so it
      is fair.*/
    
    char state;       /* current state of the i2c request */
    uint16_t value;   /* value of the incoming ADC reading */
    uint8_t chan;
    uint8_t param[MAX_CHANNELS];  /*we reserve last param for excitation of digital channels*/
    uint16_t adc_bitmap;
    int8_t conversionNumber;
    //Note "condition" should be a global variable.Since It is passed by address to I2CPacketM.nc and so
    //should be valid even out of the scope of that function since I2CPacketM.nc uses it by its address.
    uint8_t condition;   // set the condition command byte.

typedef struct _private_data {
    uint8_t recvPort;
    uint16_t recvData;
} private_data_t;

    
    //set of bitwise functions
#define  testbit(var, bit)   ((var) & (1 <<(bit)))      //if zero then return zero and if one not equal zero
#define  setbit(var, bit)    ((var) |= (1 << (bit)))
#define  clrbit(var, bit)    ((var) &= ~(1 << (bit)))
    
    
  //The excitation circuits
#define FIVE_VOLT_ON() {}
#define FIVE_VOLT_OFF() {}
    
#define THREE_VOLT_ON()  {}
#define THREE_VOLT_OFF() {}

#define TURN_VOLTAGE_BUFFER_ON() {}
#define TURN_VOLTAGE_BUFFER_OFF() {}

#define VOLTAGE_BOOSTER_ON() {}
#define VOLTAGE_BOOSTER_OFF() {}

  //The instrumentation amplifier
#define TURN_AMPLIFIERS_ON() {}
#define TURN_AMPLIFIERS_OFF() {}

 
    void setExcitation()
      {
        if(param[chan] & EXCITATION_25 ) TURN_VOLTAGE_BUFFER_ON();
        if(param[chan] & EXCITATION_33 ) 
          {
            VOLTAGE_BOOSTER_ON();
            THREE_VOLT_ON();
          }
        if(param[chan] & EXCITATION_50)
          {
            VOLTAGE_BOOSTER_ON();
            FIVE_VOLT_ON();
          }
      }
    
    void resetExcitation()
      {    
        uint8_t i;
        uint8_t flag25=0,flag33=0,flag50=0;
        for(i=0 ; i < MAX_CHANNELS ;i++) 
          {
            if(param[i] & EXCITATION_ALWAYS_ON)
              {
                if(param[i] & EXCITATION_25) flag25=1;
                if(param[i] & EXCITATION_33) flag33=1;
                if(param[i] & EXCITATION_50) flag50=1;
              }
          }
        if(flag25==0) TURN_VOLTAGE_BUFFER_OFF();
        if(flag33==0) THREE_VOLT_OFF();
        if(flag50==0) FIVE_VOLT_OFF();
        if((flag33==0) & (flag50==0)) VOLTAGE_BOOSTER_OFF();
      }
    
    command void EXCITATION25.on()
      {
        param[MAX_CHANNELS - 1] |= EXCITATION_25;
        param[MAX_CHANNELS - 1] |= EXCITATION_ALWAYS_ON;
        TURN_VOLTAGE_BUFFER_ON();
      }
    command void EXCITATION25.off()
      {
        param[MAX_CHANNELS - 1] &= !EXCITATION_25;
        if(state == IDLE) resetExcitation();  //otherwise the fuction will be called at the end of conversion
      }
    command void EXCITATION33.on()
      {
        param[MAX_CHANNELS - 1] |= EXCITATION_33;
        param[MAX_CHANNELS - 1] |= EXCITATION_ALWAYS_ON;
        VOLTAGE_BOOSTER_ON();
        THREE_VOLT_ON();
      }
    command void EXCITATION33.off()
      {
        param[MAX_CHANNELS - 1] &= !EXCITATION_33;
        if(state == IDLE) resetExcitation();  //otherwise the fuction will be called at the end of conversion
      }
    command void EXCITATION50.on()
      {
        param[MAX_CHANNELS - 1] |= EXCITATION_50;
        param[MAX_CHANNELS - 1] |= EXCITATION_ALWAYS_ON;
        VOLTAGE_BOOSTER_ON();
        FIVE_VOLT_ON();
      }
    command void EXCITATION50.off()
      {
        param[MAX_CHANNELS-1] &= !EXCITATION_50;
        if(state == IDLE) resetExcitation();  //otherwise the fuction will be called at the end of conversion
      }

    void setNumberOfConversions()
      {
        conversionNumber = 1;
        if(param[chan] &  AVERAGE_FOUR ) conversionNumber = 4;
        if(param[chan] &  AVERAGE_EIGHT ) conversionNumber = 8;
        if(param[chan] & AVERAGE_SIXTEEN) conversionNumber = 16;
        return;
      }

void dataReady()
{
  private_data_t *priv;
  priv = (private_data_t *)emtos_get_task_data();

  if (priv!=NULL) {
    signal ADConvert.dataReady[priv->recvPort](priv->recvData);
    free(priv);
  }
}
    


void AdcDataReady(uint8_t port, uint16_t data)
{
  private_data_t *priv;

  priv=malloc(sizeof(private_data_t));

  if (priv==NULL) {
    printf("NULL pointer, malloc failed?");
    return;
  }
  
  priv->recvData=data;
  priv->recvPort=port;

  emtos_post_task(dataReady, (void *)priv);
}

/*
 * Reset the ADC devise if it becomes stuck in an unresponsive state.
 * Does nothing if compiled for emstar!
 */
command result_t ADCReset.reset() {
  return SUCCESS;
}
    
command result_t StdControl.init() {
  int i;

  // init emtos stuff
  fp_list_t *fplist=get_fplist();

  fplist->AdcDataReady=AdcDataReady;
  emtos_adc_init(fplist);
 


  atomic{
    state = IDLE;
    adc_bitmap=0;
    for(i=0; i < MAX_CHANNELS ; i++) {
      param[i]=0x00;
      // register all ports
      emtos_adc_register_port(i, ANALOG, NULL, NULL);
    }
  }
  call SwitchControl.init();
  TOSH_MAKE_PW2_OUTPUT();
  TOSH_MAKE_PW4_OUTPUT();
  TOSH_MAKE_PW5_OUTPUT();
  TOSH_MAKE_PW6_OUTPUT();
  TURN_AMPLIFIERS_OFF();           
  VOLTAGE_BOOSTER_OFF();
  FIVE_VOLT_OFF();
  THREE_VOLT_OFF();
  TURN_VOLTAGE_BUFFER_OFF();
  return SUCCESS;
}

 command result_t StdControl.start() {
   call SwitchControl.start();
   return SUCCESS;
 }
 
 command result_t StdControl.stop() {
   call SwitchControl.stop();
   return SUCCESS;
 }


command result_t SetParam.setParam[uint8_t id](uint8_t mode){
  param[id]=mode;
  return SUCCESS;
}


default event result_t ADConvert.dataReady[uint8_t id](uint16_t data) {
  return SUCCESS;
}  

            
// get a single reading from id we
command result_t ADConvert.getData[uint8_t id]() {      
  if(id>13) return FAIL;  //should never happen unless wiring is wrong.

  emtos_adc_get_data(id, ANALOG);


  return SUCCESS;
}



//Setting the MUX has been done.
 event result_t Switch.setAllDone(bool r) 
   {
     if(!r) {
       state=IDLE;
       TURN_AMPLIFIERS_OFF(); 
       //post adc_get_data();
       resetExcitation();
       return FAIL;
     }
     
     //If the conversions happens fast there is no need to
     //wait for settling of the power supply,note that power supply should be set ON by user using the excitation command
     if(param[chan] & DELAY_BEFORE_MEASUREMENT) {
       call PowerStabalizingTimer.start(TIMER_ONE_SHOT, VOLTAGE_STABLE_TIME);
       return SUCCESS;
     }
     else {
       return SUCCESS;
     }          
     return SUCCESS;
   }
 
 
 
 event result_t PowerStabalizingTimer.fired() {      
   return SUCCESS;
 }
 
 /* not yet implemented */
 command result_t ADConvert.getContinuousData[uint8_t id]() {
   return FAIL;
 }
 
 
 
  event result_t Switch.getDone(char val) 
    {
      return SUCCESS;
    }
  
  event result_t Switch.setDone(bool r) 
    {
      return SUCCESS;
    }
  
}
