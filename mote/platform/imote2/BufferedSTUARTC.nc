configuration BufferedSTUARTC {
  provides {
    interface StdControl as Control;
    interface SendData;
    interface SendDataAlloc;
    interface ReceiveData;
  }
}
implementation {
  components BufferedSTUARTM as BufferedUARTM,
    STUARTC as UARTC;
  
  Control = BufferedUARTM;
  SendData = BufferedUARTM;
  SendDataAlloc = BufferedUARTM;
  ReceiveData = BufferedUARTM;
  
  BufferedUARTM.BulkTxRx -> UARTC;
}
