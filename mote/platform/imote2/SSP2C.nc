//@author Robbie Adler

configuration SSP2C{
  provides{
    interface BulkTxRx;
    interface SSP;
  }
}
implementation{
  components SSP2M as SSPM,
    PXA27XDMAC,
    PXA27XInterruptM;
  
  BulkTxRx=SSPM.BulkTxRx;
  SSP=SSPM.SSP;
  SSPM.SSPInterrupt -> PXA27XInterruptM.PXA27XIrq[IID_SSP2];
  SSPM.RxDMAChannel -> PXA27XDMAC.PXA27XDMAChannel[unique("DMAChannel")];
  SSPM.TxDMAChannel -> PXA27XDMAC.PXA27XDMAChannel[unique("DMAChannel")];
}
