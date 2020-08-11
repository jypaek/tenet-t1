// $Id: HPLCC2420M.nc,v 1.10 2007/03/04 23:51:29 lnachman Exp $

/*									tab:4
 * "Copyright (c) 2000-2003 The Regents of the University  of California.  
 * All rights reserved.
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose, without fee, and without written agreement is
 * hereby granted, provided that the above copyright notice, the following
 * two paragraphs and the author appear in all copies of this software.
 * 
 * IN NO EVENT SHALL THE UNIVERSITY OF CALIFORNIA BE LIABLE TO ANY PARTY FOR
 * DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES ARISING OUT
 * OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN IF THE UNIVERSITY OF
 * CALIFORNIA HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 * 
 * THE UNIVERSITY OF CALIFORNIA SPECIFICALLY DISCLAIMS ANY WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE.  THE SOFTWARE PROVIDED HEREUNDER IS
 * ON AN "AS IS" BASIS, AND THE UNIVERSITY OF CALIFORNIA HAS NO OBLIGATION TO
 * PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS."
 *
 * Copyright (c) 2002-2003 Intel Corporation
 * All rights reserved.
 *
 * This file is distributed under the terms in the attached INTEL-LICENSE     
 * file. If you do not find these files, copies can be found by writing to
 * Intel Research Berkeley, 2150 Shattuck Avenue, Suite 1300, Berkeley, CA, 
 * 94704.  Attention:  Intel License Inquiry.
 */
/*
 *
 * Authors: Phil Buonadonna, Robbie Adler
 * Date last modified:  $Revision: 1.10 $
 *
 */

/**
 * @author Phil Buonadonna
 * @author Robbie Adler
 */

