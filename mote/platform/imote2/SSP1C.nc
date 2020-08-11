//@author Robbie Adler

configuration SSP1C{
  provides{
    interface BulkTxRx;
    interface SSP;
  }
}
implementation{
  components SSP1M as SSPM,
    PXA27XDMAC,
    PXA27XInterruptM;
  
  BulkTxRx=SSPM.BulkTxRx;
  SSP=SSPM.SSP;
  SSPM.SSPInterrupt -> PXA27XInterruptM.PXA27XIrq[IID_SSP1];
  SSPM.RxDMAChannel -> PXA27XDMAC.PXA27XDMAChannel[unique("DMAChannel")];
  SSPM.TxDMAChannel -> PXA27XDMAC.PXA27XDMAChannel[unique("DMAChannel")];
}
