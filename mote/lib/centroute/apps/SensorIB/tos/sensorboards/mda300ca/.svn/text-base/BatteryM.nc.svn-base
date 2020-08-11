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
 *
 * Note:This components return the battery voltage * 100 so u should have a resolution of
 * about 0.01V in the measurement.
 *
 * NOTE THAT JTAG SHOULD BE DISABLED FOR THIS COMPONENT TO WORK.
 * This is beacause of a hardware problem.U should get the laest version of uisp(u can get it
 * from tinyos website  and try to run
 * fuse_dis--->"uisp -dprog=dapa --wr_fuse_h=0xD9"
 * fuse_en --->"uisp -dprog=dapa --wr_fuse_h=0x19"
 */

module BatteryM {
  provides interface StdControl;
  provides interface ADConvert as Battery;
  uses {
    interface ADCControl;
    interface ADC;
  }
}

implementation {

  uint16_t rawVoltage;


#ifndef PLATFORM_EMSTAR

#define MAKE_BAT_MONITOR_OUTPUT() sbi(DDRA, 5)
#define MAKE_ADC_INPUT() cbi(DDRF, 5)
#define SET_BAT_MONITOR() sbi(PORTA, 5)
#define CLEAR_BAT_MONITOR() cbi(PORTA, 5)
  
#else
// NOOP the macros

#define MAKE_BAT_MONITOR_OUTPUT() {}
#define MAKE_ADC_INPUT() {}
#define SET_BAT_MONITOR() {}
#define CLEAR_BAT_MONITOR() {}
  
#endif //PLATFORM_EMSTAR

void delay() {
    asm volatile  ("nop" ::);
    asm volatile  ("nop" ::);
    asm volatile  ("nop" ::);
    asm volatile  ("nop" ::);
}
    
  command result_t StdControl.init() {
      MAKE_BAT_MONITOR_OUTPUT();
      MAKE_ADC_INPUT();
      call ADCControl.bindPort(BATTERY_PORT,BATTERY_PORT);
    return call ADCControl.init();
  }
  command result_t StdControl.start() {
    return SUCCESS;
  }

  command result_t StdControl.stop() {
      return SUCCESS;
  }

command result_t Battery.getData(){
      //MAKE_ADC_INPUT();
      SET_BAT_MONITOR();      
      delay();
      return call ADC.getData();
  }
    
command result_t Battery.getContinuousData(){
      return call ADC.getContinuousData();     
  }
  
default event result_t Battery.dataReady(uint16_t data) {
      return SUCCESS;
  }

 task void sendVoltage()
   {
     /*Floating point calculation better inside a task*/
     uint16_t myVoltage;
     atomic { myVoltage=rawVoltage; }
     signal Battery.dataReady((uint16_t)(125440L / myVoltage));
   }
async event result_t ADC.dataReady(uint16_t data){
  CLEAR_BAT_MONITOR();  
  atomic {rawVoltage=data;}
  post sendVoltage();
  return SUCCESS;
   }

}
