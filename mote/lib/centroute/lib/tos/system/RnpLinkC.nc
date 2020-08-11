includes RnpLink;

configuration RnpLinkC 
{
    provides {
        interface StdControl;
        interface RnpLinkI;
        interface SendMsg[uint8_t id];
        interface ReceiveMsg[uint8_t id];
    }
}


implementation {

    components
        RnpLinkM,
        GenericCommPromiscuous as Comm,
        EmStatusServerC;

    StdControl = RnpLinkM.StdControl;
    StdControl = Comm;
    RnpLinkI = RnpLinkM.RnpLinkI;
    SendMsg = RnpLinkM.RnpSendMsg;
    ReceiveMsg = RnpLinkM.RnpReceiveMsg;

    RnpLinkM.CommControl -> Comm.CommControl;
    RnpLinkM.CommSendMsg -> Comm.SendMsg;
    RnpLinkM.CommReceiveMsg -> Comm.ReceiveMsg;

    RnpLinkM.RnpStatus -> 
        EmStatusServerC.EmStatusServerI[unique("EmStatusServerI")];

}
