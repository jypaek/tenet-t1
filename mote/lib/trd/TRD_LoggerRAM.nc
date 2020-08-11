/*
* "Copyright (c) 2006~2007 University of Southern California.
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
 * TRD packet logger that uses RAM instead of Flash.
 *
 * Use RAM space instead of Flash for logging TRD packets.
 * Built for motes that cannot access the flash for some reason.
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 2/5/2007
 **/

#include "trd.h"

module TRD_LoggerRAM {
    provides {
        interface StdControl;
        interface TRD_Logger as Logger;
    }
}

implementation
{
    //TOS_Msg buf[TRD_CACHE_ENTRIES_PER_NODE*TRD_NODE_ENTRIES];
    uint8_t buf[TRD_CACHE_ENTRIES_PER_NODE*TRD_NODE_ENTRIES][TOSH_DATA_LENGTH];

    uint16_t curr_flash_vptr = 0;

    uint8_t *write_data;
    uint8_t write_size;
    uint8_t *read_data;
    uint8_t rambusy = FALSE;

    command result_t StdControl.init() { return SUCCESS; }
    command result_t StdControl.start() { return SUCCESS; }
    command result_t StdControl.stop() { return SUCCESS; }

    task void signal_init_done() {
        signal Logger.initDone(SUCCESS);
    }
    command result_t Logger.init() {
        post signal_init_done();
        return SUCCESS;
    }

    task void signal_writeDone() {
        signal Logger.writeDone(write_data, (uint8_t)write_size, SUCCESS);
        rambusy = FALSE;
    }

    command result_t Logger.write(uint16_t *memloc, uint8_t *data, uint8_t size) {
        uint16_t virtual_addr = curr_flash_vptr;

        if (size > TRD_FLASH_PKT_SIZE)
            return FAIL;
        memcpy(&buf[curr_flash_vptr][0], data, size);
        #ifdef DEBUG_TRD_LOGGER
            dbg(DBG_USR1, "writing ramtrd addr %d\n", curr_flash_vptr);
        #endif
        *memloc = virtual_addr;
        curr_flash_vptr++;
        if (curr_flash_vptr >= TRD_CACHE_ENTRIES_PER_NODE)
            curr_flash_vptr = 0;    // flash wrap-around

        write_data = data;
        write_size = size;
        rambusy = TRUE;
        post signal_writeDone();
        return SUCCESS;
    }

    task void signal_readDone() {
        signal Logger.readDone(read_data, SUCCESS);
        rambusy = FALSE;
    }
    
    command result_t Logger.read(uint16_t memloc, uint8_t* buffer) {
        if (memloc >= TRD_CACHE_ENTRIES_PER_NODE)
            return FAIL;
        memcpy(buffer, &buf[memloc][0], TRD_FLASH_PKT_SIZE);
        #ifdef DEBUG_TRD_LOGGER
            dbg(DBG_USR1, "reading ramtrd memloc %d\n", memloc);
        #endif
        read_data = buffer;
        rambusy = TRUE;
        post signal_readDone();
        return SUCCESS;
    }

    default event void Logger.initDone(result_t success) {}
    default event void Logger.writeDone(uint8_t *data, uint8_t size, result_t success) {}
    default event void Logger.readDone(uint8_t* buffer, result_t success) {}

}

