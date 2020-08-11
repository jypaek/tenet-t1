/**
 * "Copyright (c) 2006~2009 University of Southern California.
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
 **/

/**
 * RCRT packet logger module that uses RAM instead of flash
 *
 * @author Jeongyeup Paek (jpaek@usc.edu)
 *
 * @modified Oct/16/2009
 **/

#include "RtrLogger.h"
#include "TrLoggerMote.h"

module RtrLoggerRAM
{
    provides {
        interface StdControl;
        interface TrPktLogger as Logger;
    }
    uses {
        interface Leds;
    }
}

implementation
{
    uint8_t buf[TR_FLASH_BYTES_PER_CON * RCRT_NUM_ACTIVE_CON];

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

    command result_t Logger.write(uint8_t id, uint16_t seqno, uint8_t *data, uint8_t size) {
        // seqno : 1 ~ TR_MAX_SEQNO, not 0 ~.
        uint16_t seq2idx = (seqno - 1) % TR_FLASH_PKTS_PER_CON;
        // id : 0 ~ RCRT_NUM_ACTIVE_CON.
        uint32_t offset = id * TR_FLASH_BYTES_PER_CON;    // id is connection id
        offset = offset + (uint32_t)seq2idx * TR_FLASH_BYTES_PER_PKT;

        if (size > TR_FLASH_BYTES_PER_PKT)
            return FAIL;
        if (offset > TR_FLASH_BYTES_PER_CON * RCRT_NUM_ACTIVE_CON)
            return FAIL;

        rambusy = TRUE;
        memcpy(&buf[offset], data, size);
        write_data = data;
        write_size = size;
        post signal_writeDone();
        return SUCCESS;

    }

    task void signal_readDone() {
        signal Logger.readDone(read_data, TR_FLASH_BYTES_PER_PKT, SUCCESS);
        rambusy = FALSE;
    }

    command result_t Logger.read(uint8_t id, uint16_t seqno, uint8_t* buffer) {
        // seqno : 1 ~ TR_MAX_SEQNO, not 0 ~.
        uint16_t seq2idx = (seqno - 1) % TR_FLASH_PKTS_PER_CON;
        // id : 0 ~ RCRT_NUM_ACTIVE_CON.
        uint32_t offset = id * TR_FLASH_BYTES_PER_CON;    // id is connection id
        offset = offset + (uint32_t)seq2idx * TR_FLASH_BYTES_PER_PKT;

        if (offset > TR_FLASH_BYTES_PER_CON * RCRT_NUM_ACTIVE_CON)
            return FAIL;

        rambusy = TRUE;
        memcpy(buffer, &buf[offset], TR_FLASH_BYTES_PER_PKT);
        read_data = buffer;
        post signal_readDone();
        return SUCCESS;
    }

    default event void Logger.initDone(result_t success) { }
    default event void Logger.writeDone(uint8_t *data, uint8_t size, result_t success) { }
    default event void Logger.readDone(uint8_t* buffer, uint8_t size, result_t success) { }

}

