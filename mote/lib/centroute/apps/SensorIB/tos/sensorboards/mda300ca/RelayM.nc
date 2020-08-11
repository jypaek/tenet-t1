
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
 * History:   created @ 11/14/2003 
 * 
 * To change the state of the relays
 *
 */

module RelayM {
  provides {
    interface Relay as relay_normally_closed;
    interface Relay as relay_normally_open;
    interface StdControl as RelayControl;  //if u use Digital I/O no and initialize them no need to this.
  }
  uses {
    interface Dio as Dio6;
    interface Dio as Dio7;
    interface StdControl as DioControl;
  }
}
implementation {


  command result_t RelayControl.init() { 
    call DioControl.init();
    return SUCCESS;
  }
  command result_t RelayControl.start() {
    call DioControl.init();
    return SUCCESS;
  }
  
  command result_t RelayControl.stop() {
    return SUCCESS;
  }

  command result_t relay_normally_closed.open()
    {
      call Dio7.low();      
      return SUCCESS;
    }
  
  command result_t relay_normally_closed.close()
    {
      call Dio7.high();
      return SUCCESS;
    }
  
  command result_t relay_normally_closed.toggle()
    {
      call Dio7.Toggle();
      return SUCCESS;
    }
  
  command result_t relay_normally_open.open()
    {
      call Dio6.high();
      return SUCCESS;
    }
  
  command result_t relay_normally_open.close()
    {
      call Dio6.low();
      return SUCCESS;
    }
  
  command result_t relay_normally_open.toggle()
    {
      call Dio6.Toggle();
      return SUCCESS;
    }

   event result_t Dio6.dataReady(uint16_t data) {
      return SUCCESS;
  }

   event result_t Dio7.dataReady(uint16_t data) {
      return SUCCESS;
  }


  event result_t Dio6.dataOverflow() {
      return SUCCESS;
  }

  event result_t Dio7.dataOverflow() {
      return SUCCESS;
  }

  event result_t Dio6.valueReady(bool data) 
    {
      return SUCCESS;
    } 

   event result_t Dio7.valueReady(bool data) 
    {
      return SUCCESS;
    } 
}
