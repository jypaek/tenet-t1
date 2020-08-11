/*
* "Copyright (c) 2006 University of Southern California.
* All rights reserved.
*
* Permission to use, copy, modify, and distribute this software and its
* documentation for any purpose, without fee, and without written
* agreement is hereby granted, provided that the above copyright
* notice, the following two paragraphs and the author appear in all
* copies of this software.
*
* IN NO EVENT SHALL THE UNIVERSITY OF SOUTHERN CALIFORNIA BE LIABLE TO
* ANY PARTY FOR DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL
* DAMAGES ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS
* DOCUMENTATION, EVEN IF THE UNIVERSITY OF SOUTHERN CALIFORNIA HAS BEEN
* ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*
* THE UNIVERSITY OF SOUTHERN CALIFORNIA SPECIFICALLY DISCLAIMS ANY
* WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
* MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.  THE SOFTWARE
* PROVIDED HEREUNDER IS ON AN "AS IS" BASIS, AND THE UNIVERSITY OF
* SOUTHERN CALIFORNIA HAS NO OBLIGATION TO PROVIDE MAINTENANCE,
* SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS."
*
*/

/**
 * TRD packet logger module for MicaZ platform.
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 2/5/2007
 **/


#include "TRD_Logger.h"

module TRD_LoggerMicazM
{
    provides {
        interface StdControl;
        interface TRD_Logger as Logger;
    }
    uses {
        interface StdControl as LoggerControl;
        interface AllocationReq;
        interface WriteData;
        interface ReadData;
    }
}

implementation
{
    uint16_t curr_flash_vptr;

    command result_t StdControl.init() {
        uint32_t numBytes = TRD_FLASH_BYTES;
        call LoggerControl.init();
        curr_flash_vptr = 0;
        return call AllocationReq.request(numBytes);
    }

    command result_t StdControl.start() {
        call LoggerControl.start();
        return SUCCESS;
    }

    command result_t StdControl.stop() {
        call LoggerControl.stop();
        return SUCCESS;
    }

    command result_t Logger.init() {
        return SUCCESS;
    }

    event result_t AllocationReq.requestProcessed(result_t success) {
        signal Logger.initDone(success);
        return SUCCESS;
    }

    command result_t Logger.write(uint16_t *memloc, uint8_t *data, uint8_t size) {
        // virtual_addr is the sequence number of the logging packet in flash
        uint16_t virtual_addr = curr_flash_vptr;
        uint32_t physical_addr = virtual_addr * TRD_FLASH_PKT_SIZE;

        if (size > TRD_FLASH_PKT_SIZE)
            return FAIL;
        if (call WriteData.write(physical_addr, data, (uint32_t)size) == FAIL)
            return FAIL;
        *memloc = virtual_addr;
        curr_flash_vptr++;
        if (curr_flash_vptr >= TRD_FLASH_NUM_PKTS)
            curr_flash_vptr = 0;    // flash wrap-around
        return SUCCESS;
    }

    event result_t WriteData.writeDone(uint8_t* data, uint32_t size, result_t success) {
        signal Logger.writeDone(data, (uint8_t)size, success);
        return SUCCESS;
    }

    command result_t Logger.read(uint16_t memloc, uint8_t* buffer) {
        // memloc is the sequence number of the logged packet in flash,
        // which was given by 'virtual_addr' when written
        uint32_t physical_addr = memloc * TRD_FLASH_PKT_SIZE;
        if (memloc > TRD_FLASH_NUM_PKTS)
            return FAIL;
        return call ReadData.read(physical_addr, buffer, TRD_FLASH_PKT_SIZE);
    }

    event result_t ReadData.readDone(uint8_t* buffer, uint32_t size, result_t success) {
        signal Logger.readDone(buffer, success);
        return SUCCESS;
    }

    default event void Logger.initDone(result_t success) {}
    default event void Logger.writeDone(uint8_t *data, uint8_t size, result_t success) {}
    default event void Logger.readDone(uint8_t* buffer, result_t success) {}

}

