//@author Robbie Adler

configuration PXA27XI2SC{
  provides{
    interface BulkTxRx;
    interface I2S;
  }
}
implementation{
  components PXA27XI2SM as I2SM,
    PXA27XDMAC,
    PXA27XInterruptM;
  
  BulkTxRx=I2SM.BulkTxRx;
  I2S=I2SM.I2S;
  I2SM.I2SInterrupt -> PXA27XInterruptM.PXA27XIrq[IID_I2S];
  I2SM.RxDMAChannel -> PXA27XDMAC.PXA27XDMAChannel[unique("DMAChannel")];
  I2SM.TxDMAChannel -> PXA27XDMAC.PXA27XDMAChannel[unique("DMAChannel")];
}
