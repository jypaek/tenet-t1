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

module HPLSTUARTM {
    provides {
        interface HPLUART as UART;
    }
    uses {
        interface PXA27XInterrupt as Interrupt;
    }
}

implementation
{
    uint8_t baudrate = 115200;
   
    async event void Interrupt.fired(){
      uint8_t error,intSource = STIIR;
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
          while(STLSR & LSR_DR){
              signal UART.get(STRBR);
          }
          break;
      case 3:
          //Receive Error
          error = STLSR;
          break;
      }
      return;
    }
    
    async command result_t UART.init() {
        
        /*** 
           need to configure the ST UART pins for the correct functionality
           
           GPIO<46> = STDRXD = ALT2(in)
           GPIO<47> = STDTXD = ALT1(out)
        *********/
        //atomic{
          
            //configure the GPIO Alt functions and directions
        GPIO_SET_ALT_FUNC(46,2,GPIO_IN);
        GPIO_SET_ALT_FUNC(47,1,GPIO_OUT);
        
        STLCR |=LCR_DLAB; //turn on DLAB so we can change the divisor
        STDLL = 8;  //configure to 115200;
        STDLH = 0;
        STLCR &= ~(LCR_DLAB);  //turn off DLAB
        
        STLCR |= 0x3; //configure to 8 bits
        
        STMCR &= ~MCR_LOOP;
        STMCR |= MCR_OUT2;
        STIER |= IER_RAVIE;
        STIER |= IER_TIE;
        STIER |= IER_UUE; //enable the UART
        
        //STMCR |= MCR_AFE; //Auto flow control enabled;
        //STMCR |= MCR_RTS;
        
        STFCR = FCR_TRFIFOE; //enable the fifos
        
        call Interrupt.allocate();
        call Interrupt.enable();
        //configure all the interrupt stuff
        //make sure that the interrupt causes an IRQ not an FIQ
        // __REG(0x40D00008) &= ~(1<<21);
        //configure the priority as IPR1
        //__REG(0x40D00020) = (1<<31 | 21);
        //unmask the interrupt
        //__REG(0x40D00004) |= (1<<21);
        
        CKEN |= CKEN_CKEN5; //enable the UART's clk
	    // }
        return SUCCESS;
    }
    
    command result_t UART.setRate(uint8_t newbaudrate){
        return SUCCESS;
    }
    
    async command result_t UART.stop() {
        CKEN &= ~CKEN_CKEN5;
        return SUCCESS;
    }
    
    async command result_t UART.put(uint8_t data) {
        STTHR = data;
        return SUCCESS;
    }

    default async event result_t UART.get(uint8_t data) { return SUCCESS; }
    
    default async event result_t UART.putDone() { return SUCCESS; }
    
}
