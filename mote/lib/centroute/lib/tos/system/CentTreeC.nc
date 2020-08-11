//includes RnpLink;
includes CentTree;

configuration CentTreeC
{
    provides {
        interface StdControl;
        interface CentTreeCtrlI;
        interface RoutingTable;

        interface CentTreeSinkI;
        interface CentTreeSendI[uint8_t id];
        interface CentTreeSendStatusI[uint8_t id];
        interface CentTreeRecvI[uint8_t id];
    }
}


implementation {

    components
        CentTreeM,
        JoinerC,
        DupCheckerC,
        LinkTestC,
        //RnpLinkC as Comm,
#ifdef EMSTAR_NO_KERNEL
        EmTimerC,
        //EmSocketC,
	GenericComm as Comm,
	
#else
        TimerC,
        GenericComm as Comm,
#endif

//        PktQueue_RnpC as PktQueueC,
        PktQueueC,
#ifdef NODE_HEALTH
    NodeHealthC,
#endif
	LedsC,
        StatsC;

    StdControl = CentTreeM.StdControl;
#ifdef EMSTAR_NO_KERNEL
    //StdControl = EmSocketC;
    StdControl = Comm;
#else    
    StdControl = Comm;
    
#endif
    StdControl = JoinerC;
    StdControl = StatsC;
    StdControl = DupCheckerC;
    StdControl = LinkTestC;
    CentTreeSendI = CentTreeM.CentTreeSendI;
    CentTreeSendStatusI = CentTreeM.CentTreeSendStatusI;
    CentTreeRecvI = CentTreeM.CentTreeRecvI;
    CentTreeCtrlI = CentTreeM.CentTreeCtrlI;
    CentTreeSinkI = CentTreeM.CentTreeSinkI;
    
    CentTreeM.Leds -> LedsC;

    RoutingTable = CentTreeM.RoutingTable;
//    CentTreeM.RnpLinkI -> Comm;

    CentTreeM.SendMsg -> PktQueueC.SendMsg[CENTTREE_MSG_TYPE];
#ifdef EMSTAR_NO_KERNEL
    //CentTreeM.ReceiveMsg -> EmSocketC.ReceiveMsg;
    CentTreeM.ReceiveMsg -> Comm.ReceiveMsg[CENTTREE_MSG_TYPE];
#else
    CentTreeM.ReceiveMsg -> Comm.ReceiveMsg[CENTTREE_MSG_TYPE];
#endif

    CentTreeM.PktQ1 -> PktQueueC.PktQueueI[unique("PktQueueI")];
    CentTreeM.PktQ2 -> PktQueueC.PktQueueI[unique("PktQueueI")];
    CentTreeM.PktQ3 -> PktQueueC.PktQueueI[unique("PktQueueI")];
    CentTreeM.PktQ4 -> PktQueueC.PktQueueI[unique("PktQueueI")];
    CentTreeM.PktQ5 -> PktQueueC.PktQueueI[unique("PktQueueI")];
    /*CentTreeM.PktQ6 -> PktQueueC.PktQueueI[unique("PktQueueI")];
    CentTreeM.PktQ7 -> PktQueueC.PktQueueI[unique("PktQueueI")];
    CentTreeM.PktQ8 -> PktQueueC.PktQueueI[unique("PktQueueI")];
    CentTreeM.PktQ9 -> PktQueueC.PktQueueI[unique("PktQueueI")];
    CentTreeM.PktQ10 -> PktQueueC.PktQueueI[unique("PktQueueI")];
    CentTreeM.PktQ11 -> PktQueueC.PktQueueI[unique("PktQueueI")];
    CentTreeM.PktQ12 -> PktQueueC.PktQueueI[unique("PktQueueI")];
    CentTreeM.PktQ13 -> PktQueueC.PktQueueI[unique("PktQueueI")];
    CentTreeM.PktQ14 -> PktQueueC.PktQueueI[unique("PktQueueI")];
    CentTreeM.PktQ15 -> PktQueueC.PktQueueI[unique("PktQueueI")];*/

    CentTreeM.QueueCtrl -> PktQueueC.PktQueueCtrlI;
    CentTreeM.DupCheckerI -> DupCheckerC;

#ifdef EMSTAR_NO_KERNEL
    CentTreeM.StartupTimer -> EmTimerC.EmTimerI[unique("Timer")];
#else
    CentTreeM.StartupTimer -> TimerC.Timer[unique("Timer")];
#endif

    CentTreeM.StatsI -> StatsC;

    CentTreeM.JoinerI -> JoinerC;

#ifdef NODE_HEALTH
    CentTreeM.NodeHealthI -> NodeHealthC.NodeHealthI;
#endif

}
