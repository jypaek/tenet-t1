/**
   @author Robbie Adler
**/


module PXA27XRTCM{
  provides interface PXA27XOneHzClock;
  uses interface PXA27XInterrupt as OneHzIrq;
}

implementation
{
  
  command result_t PXA27XOneHzClock.init(){
    
    call OneHzIrq.allocate();
    return SUCCESS;
  }

  command result_t PXA27XOneHzClock.enable(){
   
    RTSR |= RTSR_HZE;
    call OneHzIrq.enable();
    return SUCCESS;
  }

  command result_t PXA27XOneHzClock.disable(){

    RTSR &= ~RTSR_HZE;
    call OneHzIrq.disable();
    return SUCCESS;
  }
  
  async event void OneHzIrq.fired(){
    
    RTSR |= RTSR_HZ;
    return signal PXA27XOneHzClock.OneHzClockFired();
  }
    
  default async event void PXA27XOneHzClock.OneHzClockFired(){
    return;
  }
  
}
