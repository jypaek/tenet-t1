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
 * RCRT packet logger module for telosb.
 * - support only 1 connection at a time (uses 2 flash volume)
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 3/26/2007
 **/


#include "TrLoggerMote.h"
#include "RtrLogger.h"

module RtrLoggerTelosbM
{
    provides {
        interface StdControl;
        interface TrPktLogger as PktLogger;
    }
    uses {
        interface Mount as Mount0;
        interface Mount as Mount1;
        interface BlockWrite as BlockWrite0;
        interface BlockWrite as BlockWrite1;
        interface BlockRead as BlockRead0;
        interface BlockRead as BlockRead1;
        interface Timer as ReMountTimer; //avoid conflict with other flash user
        interface Leds;
    }
}

implementation
{

    struct bufferInfo b;

    uint8_t m_state;
    
    command result_t StdControl.init() {
        b.ready = FALSE;
        b.currVol = 0;
        b.nextIndex = 0;
        b.dirty0 = FALSE;
        b.dirty1 = FALSE;
        m_state = S_MOUNT;
        call Leds.init();
        return SUCCESS;
    }

    command result_t StdControl.start() {
        // below should be done strictly after StdControl.init();
        //  where as in Micaz this should be strictly within StdControl.init();
        result_t result = SUCCESS;
        if (TR_FLASH_BYTES_PER_CON > STORAGE_BLOCK_SIZE)  // 64KB
            result = FAIL;
        if (result != FAIL)
            call ReMountTimer.start(TIMER_ONE_SHOT, 10000);
        else
            call Leds.redOn();
        return result;
    }

    command result_t StdControl.stop() {
        return SUCCESS;
    }

    event result_t ReMountTimer.fired() {
        if (!call Mount0.mount(RCRT_VOL_ID0)) {
            call Leds.redOn();
            call ReMountTimer.start(TIMER_ONE_SHOT, 1000);
        }
        return SUCCESS;
    }
      
    result_t _erase(uint8_t vol) {
        result_t result = FAIL;
        if (vol == 0)
            result = call BlockWrite0.erase();
        else if (vol == 1)
            result = call BlockWrite1.erase();
        if (result != SUCCESS)
            call Leds.redOn();
        return result;
    }

    command result_t PktLogger.erase(uint8_t id) {
        if (id >= RCRT_NUM_VOLS)
            return FAIL;
        if (m_state != S_IDLE)
            return FAIL;
        m_state = S_ERASE_VOL;
        b.ready = FALSE;    // This will erase both volumes (2*id) and (2*id + 1)
        b.currVol = 0;
        b.nextIndex = 0;
        return _erase(0);
    }

    command result_t PktLogger.init() {  // This will erase ALL volumes!!!
        if (m_state == S_IDLE) {         // in idle. mount was done.
            _erase(0);                     // start erasing all volumes
        } else if (m_state != S_MOUNT) { // either in INIT or ERASE_VOL state
            return FAIL;    // conflicting calls.
        }
        b.ready = FALSE;    // This will erase both volumes (2*id) and (2*id + 1)
        b.currVol = 0;
        b.nextIndex = 0;
        m_state = S_INIT;
        return SUCCESS;
    }

    result_t _write(uint8_t vol, uint32_t offset, uint8_t *data, uint32_t size) {
        result_t result = FAIL;
        if (vol == 0)
            result = call BlockWrite0.write(offset, data, size);
        else if (vol == 1)
            result = call BlockWrite1.write(offset, data, size);
        return result;
    }

    // Assumes sequential write (log). You cannot write seqno=10 after seqno=11.
    command result_t PktLogger.write(uint8_t id, uint16_t seqno, uint8_t *data, uint8_t size) {
        //seqno are 1 ~ TR_MAX_SEQNO, not 0 ~.
        uint16_t data_idx = (seqno - 1) % TR_FLASH_PKTS_PER_CON;
        // TR_MAX_SEQNO should be multiples of (2*TR_FLASH_PKTS_PER_CON)
        uint32_t offset;
        uint8_t vol;

        offset = (uint32_t)data_idx * TR_FLASH_BYTES_PER_PKT;

        if (size > TR_FLASH_BYTES_PER_PKT) {
            return FAIL;
        } else if (seqno > TR_MAX_SEQNO) {
            return FAIL;
        } else if (data_idx != b.nextIndex) {   // assumes sequential write
            return FAIL;
        } else if (((b.currVol == 0) && (b.dirty0)) ||
                   ((b.currVol == 1) && (b.dirty1))) {  // before eraseDone
            return FAIL;
        } else if (m_state != S_IDLE) {
            return FAIL;
        }

        vol = b.currVol;
        
        if (_write(vol, offset, data, (uint32_t)size) == FAIL)
            return FAIL;

        b.nextIndex = data_idx + 1;
        if (b.nextIndex >= TR_FLASH_PKTS_PER_CON)
            b.nextIndex = 0;
        return SUCCESS;
    }

    void _writeDone(uint8_t vol, storage_result_t result, block_addr_t addr, void* buf, block_addr_t len)
    {
        if (result != STORAGE_OK) {
            signal PktLogger.writeDone(buf, (uint8_t)len, FAIL);
            return;
        }
        if (b.nextIndex == 0) {
            if (b.currVol == 0) {
                b.dirty0 = TRUE;    // this volume is full
                b.currVol = 1;      // change to the other volume
            } else {
                b.dirty1 = TRUE;    // this volume is full
                b.currVol = 0;      // change to the other volume
            }
            if (b.currVol == 0) {
                if (b.dirty0) { // if that is also full,
                    _erase(0);
                }
            } else {
                if (b.dirty1) { // if that is also full,
                    _erase(1);
                }
            }
        }
        signal PktLogger.writeDone(buf, len, SUCCESS);
    }

    event void BlockWrite0.writeDone(storage_result_t result, block_addr_t addr, void* buf, block_addr_t len) {
        _writeDone(0, result, addr, buf, len);
    }
    event void BlockWrite1.writeDone(storage_result_t result, block_addr_t addr, void* buf, block_addr_t len) {
        _writeDone(1, result, addr, buf, len);
    }

    result_t _read(uint8_t vol, uint32_t offset, uint8_t* buffer, uint32_t size) {
        result_t result = FAIL;
        if (vol == 0)
            result = call BlockRead0.read(offset, buffer, size);
        else if (vol == 1)
            result = call BlockRead1.read(offset, buffer, size);
        return result;
    }

    command result_t PktLogger.read(uint8_t id, uint16_t seqno, uint8_t* buffer) {
        uint16_t data_idx = (seqno - 1) % TR_FLASH_PKTS_PER_CON;
        uint32_t offset = (uint32_t)data_idx * TR_FLASH_BYTES_PER_PKT;
        uint8_t vol;

        if (seqno > TR_MAX_SEQNO) { // TR_MAX_SEQNO == 2*TR_FLASH_PKTS_PER_CON
            return FAIL;
        } else if (m_state != S_IDLE) {
            return FAIL;
        }

        if ((((seqno - 1)/TR_FLASH_PKTS_PER_CON) % 2) == 0) {
            vol = 0;
        } else {
            vol = 1;
        }
        if (_read(vol, offset, buffer, TR_FLASH_BYTES_PER_PKT) == FAIL)
            return FAIL;
        return SUCCESS;
    }


    void _readDone(uint8_t vol, storage_result_t result, block_addr_t addr, void* buf, block_addr_t len) {
        if (result == STORAGE_OK) {
            signal PktLogger.readDone(buf, len, SUCCESS);
        } else {
            signal PktLogger.readDone(buf, len, FAIL);
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
            if (call Mount1.mount(RCRT_VOL_ID1) == SUCCESS)
                return;
        }
        if (m_state == S_INIT)   // init(=erase_all) requested
            signal PktLogger.initDone(FAIL);
        call Leds.redOn();
    }
    event void Mount1.mountDone(storage_result_t result, volume_id_t id) {
        if (result == STORAGE_OK) {
            if (m_state == S_MOUNT)   // init(=erase_all) not requested
                m_state = S_IDLE;     // go idle
            else if (m_state == S_INIT)   // init(=erase_all) requested
                _erase(0);                // start erasing all volumes
            else
                call Leds.redOn();
        } else {
            if (m_state == S_INIT)   // init(=erase_all) requested
                signal PktLogger.initDone(FAIL);
            call Leds.redOn();
        }
    }

    event void BlockWrite0.eraseDone(storage_result_t result) {
        b.dirty0 = FALSE;
        if (result != STORAGE_OK) {
            if (m_state == S_ERASE_VOL) {
                signal PktLogger.eraseDone(0, FAIL);
            } else if (m_state == S_INIT) {   // init(=erase_all) requested
                signal PktLogger.initDone(FAIL);
            }
            m_state = S_IDLE;
            call Leds.redOn();
        } else if ((!b.ready) || (m_state == S_INIT)) {
            _erase(1);
        } else {
            // erase was called internally, because of write wrap-around.
        }
    }
    event void BlockWrite1.eraseDone(storage_result_t result) {
        b.dirty1 = FALSE;
        if (result != STORAGE_OK) {
            if (m_state == S_ERASE_VOL) {
                signal PktLogger.eraseDone(0, FAIL);
            } else if (m_state == S_INIT) {   // init(=erase_all) requested
                signal PktLogger.initDone(FAIL);
            }
            m_state = S_IDLE;
            call Leds.redOn();
        } else if ((!b.ready) || (m_state == S_INIT)) {
            b.ready = TRUE;
            if (m_state == S_INIT) {  // init(=erase_all) requested
                signal PktLogger.initDone(SUCCESS);
                call Leds.redOff();
            } else if (m_state == S_ERASE_VOL) {
                signal PktLogger.eraseDone(0, SUCCESS);
            }
            m_state = S_IDLE;
        } else {
            // erase was called internally, because of write wrap-around.
        }
    }

    event void BlockWrite0.commitDone(storage_result_t result) {}
    event void BlockWrite1.commitDone(storage_result_t result) {}

    event void BlockRead0.verifyDone(storage_result_t result) {}
    event void BlockRead1.verifyDone(storage_result_t result) {}

    event void BlockRead0.computeCrcDone(storage_result_t result, uint16_t crc, block_addr_t addr, block_addr_t len) {}
    event void BlockRead1.computeCrcDone(storage_result_t result, uint16_t crc, block_addr_t addr, block_addr_t len) {}

    default event void PktLogger.initDone(result_t success) { }
    default event void PktLogger.eraseDone(uint8_t id, result_t success) { }
    default event void PktLogger.writeDone(uint8_t *data, uint8_t size, result_t success) { }
    default event void PktLogger.readDone(uint8_t* buffer, uint8_t size, result_t success) { }

}