includes MMU;
includes profile;
module HPLCC2420M {
  provides {
    interface StdControl;
    interface HPLCC2420;
    interface HPLCC2420RAM;
    interface HPLCC2420FIFO;
    interface HPLCC2420Interrupt as InterruptFIFOP;
    interface HPLCC2420Interrupt as InterruptFIFO;
    interface HPLCC2420Interrupt as InterruptCCA;
    interface HPLCC2420Capture as CaptureSFD;
  }
  uses {
    interface StdControl as GPIOControl;
    interface PXA27XGPIOInt as FIFOP_GPIOInt;
    interface PXA27XGPIOInt as FIFO_GPIOInt;
    interface PXA27XGPIOInt as CCA_GPIOInt;
    interface PXA27XGPIOInt as SFD_GPIOInt;
    interface PXA27XDMAChannel as RxDMAChannel;
    interface PXA27XDMAChannel as TxDMAChannel;
  }
}
implementation
{

#define USE_DMA 0
#define DEBUG 0
#define TXDEBUG 0
#define RXDEBUG 0

  uint8_t gbDMAChannelInitDone;
  bool gbIgnoreTxDMA;
  bool gRadioOpInProgress;    
  
  uint8_t* rxbuf;
  uint8_t* txbuf;
  uint8_t* txrambuf;
  uint8_t* rxrambuf;
  uint8_t txlen;
  uint8_t rxlen;
  uint8_t txramlen;
  uint8_t rxramlen;
  uint8_t rxdummy,txdummy;
  uint16_t txramaddr;
  uint16_t rxramaddr;
  uint32_t errno;
  
#define HPLCC2420_DBG_LEVEL (DBG_USR1) 
#define DEASSERT_SPI_CS {TOSH_uwait(1); TOSH_SET_CC_CSN_PIN();}
#define ASSERT_SPI_CS {TOSH_CLR_CC_CSN_PIN(); TOSH_uwait(1);}
#define DRAIN_RXFIFO(_tmp) {while (SSSR_3 & SSSR_RNE) _tmp = SSDR_3;}
  
  command result_t StdControl.init() {

    GPIO_SET_ALT_FUNC(SSP3_SCLK,SSP3_SCLK_ALTFN,GPIO_OUT);
    GPIO_SET_ALT_FUNC(SSP3_TXD,SSP3_TXD_ALTFN,GPIO_OUT);
    GPIO_SET_ALT_FUNC(SSP3_RXD,SSP3_RXD_ALTFN,GPIO_IN);
    //    _PXA_setaltfn(SSP3_SFRM,SSP3_SFRM_ALTFN,GPIOIN);

    atomic{
#if USE_DMA
      gbDMAChannelInitDone = 2;
#else
      gbDMAChannelInitDone = 0;
#endif
      gRadioOpInProgress = FALSE;
    }
#if USE_DMA
    call RxDMAChannel.requestChannel(DMAID_SSP3_RX,DMA_Priority1, TRUE); 
    call TxDMAChannel.requestChannel(DMAID_SSP3_TX,DMA_Priority1, TRUE); 
    
    call TxDMAChannel.setTargetAddr(0x41900010);
    call TxDMAChannel.enableSourceAddrIncrement(TRUE);
    call TxDMAChannel.enableTargetAddrIncrement(FALSE);
    call TxDMAChannel.enableSourceFlowControl(FALSE);
    call TxDMAChannel.enableTargetFlowControl(TRUE);
    call TxDMAChannel.setMaxBurstSize(DMA_8ByteBurst);
    call TxDMAChannel.setTransferWidth(DMA_1ByteWidth);
    
    call RxDMAChannel.setSourceAddr(0x41900010);
    call RxDMAChannel.enableSourceAddrIncrement(FALSE);
    call RxDMAChannel.enableTargetAddrIncrement(TRUE);
    call RxDMAChannel.enableSourceFlowControl(TRUE);
    call RxDMAChannel.enableTargetFlowControl(FALSE);
    call RxDMAChannel.setMaxBurstSize(DMA_8ByteBurst);
    call RxDMAChannel.setTransferWidth(DMA_1ByteWidth);
#endif
    call GPIOControl.init();
    
    return SUCCESS;
  } 

  command result_t StdControl.start() {


    CKEN |= (CKEN_CKEN4);

    // Serial Clock Rate = 6.5 MHz, Frame Format = SPI, Data Size = 8-bit
    // RX&TX 
    SSCR1_3 = (SSCR1_TRAIL | SSCR1_RFT(8) | SSCR1_TFT(8));
    SSTO_3 = (96*8);
    SSCR0_3 = (SSCR0_SCR(1) | SSCR0_FRF(0) | SSCR0_DSS(0x7) | SSCR0_SSE);
 
    call GPIOControl.start();
    return SUCCESS;
  }

  command result_t StdControl.stop() { 

    call GPIOControl.stop();

    SSCR0_3 &= ~(SSCR0_SSE);  // Disable SSP3 port
    CKEN &= ~(CKEN_CKEN4);

    return SUCCESS;
  }

  /**
   * Send a command strobe
   * 
   * @return status byte from the chipcon
   */ 
  result_t getSSPPort(){
    result_t res;
    atomic{
      if(gRadioOpInProgress){
	res = FAIL;
      }
      else{
	res = SUCCESS;
	gRadioOpInProgress = TRUE;
      }
    }
    return res;
  }

  result_t releaseSSPPort(){
    result_t res;
    atomic{
      if(gRadioOpInProgress){
	res = SUCCESS;
	gRadioOpInProgress = FALSE;
      }
      else{
	res = FAIL;
      }
    }
    return res;
  }
  
  task void HPLCC2420CmdContentionError(){
    trace(DBG_USR1,"ERROR:  HPLC2420.cmd has attempted to access the radio during an existing radio operation\r\n");
  }
  
  task void HPLCC2420CmdReleaseError(){
    trace(DBG_USR1,"ERROR:  HPLCC2420.cmd failed while attempting to release the SSP port\r\n");
  }
  
  async command uint8_t HPLCC2420.cmd(uint8_t addr) {
    uint8_t status = 0;
    uint8_t tmp;

    if(getSSPPort()==FAIL){
      //something else is using the radio, print a message and return;
      //post HPLCC2420CmdContentionError();
      return 0;
    }
   
    // Empty the PXA recieve fifo...
    DRAIN_RXFIFO(tmp);
    
    ASSERT_SPI_CS;
    SSDR_3 = addr;
    while (SSSR_3 & SSSR_BSY);
    DEASSERT_SPI_CS;
    status = SSDR_3;
    
    if(releaseSSPPort() == FAIL){
      post HPLCC2420CmdReleaseError();
      return 0;
    }
#if DEBUG
    trace(HPLCC2420_DBG_LEVEL,"HPLCC2420 cmd %#x..status =%#x\r\n",addr,status);
#endif
    return status;
  }
  
  /**
   * Transmit 16-bit data
   *
   * @return status byte from the chipcon.  0xff is return of command failed.
   */

  task void HPLCC2420WriteContentionError(){
    trace(DBG_USR1,"ERROR:  HPLCC2420.write has attempted to access the radio during an existing radio operation\r\n");
  }  
  
  task void HPLCC2420WriteError(){
    trace(DBG_USR1,"ERROR:  HPLCC2420.write failed while attempting to release the SSP port\r\n");
  }   
  
  async command uint8_t HPLCC2420.write(uint8_t addr, uint16_t data) {
    uint8_t status = 0;
    uint8_t tmp;
    
    if(getSSPPort()==FAIL){
      //something else is using the radio, print a message and return;
      post HPLCC2420WriteContentionError();
      return 0;
    }
    
#if DEBUG
    trace(HPLCC2420_DBG_LEVEL,"HPLCC2420 write %#x to %#x\r\n",data,addr);
#endif

    //drain the fifo
    DRAIN_RXFIFO(tmp);
 
    ASSERT_SPI_CS;
    
    SSDR_3 = addr;
    SSDR_3 = ((data >> 8) & 0xFF);
    SSDR_3 = (data & 0xFF);
   
    while (SSSR_3 & SSSR_BSY);

    DEASSERT_SPI_CS;
    status = SSDR_3;
    //drain the fifo since we got a couple of extra samples in there due to writes>reads
    DRAIN_RXFIFO(tmp);
   
    if(releaseSSPPort() == FAIL){
      post HPLCC2420WriteError();
      return 0;
    }
    return status;
  }
  
  task void HPLCC2420ReadContentionError(){
    trace(DBG_USR1,"ERROR:  HPLCC2420.read has attempted to access the radio during an existing radio operation\r\n");
  }
  
  task void HPLCC2420ReadReleaseError(){
    trace(DBG_USR1,"ERROR:  HPLCC2420.read failed while attempting to release the SSP port\r\n");
  }
  
  /**
   * Read 16-bit data
   *
   * @return 16-bit register value
   */
  async command uint16_t HPLCC2420.read(uint8_t addr) {
    uint16_t data = 0;
    uint8_t tmp;
    
    if(getSSPPort()==FAIL){
      //something else is using the radio, print a message and return;
      post HPLCC2420ReadContentionError();
      return 0;
    }
    
#if DEBUG
    trace(HPLCC2420_DBG_LEVEL,"HPLCC2420 read from %#x\r\n",addr);
#endif    

    //drain the fifo so that we're in the right state
    DRAIN_RXFIFO(tmp);
    
    ASSERT_SPI_CS;
    
    SSDR_3 = (addr | 0x40);
    SSDR_3 = 0;
    SSDR_3 = 0;
    
    while (SSSR_3 & SSSR_BSY);
    DEASSERT_SPI_CS;
    
    tmp = SSDR_3;
    data = SSDR_3;
    data = ((data << 8 ) & 0xFF00);
    data |= SSDR_3;
    
    DRAIN_RXFIFO(tmp);
    
    if(releaseSSPPort() == FAIL){
      post HPLCC2420ReadReleaseError();
      return 0;
    }
    
    return data;      
  }


  task void signalRAMRd() {
    uint16_t ramaddr;
    uint8_t ramlen;
    uint8_t* rambuf;
    
    atomic{
      ramaddr = rxramaddr;
      ramlen = rxramlen;
      rambuf = rxrambuf;
    }

    signal HPLCC2420RAM.readDone(ramaddr, ramlen, rambuf);
  }
  
  task void HPLCC2420RAMReadContentionError(){
    trace(DBG_USR1,"ERROR:  HPLCC2420RAM.read has attempted to access the radio during an existing radio operation\r\n");
  }
  task void HPLCC2420RamReadReleaseError(){
    trace(DBG_USR1,"ERROR:  HPLCC2420RAM.read failed while attempting to release the SSP port\r\n");
  }  
  
  async command result_t HPLCC2420RAM.read(uint16_t addr, uint8_t length, uint8_t* buffer) {
    uint8_t i = 0, tmp;
    uint32_t temp32;

    // XXX - To simplify things, this only supports 11 byte reads. Longer would be
    // signficantly more complicated.
         
#if DEBUG
    trace(HPLCC2420_DBG_LEVEL,"HPLCC2420 read %d bytes from %#x\r\n",length,addr);
#endif
    if(getSSPPort()==FAIL){
      //something else is using the radio, print a message and return;
      post HPLCC2420RAMReadContentionError();
      return 0;
    }
   
    //flush the SSP rx fifo and save state
    DRAIN_RXFIFO(tmp);
    
    atomic {
      rxramaddr = addr;
      rxramlen = length;
      rxrambuf = buffer;
    }
    
    ASSERT_SPI_CS;
    
    SSDR_3 = ((addr & 0x7F) | 0x80);
    SSDR_3 = (((addr >> 1) & 0xC0) | 0x20);
    //wait for the bytes to get out, but let the fifo over flow
    while (SSSR_3 & SSSR_BSY);
    
    while(length >16){
      //still have more than 16 byte to go, do a "burst"
      for(i=0; i<16; i++){
	SSDR_3 = 0;
      }
      while(SSSR_3 & SSSR_BSY);
      for(i=0; i<16; i++){
	temp32=SSDR_3;
	*buffer++ = temp32; 
      }
      length -= 16;
    }
    for(i=0;i<length;i++){
      SSDR_3 = 0;
    }
    while(SSSR_3 & SSSR_BSY);

    for(i=0; i<length; i++){
      temp32=SSDR_3;
      *buffer++ = temp32; 
    }
    DEASSERT_SPI_CS;      
    DRAIN_RXFIFO(tmp);
    
    if(releaseSSPPort() == FAIL){
      post HPLCC2420RamReadReleaseError();
      return 0;
    }
    return post signalRAMRd();
  }
  

  task void signalRAMWr() {
    uint16_t ramaddr;
    uint8_t ramlen;
    uint8_t* rambuf;
    atomic{
      ramaddr = txramaddr;
      ramlen = txramlen;
      rambuf = txrambuf;
    }
    
    signal HPLCC2420RAM.writeDone(ramaddr, ramlen, rambuf);
  }

  task void HPLCC2420RAMWriteContentionError(){
    trace(DBG_USR1,"ERROR:  HPLCC2420RAM.write has attempted to access the radio during an existing radio operation\r\n");
  }
  task void HPLCC2420RamWriteReleaseError(){
    trace(DBG_USR1,"ERROR:  HPLCC2420RAM.write failed while attempting to release the SSP port\r\n");
  }
  
  async command result_t HPLCC2420RAM.write(uint16_t addr, uint8_t length, uint8_t* buffer) {
    uint8_t i = 0, tmp;
    

#if DEBUG
    trace(HPLCC2420_DBG_LEVEL,"HPLCC2420 write %d bytes to %#x\r\n",length,addr);
#endif
    if(getSSPPort()==FAIL){
      //something else is using the radio, print a message and return;
      post HPLCC2420RAMWriteContentionError();
      return 0;
    }
    
    DRAIN_RXFIFO(tmp);
    atomic {
        txramaddr = addr;
        txramlen = length;
        txrambuf = buffer;
    }
    
    ASSERT_SPI_CS;
    
    SSDR_3 = ((addr & 0x7F) | 0x80);
    SSDR_3 = ((addr >> 1) & 0xC0);
    while (SSSR_3 & SSSR_BSY);
    
    while(length >16){
      //still have more than 16 byte to go, do a "burst"
      for(i=0; i<16; i++){
	SSDR_3 = *buffer++;
      }
      while(SSSR_3 & SSSR_BSY);
      length -= 16;
    }
    for(i=0;i<length;i++){
      SSDR_3 = *buffer++;
    }
    while(SSSR_3 & SSSR_BSY);
    
    //now clear out the FIFO
    DEASSERT_SPI_CS;
   
    DRAIN_RXFIFO(tmp);

    if(releaseSSPPort() == FAIL){
      post HPLCC2420RamWriteReleaseError();
      return 0;
    }
    
    return post signalRAMWr();
  }

  task void signalRXFIFO() {
    uint8_t len, *buf;
    atomic{
      len = rxlen;
      buf = rxbuf;
    }
    signal HPLCC2420FIFO.RXFIFODone(len, buf);
  }

  task void HPLCC2420FIFOReadRxFifoContentionError(){ 
    trace(DBG_USR1,"ERROR:  HPLCC2420FIFO.readRXFIFO has attempted to access the radio during an existing radio operation\r\n");
  }
  task void HPLCC2420FifoReadRxFifoReleaseError(){
    trace(DBG_USR1,"ERROR:  HPLCC2420FIFO.readRXFIFO failed while attempting to release the SSP port\r\n");
  }
  /**
   * Read from the RX FIFO queue.  Will read bytes from the queue
   * until the length is reached (determined by the first byte read).
   * RXFIFODone() is signalled when all bytes have been read or the
   * end of the packet has been reached.
   *
   * @param length number of bytes requested from the FIFO
   * @param data buffer bytes should be placed into
   *
   * @return SUCCESS if the bus is free to read from the FIFO
   */
  async command result_t HPLCC2420FIFO.readRXFIFO(uint8_t length, uint8_t *data) {
    uint32_t temp32;
    uint8_t status,tmp, OkToUse;
    uint8_t pktlen;
    result_t ret;
   
    if(getSSPPort()==FAIL){
      //something else is using the radio, print a message and return;
      post HPLCC2420FIFOReadRxFifoContentionError();
      return 0;
    }
   
#if RXDEBUG 
    trace(HPLCC2420_DBG_LEVEL,"HPLCC2420 readRXFIFO...length=%d\r\n",length);
    startProfile();
#endif
    
    //flush the receive fifo
    DRAIN_RXFIFO(tmp);
    
    //store stuff away correctlu
    atomic{
      rxbuf = data;
      OkToUse = gbDMAChannelInitDone;
    }
    
#if 0
    //for cache coherency reasons, we need to read in the length field from the radio's ram
    //read 1 byte from address 0x80
    ASSERT_SPI_CS;
      
    //put the address we're interested in out after formating it properly
    SSDR_3 = 0x80;
    SSDR_3 = (((0x80 >>1) & 0xc0) | 0x20);
    SSDR_3 = 0; //get the byte we care about
    
    while(SSSR_3 & SSSR_BSY);
    DEASSERT_SPI_CS;
      
    status = SSDR_3;
    tmp = SSDR_3;
    pktlen = SSDR_3;
      
#endif
      
    ASSERT_SPI_CS;
      
    //send the access RXFIFO command
    SSDR_3 = (CC2420_RXFIFO | 0x40);
    SSDR_3 = 0;
    while (SSSR_3 & SSSR_BSY);
    status = SSDR_3;
    pktlen = SSDR_3;
    data[0] = pktlen;
    data++;
#if 1
    //increment the length to include the length byte itself
    pktlen++;
#else
    //don't increment the length since we no longer need to read it out
#endif

    if (pktlen > 0  && (OkToUse == 0)) {
      //don't want to overflow memory...
      atomic{
	rxlen = (pktlen < length) ? pktlen : length;
      }
      
#if USE_DMA      
      //DO NOT USE DMA !!!
	
      cleanDCache(data-1,1);
      call RxDMAChannel.setTargetAddr((uint32_t)(rxbuf+1));
      call RxDMAChannel.setTransferLength(rxlen-1);
      
      //enable the dma interrupt and go
      SSCR1_3 |= SSCR1_RSRE;
      if(call RxDMAChannel.run(TRUE) == FAIL){
	errno = -1;
	ret=FAIL;
      }
      RxDMAInProgress = TRUE;
      atomic{
	gbIgnoreTxDMA = TRUE;
      }
      //just want to send something
      call TxDMAChannel.setSourceAddr((uint32_t)txbuf);
      call TxDMAChannel.enableSourceAddrIncrement(FALSE);
      call TxDMAChannel.setTransferLength(rxlen);
      
      //enable the dma interrupt and go
      SSCR1_3 |= SSCR1_TSRE;
      ret = call TxDMAChannel.run(TRUE);  
#else
      //read it out manually...don't use DMA  we have a 16 entry fifo, so let's take advantage!
      {
	//introduce a new scope to avoid compiler warnings
	int i;
	atomic{
	  length = rxlen; //overload the parameter that was passed to use with the proper value
	}
	while(length >16){
	  //still have more than 16 byte to go, do a "burst"
	  for(i=0; i<16; i++){
	    SSDR_3 = 0;
	  }
	  while(SSSR_3 & SSSR_BSY);
	  for(i=0; i<16; i++){
	    temp32=SSDR_3;
	    *data++ = temp32; 
	  }
	  length -= 16;
	}
	for(i=0;i<length;i++){
	  SSDR_3 = 0;
	}
	while(SSSR_3 & SSSR_BSY);
	for(i=0; i<length; i++){
	  temp32=SSDR_3;
	  *data++ = temp32; 
	}
	post signalRXFIFO();
	DEASSERT_SPI_CS;
	ret = SUCCESS;
	
#if RXDEBUG
	stopProfile();
	printProfile(profilePrintAll);
#endif
      
      }
#endif
    }
    else {
      DEASSERT_SPI_CS;
      ret=FAIL;
    }
    if(releaseSSPPort() == FAIL){
      post HPLCC2420FifoReadRxFifoReleaseError();
      return 0;
    }
    
    return ret;
  }

  task void signalTXFIFO() {
    uint8_t len, *buf;
    atomic{
      len = txlen;
      buf = txbuf;
    }
    signal HPLCC2420FIFO.TXFIFODone(len, buf);
  }
  
  task void HPLCC2420FifoWriteTxFifoContentioError(){
    trace(DBG_USR1,"ERROR:  HPLCC2420FIFO.writeTXFIFO has attempted to access the radio during an existing radio operation\r\n");
  }
  task void HPLCC2420FifoWriteTxFifoReleaseError(){
    trace(DBG_USR1,"ERROR:  HPLCC2420FIFO.writeTXFIFO failed while attempting to release the SSP port\r\n");
  }
  
  /**
   * Writes a series of bytes to the transmit FIFO.
   *
   * @param length length of data to be written
   * @param data the first byte of data
   *
   * @return SUCCESS if the bus is free to write to the FIFO
   */
  async command result_t HPLCC2420FIFO.writeTXFIFO(uint8_t length, uint8_t *data) {
    uint8_t OkToUse;
    if(getSSPPort()==FAIL){
      //something else is using the radio, print a message and return;
      post HPLCC2420FifoWriteTxFifoContentioError();
      return FAIL;
    }
    
#if TXDEBUG
    trace(HPLCC2420_DBG_LEVEL,"HPLCC2420 writeTXFIFO length=%d\r\n",length);
    startProfile();
#endif
    
    atomic {
      txbuf = data;
      txlen = length;
      OkToUse = gbDMAChannelInitDone;
    }
#if USE_DMA
    if(OkToUse == 0){
      cleanDCache(txbuf, txlen);
      
      call TxDMAChannel.setSourceAddr((uint32_t)data);
      call TxDMAChannel.enableSourceAddrIncrement(TRUE);
      call TxDMAChannel.setTransferLength(length);
      
      //request a permanent channel
      atomic{
	gbIgnoreTxDMA = FALSE;
      }
      ASSERT_SPI_CS;
      
      SSDR_3 = (CC2420_TXFIFO);
      while (SSSR_3 & SSSR_BSY);
      
      SSCR1_3 |= SSCR1_TSRE;
      call TxDMAChannel.run(TRUE);  
      return SUCCESS;
    }
    else{
      return FAIL;
    }
#else
    {
      //introduce a new scope to avoid compiler warnings
      int i;
      uint8_t tmp;
      
      DRAIN_RXFIFO(tmp);
      
      ASSERT_SPI_CS;
      SSDR_3 = (CC2420_TXFIFO);
      while(SSSR_3 & SSSR_BSY);
      
      while(length >16){
	//still have more than 16 byte to go, do a "burst"
	for(i=0; i<16; i++){
	  SSDR_3 = *data++;
	}
	while(SSSR_3 & SSSR_BSY);
	length -= 16;
      }
      for(i=0;i<length;i++){
	SSDR_3 = *data++;
      }
      while(SSSR_3 & SSSR_BSY);
      
      //now clear out the FIFO
      for(i=0; i<16; i++){
	tmp = SSDR_3; 
      }
      post signalTXFIFO();
      DEASSERT_SPI_CS;
      DRAIN_RXFIFO(tmp);
      
      if(releaseSSPPort() == FAIL){
	post HPLCC2420FifoWriteTxFifoReleaseError();
	return 0;
      }
#if TXDEBUG
      stopProfile();
      printProfile(profilePrintAll);
#endif
      return SUCCESS;
    }
#endif
  }

  async command result_t InterruptFIFOP.startWait(bool low_to_high){
    // set FIFOP to a rising edge interrupt
    atomic {
      call FIFOP_GPIOInt.disable();
      call FIFOP_GPIOInt.clear();
      if (low_to_high) {
	call FIFOP_GPIOInt.enable(TOSH_RISING_EDGE);
      }
      else {
	call FIFOP_GPIOInt.enable(TOSH_FALLING_EDGE);
      }
    }
    return SUCCESS;
  }

  async command result_t InterruptFIFO.startWait(bool low_to_high){
    // set FIFOP to a rising edge interrupt
    atomic {
      call FIFO_GPIOInt.disable();
      call FIFO_GPIOInt.clear();
      if (low_to_high) {
	call FIFO_GPIOInt.enable(TOSH_RISING_EDGE);
      }
      else {
	call FIFO_GPIOInt.enable(TOSH_FALLING_EDGE);
      }
    }
    return SUCCESS;
  }

  async command result_t InterruptCCA.startWait(bool low_to_high){
    // set FIFOP to a rising edge interrupt
    atomic {
      call CCA_GPIOInt.disable();
      call CCA_GPIOInt.clear();
      if (low_to_high) {
	call CCA_GPIOInt.enable(TOSH_RISING_EDGE);
      }
      else {
	call CCA_GPIOInt.enable(TOSH_FALLING_EDGE);
      }
    }
    return SUCCESS;
  }

  async command result_t CaptureSFD.enableCapture(bool low_to_high){
    // set FIFOP to a rising edge interrupt
    atomic {
      //call SFD_GPIOInt.disable();
      // call SFD_GPIOInt.clear();
      call SFD_GPIOInt.enable(TOSH_BOTH_EDGE);
#if 0
      if (low_to_high) {
	call SFD_GPIOInt.enable(TOSH_RISING_EDGE);
      }
      else {
	call SFD_GPIOInt.enable(TOSH_FALLING_EDGE);
      }
#endif
    }
    return SUCCESS;
  }
 

  async command result_t InterruptFIFOP.disable(){
    // disable FIFOP interrupt
    call FIFOP_GPIOInt.disable();
    return SUCCESS;
  }

  async command result_t InterruptFIFO.disable(){
    // disable FIFOP interrupt
    call FIFO_GPIOInt.disable();
    return SUCCESS;
  }

  async command result_t InterruptCCA.disable(){
    // disable FIFOP interrupt
    call CCA_GPIOInt.disable();
    return SUCCESS;
  }

  async command result_t CaptureSFD.disable(){
    // disable FIFOP interrupt
    call SFD_GPIOInt.disable();
    return SUCCESS;
  }

  async event void FIFOP_GPIOInt.fired() {
    result_t result;
    call FIFOP_GPIOInt.clear();
    result = signal InterruptFIFOP.fired();
    if (FAIL == result) {
      call InterruptFIFOP.disable();
    }

    return;
  }

  async event void FIFO_GPIOInt.fired() {
    result_t result;
    call FIFO_GPIOInt.clear();
    result = signal InterruptFIFO.fired();
    if (FAIL == result) {
      call InterruptFIFO.disable();
    }

    return;
  }

  async event void CCA_GPIOInt.fired() {
    result_t result;
    call CCA_GPIOInt.clear();
    result = signal InterruptCCA.fired();
    if (FAIL == result) {
      call InterruptCCA.disable();
    }
    return;
  }

  async event void SFD_GPIOInt.fired() {
    result_t result;
    call SFD_GPIOInt.clear();
    result = signal CaptureSFD.captured(0);
    if (result == FAIL) {
      call CaptureSFD.disable();
    }
    
    return;
  }

  event result_t RxDMAChannel.requestChannelDone(){
    atomic {gbDMAChannelInitDone -= 1;}
    return SUCCESS;
  }
  
  async event void RxDMAChannel.startInterrupt(){
    return;
  }
  
  async event void RxDMAChannel.stopInterrupt(uint16_t numbBytesSent){
    return;
  }
    
  async event void RxDMAChannel.eorInterrupt(uint16_t numBytesSent){
    return;
  }
  
  task void HPLCC2420RxDMAEndInterruptReleaseError(){
    trace(DBG_USR1,"ERROR:  HPLCC2420FIFO.readRXFIFO DMA version failed while attempting to release the SSP port\r\n");
  }  

  async event void RxDMAChannel.endInterrupt(uint16_t numBytesSent){
    //turn off things and post a task to signal that we're done
    DEASSERT_SPI_CS;
    if(releaseSSPPort() == FAIL){
      post HPLCC2420RxDMAEndInterruptReleaseError();
    }

    SSCR1_3 &= ~SSCR1_RSRE;
    atomic{
      invalidateDCache(rxbuf, rxlen);
    }
    post signalRXFIFO();
    return;
  }
  
  event result_t TxDMAChannel.requestChannelDone(){
    atomic {gbDMAChannelInitDone -= 1;}
    return SUCCESS;
  }
  
  async event void TxDMAChannel.startInterrupt(){
    return;
  }
  
  async event void TxDMAChannel.stopInterrupt(uint16_t numbBytesSent){
    return;
  }
    
  async event void TxDMAChannel.eorInterrupt(uint16_t numBytesSent){
    return;
  }
  
  task void HPLCC2420TxDmaEndInterrupt(){
    trace(DBG_USR1,"ERROR:  HPLCC2420FIFO.writeTXFIFO DMA version failed while attempting to release the SSP port\r\n");
  }
  async event void TxDMAChannel.endInterrupt(uint16_t numBytesSent){
    uint8_t tmp, localIgnoreTxDMA;
    atomic{
      localIgnoreTxDMA = gbIgnoreTxDMA;
    }
    if(localIgnoreTxDMA == FALSE){
      SSCR1_3 &= ~SSCR1_TSRE;
      // Drain the RXFIFO
      while(SSSR_3 & SSSR_RNE){
	tmp = SSDR_3;
      }
      DEASSERT_SPI_CS;
      if(releaseSSPPort() == FAIL){
	post HPLCC2420TxDmaEndInterrupt();
      }
      
      post signalTXFIFO();
    }
    return;
  }
  
  default async event result_t InterruptFIFOP.fired() {
    return FAIL;
  }

  default async event result_t InterruptFIFO.fired() {
    return FAIL;
  }

  default async event result_t InterruptCCA.fired() {
    return FAIL;
  }

  default async event result_t CaptureSFD.captured(uint16_t val) {
    return FAIL;
  }

  default async event result_t HPLCC2420FIFO.RXFIFODone(uint8_t length, uint8_t *data) { 
    return SUCCESS; 
  }

  default async event result_t HPLCC2420FIFO.TXFIFODone(uint8_t length, uint8_t *data) { 
    return SUCCESS; 
  }

  default async event result_t HPLCC2420RAM.readDone(uint16_t addr, uint8_t length, uint8_t *data) { 
    return SUCCESS; 
  }

  default async event result_t HPLCC2420RAM.writeDone(uint16_t addr, uint8_t length, uint8_t *data) { 
    return SUCCESS; 
  }

}
  




