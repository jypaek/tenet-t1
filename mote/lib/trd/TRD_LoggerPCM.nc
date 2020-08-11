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
 * TRD packet logger for TOSSIM simulation.
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 2/5/2007
 **/

//#define DEBUG_TRD_LOGGER

#include "TRD_Logger.h"

module TRD_LoggerPCM
{
    provides {
        interface StdControl;
        interface TRD_Logger as Logger;
    }
    uses {
        interface StdControl as LoggerControl;
        interface BulkLoggerWrite;
        interface BulkLoggerRead;
    }
}

implementation
{

    uint16_t curr_flash_vptr;

    uint16_t write_memloc;
    uint8_t *write_data;
    uint8_t write_size;
    uint16_t read_memloc;
    uint8_t *read_data;

    command result_t StdControl.init() {
        call LoggerControl.init();
        curr_flash_vptr = 0;
        return SUCCESS;
    }

    command result_t StdControl.start() {
        call LoggerControl.start();
        return SUCCESS;
    }

    command result_t StdControl.stop() {
        call LoggerControl.stop();
        return SUCCESS;
    }

    task void signal_init_done() {
        signal Logger.initDone(SUCCESS);
    }
    command result_t Logger.init() {
        post signal_init_done();
        return SUCCESS;
    }

    command result_t Logger.write(uint16_t *memloc, uint8_t *data, uint8_t size) {
        uint16_t virtual_addr = curr_flash_vptr;
        uint32_t physical_addr = FIRST_LINE_START + (virtual_addr * LINES_PER_PKT);

        if (size > TRD_FLASH_PKT_SIZE)
            return FAIL;
        if (call BulkLoggerWrite.write(physical_addr, (uint32_t)size, data) == FAIL) {
            return FAIL;
        }
        #ifdef DEBUG_TRD_LOGGER
            dbg(DBG_USR1, "writing phy_addr %d\n", physical_addr);
        #endif
        *memloc = virtual_addr;
        curr_flash_vptr++;
        if (curr_flash_vptr >= FLASH_NUM_PKTS)
            curr_flash_vptr = 0;    // flash wrap-around

        write_memloc = *memloc;
        write_data = data;
        write_size = size;
        return SUCCESS;
    }

    event result_t BulkLoggerWrite.writeDone(result_t success) {
        signal Logger.writeDone(write_data, (uint8_t)write_size, success);
        return SUCCESS;
    }

    command result_t Logger.read(uint16_t memloc, uint8_t* buffer) {
        result_t result;
        uint32_t physical_addr = FIRST_LINE_START + (memloc * LINES_PER_PKT);
        if (memloc > FLASH_NUM_PKTS)
            return FAIL;
        result = call BulkLoggerRead.read(physical_addr, LINES_PER_PKT, buffer);
        #ifdef DEBUG_TRD_LOGGER
            if (result == SUCCESS)
                dbg(DBG_USR1, "reading phy_addr %d\n", physical_addr);
        #endif

        read_memloc = memloc;
        read_data = buffer;
        return result;
    }

    event result_t BulkLoggerRead.readDone(uint8_t* buffer, result_t success) {
        signal Logger.readDone(buffer, success);
        return SUCCESS;
    }

    default event void Logger.initDone(result_t success) {}
    default event void Logger.writeDone(uint8_t *data, uint8_t size, result_t success) {}
    default event void Logger.readDone(uint8_t* buffer, result_t success) {}

}

