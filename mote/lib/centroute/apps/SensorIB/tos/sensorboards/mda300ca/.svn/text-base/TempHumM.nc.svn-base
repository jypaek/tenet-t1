
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
 * History:   created @ 01/14/2003 
 * Last Modified:     @ 11/14/2003
 * 
 * driver for sensirion temperature and humidity sensor 
 *
 */

module TempHumM {
  provides {
    interface StdControl;
    interface ADConvert as TempSensor;
    interface ADConvert as HumSensor;
  }
  uses {
    interface Leds;
  }
}
implementation {

  //states
  enum { IDLE, TEMP_MEASUREMENT, HUM_MEASUREMENT };

  //Temprature Conversion semantics
#define FAHRENHEIT 0
#define KELVIN 1

  //flags
#define TEMP_PENDING 0x01
#define HUM_PENDING 0x02

//Interrupt definition.It is INT3 in sch which is INT7 of MCU! 
#define INT_ENABLE()  sbi(EIMSK , 7)
#define INT_DISABLE() cbi(EIMSK , 7)

//#define delay() asm volatile  ("nop" ::)
/*
#define SET_CLOCK() sbi(PORTC, 3)
#define CLEAR_CLOCK() cbi(PORTC, 3)
#define SET_DATA() sbi(PORTD, 3)
#define CLEAR_DATA() cbi(PORTD, 3)
#define MAKE_DATA_OUTPUT() sbi(DDRD, 3)
#define MAKE_DATA_INPUT() cbi(DDRD, 3)
#define GET_DATA() (inp(PIND) >> 3) & 0x1
*/

//usese PW0 (PORTC,0) for Clock and INT3 (PORTE,7) for data.
#define SET_CLOCK() sbi(PORTC, 0)
#define CLEAR_CLOCK() cbi(PORTC, 0)
#define MAKE_CLOCK_OUTPUT() sbi(DDRC, 0)    
#define SET_DATA() sbi(PORTE, 7)
#define CLEAR_DATA() cbi(PORTE, 7)
#define MAKE_DATA_OUTPUT() sbi(DDRE, 7)
#define MAKE_DATA_INPUT() cbi(DDRE, 7)
#define GET_DATA() (inp(PINE) >> 7) & 0x1


void delay() {
    asm volatile  ("nop" ::);
    asm volatile  ("nop" ::);
    asm volatile  ("nop" ::);
}


//#define TEMP_COMMAND 0x1e
#define TEMP_COMMAND 0x03
#define HUM_COMMAND  0x05
#define SOFT_RESET   0x1e 
 
//#define TOS_FRAME_TYPE Sensor_frame
 char state;  //all states are changed inside tasks.
 float t=25;   //temprature value.we set temprature to 25.if sombody not reads temprature and 
               //reads humidity then by t=25 it means no temperature compensation  
 char pending_states;

static inline void clk(){
    delay();
    CLEAR_CLOCK();
    delay();
    SET_CLOCK();
}

static inline void  ack()
{
  MAKE_DATA_OUTPUT();
  CLEAR_DATA();
  delay();
  SET_CLOCK();
  delay();
  CLEAR_CLOCK();
  MAKE_DATA_INPUT();
}

static inline void initseq()
{ 
  MAKE_DATA_OUTPUT();
  SET_DATA();
  CLEAR_CLOCK();   
  delay();         
  SET_CLOCK();
  delay();
  CLEAR_DATA();
  delay();
  CLEAR_CLOCK();
  delay();
  SET_CLOCK();
  delay(); 
  SET_DATA();
  delay(); 
  CLEAR_CLOCK();
}

static inline void reset()
{
  int i;
  MAKE_DATA_OUTPUT();
  SET_DATA();
  CLEAR_CLOCK();
  for (i=0;i<9;i++) {
    SET_CLOCK();
    delay();
    CLEAR_CLOCK();
  }
}


static inline char processCommand(int cmd)
{
  int i;
  int CMD=cmd;
  cmd &= 0x1f;
  INT_DISABLE();
  reset();           
  initseq();        //sending the init sequence
  for(i=0;i<8;i++){
    if(cmd & 0x80) SET_DATA();
    else CLEAR_DATA();
    cmd = cmd << 1 ;
    SET_CLOCK();
    delay();              
    delay();              
    CLEAR_CLOCK();        
    
  }
  MAKE_DATA_INPUT();
  delay();
  SET_CLOCK();
  delay();
  if(GET_DATA()) 
    { 
      reset(); 
      return 0; 
    }
  delay();
  CLEAR_CLOCK();
  if( CMD==TEMP_COMMAND || CMD==HUM_COMMAND){
      INT_ENABLE();
  }
 return 1;
}

//char TOS_COMMAND(SENSOR_INIT)(){
command result_t StdControl.init() { 
    atomic { state=IDLE;  pending_states=0x0;}
    INT_DISABLE();
    MAKE_CLOCK_OUTPUT();
    reset();
    processCommand(SOFT_RESET);
    return SUCCESS;
}
command result_t StdControl.start() {
  return SUCCESS;
}

command result_t StdControl.stop() {
  return SUCCESS;
}


default event result_t TempSensor.dataReady(uint16_t tempData) 
{
    return SUCCESS;
}

default event result_t HumSensor.dataReady(uint16_t humData) 
{
    return SUCCESS;
}

// Start gathering temperature reading.
task void initiateTemperature() {
  if(state != IDLE) {
    pending_states |= TEMP_PENDING; 
    return;
  };
  state=TEMP_MEASUREMENT;
  processCommand(TEMP_COMMAND);
  return;
}

// Start gathering a humidity reading.
task void initiateHumidity() {
  if (state!= IDLE) {
    pending_states |= HUM_PENDING;
    return;
  };
  state = HUM_MEASUREMENT;
  processCommand(HUM_COMMAND);
  return;
}

task void readSensor()
{
  char i;
  char CRC=0;
  uint16_t data;
  uint16_t temp,hum;
  float h;   //humidity value.
  data=0; 
  for(i=0;i<8;i++){
    SET_CLOCK();   
    delay();
    data |= GET_DATA();
    data = data << 1;
    //    if(i!=7) data = data << 1;
    CLEAR_CLOCK();
 }
  ack();
  for(i=0;i<8;i++){
    SET_CLOCK();   
    delay();
    data |= GET_DATA();
    //    data = data << 1;
    if(i!=7) data = data << 1;  //the last byte of data should not be shifted
    CLEAR_CLOCK();
    
 }
  ack();
  for(i=0;i<8;i++){           //I am not cheching the checksum
    SET_CLOCK();   
    delay(); 
    CRC |= GET_DATA();
    if(i!=7)CRC = CRC << 1;
    CLEAR_CLOCK();
 }
  //ack with high as it should be for the CRC ack
  MAKE_DATA_OUTPUT();
  SET_DATA();          
  delay();
  SET_CLOCK();
  delay();
  CLEAR_CLOCK();
  if(state==TEMP_MEASUREMENT){
      temp=data;
      t= (((float)(temp) )*0.98-3840)/100;
      if(t > 100 ) temp=100;      //for centigrade    
      if(t < -15 ) temp=-15;      //for centigrade    

      //we convert to Fahrenheit or Kelvin to avoid negative values in transmition
#if FAHRENHEIT
      // Convert to Kelvin * 100 by adding the offset plus a small
      // increment that will give rounded results instead of truncated
      // results.
      temp = (uint16_t)( ( ((float)(data))*0.98-3840) + 27315 + 0.5);
#else
      // Fahrenheit
      temp = (uint16_t) (t * 180 + 3200);
#endif
      signal TempSensor.dataReady(temp);      
      if(pending_states & HUM_PENDING) { pending_states=0; post initiateHumidity();}
  }
  else if(state==HUM_MEASUREMENT) {
    hum=data;
    h= 0.0405 * (float) (hum) - 4 - (float)(hum) * (float)(hum)*0.0000028;
    h= (t-25) * (0.01 + 0.00128 * hum) + h;
    hum= (uint16_t) h;
    if(hum > 100 ) hum=100;
    if(hum < 0 ) hum=0;
    signal HumSensor.dataReady(hum);
    if(pending_states & TEMP_PENDING) {pending_states=0;  post initiateTemperature();}
  }
  state=IDLE;
}

#ifndef PLATFORM_EMSTAR
TOSH_SIGNAL(SIG_INTERRUPT7)
{
    INT_DISABLE();
    post readSensor();
    return;
 }
#endif


command result_t TempSensor.getData()
{
  if(!post initiateTemperature()) return FAIL;
  return SUCCESS;
}

command result_t HumSensor.getData()
{
  if(!post initiateHumidity()) return FAIL;
  return SUCCESS;
}


command result_t TempSensor.getContinuousData(){
  return FALSE;
}

command result_t HumSensor.getContinuousData(){
  return FALSE;
}

}
