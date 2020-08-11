configuration BufferedBTUARTC {
  provides {
    interface StdControl as Control;
    interface SendData;
    interface SendDataAlloc;
    interface ReceiveData;
  }
}
implementation {
  components BufferedBTUARTM as BufferedUARTM,
    BTUARTC as UARTC;
  
  Control = BufferedUARTM;
  SendData = BufferedUARTM;
  SendDataAlloc = BufferedUARTM;
  ReceiveData = BufferedUARTM;
  
  BufferedUARTM.BulkTxRx -> UARTC;
}
