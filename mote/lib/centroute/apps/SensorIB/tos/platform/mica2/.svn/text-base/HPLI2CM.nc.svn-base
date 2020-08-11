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
 * The component written from scratch inspired from original component
 * by Phil Buonadonna whcih no longer in tos distribution
 */

module HPLI2CM
{
  provides {
    interface StdControl;
    interface I2C;
  }
  uses interface Interrupt;
  uses interface Leds;
}
implementation
{
  // global variables
  char state;           	// maintain the state of the current processx
  char global_data;
 
#define SET_START_TX() sbi(TWCR,TWSTA)
#define CLEAR_START_TX() cbi(TWCR,TWSTA)
#define SET_STOP_TX() sbi(TWCR,TWSTO)
#define CLEAR_STOP_TX() cbi(TWCR,TWSTO)
#define I2C_ENABLE() sbi(TWCR,TWEN)    
#define I2C_DISABLE() cbi(TWCR,TWEN)
#define INT_ENABLE() sbi(TWCR,TWIE)
#define INT_DISABLE() cbi(TWCR,TWIE)
#define INT_FLAG_ENABLE() sbi(TWCR,TWINT)
#define INT_FLAG_DISABLE() cbi(TWCR,TWINT)
#define ACK_ENABLE() sbi(TWCR,TWEA)
#define NACK_ENABLE() cbi(TWCR,TWEA)
#define RESET() outp(0x0,TWCR);
#define MAKE_CLOCK_OUTPUT() sbi(DDRD, 0);
#define CLOCK_HIGH() sbi(PORTD,0);  
#define CLCOK_LOW() cbi(PORTD,0);  
#define MAKE_DATA_INPUT() cbi(DDRD, 1);
#define DATA_PULL_UP() sbi(PORTD, 1);
#define DATA_NO_PULL_UP() cbi(PORTD, 1);

  // define constants for state
  enum {
      IDLE = 1,   // idle 
      MA_START,   // Initiation of the Master Bus
      MA_ADDRESS, // Master Transmitter,writing address
      MT_DATA,    // Master Transmitter,writing data
      MR_DATA,	  // Master Receiver
      ST,	      // Slave Transmitter
      SR          // Slave Receiver
  };	  
  
  
  // define TWI device status codes. 
  enum {
      TWS_BUSERROR	= 0x00,
      TWS_START		= 0x08,
      TWS_RSTART		= 0x10,
      TWS_MT_SLA_ACK	= 0x18,
      TWS_MT_SLA_NACK	= 0x20,
      TWS_MT_DATA_ACK	= 0x28,
      TWS_MT_DATA_NACK	= 0x30,
      TWS_M_ARB_LOST	= 0x38,
      TWS_MR_SLA_ACK	= 0x40,
      TWS_MR_SLA_NACK	= 0x48,
      TWS_MR_DATA_ACK	= 0x50,
      TWS_MR_DATA_NACK	= 0x58
  };
  
static inline void setBitRate()   // See Note, Page 205 of ATmega128 docs
      { 
          cbi(TWSR, TWPS0);
          cbi(TWSR, TWPS1);
          //28->100KHz and 40-75KHz
          outp(40,TWBR);           //outp(100,TWBR);           
      }
  
static inline void init()
      {
          //sbi(PORTD, 0);	// i2c SCL,this activate pullup resistor
          //sbi(PORTD, 1);	// i2c SDA,this activate pullup resistor
          
          MAKE_CLOCK_OUTPUT();
          MAKE_DATA_INPUT();
          CLOCK_HIGH();
          DATA_PULL_UP();          
          RESET();     
          I2C_ENABLE();
          INT_ENABLE();           
          ACK_ENABLE();
          call Interrupt.enable();          
          state = IDLE;
      }
  
static inline void reset()
      {
          RESET();
          setBitRate();
          init();          
      }  
  
  // Silly task to signal when a stop condition is completed.
  task void I2C_task() {
      loop_until_bit_is_clear(TWCR,TWSTO);
      INT_FLAG_ENABLE();
      signal I2C.sendEndDone();
  }
  
async command result_t StdControl.init() {      
      setBitRate();
      init();
      return SUCCESS;
  }
  
async command result_t StdControl.start() {
      return SUCCESS;
  }
  
async command result_t StdControl.stop() {
      return SUCCESS;
  }
  
  command result_t I2C.sendStart() {
      atomic{
          state=MA_START;
      }
      signal I2C.sendStartDone();                    
      return SUCCESS;
  }
  
  
  void sendstart()
      {
          SET_START_TX();
          INT_FLAG_ENABLE();
      }

  void sendAddress()
      {
          outb(TWDR,global_data);
          CLEAR_START_TX();
          INT_FLAG_ENABLE();
      }

  command result_t I2C.sendEnd() {
      SET_STOP_TX();
      post I2C_task();
      return SUCCESS;
  }
  
  // For reads and writes, if the TWINT bit is clear, the TWI is
  // busy or the TWI improperly initialized
  command result_t I2C.read(bool ack) {
      if(state!=MR_DATA) {
          atomic {
          state=IDLE;
          }
          return FAIL;
      }
      if (ack)  ACK_ENABLE();
      else      NACK_ENABLE();
      INT_FLAG_ENABLE();
      return SUCCESS;
  }
  
  command result_t I2C.write(char data) {
      global_data=data;
      if(state==MA_START) {
          atomic{
          state=MA_ADDRESS;
          }
          sendstart();
      }
      else if(state==MT_DATA)
          {
              outb(TWDR,data);
              INT_FLAG_ENABLE();
          }
      else {
          atomic{
              state=IDLE;
          }
          return FAIL;
      }
      return SUCCESS;
  }
  
  default event result_t I2C.sendStartDone() {
      return SUCCESS;
  }
  
  default event result_t I2C.sendEndDone() {
      return SUCCESS;
  }
  
  default event result_t I2C.readDone(char data) {
      return SUCCESS;
  }
  
  default event result_t I2C.writeDone(bool success) {
      return SUCCESS;
  }

  TOSH_SIGNAL(SIG_2WIRE_SERIAL) {
    uint8_t i2cState;
    uint8_t currentState;

    i2cState=inp(TWSR) & 0xF8;      
    INT_FLAG_DISABLE();
    switch (i2cState) {
    case TWS_BUSERROR:
        currentState=state;
        reset();
        if(currentState == MA_START) signal I2C.sendStartDone(); 
        else if(currentState == MT_DATA | currentState == MA_ADDRESS) signal I2C.writeDone(FAIL);
        else if(currentState == MR_DATA) signal I2C.readDone(FAIL);
        break;          
    case TWS_START:                //08
    case TWS_RSTART:               //10
        sendAddress();              
        break;          
    case TWS_MT_SLA_ACK:           //18
        if(global_data & 0x01) state=MR_DATA;
        else state=MT_DATA;
        signal I2C.writeDone(SUCCESS);
        break;          
    case TWS_MT_DATA_ACK:          //28
        state=MT_DATA;
        signal I2C.writeDone(SUCCESS);
        break;          
    case TWS_MT_SLA_NACK:          //20
        state=IDLE;
        reset();
        signal I2C.writeDone(FAIL);
        break;
    case TWS_MT_DATA_NACK:         //30
        state=IDLE;
        reset();
        signal I2C.writeDone(FAIL);
        break;      
    case TWS_MR_SLA_ACK:
        state=MR_DATA;
        signal I2C.writeDone(SUCCESS);
        break;          
    case TWS_MR_SLA_NACK:
        state=IDLE;
        signal I2C.readDone(FAIL);
        break;          
    case TWS_MR_DATA_ACK:
    case TWS_MR_DATA_NACK:
        state=MR_DATA;
        signal I2C.readDone(inb(TWDR));
        break;          
    default:          
        currentState=state;  //something is wrong
        reset();
        if(currentState == MA_START) signal I2C.sendStartDone(); 
        else if(currentState == MT_DATA | currentState == MA_ADDRESS) signal I2C.writeDone(FAIL);
        else if(currentState == MR_DATA) signal I2C.readDone(FAIL);
        break;          
    }   
  } 
}

