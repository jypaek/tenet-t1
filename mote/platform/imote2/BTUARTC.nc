//@author Robbie Adler

configuration BTUARTC{
  provides{
    interface BulkTxRx;
    //interface UART;
  }
}
implementation{
  components BTUARTM as UARTM,
    PXA27XDMAC,
    PXA27XInterruptM;
  
  BulkTxRx=UARTM.BulkTxRx;
  //UART=UARTM.UART;
  UARTM.UARTInterrupt -> PXA27XInterruptM.PXA27XIrq[IID_BTUART];
  UARTM.RxDMAChannel -> PXA27XDMAC.PXA27XDMAChannel[unique("DMAChannel")];
  UARTM.TxDMAChannel -> PXA27XDMAC.PXA27XDMAChannel[unique("DMAChannel")];
}
