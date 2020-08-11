
configuration GenericCommSendVBwrapperC
{
    provides {
        interface StdControl as Control;

        interface SendMsg[uint8_t id];
    }
}
implementation
{
    components GenericCommSendVBwrapperM as Wrapper,
               GenericComm as Comm,
            #ifdef MDA400
               MDA400ControlC as MDA400C
            #else
               # Not supported
            #endif
               ;

    Control = Wrapper.Control;
    SendMsg = Wrapper.SendMsg;
    
    Wrapper.VBStdControl -> MDA400C;
    //Wrapper.VBSRControl -> MDA400C.VBSRControl[1];
    Wrapper.VBLock -> MDA400C.VBLock;
    
    Wrapper.GC_StdControl -> Comm.Control;
    Wrapper.GC_SendMsg -> Comm.SendMsg;
}

