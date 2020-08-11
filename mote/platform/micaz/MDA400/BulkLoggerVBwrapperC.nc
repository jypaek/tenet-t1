
/*
 * Authors: Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 */

/**
 * @author Jeongyeup Paek
 * @modified Oct/13/2005
 */


//////////////////////////////////////////////////////////////////
// BulkLoggerVBwrapperC
//  - This module is built on top of BulkLoggerC module.
//  - This module takes care of suspend/resume of VBoard.
//  - Suspend/resume is performed in per-bulk bases, not per-line
//////////////////////////////////////////////////////////////////

configuration BulkLoggerVBwrapperC {
    provides {
        interface StdControl;
        interface BulkLoggerWrite;
        interface BulkLoggerRead;
    }
}
implementation {
    components BulkLoggerC as Logger,
        #ifdef MDA400
            MDA400ControlC as VBoard,
        #elif MDA420
            MDA420ControlC as VBoard,
        #endif
            BulkLoggerVBwrapperM as WrapperM,
            LedsC;

    StdControl = WrapperM;
    BulkLoggerWrite = WrapperM;
    BulkLoggerRead = WrapperM;

    WrapperM.VBStdControl -> VBoard.StdControl;
    WrapperM.VBSRControl -> VBoard.VBSRControl[0];

    WrapperM.B_LoggerControl -> Logger.StdControl;
    WrapperM.B_LoggerWrite -> Logger.BulkLoggerWrite;
    WrapperM.B_LoggerRead -> Logger.BulkLoggerRead;

    WrapperM.Leds -> LedsC.Leds;

}

