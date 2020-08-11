configuration BufferedFFUARTC {
  provides {
    interface StdControl as Control;
    interface SendData;
    interface SendDataAlloc;
    interface ReceiveData;
  }
}
implementation {
  components BufferedFFUARTM as BufferedUARTM,
    FFUARTC as UARTC;
  
  Control = BufferedUARTM;
  SendData = BufferedUARTM;
  SendDataAlloc = BufferedUARTM;
  ReceiveData = BufferedUARTM;
  
  BufferedUARTM.BulkTxRx -> UARTC;
}
