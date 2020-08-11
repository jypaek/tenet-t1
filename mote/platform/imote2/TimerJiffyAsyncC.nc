//$Id: TimerJiffyAsyncC.nc,v 1.3 2007/03/04 23:51:29 lnachman Exp $
// @author Cory Sharp <cssharp@eecs.berkeley.edu>

configuration TimerJiffyAsyncC
{
  provides interface StdControl;
  provides interface TimerJiffyAsync;
}
implementation
{
  components TimerJiffyAsyncM, PXA27XInterruptM;

  StdControl = TimerJiffyAsyncM;
  TimerJiffyAsync = TimerJiffyAsyncM;

  TimerJiffyAsyncM.OSTIrq -> PXA27XInterruptM.PXA27XIrq[IID_OST_4_11];


}

