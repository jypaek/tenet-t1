//@author Robbie Adler

configuration STUARTC{
  provides{
    interface BulkTxRx;
    //interface UARTConfig;
  }
}
implementation{

  components STUARTM as UARTM,
    PXA27XDMAC,
    PXA27XInterruptM;
  
  BulkTxRx=UARTM.BulkTxRx;
  //UART=UARTM.UART;
  UARTM.UARTInterrupt -> PXA27XInterruptM.PXA27XIrq[IID_STUART];
  UARTM.RxDMAChannel -> PXA27XDMAC.PXA27XDMAChannel[unique("DMAChannel")];
  UARTM.TxDMAChannel -> PXA27XDMAC.PXA27XDMAChannel[unique("DMAChannel")];
  }
