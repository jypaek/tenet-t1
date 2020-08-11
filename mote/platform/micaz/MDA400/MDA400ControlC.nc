
/*
 * Authors: Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 */

/**
 * @author Jeongyeup Paek
 * @modified Oct/13/2005
 */

/* We seperated the interface VBoard.nc into two interfaces,
    - VBSRControl.nc : for suspend/resume control only
    - MDA400Control.nc : for all other control (init,start,stop,power..etc)
   By doing this, we seperated the responsibility of 
    - Making sure that VBoard does not interfere with it's own job.
    - Use (turning on/off, init, etc) of VBoard.
*/

#ifndef MDA400
    # You should define 'MDA400' in the Makefile
      to make sure that correct components are included
#endif

configuration MDA400ControlC { 
    provides {
        interface StdControl;
        interface MDA400I as VBControl;
        interface VBSRControl[uint8_t id];
        interface VBLock;
        interface VBTimeSync;
    }
}

implementation {
    components MDA400ControlM, 
               MDA400C, 
               VBTimeSyncC,
               LedsC;

    StdControl = MDA400ControlM.StdControl;
    VBControl = MDA400ControlM.MDA400Control;
    VBSRControl = MDA400ControlM.VBSRControl;
    VBLock = MDA400ControlM.VBLock;
    VBTimeSync = MDA400ControlM.VBTimeSync;

    MDA400ControlM.VBStdControl -> MDA400C.StdControl;
    MDA400ControlM.MDA400Real -> MDA400C.MDA400I;
    MDA400ControlM.MDA400SRControl -> MDA400C.VBSRControl;

    MDA400ControlM.MDA400TimeSync -> MDA400C;
    MDA400ControlM.VBTSStdControl -> VBTimeSyncC;

    MDA400ControlM.Leds -> LedsC;
}

