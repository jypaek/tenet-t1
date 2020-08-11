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
 * to test hardware I2C
 */


module I2CPackettestM
{
  provides interface StdControl;
  uses {
    interface Leds;
    interface Timer;
    interface StdControl as CommControl;
    interface SendMsg as SendMsg;
    interface ReceiveMsg as ReceiveMsg;

    interface I2CPacket;
    interface StdControl as I2CStdControl;

  }
}
implementation
{
  enum {
    MAX_CHIRPS = 100
  };

  enum {
      WRITE_TEST,
      READ_TEST
  };

  uint8_t counter;		/* Component counter counter */
  TOS_Msg msg;			/* Message to be sent out */
  bool sendPending;		/* Variable to store counter of buffer*/
  uint8_t index;
  uint8_t i2c_data;


#define test WRITE_TEST

  command result_t StdControl.init() {
    call Leds.init();
    counter = 0;
    index=0;
    i2c_data=0;
    sendPending = FALSE;
    msg.data[0] = TOS_LOCAL_ADDRESS; //record your id in the packet.
    call CommControl.init();
    call I2CStdControl.init();      
    return SUCCESS;
  }

  command result_t StdControl.start() {
      return call Timer.start(TIMER_REPEAT, 5);
  }

  command result_t StdControl.stop() {
      return call Timer.stop();
  }
  
    void sendComplete() {
        sendPending = FALSE;
    }
    
  event result_t Timer.fired() {
      if(i2c_data != 0x00) i2c_data =0x00;
      else i2c_data=0xff;
      if(test==WRITE_TEST) {
          sendPending = TRUE;
          call I2CPacket.writePacket(1,(char*) (&i2c_data),0x01);
      }
      if(test==READ_TEST)
          {
              i2c_data=0x9f;
              call I2CPacket.writePacket(1,(char*) (&i2c_data),0x01);
          }          
    return SUCCESS;
  }

  event result_t SendMsg.sendDone(TOS_MsgPtr sent, result_t success) { 
    if (&msg == sent)
      sendComplete();
    return SUCCESS;
  }

  event TOS_MsgPtr ReceiveMsg.receive(TOS_MsgPtr data) {
    return data;
  }


  event result_t I2CPacket.readPacketDone(char len,char *data) {
      sendPending = TRUE;
      msg.data[1] = 0x33; 
      msg.data[2] = 0x33; 
      msg.data[3] = 0x33; 
      msg.data[4] = 0x33; 
      msg.data[5] = (data[0] << 8) & 0xff;
      msg.data[6] = data[1] & 0xff;

      if( call SendMsg.send(TOS_BCAST_ADDR, 3, &msg) == FAIL) sendComplete();
      return SUCCESS;
  }

  event result_t I2CPacket.writePacketDone(bool r) {
      if(r==TRUE && test==READ_TEST) { call I2CPacket.readPacket(2,0x03);}
      return SUCCESS;
  }

}
