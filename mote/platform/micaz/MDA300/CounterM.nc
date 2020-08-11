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
 * High speed counter channel
 * Also detects the presence of the Board.For plug and play application.
 */

module CounterM {
    provides {
        interface StdControl as CounterControl;
        interface Dio as Counter;
        command result_t Plugged();
        command result_t setPeriod(uint16_t myPeriod);
    }
    uses {
        interface Leds;
        //Timer
        interface Timer;

    }
}

implementation {

#define INT_ENABLE()  sbi(EIMSK , 5)
#define INT_DISABLE() cbi(EIMSK , 5)

    uint16_t count;
    uint16_t sensorCounter;
    uint8_t state;
    uint8_t mode;
    result_t boardConnected;
    uint16_t sensorPeriodSetting;

    command result_t CounterControl.init() {
        char c;
        INT_DISABLE();
        TOSH_MAKE_PW4_OUTPUT();
        TOSH_CLR_PW4_PIN();
        TOSH_uwait(1);
        c =(inp(PINE) >> 5) & 0x1;          //PORTE pin 5
        TOSH_SET_PW4_PIN();
        TOSH_uwait(1);
        if(c == ((inp(PINE) >> 5) & 0x1) ) boardConnected=FALSE;
        else boardConnected=TRUE;
        TOSH_CLR_PW4_PIN();
        atomic {
        mode=RISING_EDGE;
        count=0;
        state=0;
        sensorPeriodSetting=1000;
        sensorCounter = 0;
        }
        cbi(DDRE,5);            //Making INT pin input
        sbi(PORTE,5);           //and pull-up so that when the board is not there still operates
        //cbi(EICRB,ISC50);       //Making INT sensitive to falling edge
        //sbi(EICRB,ISC51);
        return SUCCESS;
    }
    
    command result_t CounterControl.start() {
      TOSH_CLR_PW4_PIN();
      atomic {
        count=0;
        state=0;
      }
      INT_ENABLE();
      return SUCCESS;
    }
    
    command result_t CounterControl.stop() {
      INT_DISABLE();
      return SUCCESS;
    }
    
    command uint8_t Counter.getparam()
      {
        return mode;
      }
    
    command result_t Counter.setparam(uint8_t modeToSet)
      {    
        //The available INT that is IN0-INT4 are not configurable
        //io is always input
        atomic{
          mode=modeToSet;
          if( ((mode & RISING_EDGE) == 0) & ((mode & FALLING_EDGE) == 0) ) 
            mode |= RISING_EDGE;
          if(mode & COUNTER_FREE_RUN) call Timer.start(TIMER_REPEAT, sensorPeriodSetting);
        }
        return SUCCESS;  
      }
    
    command result_t setPeriod(uint16_t myPeriod)
      {
        sensorPeriodSetting = myPeriod;
        if(mode & COUNTER_FREE_RUN) call Timer.start(TIMER_REPEAT, sensorPeriodSetting);
      }
    
    command result_t Plugged(){
      return boardConnected;
    }
    
    default event result_t Counter.valueReady(bool data) 
      {
        return SUCCESS;
      } 
    
    command result_t Counter.getValue()
      {    
        bool value;
        //signal Counter.valueReady[channel](value);
        return SUCCESS;
      } 
  
    command result_t Counter.high()
      {
        return SUCCESS;
      }
    
    command result_t Counter.low()
      {
        return SUCCESS;
      }
    
    command result_t Counter.Toggle()
      {
        return SUCCESS;
      }
  
    command result_t Counter.getData()
      {             
        uint16_t counter;
        if(mode & COUNTER_FREE_RUN) {
          signal Counter.dataReady(sensorCounter);
          return SUCCESS;        
        }
        atomic { 
          counter = count;
          if(RESET_ZERO_AFTER_READ & mode) count=0;
        }
        signal Counter.dataReady(counter);
        return SUCCESS;
      } 
    
    default event result_t Counter.dataReady(uint16_t data) 
      {
        return SUCCESS;
      } 
    
    event result_t Timer.fired() 
      {
        atomic {
        sensorCounter = count;
        count = 0;
        }
        return SUCCESS;
      }
    
    task void count_ready()
      {
        uint16_t counter;
        atomic { 
          counter = count;
        }
        signal Counter.dataReady(counter);
      }
   
#ifndef PLATFORM_EMSTAR
    TOSH_SIGNAL(SIG_INTERRUPT5)
      {           
        atomic {
          //INT_DISABLE();
          if(state==0){
            TOSH_CLR_PW4_PIN();
            state=1;
            if(mode & FALLING_EDGE) {
              count++;
              if(EVENT & mode) post count_ready();
            }
          }
          else {
            TOSH_SET_PW4_PIN();
            state=0;
            if(mode & RISING_EDGE) {
              count++;
              if(EVENT & mode) post count_ready();
            }
          }
          //INT_ENABLE();
        }
        return;
      }      
#endif
}
