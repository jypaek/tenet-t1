 //Authors:		Mohammad Rahimi mhr@cens.ucla.edu 

/**
 * @modified 6/30/2007
 * @author Jeongyeup Paek (jpaek@enl.usc.edu)
 *
 * I2CPacket Master/Slave Read protocol
 * - first byte that the master reads from the slave is the 'length'
 *   of the whole packet that the slave wants to return.
 **/
 
module I2CPacketMasterM
{
    provides {
        interface StdControl;
        interface I2CPacketMaster[uint8_t id];
    }
    uses {
        interface I2CMaster;
        interface StdControl as I2CStdControl;
    }
}

implementation
{

    /* state of the i2c request  */
    enum {IDLE=45,
        I2C_START_COMMAND=35,
        I2C_WRITE_ADDRESS=33,
        I2C_WRITE_DATA=22,
        I2C_WRITE_DONE=31,
        I2C_READ_ADDRESS=56,
        I2C_READ_DATA=41,
        I2C_READ_DONE=44,
        I2C_STOP_COMMAND=27};

    //Note: The only variable to be protected is state most notably at two places that the component 
    //can be entered at write and read
    norace char* m_data;    //bytes to write to the i2c bus 
    norace char m_length; //length in bytes of the request 
    norace char index;    //current index of read/write byte 
    norace char state;    //current state of the i2c request 
    norace char address;  //destination address 
    norace bool m_result; //result of write

    //**************************************************************
    //*****************Initialization and Termination***************
    //************************************************************** 
    command result_t StdControl.init() {    
        atomic {state = IDLE;}
        index = 0;
        call I2CStdControl.init();
        return SUCCESS;
    }

    command result_t StdControl.start() {
        call I2CStdControl.start();
        return SUCCESS;
    }

    command result_t StdControl.stop() {return SUCCESS;}

    //**************************************************************
    //***************Starting the Read/Write transaction************
    //************************************************************** 
    command result_t I2CPacketMaster.writePacket[uint8_t id](char len, char* data) {       
        uint8_t status;
        atomic {
            status = FALSE; 
            if (state == IDLE) status = TRUE;   
        }
        if (status == FALSE) return FAIL;
        address = id;
        m_data = data;
        index = 0;
        m_length = len;
        state = I2C_WRITE_ADDRESS;
        call I2CMaster.sendStart();
        return SUCCESS;
    }

    command result_t I2CPacketMaster.readPacket[uint8_t id](char* readbuf) {
        uint8_t status;
        atomic {
            status = FALSE;
            if (state == IDLE) status = TRUE;             
        }
        if (status == FALSE ) return FAIL;     
        address = id;
        m_data = readbuf;
        index = 0;
        m_length = I2C_MAX_PACKETSIZE;
        state = I2C_READ_ADDRESS;
        call I2CMaster.sendStart();
        return SUCCESS;
    }

    // the start symbol was sent    
    async event result_t I2CMaster.sendStartDone() {
        if (state == I2C_WRITE_ADDRESS) {
            state = I2C_WRITE_DATA;
            call I2CMaster.write((address << 1) + 0);
        }
        else if (state == I2C_READ_ADDRESS) {
            state = I2C_READ_DATA;
            call I2CMaster.write((address << 1) + 1);
        }
        return SUCCESS;
    }

    //write fail task.
    task void signal_done() {
        char p_state;
        atomic {
            p_state = state;
            state = IDLE;
        }
        switch (p_state) {
            case I2C_WRITE_DONE:    //successfull write
                signal I2CPacketMaster.writePacketDone[address](SUCCESS);
                break;
            case I2C_READ_DONE:     //successfull read
                signal I2CPacketMaster.readPacketDone[address](index - 1, m_data);
                break;
            case I2C_READ_DATA:     // shouldn't there be readDone(FAIL)???
            case I2C_WRITE_DATA:
            case I2C_STOP_COMMAND:
            default:
                signal I2CPacketMaster.writePacketDone[address](FAIL);
                break;
        }
    }

    // the stop symbol was sent, note that it is return in a task so we can very well return to upper layer
    async event result_t I2CMaster.sendEndDone() {
        post signal_done(); //we can not return in the context of interrupt
        return SUCCESS;    
    }

    //notification of a byte successfully written to the bus following by write or read continuation or ending
    async event result_t I2CMaster.writeDone(bool result) {     
        if (result == FAIL) {
            post signal_done(); //we can not return in the context of interrupt
            return FAIL;
        }
        switch (state) {
            case I2C_WRITE_DATA:
                index++;
                if (index == m_length) state = I2C_STOP_COMMAND;                     
                return call I2CMaster.write(m_data[index-1]);
                break;
            case I2C_STOP_COMMAND:
                state = I2C_WRITE_DONE;
                return call I2CMaster.sendEnd();
                break;
            case I2C_READ_DATA:
                //index++;  // let the first byte be non-data byte (length)
                if (index < m_length)
                    return call I2CMaster.read(1);
                else        // will never go here
                    return call I2CMaster.read(0);
                break;
            default:
                return FAIL;
        }
        return SUCCESS;
    }
    
    //notification of a byte successfully read from the bus following by more read continuation or ending
    async event result_t I2CMaster.readDone(char in_data) {
        /* I2CPacket Master/Slave Read protocol
           - first byte that the master reads from the slave is the 'length'
             of the whole packet that the slave wants to return. */
        if (index == 0) {
            if (in_data < m_length) // m_length is the maximum length that master can read
                m_length = in_data; // (can possiblily be the buffer size limit)
        } else {
            m_data[index-1] = in_data;
        }
        index++;
        if (index < m_length)
            call I2CMaster.read(1);
        else if (index == m_length)
            call I2CMaster.read(0);
        else if (index > m_length) {
            state = I2C_READ_DONE;
            call I2CMaster.sendEnd();
        }
        return SUCCESS;
    }

    default event result_t I2CPacketMaster.readPacketDone[uint8_t id](char len, char* data) {
        return SUCCESS;
    }
    default event result_t I2CPacketMaster.writePacketDone[uint8_t id](bool result) {
        return SUCCESS;
    }

}

