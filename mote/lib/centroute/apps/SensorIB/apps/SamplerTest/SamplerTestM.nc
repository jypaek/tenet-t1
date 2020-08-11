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
 *
 * This application samples all the channels and sends them either to UART
 * or Radio based on the variable test that can be defined as UART_TEST or 
 * RADIO_TEST.U will receive four packet types.
 * The one starting with 11,11 all 14 analog channels
 * analog channels are raw values of adc
 * The one starting with 22,22 batterey,humidity,temprature,counter
 * battery is in volt*100, humidity is in percentage,temperature is fahrenheit*100
 * The one starting with 33,33 all 5 digital channels
 * The one starting with 44,44 are dummy timer for sanity check
 */


includes sensorboard;

module SamplerTestM
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

    //UART communication
    interface StdControl as UARTControl;
    interface BareSendMsg as UARTSendMsg;
    interface ReceiveMsg as UARTReceiveMsg;

    //Timer
    interface Timer;
    
    //support for plug and play
    command result_t PlugPlay();
  }
}
implementation
{

    enum {
        PENDING = 0,
        NO_MSG = 1
    };        

    TOS_Msg msg1,msg2,msg3,msg4;		/* Message to be sent out */
    uint16_t msg1_status,msg2_status,msg3_status;
    char test;
    int8_t record[25];

    command result_t StdControl.init() {
        call Leds.init();
        call UARTControl.init();
        //call SensorControl.init();
        msg1.data[0] = TOS_LOCAL_ADDRESS; //record your id in the packet.
        msg2.data[0] = TOS_LOCAL_ADDRESS; //record your id in the packet.
        msg3.data[0] = TOS_LOCAL_ADDRESS; //record your id in the packet.
        test=RADIO_TEST;
        msg1_status=0;
        msg2_status=0;
        msg3_status=0;
        return rcombine(call SamplerControl.init(), call CommControl.init());
         return SUCCESS;
    }
    
    command result_t StdControl.start() {
        call SamplerControl.start();
        call CommControl.start();
        call UARTControl.start();        

        if(call PlugPlay())
            {
              //call Timer.start(TIMER_REPEAT, 30000);
                //start sampling  channels. Channels 7-10 with averaging since they are more percise.channels 3-6 make active excitation              
                record[0] = call Sample.getSample(0,ANALOG,50,SAMPLER_DEFAULT | EXCITATION_33);
                record[1] = call Sample.getSample(1,ANALOG,50,SAMPLER_DEFAULT );
                record[2] = call Sample.getSample(2,ANALOG,50,SAMPLER_DEFAULT);
                record[3] = call Sample.getSample(3,ANALOG,50,SAMPLER_DEFAULT | EXCITATION_33 | DELAY_BEFORE_MEASUREMENT);
                record[4] = call Sample.getSample(4,ANALOG,50,SAMPLER_DEFAULT);
                record[5] = call Sample.getSample(5,ANALOG,50,SAMPLER_DEFAULT);
                record[6] = call Sample.getSample(6,ANALOG,50,SAMPLER_DEFAULT);
                record[7] = call Sample.getSample(7,ANALOG,50,AVERAGE_SIXTEEN | EXCITATION_25);
                record[8] = call Sample.getSample(8,ANALOG,50,AVERAGE_SIXTEEN | EXCITATION_25);
                record[9] = call Sample.getSample(9,ANALOG,50,AVERAGE_SIXTEEN | EXCITATION_25);
                record[10] = call Sample.getSample(10,ANALOG,50,AVERAGE_SIXTEEN | EXCITATION_25);
                record[11] = call Sample.getSample(11,ANALOG,50,SAMPLER_DEFAULT);
                record[12] = call Sample.getSample(12,ANALOG,50,SAMPLER_DEFAULT);
                record[13] = call Sample.getSample(13,ANALOG,50,SAMPLER_DEFAULT | EXCITATION_50 | EXCITATION_ALWAYS_ON);
                
                //channel parameteres are irrelevent
                record[14] = call Sample.getSample(0,TEMPERATURE,70,SAMPLER_DEFAULT);
                record[15] = call Sample.getSample(0,HUMIDITY,70,SAMPLER_DEFAULT);
                record[16] = call Sample.getSample(0, BATTERY,70,SAMPLER_DEFAULT);
                
                //digital chennels as accumulative counter
                record[17] = call Sample.getSample(0,DIGITAL,20,FALLING_EDGE | RESET_ZERO_AFTER_READ | EVENT );
                record[18] = call Sample.getSample(1,DIGITAL,20,RISING_EDGE | EVENT);
                record[19] = call Sample.getSample(2,DIGITAL,20,SAMPLER_DEFAULT | EVENT);
                record[20] = call Sample.getSample(3,DIGITAL,20,FALLING_EDGE);
                record[21] = call Sample.getSample(4,DIGITAL,20,RISING_EDGE);
                record[22] = call Sample.getSample(5,DIGITAL,20,RISING_EDGE | EEPROM_TOTALIZER);
                
                //counter channels for frequency measurement, will reset to zero.
                record[23] = call Sample.getSample(0, COUNTER,70,RESET_ZERO_AFTER_READ | RISING_EDGE | COUNTER_FREE_RUN);
            }
        else call Leds.redOn();
        return SUCCESS;
    }
    
    command result_t StdControl.stop() {
        call UARTControl.stop();
        call SamplerControl.stop();
    return SUCCESS;
    }


  event result_t SendMsg.sendDone(TOS_MsgPtr sent, result_t success) {
      if(test==RADIO_TEST) {
          if (&msg1 == sent) { msg1_status=0; return SUCCESS; }
          if (&msg2 == sent) { msg2_status=0; return SUCCESS; }
          if (&msg3 == sent) { msg3_status=0; return SUCCESS; }
          if(msg1_status==0x3fff) 
              {
                call Leds.redToggle();
                msg1_status=0; 
                call SendMsg.send(TOS_BCAST_ADDR, 29, &msg1); 
              }
          else if(msg2_status==0x0f)  
              {
                call Leds.greenToggle();
                msg2_status=0; 
                call SendMsg.send(TOS_BCAST_ADDR, 29, &msg2); 
              }
          else if(msg3_status==0x3f)  
              {
                call Leds.yellowToggle();
                msg3_status=0; 
                call SendMsg.send(TOS_BCAST_ADDR, 29, &msg3); 
              }
          else return FAIL;
      }
      else return SUCCESS;
  }
  
  event result_t UARTSendMsg.sendDone(TOS_MsgPtr sent, result_t success) {
      if(test==UART_TEST) {
          msg1.addr=TOS_UART_ADDR;
          msg2.addr=TOS_UART_ADDR;
          msg3.addr=TOS_UART_ADDR;
          if (&msg1 == sent) { msg1_status=0; return SUCCESS; }
          if (&msg2 == sent) { msg2_status=0; return SUCCESS; }
          if (&msg3 == sent) { msg3_status=0; return SUCCESS; }      
          if(msg1_status==0x3fff) 
              {
                  msg1_status=0;
                  call UARTSendMsg.send(&msg1); 
              }
          else if(msg2_status==0x0f)  
              {
                  msg2_status=0; 
                  call UARTSendMsg.send(&msg2); 
              }
          else if(msg3_status==0x3f)  
              {
                  msg3_status=0; 
                  call UARTSendMsg.send(&msg3); 
              }
          else return FAIL;
      }
      else return SUCCESS;      
      return FALSE;
  }

  event TOS_MsgPtr ReceiveMsg.receive(TOS_MsgPtr data) {
      return data;
  }
  
  event TOS_MsgPtr UARTReceiveMsg.receive(TOS_MsgPtr data) {
      return data;
  }
  
  event result_t Sample.dataReady(int8_t samplerRecord,uint8_t channel,uint8_t channelType,uint16_t data)
      {
          if(channelType==ANALOG) {
              msg1.data[0]=0x11;
              msg1.data[1]=0x11;
              switch (channel) {
              case 0:
                  msg1.data[2]=data & 0xff;
                  msg1.data[3]=(data >> 8) & 0xff;
                  msg1_status|=0x01;
                  break;
              case 1:   
                  msg1.data[4]=data & 0xff;
                  msg1.data[5]=(data >> 8) & 0xff;
                  msg1_status|=0x02;
                  break;
              case 2:
                  msg1.data[6]=data & 0xff;
                  msg1.data[7]=(data >> 8) & 0xff;
                  msg1_status|=0x04;
                  break;
              case 3:
                  msg1.data[8]=data & 0xff;
                  msg1.data[9]=(data >> 8) & 0xff;
                  msg1_status|=0x08;
                  break;
              case 4:
                  msg1.data[10]=data & 0xff;
                  msg1.data[11]=(data >> 8) & 0xff;
                  msg1_status|=0x10;
                  break;
              case 5:
                  msg1.data[12]=data & 0xff;
                  msg1.data[13]=(data >> 8) & 0xff;
                  msg1_status|=0x20;
                  break;
              case 6:
                  msg1.data[14]=data & 0xff;
                  msg1.data[15]=(data >> 8) & 0xff;
                  msg1_status|=0x40;
                  break;
              case 7:
                  msg1.data[16]=data & 0xff;
                  msg1.data[17]=(data >> 8) & 0xff;
                  msg1_status|=0x80;
                  break;
              case 8:
                  msg1.data[18]=data & 0xff;
                  msg1.data[19]=(data >> 8) & 0xff;
                  msg1_status|=0x100;
                  break;
              case 9:
                  msg1.data[20]=data & 0xff;
                  msg1.data[21]=(data >> 8) & 0xff;
                  msg1_status|=0x200;
                  break;
              case 10:
                  msg1.data[22]=data & 0xff;
                  msg1.data[23]=(data >> 8) & 0xff;
                  msg1_status|=0x400;
                  break;
              case 11:
                  msg1.data[24]=data & 0xff;
                  msg1.data[25]=(data >> 8) & 0xff;
                  msg1_status|=0x800;
                  break;
              case 12:
                  msg1.data[26]=data & 0xff;
                  msg1.data[27]=(data >> 8) & 0xff;
                  msg1_status|=0x1000;
                  break;
              case 13:
                  msg1.data[28]=data & 0xff;
                  msg1.data[29]=(data >> 8) & 0xff;
                  msg1_status|=0x2000;
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
              msg2_status|=0x01;
          }

          if(channelType== HUMIDITY) {
              msg2.data[4]=data & 0xff;
              msg2.data[5]=(data >> 8) & 0xff;
              msg2_status|=0x02;
          }
                    
          if(channelType== TEMPERATURE) {
              msg2.data[6]=data & 0xff;
              msg2.data[7]=(data >> 8) & 0xff;
              msg2_status|=0x04;
          }
          
          if(channelType== COUNTER) {
              msg2.data[8]=data & 0xff;
              msg2.data[9]=(data >> 8) & 0xff;
              msg2_status|=0x08;
          }                    

          if(channelType==DIGITAL) {
              msg3.data[0]=0x33;
              msg3.data[1]=0x33;
              switch (channel) {
              case 0:
                  msg3.data[2]=data & 0xff;
                  msg3.data[3]=(data >> 8) & 0xff;
                  msg3_status|=0x01;
                  break;
              case 1:
                  msg3.data[4]=data & 0xff;
                  msg3.data[5]=(data >> 8) & 0xff;
                  msg3_status|=0x02;
                  break;
              case 2:
                  msg3.data[6]=data & 0xff;
                  msg3.data[7]=(data >> 8) & 0xff;
                  msg3_status|=0x04;
;
              case 3:
                  msg3.data[8]=data & 0xff;
                  msg3.data[9]=(data >> 8) & 0xff;
                  msg3_status|=0x08;
                  break;
              case 4:
                  msg3.data[10]=data & 0xff;
                  msg3.data[11]=(data >> 8) & 0xff;
                  msg3_status|=0x10;
                  break;
              case 5:
                  msg3.data[12]=data & 0xff;
                  msg3.data[13]=(data >> 8) & 0xff;
                  msg3_status|=0x20;
                  break;
              default:
                  break;
              }
          }
          
          if(test==RADIO_TEST) {
              if(msg1_status==0x3fff) { msg1_status=0; call Leds.redToggle(); call SendMsg.send(TOS_BCAST_ADDR, 29, &msg1); }
              else if(msg2_status==0x0f) { msg2_status=0; call Leds.greenToggle(); call SendMsg.send(TOS_BCAST_ADDR, 29, &msg2); }
              else if(msg3_status==0x3f) { msg3_status=0; call Leds.yellowToggle(); call SendMsg.send(TOS_BCAST_ADDR, 29, &msg3); }
          }

          if(test==UART_TEST) {
              msg1.addr=TOS_UART_ADDR;
              msg2.addr=TOS_UART_ADDR;
              msg3.addr=TOS_UART_ADDR;

              if(msg1_status==0x3fff) { msg1_status=0; call UARTSendMsg.send(&msg1); }
              else if(msg2_status==0x0f) { msg2_status=0; call UARTSendMsg.send(&msg2); } 
              else if(msg3_status==0x3f) { msg3_status=0; call UARTSendMsg.send(&msg3); }
              
          }

          return SUCCESS;
      }
  
  event result_t Timer.fired() {
      
      msg4.data[0]=0x44;
      msg4.data[1]=0x44;
      
      call Leds.greenToggle();

      if(test==RADIO_TEST) {
          call SendMsg.send(TOS_BCAST_ADDR, 29, &msg4);
      }
      
      if(test==UART_TEST) {
          msg4.addr=TOS_UART_ADDR;
          call UARTSendMsg.send(&msg4);
      }

      if(record[0] != -1) call Sample.reTask(record[0],5);
      if(record[1] != -1) call Sample.reTask(record[1],5);
      if(record[2] != -1) call Sample.reTask(record[2],5);
      if(record[3] != -1) call Sample.reTask(record[3],5);
      if(record[4] != -1) call Sample.reTask(record[4],5);
      if(record[5] != -1) call Sample.reTask(record[5],5);
      if(record[6] != -1) call Sample.reTask(record[6],5);
      if(record[7] != -1) call Sample.reTask(record[7],5);
      if(record[8] != -1) call Sample.reTask(record[8],5);
      if(record[9] != -1) call Sample.reTask(record[9],5);
      if(record[10] != -1) call Sample.reTask(record[10],5);
      if(record[11] != -1) call Sample.reTask(record[11],5);
      if(record[12] != -1) call Sample.reTask(record[12],5);
      if(record[13] != -1) call Sample.reTask(record[13],5);

      if(record[14] != -1) call Sample.reTask(record[14],10);
      if(record[15] != -1) call Sample.reTask(record[15],10);
      if(record[16] != -1) call Sample.reTask(record[16],10);

      if(record[17] != -1) call Sample.stop(record[17]);
      if(record[18] != -1) call Sample.stop(record[18]);
      if(record[19] != -1) call Sample.stop(record[19]);
      if(record[20] != -1) call Sample.stop(record[20]);
      if(record[21] != -1) call Sample.stop(record[21]);
      if(record[22] != -1) call Sample.stop(record[22]);

      return SUCCESS;
  }
  
}
