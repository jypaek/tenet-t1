
/*
 * Authors: Sumit Rangwala, Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 */

/**
 * @author Sumit Rangwala
 * @author Jeongyeup Paek
 * @modified 10/25/2004
 */

module HPLVBOARDM {
    provides interface HPLUART as HPLVBOARD;
}
implementation
{

    async command result_t HPLVBOARD.init() {

        uint16_t i;
        uint16_t uartrate = 150; // jpaek@ this rate is different from that of /boarddriver/
    
        // Setting up the Parameters for UART1 port.
        // 115kbps, N-8-1

        // The upper 5 bits of UBRR1H represents the value of UOSR 
        // The remaining bits of UBRR represents the value of UBRR
        // Baud rate (in bps) = Clock frequency of Master/(UOSR+1)(UBRR+1)
        // In our case or UART1 master clock frequency is that of mica2 
        // which is 7.3728 MHz 
        // in the below case Baud rate = 7.3728 *10^6/(0+1)(63+1)

        // Set 57.6 KBps = 115.2 kbps, UBRR1H=0, UBRR1L=63
        UBRR1H = uartrate >> 8 ;
        UBRR1L = uartrate;
        //UBRR1H = 0;
        //UBRR1L = 63;

            //outp((1<<U2X),UCSR1A);

        // Set frame format: 8 data-bits, 1 stop-bit
        UCSR1C = ((1 << UCSZ1) | (1 << UCSZ0) | (1 << UMSEL));
     
        // Clear the buffer
        inp(UDR1);   
        
        // Enable reciever and transmitter and their interrupts
        UCSR1B  = ((1 << RXCIE) | (1 << TXCIE) | (1 << RXEN) | (1 << TXEN));

        // Set PG2 to output
        sbi(DDRG,DDG2);
        // Send an interrupt to vboard.
        i = 500;
        sbi(PORTG,2);
        while(i--)
            asm volatile    ("nop" ::);
        cbi(PORTG,2);

        return SUCCESS;
    }


    async command result_t HPLVBOARD.stop() {

         // We may want to stop the sampling before doing this ?
        UCSR1A = 0x00;
        UCSR1B = 0x00; 
        UCSR1C = 0x00;

        // We do not disable the PG2 pins here as that 
        // will be use to awake the vboard.
        // cbi(PORTG,2);
        return SUCCESS;
    }

    default async event result_t HPLVBOARD.get(uint8_t data) { return SUCCESS; }
    TOSH_SIGNAL(SIG_UART1_RECV) {    
        if (inp(UCSR1A) & (1 << RXC)) {
            signal HPLVBOARD.get(inp(UDR1));
        }
    }

    default async event result_t HPLVBOARD.putDone() { return SUCCESS; }
    TOSH_INTERRUPT(SIG_UART1_TRANS) {
        signal HPLVBOARD.putDone();
    }

    async command result_t HPLVBOARD.put(uint8_t data) {
        // Even though its sbi but this clears the TXC bit in the register.
        sbi(UCSR1A, TXC);
        outp(data, UDR1); 
        return SUCCESS;
    }
}
