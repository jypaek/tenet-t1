// $Id: PXA27XI2CM.nc,v 1.4 2007/03/05 00:06:07 lnachman Exp $ 

/*									tab:4
 *  IMPORTANT: READ BEFORE DOWNLOADING, COPYING, INSTALLING OR USING.  By
 *  downloading, copying, installing or using the software you agree to
 *  this license.  If you do not agree to this license, do not download,
 *  install, copy or use the software.
 *
 *  Intel Open Source License 
 *
 *  Copyright (c) 2005 Intel Corporation 
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
 */
/**                                         
 * Description - PXA27X I2C interface.
 *     ---------- Usage example ----------     
 *     // (1) - To read 1 byte from a slave device's register
 *     call I2C.sendStart();                                        // wait for sendStartDone()
 *     call I2C.write( getDataFromAddr(DEVICE_SLAVEADDR, FALSE) );  // wait for writeDone()
 *     call I2C.write(deviceRegAddr);                               // wait for writeDone()
 *     call I2C.sendStart();                                        // wait for sendStartDone()
 *     call I2C.write( getDataFromAddr(DEVICE_SLAVEADDR, TRUE) );   // wait for writeDone()
 *     call I2C.sendEnd();                                          // wait for sendEndDone()
 *     call I2C.read(FALSE);                                        // wait for readDone()
 *     // the data is returned in readDone()
 *     -----------------------------------
 * 
 * @author Konrad Lorincz
 * @version 1.0, August 10, 2005
 */
includes pxa27x_registers_def;

