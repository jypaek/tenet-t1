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

module FlashStorageTelosM
{
    provides {
        interface StdControl;
        interface FlashAccess;
    }
    uses {
        interface Mount as Mount0;
        interface BlockWrite as BlockWrite0;
        interface BlockRead as BlockRead0;
        interface Timer as ReMountTimer; //avoid conflict with other flash user
        interface Leds;
    }
}

implementation
{
    uint8_t m_state;
    
    command result_t StdControl.init() {
        m_state = S_MOUNT;
        call Leds.init();
        return SUCCESS;
    }

    command result_t StdControl.start() {
        return call ReMountTimer.start(TIMER_ONE_SHOT, 5000);
    }

    command result_t StdControl.stop() {
        return SUCCESS;
    }

    event result_t ReMountTimer.fired() {
        if (call Mount0.mount(STR_VOL_ID0) != SUCCESS) {
            call Leds.redOn();
            call ReMountTimer.start(TIMER_ONE_SHOT, 1000);
        }
        return SUCCESS;
    }
      
    command result_t FlashAccess.erase() {
        if (m_state != S_IDLE)
            return FAIL;
        if (call BlockWrite0.erase() != SUCCESS) {
            call Leds.redOn();
            return FAIL;
        }
        m_state = S_ERASE_VOL;
        return SUCCESS;
    }

    command result_t FlashAccess.write(uint32_t offset, uint8_t *data, uint8_t len) {
        if (offset + len > FLASH_STORAGE_SIZE)
            return FAIL;
        if (m_state != S_IDLE)
            return FAIL;
        if (call BlockWrite0.write(offset, data, (uint32_t)len) != SUCCESS)
            return FAIL;
        return SUCCESS;
    }

    event void BlockWrite0.writeDone(storage_result_t result, block_addr_t addr, void* buf, block_addr_t len)
    {
        if (result == STORAGE_OK) {
            signal FlashAccess.writeDone(buf, len, SUCCESS);
        } else {
            signal FlashAccess.writeDone(buf, len, FAIL);
        }
    }

    command result_t FlashAccess.read(uint32_t offset, uint8_t* buffer, uint8_t len) {
        if (offset + len > FLASH_STORAGE_SIZE)
            return FAIL;
        if (m_state != S_IDLE)
            return FAIL;
        if (call BlockRead0.read(offset, buffer, len) != SUCCESS)
            return FAIL;
        return SUCCESS;
    }

    event void BlockRead0.readDone(storage_result_t result, block_addr_t addr, void* buf, block_addr_t len) {
        if (result == STORAGE_OK) {
            signal FlashAccess.readDone(buf, len, SUCCESS);
        } else {
            signal FlashAccess.readDone(buf, len, FAIL);
        }
    }

    event void Mount0.mountDone(storage_result_t result, volume_id_t id) {
        if (result == STORAGE_OK) {
            m_state = S_IDLE;
        } else {
            call Leds.redOn();
        }
    }

    event void BlockWrite0.eraseDone(storage_result_t result) {
        if (result == STORAGE_OK) {
            signal FlashAccess.eraseDone(SUCCESS);
        } else {
            signal FlashAccess.eraseDone(FAIL);
            call Leds.redOn();
        }
        m_state = S_IDLE;
    }

    event void BlockWrite0.commitDone(storage_result_t result) {}
    event void BlockRead0.verifyDone(storage_result_t result) {}
    event void BlockRead0.computeCrcDone(storage_result_t result, uint16_t crc, block_addr_t addr, block_addr_t len) {}

    default event void FlashAccess.eraseDone(result_t success) { }
    default event void FlashAccess.writeDone(uint8_t *data, uint8_t size, result_t success) { }
    default event void FlashAccess.readDone(uint8_t* buffer, uint8_t size, result_t success) { }

}

