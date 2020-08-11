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
 */

includes avr_eeprom;
includes sensorboard;

module SampleConfigTestM
{
  provides interface StdControl;
  uses {
    interface Leds;

    //Sampler Communication
    interface StdControl as SamplerControl;
    interface Sample;

    //RF communication
    interface StdControl as CommControl;
    interface SendMsg as SendMsg;
    interface ReceiveMsg as ReceiveMsg;

    //Timer
    interface Timer as TestStartTimer;
    interface Timer as TestStopTimer;
    interface Timer as TestConfigTimer;
    interface Timer as TestConfigQueryTimer;

    //Data Mapping
    interface StdControl as DataMapControl;
    interface DmAcceptMnAndTI;
    interface DmMappingI;
    interface DmUpdateTableI;

    //Configuration
    interface StdControl as ConfigControl;
    interface ChAcceptCmdI;

  }
}
implementation
{
#include "utility.h"

#define ANALOG_SAMPLING_TIME 50   //time in 0.1 sec
#define MISC_SAMPLING_TIME 70     //time in 0.1 sec
#define DIGITAL_SAMPLING_TIME 20  //time in 0.1 sec
#define REPEAT_SAMPLING_TIME 10   //time in 0.1 sec

#define START_TEST_TIME 5000   //time in millisecond
#define STOP_TEST_TIME 30000   //time in millisecond
#define EPROM_WRITE_TIME 30000 //time in millisecond
#define EPROM_QUERY_TIME 30000 //time in millisecond

    TOS_Msg msg1,msg2,msg3;		/* Message to be sent out */
    uint16_t msg1_status,msg2_status,msg3_status;
    char test;

    uint8_t bootflag;
    static uint8_t epromAddress __attribute__((section(".eeprom")));

/*****************************Initialization of underneath components**************/
    command result_t StdControl.init() {
        call Leds.init();
        call DataMapControl.init();
        call ConfigControl.init();
        msg1.data[0] = TOS_LOCAL_ADDRESS; //record your id in the packet.
        msg2.data[0] = TOS_LOCAL_ADDRESS; //record your id in the packet.
        msg3.data[0] = TOS_LOCAL_ADDRESS; //record your id in the packet.        
        atomic {
        msg1_status=0;
        msg2_status=0;
        msg3_status=0;
        bootflag = 00;
        }
        return rcombine(call DataMapControl.init(), call CommControl.init());              
    }
    
    command result_t StdControl.start() {
      call DataMapControl.start();
      call CommControl.start();
      call ConfigControl.start();

      /* This creats test records of measurement names*/
      fillup_records();  
      call TestStartTimer.start(TIMER_ONE_SHOT, START_TEST_TIME);
      return SUCCESS;
    }
    
    command result_t StdControl.stop() {
      call DataMapControl.stop();
      call DataMapControl.stop();
      return SUCCESS;
    }

/***************************************actual transmission of aquired data*******/
    task void send_data() 
      {
        if((msg1_status==0x3fff)){call Leds.redToggle(); msg1_status=0; call SendMsg.send(TOS_BCAST_ADDR, 29, &msg1); }
        else if((msg2_status==0x0f)){call Leds.greenToggle(); msg2_status=0; call SendMsg.send(TOS_BCAST_ADDR, 29, &msg2); }
        else if((msg3_status==0x3f)){call Leds.yellowToggle(); msg3_status=0; call SendMsg.send(TOS_BCAST_ADDR, 29, &msg3); }
      }

    event result_t SendMsg.sendDone(TOS_MsgPtr sent, result_t success) {
      post send_data();
      return SUCCESS;
    }
  
    
    event TOS_MsgPtr ReceiveMsg.receive(TOS_MsgPtr data) {
      return data;
    }
  
    event result_t Sample.dataReady(int8_t myRecord, uint8_t channel,uint8_t channelType,uint16_t data)
      {
        //return SamplerEventByChannel(channel,channelType,data);      //call through dataMap
        return SamplerEventByName(myRecord,data);                  //directly through sampler
        //return SamplerEventBySamplerID(myRecord,channel,channelType,data);
      }
    
    event result_t ChAcceptCmdI.acceptCmdDone(char *buf) {     
      if(buf[0]==ADC0_HARDWARE_ADDRESS & buf[1]==mnADC0)
        {
          call Leds.redOn();
          call Leds.greenOn();
          call Leds.yellowOn();
          }
      return SUCCESS;
    }  

/*****************************Various Tests Start at Various Timers*********/
    event result_t TestStartTimer.fired() 
      {
        /*This is for usual test. It should work usually for STOP_TEST_TIME peroide blinking 3 leds for 3 different packets and stop with all Leds on*/
        //call TestStopTimer.start(TIMER_ONE_SHOT,STOP_TEST_TIME);      
        
        /********************************************Data Map Update test**********************************/
        //either 1 or 2 or 3
        //1- through the configuration module
        // Only first time after programming call configuration after that it should run through eeprom if datamap start looking at eeprom
        
        bootflag = eeprom_read_byte(&epromAddress); 
        if( bootflag != 0x55) 
          {
            //call Leds.redOn();
            //call Leds.greenOn();
            //call Leds.yellowOn();
            run_config_test_function();  //fill up the configuration eeprom in first reboot. In later reboots it uploads from eeprom.      
            call TestConfigTimer.start(TIMER_ONE_SHOT,EPROM_WRITE_TIME); //we write a 0x55 flag in eeprom after sometime not to reun this code in next reboots.      
          }

        //call TestConfigQueryTimer.start(TIMER_ONE_SHOT,EPROM_QUERY_TIME); //we write a 0x55 flag in eeprom after sometime not to reun this code in next reboots.      
                    
        //2- through the configuration module each time
        //run_config_test_function();           //fill up the configuration eeprom in first reboot. In later reboots it uploads from eeprom.      
        //3- by directly updating data map
        //fillup_dataMap_directly_for_test(); //fill up directly the dataMap records, bypass config.      
        /********************************************End Data Map Update test*****************************/
        
        /********************************************Calling Channels Test**********************************/
        //1-throug measurement names if they are updated in previous test
        startByMeasurementName();            //call through dataMap
        //2-Calling directly by channel type and number if measurement names are not updated
        //startByChannel();                  //directly through sampler            
        //3-Calling same measurement name mutiple time to see if it can support multiple measurement names.
        //startSameMeasurementName();            //call through dataMap but same
        /********************************************End Calling Channels Test******************************/
        
        /*This is only for testin available Sampling record function NOTE: IT SHOULD BE COMMENTED OTHERWISE*/
        //test_DataMap_Remaining_SamplerID_Function();
        return SUCCESS;
      }

    event result_t TestStopTimer.fired() 
      {
        //This is for checking if we can stop DataMap records.
        stop_analog_measurement_records();
        stop_miscelanous_measurement_records();
        stop_digital_measurement_records();
        call Leds.redOn();
        call Leds.greenOn();
        call Leds.yellowOn();
        return SUCCESS;
      }

    event result_t TestConfigTimer.fired() 
      {
        //This is for eeprom test. Next time it should run from eeprom.
        bootflag = 0x55;
        //only for eeprom removal test
        run_config_erase_function();
        eeprom_write_byte(&epromAddress,bootflag);       
        return SUCCESS;
      }

    event result_t TestConfigQueryTimer.fired() 
      {
        //only for eeprom get function test
        run_config_get_function();
        return SUCCESS;
      }
    
/****************************************utility function**********************/  
result_t SamplerEventByName(int8_t myRecord,uint16_t data)
{
  uint8_t myName;
  myName=get_measurement_name(myRecord);
  
  switch (myName) {
  case mnADC0:
    msg1.data[0]=0x11;
    msg1.data[1]=0x11;                
    msg1.data[2]=data & 0xff;
    msg1.data[3]=(data >> 8) & 0xff;
    atomic {msg1_status|=0x01;}
    break;
  case mnADC1:
    msg1.data[4]=data & 0xff;
    msg1.data[5]=(data >> 8) & 0xff;
    atomic {msg1_status|=0x02;}
    break;
  case mnADC2:
    msg1.data[6]=data & 0xff;
    msg1.data[7]=(data >> 8) & 0xff;
    atomic {msg1_status|=0x04;}
    break;          
  case mnADC3:
    msg1.data[8]=data & 0xff;
    msg1.data[9]=(data >> 8) & 0xff;
    atomic {msg1_status|=0x08;}
    break;
  case mnADC4:
    msg1.data[10]=data & 0xff;
    msg1.data[11]=(data >> 8) & 0xff;
    atomic {msg1_status|=0x10;}
    break;
  case mnADC5:
    msg1.data[12]=data & 0xff;
    msg1.data[13]=(data >> 8) & 0xff;
    atomic {msg1_status|=0x20;}
    break;
  case mnADC6:
    msg1.data[14]=data & 0xff;
    msg1.data[15]=(data >> 8) & 0xff;
    atomic {msg1_status|=0x40;}
    break;
  case mnADC7:
    msg1.data[16]=data & 0xff;
    msg1.data[17]=(data >> 8) & 0xff;
    atomic {msg1_status|=0x80;}
    break;
  case mnADC8:
    msg1.data[18]=data & 0xff;
    msg1.data[19]=(data >> 8) & 0xff;
    atomic {msg1_status|=0x100;}
    break;
  case mnADC9:
    msg1.data[20]=data & 0xff;
    msg1.data[21]=(data >> 8) & 0xff;
    atomic {msg1_status|=0x200;}
    break;
  case mnADC10:
    msg1.data[22]=data & 0xff;
    msg1.data[23]=(data >> 8) & 0xff;
    atomic {msg1_status|=0x400;}
    break;
  case mnADC11:
    msg1.data[24]=data & 0xff;
    msg1.data[25]=(data >> 8) & 0xff;
    atomic {msg1_status|=0x800;}
    break;
  case mnADC12:
    msg1.data[26]=data & 0xff;
    msg1.data[27]=(data >> 8) & 0xff;
    atomic {msg1_status|=0x1000;}
    break;
  case mnADC13:
    msg1.data[28]=data & 0xff;
    msg1.data[29]=(data >> 8) & 0xff;
    atomic {msg1_status|=0x2000;}
    break;          
  case mnBATTEREY:           
    msg2.data[0]=0x22;
    msg2.data[1]=0x22;
    msg2.data[2]=data & 0xff;
    msg2.data[3]=(data >> 8) & 0xff;    
    atomic {msg2_status|=0x01;}
    break;
  case mnHUM:
    msg2.data[4]=data & 0xff;
    msg2.data[5]=(data >> 8) & 0xff;
    atomic {msg2_status|=0x02;}
    break;        
  case mnTEMP:            
    msg2.data[6]=data & 0xff;
    msg2.data[7]=(data >> 8) & 0xff;
    atomic {msg2_status|=0x04;}
    break;
  case mnCOUNTER:
    msg2.data[8]=data & 0xff;
    msg2.data[9]=(data >> 8) & 0xff;
    atomic {msg2_status|=0x08;}
    break;
  case mnDIG0:
    msg3.data[0]=0x33;
    msg3.data[1]=0x33;          
    msg3.data[2]=data & 0xff;
    msg3.data[3]=(data >> 8) & 0xff;
    atomic {msg3_status|=0x01;}
    break;
  case mnDIG1:
    msg3.data[4]=data & 0xff;
    msg3.data[5]=(data >> 8) & 0xff;
    atomic {msg3_status|=0x02;}
    break;
  case mnDIG2:
    msg3.data[6]=data & 0xff;
    msg3.data[7]=(data >> 8) & 0xff;
    atomic {msg3_status|=0x04;}
    break;
  case mnDIG3:
    msg3.data[8]=data & 0xff;
    msg3.data[9]=(data >> 8) & 0xff;
    atomic {msg3_status|=0x08;}
    break;
  case mnDIG4:
    msg3.data[10]=data & 0xff;
    msg3.data[11]=(data >> 8) & 0xff;
    atomic {msg3_status|=0x10;}
    break;
  case mnDIG5:
    msg3.data[12]=data & 0xff;
    msg3.data[13]=(data >> 8) & 0xff;
    atomic {msg3_status|=0x20;}
    break;
  case mnError:
    break;
  default:
    break;
  }
  atomic {
    if(msg1_status==0x3fff) { post send_data(); }
    else if(msg2_status==0x0f) {  post send_data(); }
    else if(msg3_status==0x3f) {  post send_data(); }
  }
  return SUCCESS;
}
 
/****************************************utility function**********************/  
 result_t SamplerEventByChannel(uint8_t channel,uint8_t channelType,uint16_t data)
   {
     if(channelType==ANALOG) {
       msg1.data[0]=0x11;
       msg1.data[1]=0x11;
       switch (channel) {
       case 0:
         msg1.data[2]=data & 0xff;
         msg1.data[3]=(data >> 8) & 0xff;
         atomic {msg1_status|=0x01;}
         break;
       case 1:   
         msg1.data[4]=data & 0xff;
         msg1.data[5]=(data >> 8) & 0xff;
         atomic {msg1_status|=0x02;}
         break;
       case 2:
         msg1.data[6]=data & 0xff;
         msg1.data[7]=(data >> 8) & 0xff;
         atomic {msg1_status|=0x04;}
         break;
       case 3:
         msg1.data[8]=data & 0xff;
         msg1.data[9]=(data >> 8) & 0xff;
         atomic {msg1_status|=0x08;}
         break;
       case 4:
         msg1.data[10]=data & 0xff;
         msg1.data[11]=(data >> 8) & 0xff;
         atomic {msg1_status|=0x10;}
         break;
       case 5:
         msg1.data[12]=data & 0xff;
         msg1.data[13]=(data >> 8) & 0xff;
         atomic {msg1_status|=0x20;}
         break;
       case 6:
         msg1.data[14]=data & 0xff;
         msg1.data[15]=(data >> 8) & 0xff;
         atomic {msg1_status|=0x40;}
         break;
       case 7:
         msg1.data[16]=data & 0xff;
         msg1.data[17]=(data >> 8) & 0xff;
         atomic {msg1_status|=0x80;}
         break;
       case 8:
         msg1.data[18]=data & 0xff;
         msg1.data[19]=(data >> 8) & 0xff;
         atomic {msg1_status|=0x100;}
         break;
       case 9:
         msg1.data[20]=data & 0xff;
         msg1.data[21]=(data >> 8) & 0xff;
         atomic {msg1_status|=0x200;}
         break;
       case 10:
         msg1.data[22]=data & 0xff;
         msg1.data[23]=(data >> 8) & 0xff;
         atomic {msg1_status|=0x400;}
         break;
       case 11:
         msg1.data[24]=data & 0xff;
         msg1.data[25]=(data >> 8) & 0xff;
         atomic {msg1_status|=0x800;}
         break;
       case 12:
         msg1.data[26]=data & 0xff;
         msg1.data[27]=(data >> 8) & 0xff;
         atomic {msg1_status|=0x1000;}
         break;
       case 13:
         msg1.data[28]=data & 0xff;
         msg1.data[29]=(data >> 8) & 0xff;
         atomic {msg1_status|=0x2000;}
         break;
       default:
         break;
       }
     }
     
     if(channelType== BATTERY) {
       msg2.data[0]=0x22;
       msg2.data[1]=0x22;
       msg2.data[2]=data & 0xff;
       msg2.data[3]=(data >> 8) & 0xff;
       atomic {msg2_status|=0x01;}
     }
     
     if(channelType== HUMIDITY) {
       msg2.data[4]=data & 0xff;
       msg2.data[5]=(data >> 8) & 0xff;
       atomic {msg2_status|=0x02;}
     }
     
     if(channelType== TEMPERATURE) {
       msg2.data[6]=data & 0xff;
       msg2.data[7]=(data >> 8) & 0xff;
       atomic {msg2_status|=0x04;}
     }
     
     if(channelType== COUNTER) {
       msg2.data[8]=data & 0xff;
       msg2.data[9]=(data >> 8) & 0xff;
       atomic {msg2_status|=0x08;}
     }                    
     
     if(channelType==DIGITAL) {
       msg3.data[0]=0x33;
       msg3.data[1]=0x33;
       switch (channel) {
       case 0:
         msg3.data[2]=data & 0xff;
         msg3.data[3]=(data >> 8) & 0xff;
         atomic {msg3_status|=0x01;}
         break;
       case 1:
         msg3.data[4]=data & 0xff;
         msg3.data[5]=(data >> 8) & 0xff;
         atomic {msg3_status|=0x02;}
         break;
       case 2:
         msg3.data[6]=data & 0xff;
         msg3.data[7]=(data >> 8) & 0xff;
         atomic {msg3_status|=0x04;};
       case 3:
         msg3.data[8]=data & 0xff;
         msg3.data[9]=(data >> 8) & 0xff;
         atomic {msg3_status|=0x08;}
         break;
       case 4:
         msg3.data[10]=data & 0xff;
         msg3.data[11]=(data >> 8) & 0xff;
         atomic {msg3_status|=0x10;}
         break;
       case 5:
         msg3.data[12]=data & 0xff;
         msg3.data[13]=(data >> 8) & 0xff;
         atomic {msg3_status|=0x20;}
         break;
       default:
         break;
       }
     }
     
     atomic {
       if(msg1_status==0x3fff) { post send_data(); }
       else if(msg2_status==0x0f) {  post send_data(); }
       else if(msg3_status==0x3f) {  post send_data(); }
     }
     return SUCCESS;
   }

 /****************************************************utility Function****************************/ 
result_t SamplerEventBySamplerID(uint8_t samplerID,uint8_t channel,uint8_t channelType,uint16_t data)
  {
    //*********************************
    //testing for analog channels
    if(samplerID==myTestRecord[0].SamplerID)
      {
        //if(channel==0 && channelType==ANALOG) call Leds.redToggle();
          //= call DmAcceptMnAndTI.passMnT(mnADC0,ANALOG_SAMPLING_TIME);               
      }
    if(samplerID==myTestRecord[1].SamplerID)
      {
        //if(channel==0 && channelType==ANALOG) call Leds.greenToggle();
       // = call DmAcceptMnAndTI.passMnT(mnADC0,ANALOG_SAMPLING_TIME);               
      }
    //*********************************
    //testing for counter channels
    if(samplerID==myTestRecord[2].SamplerID)
      {
        //if(channelType==COUNTER) call Leds.redToggle();
        // = call DmAcceptMnAndTI.passMnT(mnCOUNTER,MISC_SAMPLING_TIME);
      }
    if(samplerID==myTestRecord[3].SamplerID)
      {
        //if(channelType==COUNTER) call Leds.greenToggle();
        // = call DmAcceptMnAndTI.passMnT(mnCOUNTER,MISC_SAMPLING_TIME);
      }
    //*********************************
    //testing for temprature channels
    if(samplerID==myTestRecord[4].SamplerID)
      {
        //if(channelType==TEMPERATURE) call Leds.redToggle();
       //= call DmAcceptMnAndTI.passMnT(mnTEMP,MISC_SAMPLING_TIME);
      }
    if(samplerID==myTestRecord[5].SamplerID)
      {
        //if(channelType==TEMPERATURE) call Leds.greenToggle();
       //= call DmAcceptMnAndTI.passMnT(mnTEMP,MISC_SAMPLING_TIME);
      }
    //*********************************
    //testing for humidity channels
    if(samplerID==myTestRecord[6].SamplerID)
      {
        //if(channelType==HUMIDITY) call Leds.redToggle();
        // = call DmAcceptMnAndTI.passMnT(mnHUM,MISC_SAMPLING_TIME);
      }
    if(samplerID==myTestRecord[7].SamplerID)
      {
        //if(channelType==HUMIDITY) call Leds.greenToggle();
        // = call DmAcceptMnAndTI.passMnT(mnHUM,MISC_SAMPLING_TIME);
      }
    //*********************************
    //testing for batterey channels
    if(samplerID==myTestRecord[8].SamplerID)
      {
        //if(channelType==BATTERY) call Leds.redToggle();
        // = call DmAcceptMnAndTI.passMnT(mnBATTEREY,MISC_SAMPLING_TIME);
      }
    if(samplerID==myTestRecord[9].SamplerID)
      {
        //if(channelType==BATTERY) call Leds.greenToggle();
       //= call DmAcceptMnAndTI.passMnT(mnBATTEREY,MISC_SAMPLING_TIME);     
      }
    if(samplerID==myTestRecord[10].SamplerID)
      {
        if(channelType==DIGITAL) call Leds.redToggle();
        // = call DmAcceptMnAndTI.passMnT(mnDIG0,DIGITAL_SAMPLING_TIME);
      }
    if(samplerID==myTestRecord[11].SamplerID)
      {
        if(channelType==DIGITAL) call Leds.greenToggle();
       //= call DmAcceptMnAndTI.passMnT(mnDIG0,DIGITAL_SAMPLING_TIME);
      }
    return SUCCESS;
  }


 /****************************************************utility Function****************************/ 
 void fillup_dataMap_directly_for_test()
   {
     uint8_t i;
     fillup_records();
     for(i=0;i<NUMBER_TEST_RECORDS;i++)
       call DmUpdateTableI.updateTable(
                                       myTestRecord[i].measurementName,
                                       00,
                                       myTestRecord[i].hardwareAddress,
                                       myTestRecord[i].channelParameter);
   }
 
 /****************************************************utility Function****************************/
 result_t startByMeasurementName()
   {     
     myTestRecord[0].SamplerID = call DmAcceptMnAndTI.passMnT(mnADC0,ANALOG_SAMPLING_TIME);               
     myTestRecord[1].SamplerID = call DmAcceptMnAndTI.passMnT(mnADC1,ANALOG_SAMPLING_TIME);     
     myTestRecord[2].SamplerID = call DmAcceptMnAndTI.passMnT(mnADC2,ANALOG_SAMPLING_TIME);
     myTestRecord[3].SamplerID = call DmAcceptMnAndTI.passMnT(mnADC3,ANALOG_SAMPLING_TIME);
     myTestRecord[4].SamplerID = call DmAcceptMnAndTI.passMnT(mnADC4,ANALOG_SAMPLING_TIME);
     myTestRecord[5].SamplerID = call DmAcceptMnAndTI.passMnT(mnADC5,ANALOG_SAMPLING_TIME);
     myTestRecord[6].SamplerID = call DmAcceptMnAndTI.passMnT(mnADC6,ANALOG_SAMPLING_TIME);
     myTestRecord[7].SamplerID = call DmAcceptMnAndTI.passMnT(mnADC7,ANALOG_SAMPLING_TIME);
     myTestRecord[8].SamplerID = call DmAcceptMnAndTI.passMnT(mnADC8,ANALOG_SAMPLING_TIME);
     myTestRecord[9].SamplerID = call DmAcceptMnAndTI.passMnT(mnADC9,ANALOG_SAMPLING_TIME);
     myTestRecord[10].SamplerID = call DmAcceptMnAndTI.passMnT(mnADC10,ANALOG_SAMPLING_TIME);
     myTestRecord[11].SamplerID = call DmAcceptMnAndTI.passMnT(mnADC11,ANALOG_SAMPLING_TIME);
     myTestRecord[12].SamplerID = call DmAcceptMnAndTI.passMnT(mnADC12,ANALOG_SAMPLING_TIME);
     myTestRecord[13].SamplerID = call DmAcceptMnAndTI.passMnT(mnADC13,ANALOG_SAMPLING_TIME);
          
     myTestRecord[14].SamplerID = call DmAcceptMnAndTI.passMnT(mnCOUNTER,MISC_SAMPLING_TIME);
     myTestRecord[15].SamplerID = call DmAcceptMnAndTI.passMnT(mnTEMP,MISC_SAMPLING_TIME);
     myTestRecord[16].SamplerID = call DmAcceptMnAndTI.passMnT(mnHUM,MISC_SAMPLING_TIME);
     myTestRecord[17].SamplerID = call DmAcceptMnAndTI.passMnT(mnBATTEREY,MISC_SAMPLING_TIME);
     
     myTestRecord[18].SamplerID = call DmAcceptMnAndTI.passMnT(mnDIG0,DIGITAL_SAMPLING_TIME);
     myTestRecord[19].SamplerID = call DmAcceptMnAndTI.passMnT(mnDIG1,DIGITAL_SAMPLING_TIME);
     myTestRecord[20].SamplerID = call DmAcceptMnAndTI.passMnT(mnDIG2,DIGITAL_SAMPLING_TIME);
     myTestRecord[21].SamplerID = call DmAcceptMnAndTI.passMnT(mnDIG3,DIGITAL_SAMPLING_TIME);
     myTestRecord[22].SamplerID = call DmAcceptMnAndTI.passMnT(mnDIG4,DIGITAL_SAMPLING_TIME);
     myTestRecord[23].SamplerID = call DmAcceptMnAndTI.passMnT(mnDIG5,DIGITAL_SAMPLING_TIME);

     return SUCCESS;
   }
 
 /****************************************************utility Function****************************/
 result_t  startByChannel()
   {
  //start sampling  channels. Channels 7-10 with averaging since they are more percise.channels 3-6 make active excitation                          
     call Sample.getSample(0,ANALOG,ANALOG_SAMPLING_TIME,EXCITATION_25 |EXCITATION_33 | EXCITATION_50);
     call Sample.getSample(1,ANALOG,ANALOG_SAMPLING_TIME,SAMPLER_DEFAULT );
     call Sample.getSample(2,ANALOG,ANALOG_SAMPLING_TIME,SAMPLER_DEFAULT);
     call Sample.getSample(3,ANALOG,ANALOG_SAMPLING_TIME,SAMPLER_DEFAULT | EXCITATION_33 | DELAY_BEFORE_MEASUREMENT);
     call Sample.getSample(4,ANALOG,ANALOG_SAMPLING_TIME,SAMPLER_DEFAULT);
     call Sample.getSample(5,ANALOG,ANALOG_SAMPLING_TIME,SAMPLER_DEFAULT);
     call Sample.getSample(6,ANALOG,ANALOG_SAMPLING_TIME,SAMPLER_DEFAULT);
     call Sample.getSample(7,ANALOG,ANALOG_SAMPLING_TIME,AVERAGE_FOUR | EXCITATION_25);
     call Sample.getSample(8,ANALOG,ANALOG_SAMPLING_TIME,AVERAGE_FOUR | EXCITATION_25);
     call Sample.getSample(9,ANALOG,ANALOG_SAMPLING_TIME,AVERAGE_FOUR | EXCITATION_25);
     call Sample.getSample(10,ANALOG,ANALOG_SAMPLING_TIME,AVERAGE_FOUR | EXCITATION_25);
     call Sample.getSample(11,ANALOG,ANALOG_SAMPLING_TIME,SAMPLER_DEFAULT);
     call Sample.getSample(12,ANALOG,ANALOG_SAMPLING_TIME,SAMPLER_DEFAULT);
     call Sample.getSample(13,ANALOG,ANALOG_SAMPLING_TIME,SAMPLER_DEFAULT | EXCITATION_50 | EXCITATION_ALWAYS_ON);                                           
     //channel parameteres are irrelevent
     call Sample.getSample(0,TEMPERATURE,MISC_SAMPLING_TIME,SAMPLER_DEFAULT);
     call Sample.getSample(0,HUMIDITY,MISC_SAMPLING_TIME,SAMPLER_DEFAULT);
     call Sample.getSample(0, BATTERY,MISC_SAMPLING_TIME,SAMPLER_DEFAULT);
     
     //digital chennels as accumulative counter                
     call Sample.getSample(0,DIGITAL,DIGITAL_SAMPLING_TIME,RESET_ZERO_AFTER_READ | FALLING_EDGE);
     call Sample.getSample(1,DIGITAL,DIGITAL_SAMPLING_TIME,RISING_EDGE | EVENT);
     call Sample.getSample(2,DIGITAL,DIGITAL_SAMPLING_TIME,SAMPLER_DEFAULT | EVENT);
     call Sample.getSample(3,DIGITAL,DIGITAL_SAMPLING_TIME,FALLING_EDGE);
     call Sample.getSample(4,DIGITAL,DIGITAL_SAMPLING_TIME,RISING_EDGE);
     call Sample.getSample(5,DIGITAL,DIGITAL_SAMPLING_TIME,RISING_EDGE | EEPROM_TOTALIZER);                                
     //counter channels for frequency measurement, will reset to zero.
     call Sample.getSample(0, COUNTER,MISC_SAMPLING_TIME,RESET_ZERO_AFTER_READ | RISING_EDGE);
     return SUCCESS;
   }

result_t startSameMeasurementName()
{

     myTestRecord[0].SamplerID = call DmAcceptMnAndTI.passMnT(mnADC0,ANALOG_SAMPLING_TIME);               
     myTestRecord[1].SamplerID = call DmAcceptMnAndTI.passMnT(mnADC0,REPEAT_SAMPLING_TIME);     

     myTestRecord[2].SamplerID = call DmAcceptMnAndTI.passMnT(mnCOUNTER,MISC_SAMPLING_TIME);
     myTestRecord[3].SamplerID = call DmAcceptMnAndTI.passMnT(mnCOUNTER,REPEAT_SAMPLING_TIME);

     myTestRecord[4].SamplerID = call DmAcceptMnAndTI.passMnT(mnTEMP,MISC_SAMPLING_TIME);
     myTestRecord[5].SamplerID = call DmAcceptMnAndTI.passMnT(mnTEMP,REPEAT_SAMPLING_TIME);

     myTestRecord[6].SamplerID = call DmAcceptMnAndTI.passMnT(mnHUM,MISC_SAMPLING_TIME);
     myTestRecord[7].SamplerID = call DmAcceptMnAndTI.passMnT(mnHUM,REPEAT_SAMPLING_TIME);

     myTestRecord[8].SamplerID = call DmAcceptMnAndTI.passMnT(mnBATTEREY,MISC_SAMPLING_TIME);
     myTestRecord[9].SamplerID = call DmAcceptMnAndTI.passMnT(mnBATTEREY,REPEAT_SAMPLING_TIME);
     
     myTestRecord[10].SamplerID = call DmAcceptMnAndTI.passMnT(mnDIG0,DIGITAL_SAMPLING_TIME);
     myTestRecord[11].SamplerID = call DmAcceptMnAndTI.passMnT(mnDIG0,REPEAT_SAMPLING_TIME);
     return SUCCESS;
}
 
}

