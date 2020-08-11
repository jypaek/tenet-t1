//$Id: TimerJiffyAsyncM.nc,v 1.2 2007/03/04 23:51:29 lnachman Exp $
// @author Joe Polastre

/*****************************************************************************
Provides a highresolution (32uSec interval) timer for CC2420Radio stack
Uses ATMega128 Timer2 via HPLTimer2
*****************************************************************************/
module TimerJiffyAsyncM
{
  provides interface StdControl;
  provides interface TimerJiffyAsync;
  uses interface PXA27XInterrupt as OSTIrq;
}
implementation
{
#define JIFFY_MAX ((1 << 27) -1)
  uint32_t jiffy;
  bool bSet;

  void StartTimer(uint32_t interval) {

    OSMR6 = (interval << 5);
    atomic {
      OIER |= (OIER_E6);
    }
    OSCR6 = 0x0UL;

  }


  command result_t StdControl.init()
  {
    //    call Alarm.setControlAsTimer();
    call OSTIrq.allocate();
    OMCR6 = (OMCR_C | OMCR_R | OMCR_CRES(0x4)); // Aperiodic, 1us increment
    return SUCCESS;
  }

  command result_t StdControl.start()
  {
    atomic bSet = FALSE;
    return SUCCESS;
  }

  command result_t StdControl.stop()
  {
    atomic {
      bSet = FALSE;
      atomic {
	OIER &= ~(OIER_E6);
      }
      //call Timer.intDisable();
    }
    return SUCCESS;
  }

  //  async event void Alarm.fired()
  async event void OSTIrq.fired() {
    uint32_t localjiffy;
    atomic localjiffy = jiffy;

    if (OSSR & OIER_E6) {
      OSSR = OIER_E6; // reset status bit
      if (localjiffy < JIFFY_MAX) {
	atomic {
	  OIER &= ~(OIER_E6); //call Timer.intDisable();
	}
	atomic bSet = FALSE;
	signal TimerJiffyAsync.fired();  //finished!
      }
      else {
	localjiffy = localjiffy - JIFFY_MAX;
	//atomic jiffy = localjiffy;
	call TimerJiffyAsync.setOneShot(localjiffy);
      }

    }
    return;
  }

  async command result_t TimerJiffyAsync.setOneShot( uint32_t _jiffy )
  {
    atomic {
      jiffy = _jiffy;
      bSet = TRUE;
    }

    if (_jiffy > JIFFY_MAX) {
      StartTimer(JIFFY_MAX);
    }
    else {
      StartTimer(_jiffy);
    }

    return SUCCESS;
  }

  async command bool TimerJiffyAsync.isSet( )
  {
    bool val;
    atomic val = bSet;
    return val;
  }

  async command result_t TimerJiffyAsync.stop()
  {
    atomic { 
      bSet = FALSE;
      atomic {
	OIER &= ~(OIER_E6);//call Timer.intDisable();
      }
    }
    return SUCCESS;
  }
}//TimerJiffyAsync

