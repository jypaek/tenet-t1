// $Id: MSP430TimerAExclusiveC.nc,v 1.1 2006-08-18 21:31:22 august Exp $
/*
 * Copyright (c) 2005 Moteiv Corporation
 * All rights reserved.
 *
 * This file is distributed under the terms in the attached MOTEIV-LICENSE     
 * file. If you do not find these files, copies can be found at
 * http://www.moteiv.com/MOTEIV-LICENSE.txt and by emailing info@moteiv.com.
 */
configuration MSP430TimerAExclusiveC {
  provides {
    interface StdControl;
    interface TimerExclusive[uint8_t id];
  }
}
implementation {
  components MSP430TimerAExclusiveM as Impl, MSP430TimerC, LedsC;

  StdControl = Impl;
  TimerExclusive = Impl;

  Impl.TimerA -> MSP430TimerC.TimerA;
  Impl.ControlA0 -> MSP430TimerC.ControlA0;
  Impl.ControlA1 -> MSP430TimerC.ControlA1;
  Impl.CompareA0 -> MSP430TimerC.CompareA0;
  Impl.CompareA1 -> MSP430TimerC.CompareA1;
  Impl.Leds -> LedsC;
}
