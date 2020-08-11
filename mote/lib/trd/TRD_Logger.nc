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
 * Interface for TRD packet logger.
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 2/26/2006
 **/

interface TRD_Logger {

    /* init
        - In TelosB, erase all volumes prior to use.
        - In Mica2/MicaZ, initDone is signaled when allocation is done.
    */
    command result_t init();

    event void initDone(result_t success);

    /**
     * Write 'data' of length 'size' into the flash.
     *  - returns the memory location in *memloc where *data is writen.
     *  - size can be less than BYTES_PER_PKT, but that amount is allocated.
     **/
    command result_t write(uint16_t *memloc, uint8_t *data, uint8_t size);      

    event void writeDone(uint8_t *data, uint8_t size, result_t success);

    command result_t read(uint16_t memloc, uint8_t* buffer);

    event void readDone(uint8_t* buffer, result_t success);
}

