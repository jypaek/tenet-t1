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
  uses interface I2CPacketMaster;
  uses interface Leds;
  uses interface StdControl as I2CStdControl;
  uses interface Timer as TimeoutTimer;
  uses interface Timer as PowerStabalizingTimer;
  uses interface StdControl as SwitchControl;
  uses interface Switch;
}
implementation
{
  enum {IDLE, PICK_CHANNEL, GET_SAMPLE, CONTINUE_SAMPLE , START_CONVERSION_PROCESS};
  
#define VOLTAGE_STABLE_TIME 200           //Time it takes for the supply voltage to be stable enough
#define TIMEOUT_TIME (VOLTAGE_STABLE_TIME + 5000)  // Time to timeout a reading
#define MAX_ANALOG_CHNNELS 13
#define MAX_CHANNELS MAX_ANALOG_CHNNELS + 1 //The last channel is not an analog channel but we keep it only for the sake of exciation.


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

    // I2C buffer
    char i2c_buf[10];

    //set of bitwise functions
#define  testbit(var, bit)   ((var) & (1 <<(bit)))      //if zero then return zero and if one not equal zero
#define  setbit(var, bit)    ((var) |= (1 << (bit)))
#define  clrbit(var, bit)    ((var) &= ~(1 << (bit)))
    
    
  //The excitation circuits
#define FIVE_VOLT_ON() TOSH_SET_PW5_PIN()
#define FIVE_VOLT_OFF() TOSH_CLR_PW5_PIN()
    
#define THREE_VOLT_ON()  TOSH_SET_PW3_PIN()
#define THREE_VOLT_OFF() TOSH_CLR_PW3_PIN()

#define TURN_VOLTAGE_BUFFER_ON() TOSH_SET_PW2_PIN()
#define TURN_VOLTAGE_BUFFER_OFF() TOSH_CLR_PW2_PIN()

#define VOLTAGE_BOOSTER_ON() TOSH_CLR_PW1_PIN()
#define VOLTAGE_BOOSTER_OFF() TOSH_SET_PW1_PIN()

  //The instrumentation amplifier
#define TURN_AMPLIFIERS_ON() TOSH_SET_PW6_PIN()
#define TURN_AMPLIFIERS_OFF() TOSH_CLR_PW6_PIN()

    /*declareation of function convert*/
    result_t convert();

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
        
        // Turn off the time out timer as the conversion finished.
        call TimeoutTimer.stop();
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
    
/*
 * Through various experiments, we found that various voltage and other
 * stuff can cause one or more of the callback functions to never be called,
 * and hence get the ADC stuck in a bad state.  While a perfect solution would
 * be to add timeouts to various parts of this code, for now I have just shoved
 * in a manual reset interface.  This was written to be called by the dse command
 * parser.  Note: If this is called during a current measurement reading, that
 * reading will be lost!
 */
command result_t ADCReset.reset() {
  // Return the ADC to an idle state.
  atomic {
    state      = IDLE;
    adc_bitmap = 0;
  }
  
  // Reinitialize the I2C module.
  call I2CStdControl.init();
  
  // Reset the pins to reflect the idle state.
  TOSH_MAKE_PW2_OUTPUT();
  TOSH_MAKE_PW4_OUTPUT();
  TOSH_MAKE_PW5_OUTPUT();
  TOSH_MAKE_PW6_OUTPUT();
  TURN_AMPLIFIERS_OFF();           
  VOLTAGE_BOOSTER_OFF();
  FIVE_VOLT_OFF();
  THREE_VOLT_OFF();
  TURN_VOLTAGE_BUFFER_OFF();
  resetExcitation();

  return SUCCESS;
}
 
command result_t StdControl.init() {
  int i;
  atomic{
    state = IDLE;
    adc_bitmap=0;
    for(i=0; i < MAX_CHANNELS ; i++) param[i]=0x00;
  }
  call I2CStdControl.init();
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

 task void adc_get_data()
   {
     uint8_t myIndex;
     uint8_t count;
     uint16_t my_bitmap;
     if(state != IDLE) return; //That means the component is busy in a conversion process.When conversion done either successfull or
                               //fail it is gauranteed that this task will be posted so we can safely return.     
     value=0;    
     state=START_CONVERSION_PROCESS; 

     // Now that the conversion process has started, we can start a timeout
     // ..timer controlling this process.  If it has taken too long, we will
     // ..reset the state back to IDLE.
     call TimeoutTimer.start(TIMER_ONE_SHOT, TIMEOUT_TIME);

     atomic { my_bitmap = adc_bitmap; }
     //it gaurantees a round robin fair scheduling of ADC conversions.
     count=0;
     myIndex=chan+1;
     if(myIndex > MAX_ANALOG_CHNNELS) myIndex=0;
     while(!testbit(my_bitmap,myIndex))
       {
         myIndex++;
         if(myIndex > MAX_ANALOG_CHNNELS) myIndex=0;
         count++;
         if(count > MAX_ANALOG_CHNNELS) {state=IDLE; return; }   //no one waiting for conversion
       }

     chan=myIndex;
 
     setExcitation();
     setNumberOfConversions();
     //if among the instrumentation channels we set the MUX     
     if(chan == 7 || chan==8 || chan==9 || chan==10) 
       {
         char muxChannel;
         TURN_AMPLIFIERS_ON();              
         switch (chan) {
         default:			// should never happen
         case 7:
           muxChannel = MUX_CHANNEL_SEVEN;
           break;
         case 8:
           muxChannel = MUX_CHANNEL_EIGHT;
           break;
         case 9:
           muxChannel = MUX_CHANNEL_NINE;
           break;
         case 10:
           muxChannel = MUX_CHANNEL_TEN;
           break;
         };                 
         if ((call Switch.setAll(muxChannel)) == FAIL)
           {     
             // Can not select channel
             state = IDLE;
             TURN_AMPLIFIERS_OFF(); 
             post adc_get_data();
             resetExcitation();
           }
       }
     else {
       //If the conversions happens fast there is no need to
       //wait for settling of the power supply,note that power supply should be set ON by user using the excitation command
       if(param[chan] & DELAY_BEFORE_MEASUREMENT) {
         call PowerStabalizingTimer.start(TIMER_ONE_SHOT, VOLTAGE_STABLE_TIME);
       }
       else {
         convert();
       }
     }
   }
 
result_t convert() {
   if (state == START_CONVERSION_PROCESS || state == CONTINUE_SAMPLE)
     {
       state = PICK_CHANNEL;
       // figure out which channel is to be set
       switch (chan) {
       default:			// should never happen
       case 0:
         condition = 8;
         break;
       case 1:
         condition = 12;
         break;
       case 2:
         condition = 9;
         break;
       case 3:
         condition = 13;
         break;
       case 4:
         condition = 10;
         break;
       case 5:
         condition = 14;
         break;
       case 6:
         condition = 11;
         break;
       case 7:
       case 8:
       case 9:
       case 10:
         //these channels all use ADC channel 7 and multiplex it.
         condition = 15;
         break;
       case 11:
         condition = 0;
         break;
       case 12:
         condition = 1;
         break;
       case 13:
         condition = 2;
         break;
       }
     }
   // shift the channel and single-ended input bits over
   condition = (condition << 4) & 0xf0;
   condition = condition | 0x0f;
   //tell the ADC to start converting
   if ((call I2CPacketMaster.writePacket(1, (char*)(&condition))) == FAIL)
     {
       state = IDLE;
       post adc_get_data();
       resetExcitation();
       return FALSE;
     }
   TURN_AMPLIFIERS_OFF(); // NR This was after return SUCCESS!
   return SUCCESS;
   }
            
// get a single reading from id we
command result_t ADConvert.getData[uint8_t id]() {      
  if(id>13) return FAIL;  //should never happen unless wiring is wrong.
  atomic {
    setbit(adc_bitmap,id);
  }
  post adc_get_data();
  return SUCCESS;
}
 
  // Timeout timer called, reset the module.
  event result_t TimeoutTimer.fired() {
      call Leds.redOn();
      return SUCCESS;
      //return (call ADCReset.reset());
  }

//Setting the MUX has been done.
 event result_t Switch.setAllDone(bool r) 
   {
     if(!r) {
       state=IDLE;
       TURN_AMPLIFIERS_OFF(); 
       post adc_get_data();
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
       return convert();
     }          
     return SUCCESS;
   }
 
 
 
 event result_t PowerStabalizingTimer.fired() {      
   return convert();
 }
 
 /* not yet implemented */
 command result_t ADConvert.getContinuousData[uint8_t id]() {
   return FAIL;
 }
 
 event result_t I2CPacketMaster.readPacketDone(char length, char* data) {
   if (length != 2)
     {
       state = IDLE;
       TURN_AMPLIFIERS_OFF();
       atomic { clrbit(adc_bitmap,chan); }
       post adc_get_data();
       signal ADConvert.dataReady[chan](ADC_ERROR);
       resetExcitation();

       call Leds.redOn();
       
       return SUCCESS;
     }
   
   if (state == GET_SAMPLE)
     {
       value += (data[1] & 0xff) + ((data[0] << 8) & 0x0f00);
       conversionNumber--;
       //value = (data[0] << 8) & 0x0f00;
       //value += (data[1] & 0xff);        
       if (conversionNumber==0) {
         state = IDLE;
         if(param[chan] & AVERAGE_SIXTEEN)
           value = ((value+8) >>4) & 0x0fff;  //the addition is for more percision 
         else if(param[chan] &  AVERAGE_EIGHT )
           value = ((value+4) >>3) & 0x0fff;  //the addition is for more percision 
         else if(param[chan] &  AVERAGE_FOUR ) 
           value = ((value+2) >>2) & 0x0fff;   //the addition is for more percision 
         // else { //do nothing since no averaging}
         TURN_AMPLIFIERS_OFF();
         atomic { clrbit(adc_bitmap,chan); }
         post adc_get_data();
         signal ADConvert.dataReady[chan](value);
         resetExcitation();
       }
       else {
         state = CONTINUE_SAMPLE;
         convert();
       }
     }
   return SUCCESS;
 }
 
 event result_t I2CPacketMaster.writePacketDone(bool result) {
   if (!result)
     {
       state = IDLE;
       TURN_AMPLIFIERS_OFF();
       atomic { clrbit(adc_bitmap,chan); }
       post adc_get_data();
       signal ADConvert.dataReady[chan](ADC_ERROR);
       resetExcitation();
       return FAIL;
     }
   
   if (state == PICK_CHANNEL)
     {
       state = GET_SAMPLE;
       if ((call I2CPacketMaster.readPacket(2, i2c_buf, DEFAULT)) == 0)
         {
           //reading from the bus failed
           state = IDLE;
           post adc_get_data();
           resetExcitation();
           return FAIL;
         }
     }
   return SUCCESS;            
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
