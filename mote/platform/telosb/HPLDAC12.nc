// $Id: HPLDAC12.nc,v 1.1 2006-08-18 21:31:22 august Exp $
/*
 * Copyright (c) 2005 Moteiv Corporation
 * All rights reserved.
 *
 * This file is distributed under the terms in the attached MOTEIV-LICENSE     
 * file. If you do not find these files, copies can be found at
 * http://www.moteiv.com/MOTEIV-LICENSE.txt and by emailing info@moteiv.com.
 */
includes MSP430DAC12;

/**
 * Interface to the DAC on the MSP430 platform
 *
 * @author Joe Polastre <info@moteiv.com>
 */
interface HPLDAC12
{
  async command void setControl(dac12ctl_t control); 
  async command dac12ctl_t getControl(); 

  async command void setRef(dac12ref_t refSelect);
  async command dac12ref_t getRef();

  /**
   * Set the resolution of the DAC
   *
   * @param res FALSE for 12-bit, TRUE for 8-bit
   */
  async command void setRes(bool res);
  /**
   * Get the resolution of the DAC
   *
   * @return FALSE for 12-bit, TRUE for 8-bit
   */
  async command bool getRes();

  async command void setLoadSelect(dac12load_t loadSelect);
  async command dac12load_t getLoadSelect();

  async command void startCalibration();
  async command bool getCalibration();

  /**
   * Sets the input range of the DAC
   *
   * @param range FALSE for a full-scale output = 3x reference voltage
   *              TRUE for a full-scale output =  1x reference voltage
   */
  async command void setInputRange(bool range);
  async command bool getInputRange();

  async command void setAmplifier(dac12amp_t ampsetting);
  async command dac12amp_t getAmplifier();

  async command void setFormat(bool format);
  async command bool getFormat();

  async command void enableInterrupts();
  async command void disableInterrupts();

  async command bool isInterruptPending();

  async command void on();
  async command void off();

  async command void group();
  async command void ungroup();

  async command void setData(uint16_t data);
  async command uint16_t getData();
}

