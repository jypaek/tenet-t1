/*									tab:4
 *  IMPORTANT: READ BEFORE DOWNLOADING, COPYING, INSTALLING OR USING.  By
 *  downloading, copying, installing or using the software you agree to
 *  this license.  If you do not agree to this license, do not download,
 *  install, copy or use the software.
 *
 *  Intel Open Source License
 *
 *  Copyright (c) 2002 Intel Corporation
 *  All rights reserved.
 *  Redistribution and use in source and binary forms, with or without
 *  modification, are permitted provided that the following conditions are
 *  met:
 *
 *	Redistributions of source code must retain the above copyright
 *  notice, this list of conditions and the following disclaimer.
 *	Redistributions in binary form must reproduce the above copyright
 *  notice, this list of conditions and the following disclaimer in the
 *  documentation and/or other materials provided with the distribution.
 *      Neither the name of the Intel Corporation nor the names of its
 *  contributors may be used to endorse or promote products derived from
 *  this software without specific prior written permission.
 *
 *  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 *  ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 *  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
 *  PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE INTEL OR ITS
 *  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 *  EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 *  PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 *  PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 *  LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 *  NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 *  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 *
 */

// The hardware presentation layer. See hpl.h for the C side.
// Note: there's a separate C side (hpl.h) to get access to the avr macros

// The model is that HPL is stateless. If the desired interface is as stateless
// it can be implemented here (Clock, FlashBitSPI). Otherwise you should
// create a separate component
/*
 *@author Robbie Adler
 */

includes UART;

module HPLFFUARTM {
    provides {
        interface HPLUART as UART;
    }
    uses {
        interface PXA27XInterrupt as Interrupt;
    }
}

implementation
{
    uint8_t baudrate = UART_BAUD_115200;
  
    async event void Interrupt.fired(){
      uint8_t error,intSource = FFIIR;
      intSource = (intSource >> 1) & 0x3;
      switch(intSource){
      case 0:
          //MODEM STATUS
          break;
      case 1:
          //TRANSMIT FIFO Wants data
          signal UART.putDone();
          break;
      case 2:
          //Received Data Available
          while(FFLSR & LSR_DR){
              signal UART.get(FFRBR);
          }
          break;
      case 3:
          //Receive Error
          error = FFLSR;
          trace(DBG_USR1, "UART Error %d\r\n", error);
          break;
      }
      return;
    }
    
    void setBaudRate(uint8_t rate) {
   
      switch (rate) {
          case UART_BAUD_300:
              FFDLL = 0x0;  
              FFDLH = 0xC;
              break;
          case UART_BAUD_1200:
              FFDLL = 0x0;  
              FFDLH = 0x3;
              break;
          case UART_BAUD_2400:
              FFDLL = 0x80;  
              FFDLH = 0x1;
              break;
          case UART_BAUD_4800:
              FFDLL = 0xC0;  
              FFDLH = 0;
              break;
          case UART_BAUD_9600:
              FFDLL = 0x60;  
              FFDLH = 0;
              break;
          case UART_BAUD_19200:
              FFDLL = 0x30;  
              FFDLH = 0;
              break;
          case UART_BAUD_38400:
              FFDLL = 0x18;  
              FFDLH = 0;
              break;
          case UART_BAUD_57600:
              FFDLL = 0x10;  
              FFDLH = 0;
              break;
          case UART_BAUD_115200:
              FFDLL = 0x8;  
              FFDLH = 0;
              break;
          case UART_BAUD_230400:
              FFDLL = 0x4;  
              FFDLH = 0;
              break;
          case UART_BAUD_460800:
              FFDLL = 0x2;  
              FFDLH = 0;
              break;
          case UART_BAUD_921600:
              FFDLL = 0x1;  
              FFDLH = 0;
              break;
          default:
              FFDLL = 0x8;  // set default to 115200
              FFDLH = 0;
              break;
       }
    }

    async command result_t UART.init() {
      
        /*** 
           need to configure the FF UART pins for the correct functionality
           
           GPIO<46> = STDRXD = ALT2(in)
           GPIO<47> = STDTXD = ALT1(out)
        *********/
        //atomic{
          
            //configure the GPIO Alt functions and directions
      GPIO_SET_ALT_FUNC(96,3, GPIO_IN);
      GPIO_SET_ALT_FUNC(99,3, GPIO_OUT); //FFTXD
      call Interrupt.disable();
        
      atomic{
        FFLCR |=LCR_DLAB; //turn on DLAB so we can change the divisor
#if 0
        FFDLL = 8;  //configure to 115200;
        FFDLH = 0;
#else	
        // USE baudrate variable
        
	setBaudRate(baudrate);
#endif
        FFLCR &= ~(LCR_DLAB);  //turn off DLAB
      }  
        FFLCR |= 0x3; //configure to 8 bits
        
        FFMCR &= ~MCR_LOOP;
        FFMCR |= MCR_OUT2;
        FFIER |= IER_RAVIE;
        FFIER |= IER_TIE;
        FFIER |= IER_UUE; //enable the UART
        
        //STMCR |= MCR_AFE; //Auto flow control enabled;
        //STMCR |= MCR_RTS;
        
        FFFCR = FCR_TRFIFOE; //enable the fifos
        
        call Interrupt.allocate();
        call Interrupt.enable();
        //configure all the interrupt stuff
        //make sure that the interrupt causes an IRQ not an FIQ
        // __REG(0x40D00008) &= ~(1<<21);
        //configure the priority as IPR1
        //__REG(0x40D00020) = (1<<31 | 21);
        //unmask the interrupt
        //__REG(0x40D00004) |= (1<<21);
        
        CKEN |= CKEN_CKEN6; //enable the UART's clk
	    // }
        return SUCCESS;
    }
    
    command result_t UART.setRate(uint8_t newbaudrate){
        // TODO : Assume this is called before init for now
        baudrate = newbaudrate;
        return SUCCESS;
    }
    
    async command result_t UART.stop() {
        CKEN &= ~CKEN_CKEN6;
        return SUCCESS;
    }
    
    async command result_t UART.put(uint8_t data) {
        FFTHR = data;
        return SUCCESS;
    }

    default async event result_t UART.get(uint8_t data) { return SUCCESS; }
    
    default async event result_t UART.putDone() { return SUCCESS; }
    
}
