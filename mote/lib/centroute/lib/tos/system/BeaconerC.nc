includes Beaconer;

configuration BeaconerC 
{
    provides {
        interface StdControl;
        interface BeaconerI[uint8_t id];
    }
}


implementation {

    components
        BeaconerM,
        PktQueueC,
#ifdef EMSTAR_NO_KERNEL
        EmTimerC,
#else
        TimerC,
#endif      
#ifdef NODE_HEALTH
        NodeHealthC,
#endif
     GenericComm as Comm;   

    StdControl = BeaconerM.StdControl;
    BeaconerI = BeaconerM.BeaconerI;

    BeaconerM.PktQueue -> PktQueueC.PktQueueI[unique("PktQueueI")];

    BeaconerM.SendMsg -> PktQueueC.SendMsg[BEACON_MSG_TYPE];
    BeaconerM.ReceiveMsg -> Comm.ReceiveMsg[BEACON_MSG_TYPE];
#ifdef EMSTAR_NO_KERNEL
    BeaconerM.BeaconerTimer -> EmTimerC.EmTimerI[unique("Timer")];
#else
    BeaconerM.BeaconerTimer -> TimerC.Timer[unique("Timer")];
#endif


#ifdef NODE_HEALTH
    BeaconerM.NodeHealthI -> NodeHealthC.NodeHealthI;
#endif
}
