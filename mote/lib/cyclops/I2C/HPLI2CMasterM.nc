module HPLI2CMasterM {
    provides {
        interface StdControl;
        interface I2CMaster;
    }
    uses {
        interface PowerManagement;
        interface Leds;
    }
}

implementation {
    //I2C Status Register State Codes
    enum {
        //Start codes
        TWI_START = 0x08,
        TWI_REP_START = 0x10,
        
        //Master transmit codes
        TWI_MTX_ADR_ACK = 0x18,
        TWI_MTX_DATA_ACK = 0x28,

        //Master receive codes
        TWI_MRX_ADR_ACK = 0x40,
        TWI_MRX_DATA_ACK = 0x50,
        TWI_MRX_DATA_NACK = 0x58,

        //Error codes
        TWI_MTX_ADR_NACK = 0x20,
        TWI_MRX_ADR_NACK = 0x48,
        TWI_MTX_DATA_NACK = 0x30,  
        TWI_ARB_LOST = 0x38,
        TWI_NO_STATE = 0xF8,
        TWI_BUS_ERROR = 0x00
    };

    //Initialization of I2C
    command result_t StdControl.init() {
        //Set the bit rate. We will be running the I2C 
        //clock at approximately 205kHz
        TWBR = 10;
                  
        //Clear the control register to ensure expected
        //operation.
        TWCR = 0;
     
        return SUCCESS;
    }

    command result_t StdControl.start() {
        //Adjust power settings
        call PowerManagement.adjustPower();
        return SUCCESS;
    }

    command result_t StdControl.stop() {
        //Reset the control register so that power
        //can be properly adjusted
        TWCR = 0;

        //Adjust power settings
        call PowerManagement.adjustPower();
        
        return SUCCESS;
    }

    //This task performs the clean-up after an I2C transaction
    //has completed
    task void cleanUpTask() {
        //Wait until the stop condition has been asserted
        //and the flag has been reset
        while(TWCR & (1<<TWSTO));
        
        //Reset the control register so that power
        //can be properly adjusted
        TWCR = 0;
        
        //Adjust the power since we are done performing the transaction
        call PowerManagement.adjustPower();
        //Signal higher layer that we have finished
        signal I2CMaster.sendEndDone();
    }

    //This command generates the stop symbol over I2C and performs 
    //clean-up
    async command result_t I2CMaster.sendEnd() {
        //Set the control register to generate the stop condition
        TWCR = (1<<TWEN)|(1<<TWINT)|(1<<TWSTO);

        //Post a task to adjust the power now that we have finished
        //performing a transaction over I2C.
        post cleanUpTask();
        return SUCCESS;
    }

    async command result_t I2CMaster.read(bool ack) {
        //If ack is set, the acknowledge the next byte to be read
        if (ack) {
            //Set the control register to read and ack the next byte
            TWCR = (1<<TWEN)|(1<<TWIE)|(1<<TWINT)|(1<<TWEA);
        }
        else {
            //Set the control register to read and nack the next byte
            TWCR = (1<<TWEN)|(1<<TWIE)|(1<<TWINT);
        }

        return SUCCESS;
    }

    //Command to send the start symbol which begins every transaction
    //over I2C
    async command result_t I2CMaster.sendStart(){
        //Set the control register to generate the start condition
        TWCR = (1<<TWEN)|(1<<TWIE)|(1<<TWINT)|(1<<TWSTA);

        //While we are performing any tansactions over I2C, we enable
        //TWIE which ensures that the mote will not sleep if we adjust the 
        //power
        call PowerManagement.adjustPower();

        return SUCCESS;
    }

    //Command that writes a byte of data over I2C
    async command result_t I2CMaster.write(char data) {
        //Store the data to be written to the data register
        TWDR = data;
        
        //Clear the interrupt thereby sending the data
        TWCR = (1<<TWEN)|(1<<TWIE)|(1<<TWINT);

        return SUCCESS;
    }

    //Interrupt handler
    TOSH_SIGNAL(SIG_2WIRE_SERIAL) {
        //We are assuming that The Prescale bits in TWSR are set to 0
        switch(TWSR) {
            //Cases to handle start or repeated start
            case TWI_START:
            case TWI_REP_START:
                //Inform higher layer that start symbol has been 
                //asserted on the bus
                signal I2CMaster.sendStartDone();
                break;
            
            //Cases to handle successful transmission of address/data in
            //master transmitter mode
            case TWI_MTX_ADR_ACK:
            case TWI_MTX_DATA_ACK:
                //Inform higher layer that address or data transmission
                //was aknowledged
                signal I2CMaster.writeDone(SUCCESS);
                break;

            //Case to handle successful transmission of address in
            //master receiver mode
            case TWI_MRX_ADR_ACK:
                //Inform higher layer that address transmission was
                //acknowledged
                signal I2CMaster.writeDone(SUCCESS);
                break;

            //Case to handle successful reception of a byte
            case TWI_MRX_DATA_ACK:
            case TWI_MRX_DATA_NACK:
                //Inform higher layer that data was received and
                //pass it the data from the register
                signal I2CMaster.readDone(TWDR);
                break;

            //Error cases where we inform the higher layer that transmission
            //failed and reset I2C
            case TWI_MTX_ADR_NACK:
            case TWI_MTX_DATA_NACK:
                //Inform the upper layer that we failed to write
                signal I2CMaster.writeDone(FAIL);

            case TWI_MRX_ADR_NACK:
            case TWI_ARB_LOST:
            case TWI_NO_STATE:
            case TWI_BUS_ERROR:
            default:
                //Reset the control register, thereby resetting I2C.
                TWCR = 0;    
        }
    }
}
