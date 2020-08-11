// $Id: TimerExclusive.nc,v 1.1 2006-08-18 21:31:22 august Exp $
/*
 * Copyright (c) 2005 Moteiv Corporation
 * All rights reserved.
 *
 * This file is distributed under the terms in the attached MOTEIV-LICENSE     
 * file. If you do not find these files, copies can be found at
 * http://www.moteiv.com/MOTEIV-LICENSE.txt and by emailing info@moteiv.com.
 */
interface TimerExclusive {
  /**
   * Prepare Timer to be set with an interval, cs, and cd
   */
  async command result_t prepareTimer(uint16_t interval, uint16_t csSAMPCON, uint16_t cdSAMPCON);
  /**
   * Start Timer
   */
  async command result_t startTimer();
  /**
   * Stop Timer
   */
  async command result_t stopTimer();

  /**
   * Request exclusive access to Timer
   */
  async command result_t get();
  /**
   * Release control over Timer
   */
  async command result_t release();
  /**
   * Notification that someone else has released Timer
   */
  event void free();
}