module PXA27XI2CM
{
    provides interface StdControl;
    provides interface I2C;
}
implementation
{
    // ======================= Data ==================================
    uint8_t nextReadOrWrite;    
    enum {
        START = 1,        
        NO_START_OR_STOP,
        STOP,
    };

    uint8_t state;
    enum {
        IDLE = 1,
        WAITING_SEND_START,
        WAITING_SEND_STOP,
        WAITING_READ,
        WAITING_WRITE,
    };                                         


    // ======================= Methods ===============================

    // ----------------------- Internal private helper functions -----
    void I2C_configurePins()
    {
        /* 
         * Need to configure the I2C pins the correct functionality           
         *   GPIO<117> = I2C_SCL = ALT1(in)/ALT1(out)
         *   GPIO<118> = I2C_SDA = ALT1(in)/ALT1(out)
         */

        // (1) - Configure the GPIO Alt functions and directions
        //  a) tha alt functions
        GPIO_SET_ALT_FUNC(117,1, GPIO_OUT);
        GPIO_SET_ALT_FUNC(118,1, GPIO_OUT);

        //  b) the directions
        // Nothing to set because SCL and SDA are special bidirectional GPIOs
        // The direction of the pin is controlled by the peripheral directly
        // overwritting the GPIO directional settings for the pin (GPDR)
    }

    void I2C_init()
    {
        // (1) - Configure the GPIO pins
        I2C_configurePins();

        // (2) - Enablet the I2C clocks
        CKEN |= CKEN_CKEN14;    // enable I2C clock
        CKEN |= CKEN_CKEN15;  // Power Manager I2C Unit Clock Enable, this is necessary to 
                               // enable ICR[IUE] 
    }

    void I2C_enable()
    {
        // Enable the I2C unit and SCL
        ICR |= ICR_IUE;      // enable the I2C interface
        ICR |= ICR_SCLE;     // enable the SCL
    }

    void I2C_disable()
    {
        // Disable the I2C unit and SCL
        ICR &= ~(ICR_IUE);      // disable the I2C interface
        ICR &= ~(ICR_SCLE);     // disable the SCL
    }

    void I2C_reset()
    {
        // Reset the I2C
        ICR |=   ICR_UR;   // 1. Set the reset bit in ICR, and
        ICR &=   ICR_UR;   //    clear the rest of the register
        ISR ^=   ISR;      // 2. Clear the ISR register
        ICR &= ~(ICR_UR);  // 3. Clear reset in the ICR
    }

    result_t I2C_waitInterruptRxDone()
    {
        while ( !(ISR & ISR_IRF) && !(ISR & ISR_BED) )
            TOSH_wait();

        if (ISR & ISR_IRF)
            return SUCCESS;
        else
            return FAIL;       
    }

    result_t I2C_waitInterruptTxDone()
    {
        while ( !(ISR & ISR_ITE) && !(ISR & ISR_BED) )
            TOSH_wait();

        if (ISR & ISR_ITE)
            return SUCCESS;
        else
            return FAIL;       
    }

    void I2C_clearInterruptTxDone()
    {
        // Clear the "IDBR transmit-empty" by writting a logic 1
        //   if ISR_ITE == 0  =>  The data byte is still being transmitted
        //   if ISR_ITE == 1  =>  The data byte was transmitted on the I2C bus
        ISR |= ISR_ITE;  
    }

    void I2C_clearInterruptRxDone()
    {
        // Clear the "IDBR receive-full" by writting a logic 1
        //   if ISR_IRF == 0  =>  The IDBR has not received a new data on the I2C
        //   if ISR_IRF == 1  =>  The IDBR received a new data byte from the I2C
        ISR |= ISR_IRF;  
    }

    void I2C_clearInterruptArbitrLoss()
    {
        // Clear the "IDBR arbitration loss" by writting a logic 1, if set
        //   if ISR_ALD == 0  =>  When arbitration is won or never took place
        //   if ISR_ALD == 1  =>  When it loses arbitration
        // Note: If the master loses aribtration, it performs an address retry when
        //       the bus becomes free.  The arbitration-loss-detected interrupt is
        //       disabled to allow the address retry.
        if (ISR & ISR_ALD)    
            ISR |= ISR_ALD;  
    }

    void I2C_clearStateSend(bool clearACKNAK)
    {
        ICR &= ~(ICR_STOP);
        if (clearACKNAK)
            ICR &= ~(ICR_ACKNAK);
    }

    void I2C_loadIDBRwithAddr(uint8_t targetSlaveAddr7Bit, bool isRnWTypeRead)
    {
        // (1) - Load target address and R/nW bin in IDBR.
        //       Note: RnW is the LSB of IDBR (i.e. 7-bitTargetSlaveAddr + RnW-bit)
        IDBR = (targetSlaveAddr7Bit << 1);   // upper 7-bits
        if (isRnWTypeRead)
            IDBR |=  (1 << 0);  // for Read, RnW=1
        else
            IDBR &= ~(1 << 0);  // for Write, RnW=0
    }

    void I2C_loadIDBRwithData(uint8_t dataByte)
    {
        // Load the dataByte in the IDBR register
        IDBR = dataByte;
    }
      
    
    // ----------------------- StdControl interface ------------------
    command result_t StdControl.init() 
    {
        return SUCCESS;
    }

    command result_t StdControl.start() 
    {
        atomic {
            state = IDLE;
            nextReadOrWrite = NO_START_OR_STOP;
        }                         
        I2C_init();
        I2C_enable();
        return SUCCESS;
    }

    command result_t StdControl.stop() 
    {
        I2C_disable();
        return SUCCESS;
    }


    // ----------------------- I2C interface -------------------------
    void task triggerEvent()
    {
        result_t result;

        switch (state) {
            case WAITING_SEND_START:
                atomic {
                    state = IDLE;
                    nextReadOrWrite = START;
                    signal I2C.sendStartDone();
                }
                break;
            
            case WAITING_SEND_STOP:
                atomic {
                    state = IDLE;
                    nextReadOrWrite = STOP;
                    signal I2C.sendEndDone();
                }
                break;
        
            case WAITING_READ:
                if (I2C_waitInterruptRxDone())
                    result = SUCCESS;
                else
                    result = FAIL;
                I2C_clearInterruptRxDone();
                if (nextReadOrWrite == STOP)
                    I2C_clearStateSend(TRUE);

                atomic {
                    state = IDLE;
                    nextReadOrWrite = NO_START_OR_STOP;
                    signal I2C.readDone(IDBR);
                }
                break;

            case WAITING_WRITE:
                if (I2C_waitInterruptTxDone())
                    result = SUCCESS;
                else
                    result = FAIL;
                I2C_clearInterruptTxDone();                
                if (nextReadOrWrite == STOP)
                    I2C_clearStateSend(FALSE);

                atomic {
                    state = IDLE;
                    nextReadOrWrite = NO_START_OR_STOP;
                    signal I2C.writeDone(result);
                }
                break;

            default:    
                break;
        }                    
    }

    command result_t I2C.sendStart() 
    {
        if (state != IDLE)
           return FAIL;

        if (post triggerEvent()) {
            atomic state = WAITING_SEND_START;
            return SUCCESS;
        }
        else {
            return FAIL;
        }
    }

    command result_t I2C.sendEnd() 
    {
        if (state != IDLE)
           return FAIL;
                       
        if (post triggerEvent()) {
            atomic state = WAITING_SEND_STOP;
            return SUCCESS;
        }
        else            
            return FAIL;
    }

    command result_t I2C.read(bool ack) 
    {
        if (state != IDLE)
           return FAIL;

        // (1) - Do the read
        switch (nextReadOrWrite) {
            case START:
                return FAIL;  // TO DO: not yet implemented (not sure if this is valid)
                
            case NO_START_OR_STOP:
                ICR &= ~(ICR_START);
                ICR &= ~(ICR_STOP); 
                ICR |=   ICR_ALDIE;
                if (!ack)
                    ICR |=   ICR_ACKNAK;    
                ICR |=   ICR_TB;
                break;                
            
            case STOP:
                ICR &= ~(ICR_START);
                ICR |=   ICR_STOP; 
                ICR |=   ICR_ALDIE;
                if (!ack)
                    ICR |=   ICR_ACKNAK;    
                ICR |=   ICR_TB;
                break;  
                
            default:            
                return FAIL; 
        }
                
        if (post triggerEvent()) {
            atomic state = WAITING_READ;
            return SUCCESS;
        }
        else 
            return FAIL;
    }

    command result_t I2C.write(char data) 
    {
        if (state != IDLE)
           return FAIL;

        // (1) - Load the data in the IDBR register
        IDBR = data;

        // (2) - Do the write
        switch (nextReadOrWrite) {
            case START:
                ICR |=   ICR_START;
                ICR &= ~(ICR_STOP); 
                ICR &= ~(ICR_ALDIE);
                ICR |=   ICR_TB;
                break;

            case NO_START_OR_STOP:
                ICR &= ~(ICR_START);
                ICR &= ~(ICR_STOP); 
                ICR |=   ICR_ALDIE;
                ICR |=   ICR_TB;
                break;

            case STOP:
                ICR &= ~(ICR_START);
                ICR |=   ICR_STOP; 
                ICR |=   ICR_ALDIE;
                ICR |=   ICR_TB;
                break;

            default:            
                return FAIL;
        }
        
        if (post triggerEvent()) {
            atomic state = WAITING_WRITE;
            return SUCCESS;
        }
        else
            return FAIL;
    }

    default event result_t I2C.sendStartDone() 
    {
        return SUCCESS;
    }

    default event result_t I2C.sendEndDone()  
    {
        return SUCCESS;
    }

    default event result_t I2C.readDone(char data) 
    {
        return SUCCESS;
    }

    default event result_t I2C.writeDone(bool success) 
    {
        return SUCCESS;
    }

}

