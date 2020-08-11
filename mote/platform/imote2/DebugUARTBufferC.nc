configuration DebugUARTBufferC {
  provides {
    interface StdControl as Control;
    interface SendData;
    interface ReceiveData;
  }
}
implementation {
  components DebugUARTBufferM, DebugUART;

  Control = DebugUARTBufferM;
  SendData = DebugUARTBufferM;
  ReceiveData = DebugUARTBufferM;

  DebugUARTBufferM.ByteComm -> DebugUART;
  DebugUARTBufferM.ByteControl -> DebugUART;
}
