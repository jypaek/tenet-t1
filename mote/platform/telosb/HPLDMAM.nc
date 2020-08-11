//$Id: HPLDMAM.nc,v 1.1 2006-08-18 21:31:22 august Exp $
/* "Copyright (c) 2000-2005 The Regents of the University of California.  
 * All rights reserved.
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose, without fee, and without written agreement
 * is hereby granted, provided that the above copyright notice, the following
 * two paragraphs and the author appear in all copies of this software.
 * 
 * IN NO EVENT SHALL THE UNIVERSITY OF CALIFORNIA BE LIABLE TO ANY PARTY FOR
 * DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES ARISING OUT
 * OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN IF THE UNIVERSITY
 * OF CALIFORNIA HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 * 
 * THE UNIVERSITY OF CALIFORNIA SPECIFICALLY DISCLAIMS ANY WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE.  THE SOFTWARE PROVIDED HEREUNDER IS
 * ON AN "AS IS" BASIS, AND THE UNIVERSITY OF CALIFORNIA HAS NO OBLIGATION TO
 * PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS."
 */

/**
 * @author Ben Greenstein <ben@cs.ucla.edu>
 * @author Joe Polastre <info@moteiv.com>
 */
includes MSP430DMA;

module HPLDMAM {
  provides {
    interface HPLDMAControl as DMAControl;
    interface HPLDMAChannelControl as DMAChannelCtrl0;
    interface HPLDMAChannelControl as DMAChannelCtrl1;
    interface HPLDMAChannelControl as DMAChannelCtrl2;
  }  
}
implementation {
  MSP430REG_NORACE(DMACTL0);
  MSP430REG_NORACE(DMACTL1);
  MSP430REG_NORACE(DMA0CTL);
  MSP430REG_NORACE(DMA0SA);
  MSP430REG_NORACE(DMA0DA);
  MSP430REG_NORACE(DMA0SZ);
  MSP430REG_NORACE(DMA1CTL);
  MSP430REG_NORACE(DMA1SA);
  MSP430REG_NORACE(DMA1DA);
  MSP430REG_NORACE(DMA1SZ);
  MSP430REG_NORACE(DMA2CTL);
  MSP430REG_NORACE(DMA2SA);
  MSP430REG_NORACE(DMA2DA);
  MSP430REG_NORACE(DMA2SZ);


  TOSH_SIGNAL(DACDMA_VECTOR) {
    // DMAIFG flags are not reset automatically and must be reset by software
    if (DMA0CTL & DMAIFG) {
      DMA0CTL &= ~DMAIFG;
      if (DMA0CTL & DMAABORT){
	DMA0CTL &= ~DMAABORT;
	signal DMAChannelCtrl0.transferDone(FAIL);
      }
      else signal DMAChannelCtrl0.transferDone(SUCCESS);
    }
    if (DMA1CTL & DMAIFG) {
      DMA1CTL &= ~DMAIFG;
      if (DMA1CTL & DMAABORT){
	DMA1CTL &= ~DMAABORT;
	signal DMAChannelCtrl1.transferDone(FAIL);
      }
      else signal DMAChannelCtrl1.transferDone(SUCCESS);
    }
    if (DMA2CTL& DMAIFG) {
      DMA2CTL &= ~DMAIFG;
      if (DMA2CTL & DMAABORT){
	DMA2CTL &= ~DMAABORT;
	signal DMAChannelCtrl2.transferDone(FAIL);
      }
      else signal DMAChannelCtrl2.transferDone(SUCCESS);
    }
  }
  
  // ----------------------------------------------------------
  // DMA Control
  // ----------------------------------------------------------

  // Should a DMA transfer occur immediately (FALSE),
  // on the next instruction fetch after the trigger (TRUE)

  async command void DMAControl.setOnFetch(){
    DMACTL1 |= DMAONFETCH;
  }
  async command void DMAControl.clearOnFetch(){
    DMACTL1 &= ~(DMAONFETCH);
  }

  // Should the DMA channel priority be 0, 1, 2 (FALSE), or 
  // should it change with each transfer (TRUE)

  async command void DMAControl.setRoundRobin(){
      DMACTL1 |= ROUNDROBIN;
  }
  async command void DMAControl.clearRoundRobin(){
    DMACTL1 &= ~(ROUNDROBIN);
  }

  // This enables the interruption of a DMA transfer by an NMI
  // interrupt. WHen an NMI interrupts a DMA transfer, the current
  // transfer is completed normally, further transfers are stopped,
  // and DMAABORT is set.


  async command void DMAControl.setENNMI(){
    DMACTL1 |= ENNMI;
  }
  async command void DMAControl.clearENNMI(){
    DMACTL1 &= ~(ENNMI);
  }

  async command void DMAControl.setState(dma_state_t s){
    DMACTL1 = *(int*)&s;
  }
  async command dma_state_t DMAControl.getState(){
    dma_state_t s;
    s = *(dma_state_t*)&DMACTL1;
    return s;
  }
  async command void DMAControl.reset(){
    DMACTL0 = 0;
    DMACTL1 = 0;
  }

  // ----------------------------------------------------------
  // DMA Channel 0 Control
  // ----------------------------------------------------------


  // ----- DMA Trigger Mode -----


  async command result_t DMAChannelCtrl0.setTrigger(dma_trigger_t trigger){
    result_t res = SUCCESS;
    if (DMA0CTL & DMAEN) res = FAIL;
    else {
      DMACTL0 &= ~(DMA0TSEL0 | DMA0TSEL1 | DMA0TSEL2 | DMA0TSEL3);
      DMACTL0 |= ((DMATSEL_MASK & trigger)<<DMA0TSEL_SHIFT);
    }
    return res;
  }
  async command void DMAChannelCtrl0.clearTrigger(){
        DMACTL0 &= ~(DMA0TSEL0 | DMA0TSEL1 | DMA0TSEL2 | DMA0TSEL3);
  }

  // ----- DMA Transfer Mode -----

  async command void DMAChannelCtrl0.setSingleMode(){
    DMA0CTL &= ~(DMADT0 | DMADT1 | DMADT2);
  }
  async command void DMAChannelCtrl0.setBlockMode(){
    DMA0CTL &= ~(DMADT0 | DMADT1 | DMADT2);
    DMA0CTL |= DMADT0;
  }
  async command void DMAChannelCtrl0.setBurstMode(){
    DMA0CTL &= ~(DMADT0 | DMADT1 | DMADT2);
    DMA0CTL |= DMADT1;
  }
  async command void DMAChannelCtrl0.setRepeatedSingleMode(){
    DMA0CTL &= ~(DMADT0 | DMADT1 | DMADT2);
    DMA0CTL |= DMADT2;
  }
  async command void DMAChannelCtrl0.setRepeatedBlockMode(){
    DMA0CTL &= ~(DMADT0 | DMADT1 | DMADT2);
    DMA0CTL |= (DMADT2 | DMADT0);
  }
  async command void DMAChannelCtrl0.setRepeatedBurstMode(){
    DMA0CTL &= ~(DMADT0 | DMADT1 | DMADT2);
    DMA0CTL |= (DMADT2 | DMADT1);
  }

  // ----- DMA Address Incrementation -----

  async command void DMAChannelCtrl0.setSrcNoIncrement(){
    DMA0CTL &= ~(DMASRCINCR0 | DMASRCINCR1);
  }
  async command void DMAChannelCtrl0.setSrcDecrement(){
    DMA0CTL |= DMASRCINCR1;
  }
  async command void DMAChannelCtrl0.setSrcIncrement(){
    DMA0CTL |= (DMASRCINCR0 | DMASRCINCR1);
  }

  async command void DMAChannelCtrl0.setDstNoIncrement(){
    DMA0CTL &= ~(DMADSTINCR0 | DMADSTINCR1);
  }
  async command void DMAChannelCtrl0.setDstDecrement(){
    DMA0CTL |= DMADSTINCR1;
  }
  async command void DMAChannelCtrl0.setDstIncrement(){
    DMA0CTL |= (DMADSTINCR0 | DMADSTINCR1);
  }

  // ----- DMA Word Size Mode -----

  async command void DMAChannelCtrl0.setWordToWord(){ 
    DMA0CTL &= ~(DMASRCBYTE | DMADSTBYTE);
    DMA0CTL |= DMASWDW;
  }
  async command void DMAChannelCtrl0.setByteToWord(){ 
    DMA0CTL &= ~(DMASRCBYTE | DMADSTBYTE);
    DMA0CTL |= DMASBDW;
  }
  async command void DMAChannelCtrl0.setWordToByte(){ 
    DMA0CTL &= ~(DMASRCBYTE | DMADSTBYTE);
    DMA0CTL |= DMASWDB;
  }
  async command void DMAChannelCtrl0.setByteToByte(){ 
    DMA0CTL &= ~(DMASRCBYTE | DMADSTBYTE);
    DMA0CTL |= DMASBDB;
  }

  // ----- DMA Level -----

  async command void DMAChannelCtrl0.setEdgeSensitive(){
    DMA0CTL &= ~DMALEVEL;
  }
  async command void DMAChannelCtrl0.setLevelSensitive(){
    DMA0CTL |= DMALEVEL;
  }

  // ----- DMA Enable -----

  async command void DMAChannelCtrl0.enableDMA(){ DMA0CTL |= DMAEN; }
  async command void DMAChannelCtrl0.disableDMA(){ DMA0CTL &= ~DMAEN; }

  // ----- DMA Interrupt -----

  async command void DMAChannelCtrl0.enableInterrupt() { 
    DMA0CTL  |= DMAIE; 
  }
  async command void DMAChannelCtrl0.disableInterrupt() { 
    DMA0CTL  &= ~DMAIE; 
  }
  async command bool DMAChannelCtrl0.interruptPending(){
    bool ret = FALSE;
    if (DMA0CTL & DMAIFG) ret = TRUE;
    return ret;
  }

  // ----- DMA Abort -----

  // todo: should this trigger an interrupt
  async command bool DMAChannelCtrl0.aborted(){
    bool ret = FALSE;
    if (DMA0CTL & DMAABORT) ret = TRUE;
    return ret;
  }

  // ----- DMA Software Request -----

  async command void DMAChannelCtrl0.triggerDMA() { DMA0CTL  |= DMAREQ; }

  // ----- DMA Source Address -----
  async command void DMAChannelCtrl0.setSrc(void *saddr){
    DMA0SA = (uint16_t)saddr;
  }
  // ----- DMA Destination Address ----
  async command void DMAChannelCtrl0.setDst(void *daddr){
    DMA0DA = (uint16_t)daddr;
  }
  // ----- DMA Destination Address ----
  async command void DMAChannelCtrl0.setSize(uint16_t sz){
    DMA0SZ = sz;
  }

  async command void DMAChannelCtrl0.setState(dma_channel_state_t s, dma_channel_trigger_t t, void* src, void* dest, int size){
    call DMAChannelCtrl0.setStateRaw(*(int*)&s,
				     *(int*)&t,
				     src,
				     dest,
				     size);
  }
  async command void DMAChannelCtrl0.setStateRaw(uint16_t s, uint16_t t, void* src, void* dest, int size) {
    DMA0SA = (uint16_t)src;
    DMA0DA = (uint16_t)dest;
    DMA0SZ = size;
    DMACTL0 &= ~(DMATSEL_MASK << DMA0TSEL_SHIFT);
    DMACTL0 |= t << DMA0TSEL_SHIFT;
    DMA0CTL = s;
    return;
  }

  async command dma_channel_state_t DMAChannelCtrl0.getState(){
    dma_channel_state_t s = *(dma_channel_state_t*) &DMA0CTL;
    return s;
  }

  async command void* DMAChannelCtrl0.getSource() {
    return (void*)DMA0SA;
  }

  async command void* DMAChannelCtrl0.getDestination() {
    return (void*)DMA0DA;
  }

  async command int DMAChannelCtrl0.getSize() {
    return DMA0SZ;
  }

  async command dma_channel_trigger_t DMAChannelCtrl0.getTrigger() {
    dma_channel_trigger_t t;
    t.trigger = ((DMACTL0 >> DMA0TSEL_SHIFT) & DMATSEL_MASK);
    return t;
  }

  async command void DMAChannelCtrl0.reset(){
    DMA0CTL = 0;
    DMA0SA = 0;
    DMA0DA = 0;
    DMA0SZ = 0;
  }

  // ----------------------------------------------------------
  // DMA Channel 1 Control
  // ----------------------------------------------------------


  // ----- DMA Trigger Mode -----

  async command result_t DMAChannelCtrl1.setTrigger(dma_trigger_t trigger){
    result_t res = SUCCESS;
    if (DMA1CTL & DMAEN) res = FAIL;
    else {
      DMACTL0 &= ~(DMA1TSEL0 | DMA1TSEL1 | DMA1TSEL2 | DMA1TSEL3);
      DMACTL0 |= ((DMATSEL_MASK & trigger)<<DMA1TSEL_SHIFT); 
    }
    return res;
  }
  async command void DMAChannelCtrl1.clearTrigger(){
        DMACTL0 &= ~(DMA1TSEL0 | DMA1TSEL1 | DMA1TSEL2 | DMA1TSEL3);
  }
  
  // ----- DMA Transfer Mode -----

  async command void DMAChannelCtrl1.setSingleMode(){
    DMA1CTL &= ~(DMADT0 | DMADT1 | DMADT2);
  }
  async command void DMAChannelCtrl1.setBlockMode(){
    DMA1CTL &= ~(DMADT0 | DMADT1 | DMADT2);
    DMA1CTL |= DMADT0;
  }
  async command void DMAChannelCtrl1.setBurstMode(){
    DMA1CTL &= ~(DMADT0 | DMADT1 | DMADT2);
    DMA1CTL |= DMADT1;
  }
  async command void DMAChannelCtrl1.setRepeatedSingleMode(){
    DMA1CTL &= ~(DMADT0 | DMADT1 | DMADT2);
    DMA1CTL |= DMADT2;
  }
  async command void DMAChannelCtrl1.setRepeatedBlockMode(){
    DMA1CTL &= ~(DMADT0 | DMADT1 | DMADT2);
    DMA1CTL |= (DMADT2 | DMADT0);
  }
  async command void DMAChannelCtrl1.setRepeatedBurstMode(){
    DMA1CTL &= ~(DMADT0 | DMADT1 | DMADT2);
    DMA1CTL |= (DMADT2 | DMADT1);
  }

  // ----- DMA Address Incrementation -----

  async command void DMAChannelCtrl1.setSrcNoIncrement(){
    DMA1CTL &= ~(DMASRCINCR0 | DMASRCINCR1);
  }
  async command void DMAChannelCtrl1.setSrcDecrement(){
    DMA1CTL |= DMASRCINCR1;
  }
  async command void DMAChannelCtrl1.setSrcIncrement(){
    DMA1CTL |= (DMASRCINCR0 | DMASRCINCR1);
  }

  async command void DMAChannelCtrl1.setDstNoIncrement(){
    DMA1CTL &= ~(DMADSTINCR0 | DMADSTINCR1);
  }
  async command void DMAChannelCtrl1.setDstDecrement(){
    DMA1CTL |= DMADSTINCR1;
  }
  async command void DMAChannelCtrl1.setDstIncrement(){
    DMA1CTL |= (DMADSTINCR0 | DMADSTINCR1);
  }

  // ----- DMA Word Size Mode -----

  async command void DMAChannelCtrl1.setWordToWord(){ 
    DMA1CTL &= ~(DMASRCBYTE | DMADSTBYTE);
    DMA1CTL |= DMASWDW;
  }
  async command void DMAChannelCtrl1.setByteToWord(){ 
    DMA1CTL &= ~(DMASRCBYTE | DMADSTBYTE);
    DMA1CTL |= DMASBDW;
  }
  async command void DMAChannelCtrl1.setWordToByte(){ 
    DMA1CTL &= ~(DMASRCBYTE | DMADSTBYTE);
    DMA1CTL |= DMASWDB;
  }
  async command void DMAChannelCtrl1.setByteToByte(){ 
    DMA1CTL &= ~(DMASRCBYTE | DMADSTBYTE);
    DMA1CTL |= DMASBDB;
  }

  // ----- DMA Level -----

  async command void DMAChannelCtrl1.setEdgeSensitive(){
    DMA1CTL &= ~DMALEVEL;
  }
  async command void DMAChannelCtrl1.setLevelSensitive(){
    DMA1CTL |= DMALEVEL;
  }

  // ----- DMA Enable -----

  async command void DMAChannelCtrl1.enableDMA(){ DMA1CTL |= DMAEN; }
  async command void DMAChannelCtrl1.disableDMA(){ DMA1CTL &= ~DMAEN; }

  // ----- DMA Interrupt -----

  async command void DMAChannelCtrl1.enableInterrupt() { 
    DMA1CTL  |= DMAIE; 
  }
  async command void DMAChannelCtrl1.disableInterrupt() { 
    DMA1CTL  &= ~DMAIE; 
  }
  async command bool DMAChannelCtrl1.interruptPending(){
    bool ret = FALSE;
    if (DMA1CTL & DMAIFG) ret = TRUE;
    return ret;
  }

  // ----- DMA Abort -----

  // todo: should this trigger an interrupt
  async command bool DMAChannelCtrl1.aborted(){
    bool ret = FALSE;
    if (DMA1CTL & DMAABORT) ret = TRUE;
    return ret;
  }

  // ----- DMA Software Request -----

  async command void DMAChannelCtrl1.triggerDMA() { DMA1CTL  |= DMAREQ; }

  // ----- DMA Source Address -----
  async command void DMAChannelCtrl1.setSrc(void *saddr){
    DMA1SA = (uint16_t)saddr;
  }
  // ----- DMA Destination Address ----
  async command void DMAChannelCtrl1.setDst(void *daddr){
    DMA1DA = (uint16_t)daddr;
  }

  // ----- DMA Destination Address ----
  async command void DMAChannelCtrl1.setSize(uint16_t sz){
    DMA1SZ = sz;
  }

  async command void DMAChannelCtrl1.setState(dma_channel_state_t s, dma_channel_trigger_t t, void* src, void* dest, int size){
    call DMAChannelCtrl1.setStateRaw(*(int*)&s,
				     *(int*)&t,
				     src,
				     dest,
				     size);
  }
  async command void DMAChannelCtrl1.setStateRaw(uint16_t s, uint16_t t, void* src, void* dest, int size) {
    DMA1SA = (uint16_t)src;
    DMA1DA = (uint16_t)dest;
    DMA1SZ = size;
    DMACTL0 &= ~(DMATSEL_MASK << DMA1TSEL_SHIFT);
    DMACTL0 |= t << DMA1TSEL_SHIFT;
    DMA1CTL = s;
    return;
  }

  async command dma_channel_state_t DMAChannelCtrl1.getState(){
    dma_channel_state_t s = *(dma_channel_state_t*) &DMA1CTL;
    return s;
  }

  async command void* DMAChannelCtrl1.getSource() {
    return (void*)DMA1SA;
  }

  async command void* DMAChannelCtrl1.getDestination() {
    return (void*)DMA1DA;
  }

  async command int DMAChannelCtrl1.getSize() {
    return DMA1SZ;
  }

  async command dma_channel_trigger_t DMAChannelCtrl1.getTrigger() {
    dma_channel_trigger_t t;
    t.trigger = ((DMACTL0 >> DMA1TSEL_SHIFT) & DMATSEL_MASK);
    return t;
  }

  async command void DMAChannelCtrl1.reset(){
    DMA1CTL = 0;
    DMA1SA = 0;
    DMA1DA = 0;
    DMA1SZ = 0;
  }

  // ----------------------------------------------------------
  // DMA Channel 2 Control
  // ----------------------------------------------------------


  // ----- DMA Trigger Mode -----

  async command result_t DMAChannelCtrl2.setTrigger(dma_trigger_t trigger){
    result_t res = SUCCESS;
    if (DMA2CTL & DMAEN) res = FAIL;
    else {
      DMACTL0 &= ~(DMA2TSEL0 | DMA2TSEL1 | DMA2TSEL2 | DMA2TSEL3);
      DMACTL0 |= ((DMATSEL_MASK & trigger)<<DMA2TSEL_SHIFT);
    }
    return res;
  }
  async command void DMAChannelCtrl2.clearTrigger(){
        DMACTL0 &= ~(DMA2TSEL0 | DMA2TSEL1 | DMA2TSEL2 | DMA2TSEL3);
  }
  

  // ----- DMA Transfer Mode -----

  async command void DMAChannelCtrl2.setSingleMode(){
    DMA2CTL &= ~(DMADT0 | DMADT1 | DMADT2);
  }
  async command void DMAChannelCtrl2.setBlockMode(){
    DMA2CTL &= ~(DMADT0 | DMADT1 | DMADT2);
    DMA2CTL |= DMADT0;
  }
  async command void DMAChannelCtrl2.setBurstMode(){
    DMA2CTL &= ~(DMADT0 | DMADT1 | DMADT2);
    DMA2CTL |= DMADT1;
  }
  async command void DMAChannelCtrl2.setRepeatedSingleMode(){
    DMA2CTL &= ~(DMADT0 | DMADT1 | DMADT2);
    DMA2CTL |= DMADT2;
  }
  async command void DMAChannelCtrl2.setRepeatedBlockMode(){
    DMA2CTL &= ~(DMADT0 | DMADT1 | DMADT2);
    DMA2CTL |= (DMADT2 | DMADT0);
  }
  async command void DMAChannelCtrl2.setRepeatedBurstMode(){
    DMA2CTL &= ~(DMADT0 | DMADT1 | DMADT2);
    DMA2CTL |= (DMADT2 | DMADT1);
  }

  // ----- DMA Address Incrementation -----

  async command void DMAChannelCtrl2.setSrcNoIncrement(){
    DMA2CTL &= ~(DMASRCINCR0 | DMASRCINCR1);
  }
  async command void DMAChannelCtrl2.setSrcDecrement(){
    DMA2CTL |= DMASRCINCR1;
  }
  async command void DMAChannelCtrl2.setSrcIncrement(){
    DMA2CTL |= (DMASRCINCR0 | DMASRCINCR1);
  }

  async command void DMAChannelCtrl2.setDstNoIncrement(){
    DMA2CTL &= ~(DMADSTINCR0 | DMADSTINCR1);
  }
  async command void DMAChannelCtrl2.setDstDecrement(){
    DMA2CTL |= DMADSTINCR1;
  }
  async command void DMAChannelCtrl2.setDstIncrement(){
    DMA2CTL |= (DMADSTINCR0 | DMADSTINCR1);
  }

  // ----- DMA Word Size Mode -----

  async command void DMAChannelCtrl2.setWordToWord(){ 
    DMA2CTL &= ~(DMASRCBYTE | DMADSTBYTE);
    DMA2CTL |= DMASWDW;
  }
  async command void DMAChannelCtrl2.setByteToWord(){ 
    DMA2CTL &= ~(DMASRCBYTE | DMADSTBYTE);
    DMA2CTL |= DMASBDW;
  }
  async command void DMAChannelCtrl2.setWordToByte(){ 
    DMA2CTL &= ~(DMASRCBYTE | DMADSTBYTE);
    DMA2CTL |= DMASWDB;
  }
  async command void DMAChannelCtrl2.setByteToByte(){ 
    DMA2CTL &= ~(DMASRCBYTE | DMADSTBYTE);
    DMA2CTL |= DMASBDB;
  }

  // ----- DMA Level -----

  async command void DMAChannelCtrl2.setEdgeSensitive(){
    DMA2CTL &= ~DMALEVEL;
  }
  async command void DMAChannelCtrl2.setLevelSensitive(){
    DMA2CTL |= DMALEVEL;
  }

  // ----- DMA Enable -----

  async command void DMAChannelCtrl2.enableDMA(){ DMA2CTL |= DMAEN; }
  async command void DMAChannelCtrl2.disableDMA(){ DMA2CTL &= ~DMAEN; }

  // ----- DMA Interrupt -----

  async command void DMAChannelCtrl2.enableInterrupt() { 
    DMA2CTL  |= DMAIE; 
  }
  async command void DMAChannelCtrl2.disableInterrupt() { 
    DMA2CTL  &= ~DMAIE; 
  }
  async command bool DMAChannelCtrl2.interruptPending(){
    bool ret = FALSE;
    if (DMA2CTL & DMAIFG) ret = TRUE;
    return ret;
  }

  // ----- DMA Abort -----

  // todo: should this trigger an interrupt
  async command bool DMAChannelCtrl2.aborted(){
    bool ret = FALSE;
    if (DMA2CTL & DMAABORT) ret = TRUE;
    return ret;
  }

  // ----- DMA Software Request -----

  async command void DMAChannelCtrl2.triggerDMA() { DMA2CTL  |= DMAREQ; }

  // ----- DMA Source Address -----
  async command void DMAChannelCtrl2.setSrc(void *saddr){
    DMA2SA = (uint16_t)saddr;
  }

  // ----- DMA Destination Address ----
  async command void DMAChannelCtrl2.setDst(void *daddr){
    DMA2DA = (uint16_t)daddr;
  }

  // ----- DMA Destination Address ----
  async command void DMAChannelCtrl2.setSize(uint16_t sz){
    DMA2SZ = sz;
  }

  async command void DMAChannelCtrl2.setState(dma_channel_state_t s, dma_channel_trigger_t t, void* src, void* dest, int size){
    call DMAChannelCtrl2.setStateRaw(*(int*)&s,
				     *(int*)&t,
				     src,
				     dest,
				     size);
  }
  async command void DMAChannelCtrl2.setStateRaw(uint16_t s, uint16_t t, void* src, void* dest, int size) {
    DMA2SA = (uint16_t)src;
    DMA2DA = (uint16_t)dest;
    DMA2SZ = size;
    DMACTL0 &= ~(DMATSEL_MASK << DMA2TSEL_SHIFT);
    DMACTL0 |= t << DMA2TSEL_SHIFT;
    DMA2CTL = s;
    return;
  }

  async command dma_channel_state_t DMAChannelCtrl2.getState(){
    dma_channel_state_t s = *(dma_channel_state_t*) &DMA2CTL;
    return s;
  }

  async command void* DMAChannelCtrl2.getSource() {
    return (void*)DMA2SA;
  }

  async command void* DMAChannelCtrl2.getDestination() {
    return (void*)DMA2DA;
  }

  async command int DMAChannelCtrl2.getSize() {
    return DMA2SZ;
  }

  async command dma_channel_trigger_t DMAChannelCtrl2.getTrigger() {
    dma_channel_trigger_t t;
    t.trigger = ((DMACTL0 >> DMA2TSEL_SHIFT) & DMATSEL_MASK);
    return t;
  }

  async command void DMAChannelCtrl2.reset(){
    DMA2CTL = 0;
    DMA2SA = 0;
    DMA2DA = 0;
    DMA2SZ = 0;
  }
}
