
configuration PktQueueC 
{
    provides {
        interface StdControl;
        interface PktQueueCtrlI;
        interface PktQueueI[uint8_t id];
        interface SendMsg[uint8_t id];
    }
}


implementation {

    components
        PktQueueM,

#if defined(TOSH_HARDWARE_MICA2DOT) || defined(TOSH_HARDWARE_MICA2)
	CC1000RadioIntM,
        HPLPowerManagementM,
        CC1000ControlM,
#endif
        GenericComm as Comm;
         

    StdControl = PktQueueM.StdControl;
    StdControl = Comm;
    PktQueueI = PktQueueM.PktQueueI;
    PktQueueCtrlI = PktQueueM.PktQueueCtrlI;
    //PktQueueStatus = PktQueueM.PktQueueStatus;
    //PktStats = PktQueueM.PktStats;
    SendMsg = PktQueueM.PktQueueSendMsg;

    PktQueueM.SerialSendMsg -> Comm.SendMsg;  

#if defined(TOSH_HARDWARE_MICA2DOT) || defined(TOSH_HARDWARE_MICA2)
    PktQueueM.MacControl -> CC1000RadioIntM;
    //PktQueueM.CC1000Control -> CC1000ControlM;
    PktQueueM.enableHPLPowerM -> HPLPowerManagementM.Enable;
    PktQueueM.SetListeningMode -> CC1000RadioIntM.SetListeningMode;
    PktQueueM.SetTransmitMode -> CC1000RadioIntM.SetTransmitMode;
#endif
}
