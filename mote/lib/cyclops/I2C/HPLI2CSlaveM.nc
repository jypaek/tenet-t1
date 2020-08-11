
module HPLI2CSlaveM {
    provides {
        interface StdControl;
        interface I2CSlave;
    }
}

implementation {
    
    //Definitions of states
    enum {
        //Slave Transmitter states
        TWI_STX_ADR_ACK = 0xA8,
        TWI_STX_DATA_ACK = 0xB8,
        TWI_STX_DATA_NACK = 0xC0,
        TWI_STX_DATA_ACK_LAST_BYTE = 0xC8,
        
        //Slave Receiver states
        TWI_SRX_GEN_ACK = 0x70, 
        TWI_SRX_ADR_ACK = 0x60,
        TWI_SRX_GEN_DATA_ACK = 0x90,
        TWI_SRX_ADR_DATA_ACK = 0x80,        
        TWI_SRX_GEN_DATA_NACK = 0x98,
        TWI_SRX_ADR_DATA_NACK = 0x88,
        TWI_SRX_STOP_RESTART = 0xA0,
        
        //Error States 
        TWI_NO_STATE = 0xF8,
        TWI_BUS_ERROR = 0x00
    };

    //Initialization of I2C
    command result_t StdControl.init() {
        
        //Default value for I2C data register
        TWDR = 0xFF; 
        //Enable I2C, perform no other operations until we have
        //obtained the address
        TWCR = (1<<TWEN);
        return SUCCESS;
    }
    
    command result_t StdControl.start() {
        return SUCCESS;
    }

    command result_t StdControl.stop() {
        //Clear the I2C control register to ensure that it is 
        //disabled
        TWCR = 0;
        return SUCCESS;
    }

    //Command used by the higher layer to set the address of I2C Slave.
    //I2C Slave becomes responsive to interrupts after the address is
    //set.
    async command result_t I2CSlave.setAddress(uint8_t value, bool bcast) {
        //If bcast, respond to broadcast address (0x00) as well as our 
        //own address. Most significant 7 bits of TWAR are the address.
        //Least significant bit determines response to broadcast.
        if (bcast) {
            TWAR = (value<<1)|0x01;
        }
        else {
            TWAR = (value<<1);
        }

        //Set the control register to ACK when it hears its address
        TWCR = (1<<TWEN)|(1<<TWIE)|(1<<TWINT)|(1<<TWEA);

        return SUCCESS;
    }

    //Command that informs the higher layer of the address the I2C Slave
    //is currently set to.
    async command uint8_t I2CSlave.getAddress() {
        //Shift out the broadcast bit
        return (TWAR>>1);
    }

    //Function that is called at the end of transactions over I2C
    void slaveComplete(bool sendAck) {
        if (sendAck) {
            //Clear the interrupt and acknowledge or expect acknowledgement
            //of the next byte
            TWCR = (1<<TWEN)|(1<<TWIE)|(1<<TWINT)|(1<<TWEA);
        }
        else {
            //Clear the interrupt and do not acknowledge or do not expect
            //aknowledgement of the next byte
            TWCR = (1<<TWEN)|(1<<TWIE)|(1<<TWINT);
        }
    }

    //Function that prepares the next byte to be sent over I2C
    void sendNext() {
        uint16_t data;

        //Obtain next segment of data from higher layer
        data = signal I2CSlave.masterRead();

        //Mask out higher byte. The higher byte is only for control information
        TWDR = 0xFF & data;

        //If this data byte is the last one, call slaveComplete with FALSE
        //because we are not expecting an acknowledgement.
        if (data & I2CSLAVE_LAST)
            slaveComplete(FALSE);
        //Otherwise, call slaveComplete with TRUE because we are expecting
        //an acknowledgement.
        else
            slaveComplete(TRUE);
    }

    //Command that is called when the slave is ready for the master
    //to begin/continue writing to it.
    async command result_t I2CSlave.masterWriteReady(bool ack) {
        //Call slaveComplete to set TWCR so that it continues this
        //transaction or performs the proper clean-up
        slaveComplete(ack);
        return SUCCESS;
    }

    //Command that is called when the slave has prepared the data
    //for the master to read
    async command result_t I2CSlave.masterReadReady() {
        //Send the next byte of data.
        sendNext();
        return SUCCESS;       
    }

    //Interrupt handler
    TOSH_SIGNAL (SIG_2WIRE_SERIAL) {
        //We are assuming that the prescaler bits are set to 0
        switch(TWSR) {
            //Case that handles reception of address and read bit
            //designating that slave is to be read from.
            case TWI_STX_ADR_ACK:
                //Inform the higher layer that the slave will be
                //read from.
                signal I2CSlave.masterReadStart();
                //Set the control register to hold the bus. This
                //gives the cyclops time to generate the response
                TWCR = (1<<TWEN);
                break;
      
            //Case that handles the acknowledgement of a data byte
            //that the slave has transmitted.
            case TWI_STX_DATA_ACK:
                //Send the next byte of data
                sendNext();
                break;

            //Cases that handle the response of the slave after the
            //transmission of the last byte.
            case TWI_STX_DATA_NACK:
            case TWI_STX_DATA_ACK_LAST_BYTE:
                //Inform the higher layer that we have finished
                //transmitting
                signal I2CSlave.masterReadDone();
                //slaveComplete sets the control register 
                //so that it can handle the next transaction
                slaveComplete(TRUE);
                break;

            //Cases that handle reception of address and write bit
            //designating that the slave is to be written to
            case TWI_SRX_GEN_ACK:
            case TWI_SRX_ADR_ACK:     
                //Inform the higher layer that the slave will
                //be written to.
                signal I2CSlave.masterWriteStart();
                break;

            //Cases that handle reception of data
            case TWI_SRX_GEN_DATA_ACK:
            case TWI_SRX_ADR_DATA_ACK:
                //Inform higher layer that we have received a byte
                //of data
                signal I2CSlave.masterWrite(TWDR);
                break;

            //Cases to handle reception of last byte of data
            //(When slave has informed master that it cannot handle more)
            case TWI_SRX_GEN_DATA_NACK:
            case TWI_SRX_ADR_DATA_NACK:
                //Inform higher layer that we have received the last byte
                //and pass the byte.
                signal I2CSlave.masterWriteDone(TRUE,TWDR);
                break;

            //Case where transmittion is being completed
            case TWI_SRX_STOP_RESTART:
                //Inform the higher layer that the transmission has completed
                //and there are no more bytes of data
                signal I2CSlave.masterWriteDone(FALSE,0);
                break;

            //Cases where errors have occured  
            case TWI_NO_STATE:
            case TWI_BUS_ERROR:
            default:
                //slaveComplete sets the control register 
                //so that it can handle the next transaction
                slaveComplete(TRUE);
        }
    }
}
