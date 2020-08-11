configuration UARTBufferC {
  provides {
    interface StdControl as Control;
    interface SendVarLenPacket;
    interface ReceiveData;
  }
}
implementation {
  components UARTBufferM, UART;

  Control = UARTBufferM;
  SendVarLenPacket = UARTBufferM;
  ReceiveData = UARTBufferM;

  UARTBufferM.ByteComm -> UART;
  UARTBufferM.ByteControl -> UART;
}
