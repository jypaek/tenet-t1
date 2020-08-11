/**
   @author Robbie Adler
**/


configuration PXA27XRTCC{
  provides interface PXA27XOneHzClock;
}

implementation
{
  components PXA27XInterruptM,
    PXA27XRTCM;

  PXA27XOneHzClock = PXA27XRTCM;
  
  PXA27XRTCM.OneHzIrq -> PXA27XInterruptM.PXA27XIrq[IID_RTC_HZ];
  
}
