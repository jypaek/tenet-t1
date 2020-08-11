// $Id: I2CPacketSlaveM.nc,v 1.1 2007-07-02 22:51:58 jpaek Exp $

/*									tab:4
 * Copyright (c) 2002-2003 Intel Corporation
 * All rights reserved.
 *
 * This file is distributed under the terms in the attached INTEL-LICENSE     
 * file. If you do not find these files, copies can be found by writing to
 * Intel Research Berkeley, 2150 Shattuck Avenue, Suite 1300, Berkeley, CA, 
 * 94704.  Attention:  Intel License Inquiry.
 */

/**
 * @modified 6/30/2007
 * @author Jeongyeup Paek (jpaek@enl.usc.edu)
 *
 * Added I2CPacket Master/Slave Read protocol
 * - first byte that the master reads from the slave is the 'length'
 *   of the whole packet that the slave wants to return.
 **/
 
module I2CPacketSlaveM
{
    provides {
        interface StdControl;
        interface I2CPacketSlave;
    }
    uses {
        interface I2CSlave;
        interface StdControl as I2CStdControl;
    }
}
implementation
{
    char buf[I2CSLAVE_PACKETSIZE];
    norace char *currentBuffer;
    char *readBuffer;
    norace uint8_t index;
    uint8_t readLength;

    command result_t StdControl.init() {
        currentBuffer = buf;
        return call I2CStdControl.init();
    }

    command result_t StdControl.start() {
        return call I2CStdControl.start();
    }

    command result_t StdControl.stop() {
        return call I2CStdControl.stop();
    }

    command result_t I2CPacketSlave.setAddress(uint8_t value, bool bcast) {
        return call I2CSlave.setAddress(value, bcast);
    }

    command result_t I2CPacketSlave.getAddress() {
        return call I2CSlave.getAddress();
    }

    async event result_t I2CSlave.masterWriteStart() {
        index = 0;
        call I2CSlave.masterWriteReady(TRUE);
        return SUCCESS;
    }

    async event result_t I2CSlave.masterWrite(uint8_t value) {
        //If we have enough room in the buffer to store the byte,
        //then store it and increment index to the next memory location.
        if (index < I2CSLAVE_PACKETSIZE)
            currentBuffer[index++] = value;

        //If we we have space for more than one more byte then call
        //masterWriteReady with TRUE, which means that we are ready
        //to receive more data.
        if (index < (I2CSLAVE_PACKETSIZE - 1))
            call I2CSlave.masterWriteReady(TRUE);
        //If we only have space for 1 byte, then call masterReadReady 
        //with FALSE. This will inform  master that we are unable
        //to accept any more bytes after we receive the next byte.
        else
            call I2CSlave.masterWriteReady(FALSE);

        return SUCCESS;
    }

    task void packetReceived() {
        currentBuffer = signal I2CPacketSlave.write(currentBuffer, index);
    }

    async event result_t I2CSlave.masterWriteDone(bool moreData, uint8_t value) {
        //If we have to store the last byte, then copy it into the buffer
        if (moreData && (index < I2CSLAVE_PACKETSIZE))
            currentBuffer[index] = value;

        post packetReceived();

        //Call masterWriteReady with true because that will perform the 
        //necessary clean-up for the next transaction.
        call I2CSlave.masterWriteReady(TRUE);

        return SUCCESS;
    }

    task void readReq() {
        signal I2CPacketSlave.readRequest();
    }

    async event result_t I2CSlave.masterReadStart() {
        post readReq();
        return SUCCESS;
    }

    command result_t I2CPacketSlave.readBufReady(char *buff, uint8_t len) {
        atomic{
            readBuffer = buff;
            readLength = len;
            index = 0;
        }
        call I2CSlave.masterReadReady();
        return SUCCESS;
    }

    async event uint16_t I2CSlave.masterRead() {
        uint8_t data;
        uint16_t retval;
        
        /* I2CPacket Master/Slave Read protocol
           - first byte that the master reads from the slave is the 'length'
             of the whole packet that the slave wants to return. */
        if (index == 0) {
            index++;
            return (uint16_t) readLength;
        }
        data = readBuffer[index-1];
        retval = data | (index >= readLength ? I2CSLAVE_LAST : 0);
        index++;
        return retval;
    }

    task void packetSent() {
        //If the whole packet has been read, inform the higher layer
        //of success
        if (index >= readLength)
            signal I2CPacketSlave.readDone(SUCCESS);
        //Otherwise, inform the higher layer of failure. 
        else
            signal I2CPacketSlave.readDone(FAIL);
    }

    async event result_t I2CSlave.masterReadDone() {
        post packetSent();
        return SUCCESS;
    }

    default event char* I2CPacketSlave.write(char *data, uint8_t length) {return data;}
    default event result_t I2CPacketSlave.readRequest() {return SUCCESS;}
    default event result_t I2CPacketSlave.readDone(uint8_t sentLength){return SUCCESS;}
}

