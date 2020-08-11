// $Id: HPLDAC12M.nc,v 1.1 2006-08-18 21:31:22 august Exp $
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
 * HPL layer for the DAC12 module on the MSP430 platform
 *
 * @author Joe Polastre <info@moteiv.com>
 */
module HPLDAC12M {
  provides interface HPLDAC12 as DAC0;
  provides interface HPLDAC12 as DAC1;
}
implementation
{

  MSP430REG_NORACE(DAC12_0CTL);
  MSP430REG_NORACE(DAC12_0DAT);
  MSP430REG_NORACE(DAC12_1CTL);
  MSP430REG_NORACE(DAC12_1DAT);

  /***************** DAC 0 ***************/

  async command void DAC0.setControl(dac12ctl_t control) { 
    DAC12_0CTL = *(uint16_t*)&control; 
  }
  async command dac12ctl_t DAC0.getControl() { 
    return *(dac12ctl_t*) &DAC12_0CTL;
  }

  async command void DAC0.setRef(dac12ref_t refSelect) { 
    dac12ctl_t ctl;
    atomic {
      ctl = *(dac12ctl_t*) &DAC12_0CTL;
      ctl.reference = refSelect;
      DAC12_0CTL = *(uint16_t*)&ctl; 
    }
  }
  async command dac12ref_t DAC0.getRef() { 
    return (dac12ref_t)((DAC12_0CTL & DAC12SREF_3) >> 13);
  }

  async command void DAC0.setRes(bool res) {
    if (res)
      DAC12_0CTL |= DAC12RES;
    else
      DAC12_0CTL &= ~DAC12RES;
  }
  async command bool DAC0.getRes() {
    return (DAC12_0CTL & DAC12RES) ? TRUE : FALSE;
  }

  async command void DAC0.setLoadSelect(dac12load_t loadSelect) { 
    dac12ctl_t ctl;
    atomic {
      ctl = *(dac12ctl_t*) &DAC12_0CTL;
      ctl.load = loadSelect;
      DAC12_0CTL = *(uint16_t*)&ctl; 
    }
  }
  async command dac12load_t DAC0.getLoadSelect() { 
    return (dac12load_t)((DAC12_0CTL & DAC12LSEL_3) >> 10);
  }

  async command void DAC0.startCalibration() {
    DAC12_0CTL |= DAC12CALON;
  }
  async command bool DAC0.getCalibration() {
    return (DAC12_0CTL & DAC12CALON) >> 9;
  }

  async command void DAC0.setInputRange(bool range) {
    if (range)
      DAC12_0CTL |= DAC12IR;
    else
      DAC12_0CTL &= ~DAC12IR;
  }
  async command bool DAC0.getInputRange() {
    return (DAC12_0CTL & DAC12IR) ? TRUE : FALSE;
  }

  async command void DAC0.setAmplifier(dac12amp_t ampsetting) { 
    dac12ctl_t ctl;
    atomic {
      ctl = *(dac12ctl_t*) &DAC12_0CTL;
      ctl.dacamp = ampsetting;
      DAC12_0CTL = *(uint16_t*)&ctl; 
    }
  }
  async command dac12amp_t DAC0.getAmplifier() {
    return (dac12amp_t)((DAC12_0CTL & DAC12AMP_7) >> 5);
  }

  async command void DAC0.setFormat(bool format) { 
    if (format)
      DAC12_0CTL |= DAC12DF;
    else
      DAC12_0CTL &= ~DAC12DF;
  }
  async command bool DAC0.getFormat() { 
    return (DAC12_0CTL & DAC12DF) ? TRUE : FALSE;
  }

  async command void DAC0.enableInterrupts() {
    DAC12_0CTL |= DAC12IE;
  }
  async command void DAC0.disableInterrupts() {
    DAC12_0CTL &= ~DAC12IE;
  }

  async command bool DAC0.isInterruptPending() {
    return (DAC12_0CTL & DAC12IFG) ? TRUE : FALSE;
  }
  async command void DAC0.on() {
    DAC12_0CTL |= DAC12ENC;
  }
  async command void DAC0.off() {
    DAC12_0CTL &= ~DAC12ENC;
  }

  async command void DAC0.group() {
    DAC12_0CTL |= DAC12GRP;
  }
  async command void DAC0.ungroup() {
    DAC12_0CTL &= ~DAC12GRP;
  }

  async command void DAC0.setData(uint16_t data) {
    DAC12_0DAT = data;
  }

  async command uint16_t DAC0.getData() {
    uint16_t temp = DAC12_0DAT;
    return temp;
  }

  /***************** DAC 1 ***************/

  async command void DAC1.setControl(dac12ctl_t control) { 
    DAC12_1CTL = *(uint16_t*)&control; 
  }
  async command dac12ctl_t DAC1.getControl() { 
    return *(dac12ctl_t*) &DAC12_1CTL;
  }

  async command void DAC1.setRef(dac12ref_t refSelect) { 
    dac12ctl_t ctl;
    atomic {
      ctl = *(dac12ctl_t*) &DAC12_1CTL;
      ctl.reference = refSelect;
      DAC12_1CTL = *(uint16_t*)&ctl; 
    }
  }
  async command dac12ref_t DAC1.getRef() { 
    return (dac12ref_t)((DAC12_1CTL & DAC12SREF_3) >> 13);
  }

  async command void DAC1.setRes(bool res) {
    if (res)
      DAC12_1CTL |= DAC12RES;
    else
      DAC12_1CTL &= ~DAC12RES;
  }
  async command bool DAC1.getRes() {
    return (DAC12_1CTL & DAC12RES) ? TRUE : FALSE;
  }

  async command void DAC1.setLoadSelect(dac12load_t loadSelect) { 
    dac12ctl_t ctl;
    atomic {
      ctl = *(dac12ctl_t*) &DAC12_1CTL;
      ctl.load = loadSelect;
      DAC12_1CTL = *(uint16_t*)&ctl; 
    }
  }
  async command dac12load_t DAC1.getLoadSelect() { 
    return (dac12load_t)((DAC12_1CTL & DAC12LSEL_3) >> 10);
  }

  async command void DAC1.startCalibration() {
    DAC12_1CTL |= DAC12CALON;
  }
  async command bool DAC1.getCalibration() {
    return (DAC12_1CTL & DAC12CALON) >> 9;
  }

  async command void DAC1.setInputRange(bool range) {
    if (range)
      DAC12_1CTL |= DAC12IR;
    else
      DAC12_1CTL &= ~DAC12IR;
  }
  async command bool DAC1.getInputRange() {
    return (DAC12_1CTL & DAC12IR) ? TRUE : FALSE;
  }

  async command void DAC1.setAmplifier(dac12amp_t ampsetting) { 
    dac12ctl_t ctl;
    atomic {
      ctl = *(dac12ctl_t*) &DAC12_1CTL;
      ctl.dacamp = ampsetting;
      DAC12_1CTL = *(uint16_t*)&ctl; 
    }
  }
  async command dac12amp_t DAC1.getAmplifier() {
    return (dac12amp_t)((DAC12_1CTL & DAC12AMP_7) >> 5);
  }

  async command void DAC1.setFormat(bool format) { 
    if (format)
      DAC12_1CTL |= DAC12DF;
    else
      DAC12_1CTL &= ~DAC12DF;
  }
  async command bool DAC1.getFormat() { 
    return (DAC12_1CTL & DAC12DF) ? TRUE : FALSE;
  }

  async command void DAC1.enableInterrupts() {
    DAC12_1CTL |= DAC12IE;
  }
  async command void DAC1.disableInterrupts() {
    DAC12_1CTL &= ~DAC12IE;
  }

  async command bool DAC1.isInterruptPending() {
    return (DAC12_1CTL & DAC12IFG) ? TRUE : FALSE;
  }
  async command void DAC1.on() {
    DAC12_1CTL |= DAC12ENC;
  }
  async command void DAC1.off() {
    DAC12_1CTL &= ~DAC12ENC;
  }

  async command void DAC1.group() {
    DAC12_1CTL |= DAC12GRP;
  }
  async command void DAC1.ungroup() {
    DAC12_1CTL &= ~DAC12GRP;
  }

  async command void DAC1.setData(uint16_t data) {
    DAC12_1DAT = data;
  }

  async command uint16_t DAC1.getData() {
    uint16_t temp = DAC12_1DAT;
    return temp;
  }
}
