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
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 1/24/2007
 **/

#include "StrLogger.h"

configuration StrLoggerC {
    provides {
        interface StdControl;
        interface TrPktLogger as PktLogger;
    }
}
implementation
{
    components 
        #if defined(PLATFORM_TELOSB) || defined(PLATFORM_TMOTE)
            #ifdef STR_2_CON
                StrLoggerTelosbM2 as PktLoggerM
            #else
                StrLoggerTelosbM as PktLoggerM
            #endif
                , BlockStorageC
                , TimerC
        #elif defined(PLATFORM_IMOTE2)
                StrLoggerRAM as PktLoggerM
        #else   // Micaz, Mica2, (and maybe TelosA)
                StrLoggerMicazM as PktLoggerM
            #ifdef MDA400
                , ByteEEPROMVBwrapperC as ByteEEPROM
            #elif MDA420
                # Not supported!!
            #else
                , ByteEEPROM
            #endif
        #endif
                , LedsC
                ;

    StdControl = PktLoggerM;
    PktLogger = PktLoggerM;

#if defined(PLATFORM_TELOSB) || defined(PLATFORM_TMOTE)
    StdControl = TimerC;
    PktLoggerM.ReMountTimer -> TimerC.Timer[unique("Timer")];
    PktLoggerM.Mount0 -> BlockStorageC.Mount[STR_BLOCK_ID0];
    PktLoggerM.Mount1 -> BlockStorageC.Mount[STR_BLOCK_ID1];
    PktLoggerM.BlockWrite0 -> BlockStorageC.BlockWrite[STR_BLOCK_ID0];
    PktLoggerM.BlockWrite1 -> BlockStorageC.BlockWrite[STR_BLOCK_ID1];
    PktLoggerM.BlockRead0 -> BlockStorageC.BlockRead[STR_BLOCK_ID0];
    PktLoggerM.BlockRead1 -> BlockStorageC.BlockRead[STR_BLOCK_ID1];
    #ifdef STR_2_CON
    PktLoggerM.Mount2 -> BlockStorageC.Mount[STR_BLOCK_ID2];
    PktLoggerM.Mount3 -> BlockStorageC.Mount[STR_BLOCK_ID3];
    PktLoggerM.BlockWrite2 -> BlockStorageC.BlockWrite[STR_BLOCK_ID2];
    PktLoggerM.BlockWrite3 -> BlockStorageC.BlockWrite[STR_BLOCK_ID3];
    PktLoggerM.BlockRead2 -> BlockStorageC.BlockRead[STR_BLOCK_ID2];
    PktLoggerM.BlockRead3 -> BlockStorageC.BlockRead[STR_BLOCK_ID3];
    #endif
#elif defined(PLATFORM_IMOTE2)
    /* nothing else to wire. imote will just use RAM */
#else
    PktLoggerM.LoggerControl -> ByteEEPROM.StdControl;
    PktLoggerM.AllocationReq -> ByteEEPROM.AllocationReq[STR_BYTE_EEPROM_ID];
    PktLoggerM.WriteData -> ByteEEPROM.WriteData[STR_BYTE_EEPROM_ID];
    PktLoggerM.ReadData -> ByteEEPROM.ReadData[STR_BYTE_EEPROM_ID];
#endif
    PktLoggerM.Leds -> LedsC;
}

