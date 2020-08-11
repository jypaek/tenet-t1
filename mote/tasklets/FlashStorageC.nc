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
 * @author Jeongyeup Paek (jpaek@usc.edu)
 *
 * @modified Mar/3/2009
 **/

#include "FlashStorage.h"

configuration FlashStorageC {
    provides {
        interface StdControl;
        interface Element;
    }
    uses {
        interface TenetTask;
        interface List;
        interface Schedule;
        interface Memory;
        interface TaskError;
    }
}
implementation
{
    components FlashStorage
        #if defined(PLATFORM_TELOSB) || defined(PLATFORM_TMOTE)
                , FlashStorageTelosbM as StoragePlatform
                , BlockStorageC
                , TimerC, MainC
        #else   // Micaz, Mica2, (and maybe TelosA)
                , FlashStoragePlatformicazM as StoragePlatform
                , ByteEEPROM
        #endif
                , LedsC
                ;

    /* provided interfaces */
    StdControl = FlashStorage;
    Element    = FlashStorage;

    /* used interfaces */
    TenetTask  = FlashStorage;
    List       = FlashStorage;
    Schedule   = FlashStorage;
    Memory     = FlashStorage;
    TaskError  = FlashStorage;

    /* internal wirings */
    FlashStorage.FlashAcces -> StoragePlatform;


#if defined(PLATFORM_TELOSB) || defined(PLATFORM_TMOTE)
    Main.StdControl -> TimerC;
    StoragePlatform.ReMountTimer -> TimerC.Timer[unique("Timer")];
    StoragePlatform.Mount0 -> BlockStorageC.Mount[STR_BLOCK_ID0];
    StoragePlatform.BlockWrite0 -> BlockStorageC.BlockWrite[STR_BLOCK_ID0];
    StoragePlatform.BlockRead0 -> BlockStorageC.BlockRead[STR_BLOCK_ID0];
#else
    StoragePlatform.LoggerControl -> ByteEEPROM.StdControl;
    StoragePlatform.AllocationReq -> ByteEEPROM.AllocationReq[STR_BYTE_EEPROM_ID];
    StoragePlatform.WriteData -> ByteEEPROM.WriteData[STR_BYTE_EEPROM_ID];
    StoragePlatform.ReadData -> ByteEEPROM.ReadData[STR_BYTE_EEPROM_ID];
#endif
    StoragePlatform.Leds -> LedsC;
}

