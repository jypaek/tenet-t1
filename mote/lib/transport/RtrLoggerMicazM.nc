/*
* "Copyright (c) 2006~2008 University of Southern California.
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
 * RCRT packet logger module for micaz.
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 3/26/2007
 **/

#include "RtrLogger.h"
#include "TrLoggerMote.h"

module RtrLoggerMicazM
{
    provides {
        interface StdControl;
        interface TrPktLogger as Logger;
    }
    uses {
        interface StdControl as LoggerControl;
        interface AllocationReq;
        interface WriteData;
        interface ReadData;
        interface Leds;
    }
}

implementation
{

    command result_t StdControl.init() {
        uint32_t numBytes = (uint32_t)TR_FLASH_BYTES_PER_CON * RCRT_NUM_ACTIVE_CON;  // if 2 con, then 60KB

        call LoggerControl.init();
        call Leds.init();
        if (!call AllocationReq.request(numBytes)) {
            call Leds.redOn();
            return FAIL;
        }
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

    command result_t Logger.init() {
        return SUCCESS;
    }

    event result_t AllocationReq.requestProcessed(result_t success) {
        signal Logger.initDone(success);
        return SUCCESS;
    }

    command result_t Logger.write(uint8_t id, uint16_t seqno, uint8_t *data, uint8_t size) {
        // seqno : 1 ~ TR_MAX_SEQNO, not 0 ~.
        uint16_t seq2idx = (seqno - 1) % TR_FLASH_PKTS_PER_CON;
        // id : 0 ~ RCRT_NUM_ACTIVE_CON.
        uint32_t offset = id * TR_FLASH_BYTES_PER_CON;    // id is connection id
        offset = offset + (uint32_t)seq2idx * TR_FLASH_BYTES_PER_PKT;
        if (size > TR_FLASH_BYTES_PER_PKT)
            return FAIL;
        return call WriteData.write(offset, data, (uint32_t)size);
    }

    event result_t WriteData.writeDone(uint8_t* data, uint32_t size, result_t success) {
        signal Logger.writeDone(data, (uint8_t)size, success);
        return SUCCESS;
    }

    command result_t Logger.read(uint8_t id, uint16_t seqno, uint8_t* buffer) {
        // seqno : 1 ~ TR_MAX_SEQNO, not 0 ~.
        uint16_t seq2idx = (seqno - 1) % TR_FLASH_PKTS_PER_CON;
        // id : 0 ~ RCRT_NUM_ACTIVE_CON.
        uint32_t offset = id * TR_FLASH_BYTES_PER_CON;    // id is connection id
        offset = offset + (uint32_t)seq2idx * TR_FLASH_BYTES_PER_PKT;

        return call ReadData.read(offset, buffer, TR_FLASH_BYTES_PER_PKT);
    }

    event result_t ReadData.readDone(uint8_t* buffer, uint32_t size, result_t success) {
        signal Logger.readDone(buffer, (uint8_t)size, success);
        return SUCCESS;
    }

    default event void Logger.initDone(result_t success) { }
    default event void Logger.writeDone(uint8_t *data, uint8_t size, result_t success) { }
    default event void Logger.readDone(uint8_t* buffer, uint8_t size, result_t success) { }

}

