
/*
 * Authors: Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 */

/**
 * @author Jeongyeup Paek
 * @modified Oct/13/2005
 */

includes VBTimeSync;

configuration VBTimeSyncC {
    provides interface StdControl;
    uses interface VBTimeSync;
}

implementation 
{
    components VBTimeSyncM, 
               Main, TimerC, 
               MDA400ControlC,
        #ifdef TIMESYNC_SYSTIME
               SysTimeC;
        #else
               ClockC;
        #endif

    Main.StdControl -> TimerC;

    StdControl = VBTimeSyncM;
    VBTimeSync = VBTimeSyncM;
    
    VBTimeSyncM.VBTimeSync -> MDA400ControlC.VBTimeSync;
    VBTimeSyncM.Timer -> TimerC.Timer[unique("Timer")];

#ifdef TIMESYNC_SYSTIME
    VBTimeSyncM.SysTime -> SysTimeC;
#else
    VBTimeSyncM.LocalTime -> ClockC;
#endif
}

