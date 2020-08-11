/*
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
*/

/**
 *
 * @author Jeongyeup Paek (jpaek@usc.edu)
 *
 * @modified Mar/3/2009
 **/

#include "FlashStorage.h"

module FlashStorageMicazM
{
    provides {
        interface StdControl;
        interface FlashAccess;
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
        call LoggerControl.init();
        call Leds.init();
        if (!call AllocationReq.request(FLASH_STORAGE_SIZE)) {
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

    event result_t AllocationReq.requestProcessed(result_t success) {
        return SUCCESS;
    }

    command result_t FlashAccess.write(uint32_t offset, uint8_t *data, uint8_t len) {
        if (offset + len > FLASH_STORAGE_SIZE)
            return FAIL;
        return call WriteData.write(offset, data, (uint32_t)len);
    }

    event result_t WriteData.writeDone(uint8_t* data, uint32_t len, result_t success) {
        signal FlashAccess.writeDone(data, (uint8_t)len, success);
        return SUCCESS;
    }

    command result_t FlashAccess.read(uint32_t offset, uint8_t* buffer, uint8_t len) {
        if (offset + len > FLASH_STORAGE_SIZE)
            return FAIL;
        return call ReadData.read(offset, buffer, len);
    }

    event result_t ReadData.readDone(uint8_t* buffer, uint32_t len, result_t success) {
        signal FlashAccess.readDone(buffer, (uint8_t)len, success);
        return SUCCESS;
    }

    command result_t FlashAccess.erase() {
        return SUCCESS;
    }

    default event void FlashAccess.eraseDone(result_t success) { }
    default event void FlashAccess.writeDone(uint8_t *data, uint8_t len, result_t success) { }
    default event void FlashAccess.readDone(uint8_t* buffer, uint8_t len, result_t success) { }

}

