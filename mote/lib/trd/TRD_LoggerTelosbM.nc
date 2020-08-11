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
 * TRD packet logger module for TelosB platform.
 * - 1 logical volume corresponds to 2 physical volumes.
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 2/26/2006
 **/


#include "trd.h"
#include "TRD_Logger.h"

module TRD_LoggerTelosbM
{
    provides {
        interface StdControl;
        interface TRD_Logger as Logger;
    }
    uses {
        interface Mount as Mount0;
        interface Mount as Mount1;
        interface BlockWrite as BlockWrite0;
        interface BlockWrite as BlockWrite1;
        interface BlockRead as BlockRead0;
        interface BlockRead as BlockRead1;
        interface Leds;
        //interface Timer as ReMountTimer; //avoid conflict with other flash user
    }
}

implementation
{

    struct bufferInfo {
        uint8_t ready;
        uint8_t currVol;  // primary(0) or secondary(1)
        uint8_t dirty0;
        uint8_t dirty1;
        uint8_t initState;
    } bInfo;

    uint16_t curr_flash_vptr;
    
    enum {
        S_MOUNT     = 0x1,
        S_INIT      = 0x2,
        S_IDLE      = 0x3,
        S_ERASE_VOL = 0x4
    };  

    command result_t StdControl.init() {
        bInfo.ready = FALSE;
        bInfo.currVol = 0;
        bInfo.dirty0 = FALSE;
        bInfo.dirty1 = FALSE;
        bInfo.initState = S_MOUNT;
        curr_flash_vptr = 0;
        call Leds.init();
        return SUCCESS;
    }

    command result_t StdControl.start() {
        // below should be done strictly after StdControl.init();
        //  where as in Micaz this should be strictly within StdControl.init();
        if (TRD_FLASH_BYTES > STORAGE_BLOCK_SIZE)   // 64KB
            return FAIL;
        //call ReMountTimer.start(TIMER_ONE_SHOT, 6000);
            /* The problem is that other modules also attempt to mount & erase
               telosb flash in StdControl.start().
               This causes conflict, and mount to fail.
               One quick hack is to just retry few seconds later
               at the cost of 12byte RAM for additional Timer here */
        if (call Mount0.mount(VOL_ID0) == FAIL) {
            call Leds.redOn();
        }
        return SUCCESS;
    }
/*
    event result_t ReMountTimer.fired() {
        if (call Mount0.mount(VOL_ID6) == FAIL) {
            call Leds.redOn();
            call ReMountTimer.start(TIMER_ONE_SHOT, 1000);
        }
        return SUCCESS;
    }
*/      
    command result_t StdControl.stop() {
        return SUCCESS;
    }

    result_t _erase(uint8_t vol) {
        if (vol == 0)
            return call BlockWrite0.erase();
        else if (vol == 1)
            return call BlockWrite1.erase();
        return FAIL;
    }
/*
    command result_t Logger.erase() {
        if (bInfo.initState != S_IDLE)
            return FAIL;
        bInfo.initState = S_ERASE_VOL;
        bInfo.ready = FALSE;    // This will erase both volumes (2*id) and (2*id + 1)
        bInfo.currVol = 0;
        curr_flash_vptr = 0;
        return _erase(0);
    }
*/
    command result_t Logger.init() { // This will erase ALL volumes!!!
        if (bInfo.initState == S_IDLE)  // in idle. mount was done.
            _erase(0);              // start erasing all volumes
//        else if (bInfo.initState == S_ERASE_VOL)
//            return FAIL;    // conflicting calls. erase_all after erase_one!!
        bInfo.initState = S_INIT;
        return SUCCESS;
    }

    command result_t Logger.write(uint16_t *memloc, uint8_t *data, uint8_t size) {
        uint16_t virtual_addr = curr_flash_vptr;
        uint32_t physical_addr = virtual_addr * TRD_FLASH_PKT_SIZE;
        result_t result = FAIL;

        if (bInfo.initState != S_IDLE)
            return FAIL;
        if (size > TRD_FLASH_PKT_SIZE)
            return FAIL;
        if (((bInfo.currVol == 0) && (bInfo.dirty0)) ||
            ((bInfo.currVol == 1) && (bInfo.dirty1))) { // before eraseDone
            return FAIL;
        }
        if (bInfo.currVol == 0)
            result = call BlockWrite0.write(physical_addr, data, (uint32_t)size);
        else if (bInfo.currVol == 1)
            result = call BlockWrite1.write(physical_addr, data, (uint32_t)size);

        if (result == SUCCESS) {
            *memloc = virtual_addr;
            curr_flash_vptr++;
            if (curr_flash_vptr >= TRD_FLASH_NUM_PKTS)
                curr_flash_vptr = 0;    // flash wrap-around
        }
        return result;
    }

    void _writeDone(uint8_t vol, storage_result_t result, block_addr_t addr, void* buf, block_addr_t len)
    {
        if (result != STORAGE_OK) {
            signal Logger.writeDone(buf, len, FAIL);
            return;
        }
        if (curr_flash_vptr == 0) {
            if (bInfo.currVol == 0) {
                bInfo.dirty0 = TRUE;    // this volume is full
                bInfo.currVol = 1;    // change to the other volume
            } else {
                bInfo.dirty1 = TRUE;    // this volume is full
                bInfo.currVol = 0;    // change to the other volume
            }

            if (bInfo.currVol == 0) {
                if (bInfo.dirty0)   // if that is also full,
                    _erase(0);
            } else {
                if (bInfo.dirty1)   // if that is also full,
                    _erase(1);
            }
        }
        signal Logger.writeDone(buf, (uint8_t)len, SUCCESS);
    }

    event void BlockWrite0.writeDone(storage_result_t result, block_addr_t addr, void* buf, block_addr_t len) {
        _writeDone(0, result, addr, buf, len);
    }
    event void BlockWrite1.writeDone(storage_result_t result, block_addr_t addr, void* buf, block_addr_t len) {
        _writeDone(1, result, addr, buf, len);
    }


    command result_t Logger.read(uint16_t memloc, uint8_t* buffer) {
        uint8_t vol;
        uint32_t size = (uint32_t) TRD_FLASH_PKT_SIZE;
        uint32_t physical_addr = memloc * TRD_FLASH_PKT_SIZE;
        result_t result = FAIL;

        if (bInfo.initState != S_IDLE)
            return FAIL;
        if (memloc > TRD_FLASH_NUM_PKTS)
            return FAIL;

        if (memloc < curr_flash_vptr) {
            vol = bInfo.currVol;
        } else {
            if (bInfo.currVol == 0)
                vol = 1;
            else
                vol = 0;
        }

        if (vol == 0)
            result = call BlockRead0.read(physical_addr, buffer, size);
        else if (vol == 1)
            result = call BlockRead1.read(physical_addr, buffer, size);
        return result;
    }


    void _readDone(uint8_t vol, storage_result_t result, block_addr_t addr, 
                   void* buf, block_addr_t len) {
        if (result == STORAGE_OK) {
            //signal Logger.readDone(buf, (uint8_t)len, SUCCESS);
            signal Logger.readDone(buf, SUCCESS);
        } else {
            //signal Logger.readDone(buf, (uint8_t)len, FAIL);
            signal Logger.readDone(buf, FAIL);
        }
    }

    event void BlockRead0.readDone(storage_result_t result, block_addr_t addr, void* buf, block_addr_t len) {
        _readDone(0, result, addr, buf, len);
    }
    event void BlockRead1.readDone(storage_result_t result, block_addr_t addr, void* buf, block_addr_t len) {
        _readDone(1, result, addr, buf, len);
    }

    event void Mount0.mountDone(storage_result_t result, volume_id_t id) {
        if (result == STORAGE_OK) {
            if (call Mount1.mount(VOL_ID1) == SUCCESS)
                return;
        }
    }
    event void Mount1.mountDone(storage_result_t result, volume_id_t id) {
        if (result == STORAGE_OK) {
            if (bInfo.initState == S_MOUNT) // init(=erase_all) not requested
                bInfo.initState = S_IDLE;       // go idle
            else if (bInfo.initState == S_INIT) // init(=erase_all) requested
                _erase(0);                  // start erasing all volumes
        }
    }

    event void BlockWrite0.eraseDone(storage_result_t result) {
        bInfo.dirty0 = FALSE;
        if (result != STORAGE_OK) {
        /*
            if (bInfo.initState == S_ERASE_VOL) {
                signal Logger.eraseDone(FAIL);
                bInfo.initState = S_IDLE;
            }
        */
        } else if (!bInfo.ready)
            _erase(1);
    }

    event void BlockWrite1.eraseDone(storage_result_t result) {
        bInfo.dirty1 = FALSE;
        if (!bInfo.ready) {
            bInfo.ready = TRUE;
            if (bInfo.initState == S_INIT) {    // init(=erase_all) requested
                bInfo.initState = S_IDLE;
                signal Logger.initDone(SUCCESS);
            }
            /* 
            else {
                if (result == STORAGE_OK)
                    signal Logger.eraseDone(SUCCESS);
                else
                    signal Logger.eraseDone(FAIL);
                bInfo.initState = S_IDLE;
            }
            */
        }
    }

    event void BlockWrite0.commitDone(storage_result_t result) {}
    event void BlockWrite1.commitDone(storage_result_t result) {}

    event void BlockRead0.verifyDone(storage_result_t result) {}
    event void BlockRead1.verifyDone(storage_result_t result) {}

    event void BlockRead0.computeCrcDone(storage_result_t result, uint16_t crc, block_addr_t addr, block_addr_t len) {}
    event void BlockRead1.computeCrcDone(storage_result_t result, uint16_t crc, block_addr_t addr, block_addr_t len) {}


    default event void Logger.initDone(result_t success) {}
    //default event void Logger.eraseDone(result_t success) {}
    default event void Logger.writeDone(uint8_t *data, uint8_t size, result_t succ) {}
    //default event void Logger.readDone(uint8_t* buffer, uint8_t size, result_t succ) {}
    default event void Logger.readDone(uint8_t* buffer, result_t succ) {}

}

