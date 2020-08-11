includes CentTree;
includes LinkTest;
#include "PktTypes.h"

configuration LinkTestC
{
    provides {
        interface StdControl;
        //interface LinkTestI;
    }
}


implementation {

    components
        LinkTestM,
        CentTreeC,
        PktQueueC,
#ifdef EMSTAR_NO_KERNEL
        EmTimerC,
#else
        TimerC,
#endif

        BeaconerC;
        


    StdControl = LinkTestM.StdControl;
//    LinkTestI = LinkTestM.LinkTestI;

    LinkTestM.ProbeBeacon -> BeaconerC.BeaconerI[unique("BeaconerI")];

    LinkTestM.PktQ -> PktQueueC.PktQueueI[unique("PktQueueI")];

    LinkTestM.TreeSend -> CentTreeC.CentTreeSendI[CR_TYPE_LINKTEST];
    LinkTestM.TreeRecv -> CentTreeC.CentTreeRecvI[CR_TYPE_LINKTEST];
    LinkTestM.CentTreeCtrlI -> CentTreeC.CentTreeCtrlI;

#ifdef EMSTAR_NO_KERNEL
    LinkTestM.LinkTimer -> EmTimerC.EmTimerI[unique("Timer")];
#else
    LinkTestM.LinkTimer -> TimerC.Timer[unique("Timer")];
#endif

}
