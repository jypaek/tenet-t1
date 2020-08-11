
/*
 * Authors: Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 */

/**
 * @author Jeongyeup Paek
 * @modified Oct/13/2005
 */


//////////////////////////////////////////////////////////////////
// ByteByteEEPROMVBwrapperC
//  - This module is built on top of ByteByteEEPROMC module.
//  - This module takes care of suspend/resume of VBoard.
//  - Suspend/resume is performed in per-bulk bases, not per-line
//////////////////////////////////////////////////////////////////

configuration ByteEEPROMVBwrapperC {
    provides {
        interface StdControl;
        interface AllocationReq[uint8_t id];
        interface WriteData[uint8_t id];
        interface ReadData[uint8_t id];
        //interface LogData;
    }
}
implementation {
    components 
            ByteEEPROMVBwrapperM as WrapperM,
            //ByteEEPROMSingleC as ByteEEPROM,
            ByteEEPROM,
        #ifdef MDA400
            MDA400ControlC as VBoard,
        #elif MDA420
            # not supported!!
        #endif
            LedsC;

    StdControl = WrapperM;
    WriteData = WrapperM;
    ReadData = WrapperM;
    AllocationReq = ByteEEPROM;

    WrapperM.VBStdControl -> VBoard.StdControl;
    WrapperM.VBSRControl -> VBoard.VBSRControl[0];

    WrapperM.ByteEEPROMStdControl -> ByteEEPROM.StdControl;
    WrapperM.WriteDataReal -> ByteEEPROM.WriteData;
    WrapperM.ReadDataReal -> ByteEEPROM.ReadData;

    WrapperM.Leds -> LedsC.Leds;

}

