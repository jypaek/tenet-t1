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
 * Configuration file for TRD packet logger.
 *
 * This file performs necessary platform-dependant wiring to provide
 * platform-independant interface to the TRD module.
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 2/5/2007
 **/

#include "TRD_Logger.h"

configuration TRD_LoggerC {
    provides {
        interface StdControl;
        interface TRD_Logger as Logger;
    }
}
implementation
{
    components 
        #ifdef RAM_TRD
                TRD_LoggerRAM as LoggerM
        #elif defined(PLATFORM_TELOSB) || defined(PLATFORM_TMOTE)
                TRD_LoggerTelosbM as LoggerM
                , BlockStorageC
                , LedsC
        #elif defined(PLATFORM_PC)
                TRD_LoggerPCM as LoggerM
                , BulkLoggerC
        #elif defined(PLATFORM_MICAZ) || defined(PLATFORM_MICA2) || defined(PLATFORM_MICA2DOT)
            #ifdef MDA400
                TRD_LoggerMicazM as LoggerM
                , ByteEEPROMVBwrapperC as ByteEEPROM
            #elif MDA420
                TRD_LoggerRAM as LoggerM
            #else
                TRD_LoggerMicazM as LoggerM
                , ByteEEPROM
            #endif
        #endif
                ;
        
    StdControl = LoggerM;
    Logger = LoggerM;

#ifdef RAM_TRD
    /* Nothing more to wire */
#elif defined(PLATFORM_PC)
    LoggerM.LoggerControl -> BulkLoggerC.StdControl;
    LoggerM.BulkLoggerWrite -> BulkLoggerC.BulkLoggerWrite;
    LoggerM.BulkLoggerRead -> BulkLoggerC.BulkLoggerRead;
#elif defined(PLATFORM_TELOSB) || defined(PLATFORM_TMOTE)
    LoggerM.Mount0 -> BlockStorageC.Mount[BLOCK_ID0];
    LoggerM.Mount1 -> BlockStorageC.Mount[BLOCK_ID1];
    LoggerM.BlockWrite0 -> BlockStorageC.BlockWrite[BLOCK_ID0];
    LoggerM.BlockWrite1 -> BlockStorageC.BlockWrite[BLOCK_ID1];
    LoggerM.BlockRead0 -> BlockStorageC.BlockRead[BLOCK_ID0];
    LoggerM.BlockRead1 -> BlockStorageC.BlockRead[BLOCK_ID1];
    LoggerM.Leds -> LedsC;
#elif defined(PLATFORM_MICAZ) || defined(PLATFORM_MICA2) || defined(PLATFORM_MICA2DOT)
    LoggerM.LoggerControl -> ByteEEPROM.StdControl;
    LoggerM.AllocationReq -> ByteEEPROM.AllocationReq[TRD_BYTE_EEPROM_ID];
    LoggerM.WriteData -> ByteEEPROM.WriteData[TRD_BYTE_EEPROM_ID];
    LoggerM.ReadData -> ByteEEPROM.ReadData[TRD_BYTE_EEPROM_ID];
#endif
}

