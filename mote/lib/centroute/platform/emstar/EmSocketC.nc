configuration EmSocketC
{
    provides {
        interface StdControl;
        interface EmSocketI[uint8_t id];
	interface ReceiveMsg;
    }

}

implementation {
    components EmSocketM, EmTimerC;
	//GenericComm as Comm;
    
    StdControl = EmSocketM;
    EmSocketI = EmSocketM;

    ReceiveMsg = EmSocketM.ReceiveMsg;
    EmSocketM.SocketTimer -> EmTimerC.EmTimerI[unique("Timer")];
}



