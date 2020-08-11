/**
 * @author Robbie Adler
 **/

includes mmu;

module PXA27XI2SM{
  provides{
    interface BulkTxRx;
    interface I2S;
  }
  uses{
    interface PXA27XDMAChannel as RxDMAChannel;
    interface PXA27XDMAChannel as TxDMAChannel;
    interface PXA27XInterrupt as I2SInterrupt;
  }
}

implementation {

#include "paramtask.h"
  
#ifndef I2S_DEFAULTDMARXPRIORITY
#define I2S_DEFAULTDMARXPRIORITY (DMA_Priority2|DMA_Priority3|DMA_Priority4)
#endif

#ifndef I2S_DEFAULTDMATXPRIORITY
#define I2S_DEFAULTDMATXPRIORITY (DMA_Priority2|DMA_Priority3|DMA_Priority4)
#endif


  bool gInitDone=FALSE;
  bool gEnablePlayback = FALSE;
  bool gEnableRecord = FALSE;
  bool gBitClkInput = FALSE;
  bool gEnableMSBJustifiedMode = FALSE;
  I2SFifoLevel_t gRxFIFOLevel = I2S_8Samples;
  I2SFifoLevel_t gTxFIFOLevel = I2S_8Samples;
  I2SAudioDivider_t gAudioClkDivider = I2S_SYSCLK_2p053M;
  
  norace uint32_t *gRxBuffer;
  norace uint16_t gRxNumBytes, gRxBufferPos;
  
  //norace hack!!!
  norace uint32_t *gTxBuffer;
  norace uint16_t gTxNumBytes, gTxBufferPos;
  
  task void signalInitDone(){
    signal I2S.initI2SDone();
  }
  
  command result_t I2S.initI2S(){
    
    //unconditionally reconfigure the GPIO functionality just in case things get overwritten in between calls to init
    //this would cover the case where the port was use for a little while, unconfigured and used for something else, and then
    //reconfigured and used again
    
    if(gBitClkInput == TRUE){
      GPIO_SET_ALT_FUNC(I2S_BITCLK,I2S_BITCLK_IN_ALTFN, GPIO_IN);
    }
    else{
      GPIO_SET_ALT_FUNC(I2S_BITCLK,I2S_BITCLK_OUT_ALTFN, GPIO_OUT);
    }
    
    GPIO_SET_ALT_FUNC(I2S_SYSCLK,I2S_SYSCLK_ALTFN, GPIO_OUT);
    GPIO_SET_ALT_FUNC(I2S_SYNC,I2S_SYNC_ALTFN, GPIO_OUT);
    GPIO_SET_ALT_FUNC(I2S_DATA_IN,I2S_DATA_IN_ALTFN, GPIO_IN);
    GPIO_SET_ALT_FUNC(I2S_DATA_OUT,I2S_DATA_OUT_ALTFN, GPIO_OUT);
    
    if(gInitDone == FALSE){
      
      return call RxDMAChannel.requestChannel(DMAID_I2S_RX,I2S_DEFAULTDMARXPRIORITY, TRUE); 
    }
    else{
      post signalInitDone();
    }
    
    return SUCCESS;
  }
  
  
  /****************************************
   *I2S Configuration routines
   ****************************************/
 /**
   *enable the port
   *
   *@param enable:  port is enabled if TRUE, disabled if FALSE
   *
   *@return FAIL if error, SUCCESS otherwise
   **/
  command result_t I2S.enableI2S(bool enable){
    if(gInitDone == FALSE){
      return FAIL;
    }
    
    /**
     *
     * I2S_SYSCLK = K4 (113)
     * I2S_SYNC = J4 (31)
     * I2S_BITCLK = K1 (28)
     * I2S_DATA_IN = K2 (29)
     * I2S_DATA_OUT = G6 (30)
     *
     * 
     *
     * From section 14.4.1 of the PXA27X developer's manual, the step to init are:
     * 1.) set I2S_BITCLK direction
     * 2.) choose between I2S or MSB-justified modes.  WM8940 uses normal I2S mode
     * 3.) optionally use programmed I/O to prime the tx fifo
     * 4.) Set the SACRO to enable (set ENB bit) and to set tx and rx fifo thresholds 
     *
     *
     **/
    if(enable == TRUE){
      CKEN |= (CKEN_CKEN8);
      //SADIV = SADIV_SADIV(gAudioClkDivider);
      SACR0 = SACR0_RST;
      SACR0 &= ~SACR0_RST;
      SACR1 = ((gEnableMSBJustifiedMode == TRUE)?SACR1_AMSL:0) |  ((gEnableRecord == FALSE)?SACR1_DREC:0) |  ((gEnablePlayback == FALSE)?SACR1_DRPL:0);
      SADIV = SADIV_SADIV(gAudioClkDivider);
      SACR0 = SACR0 = SACR0_RFTH(gRxFIFOLevel) | SACR0_TFTH(gTxFIFOLevel) | ((gBitClkInput == FALSE)?SACR0_BCKD:0) | SACR0_ENB;
      // SADIV = SADIV_SADIV(gAudioClkDivider);
    } 
    else{
      
      CKEN &= ~CKEN_CKEN8;
	  
      SACR0 = SACR0_RST;
    }
    
    return SUCCESS;
  }

  /**
   *enable the port
   *
   *@param enable:  port is enabled for playback if TRUE, disabled if FALSE
   *
   *@return FAIL if error, SUCCESS otherwise
   **/
  command result_t I2S.enablePlayback(bool enable){
    
    gEnablePlayback = enable;
    return SUCCESS;
  }

  /**
   *enable the port
   *
   *@param enable:  port is enabled for recording if TRUE, disabled if FALSE
   *
   *@return FAIL if error, SUCCESS otherwise
   **/
  command result_t I2S.enableRecord(bool enable){
    
    gEnableRecord = enable;
    return SUCCESS;
  }

 
  /**
   *inform the port of the direciton of the I2S_BITCLK signal.
   *
   *@param enable:  signal is input if TRUE, output if FALSE
   *
   *@return FAIL if error, SUCCESS otherwise
   **/
  command result_t I2S.setBitClkDir(bool input){
    
    gBitClkInput = input;
    return SUCCESS;
  }

  /**
   *enable MSB-justified mode
   *
   *@param enable:  MSB-justified mode is used if TRUE, normal I2S mode is used of FALSE
   *
   *@return FAIL if error, SUCCESS otherwise
   **/
  command result_t I2S.enableMSBJustifiedMode(bool enable){
    
    gEnableMSBJustifiedMode = enable;
    return SUCCESS;
  }


  /**
   *configure the depth of the RX FIFO at which point an interrupt is generated
   *
   *@param level:  fifo level...see I2S.h for encodings
   *
   *@return FAIL if error, SUCCESS otherwise
   */
  command result_t I2S.setRxFifoLevel(I2SFifoLevel_t level){
    
    gRxFIFOLevel = level;
    return SUCCESS;
  }
  
  /**
   *configure the depth of the TX FIFO at which point an interrupt is generated
   *
   *@param level:  fifo level...see I2S.h for encodings
   *
   *@return FAIL if error, SUCCESS otherwise
   */
  command result_t I2S.setTxFifoLevel(I2SFifoLevel_t level){
    
    gTxFIFOLevel = level;
    return SUCCESS;
  }

  /**
   *configure the audio clock divider for the I2S hardware
   *
   *@param level:  clk divider...see I2S.h for encodings
   *
   *@return FAIL if error, SUCCESS otherwise
   */
  command result_t I2S.setAudioClkDivider(I2SAudioDivider_t divider){
    
    gAudioClkDivider = divider;
    return SUCCESS;
  }
  
  void configureRxDMA(uint8_t *RxBuffer, uint16_t NumBytes){
    call RxDMAChannel.setSourceAddr(0x40400080);
    call RxDMAChannel.setTargetAddr((uint32_t)RxBuffer);
    call RxDMAChannel.enableSourceAddrIncrement(FALSE);
    call RxDMAChannel.enableTargetAddrIncrement(TRUE);
    call RxDMAChannel.enableSourceFlowControl(TRUE);
    call RxDMAChannel.enableTargetFlowControl(FALSE);
    call RxDMAChannel.setTransferLength(NumBytes);
    call RxDMAChannel.setMaxBurstSize(DMA_32ByteBurst);
    call RxDMAChannel.setTransferWidth(DMA_4ByteWidth);
  }

  command result_t BulkTxRx.BulkReceive(uint8_t *RxBuffer, uint16_t NumBytes){
    atomic{
      gRxBuffer = (uint32_t *) RxBuffer;
      gRxNumBytes = NumBytes;
    }
    
    configureRxDMA(RxBuffer, NumBytes);
    
    call RxDMAChannel.run(DMA_ENDINTEN);
    
    return SUCCESS;
  }
  
  void configureTxDMA(uint8_t *TxBuffer, uint16_t NumBytes){
    call TxDMAChannel.setSourceAddr((uint32_t)TxBuffer);
    call TxDMAChannel.setTargetAddr(0x40400080);
    call TxDMAChannel.enableSourceAddrIncrement(TRUE);
    call TxDMAChannel.enableTargetAddrIncrement(FALSE);
    call TxDMAChannel.enableSourceFlowControl(FALSE);
    call TxDMAChannel.enableTargetFlowControl(TRUE);
    call TxDMAChannel.setTransferLength(NumBytes);
    call TxDMAChannel.setMaxBurstSize(DMA_32ByteBurst);
    call TxDMAChannel.setTransferWidth(DMA_4ByteWidth);
  }
  
  command result_t BulkTxRx.BulkTransmit(uint8_t *TxBuffer, uint16_t NumBytes){
    //port has now been opened
    atomic{
      gTxBuffer = (uint32_t *)TxBuffer;
      gTxNumBytes = NumBytes;
    }
    
    //flush the data back to memory
    configureTxDMA(TxBuffer,NumBytes);
    
    call TxDMAChannel.run(DMA_ENDINTEN);
    
    return SUCCESS;
  }

  command result_t BulkTxRx.BulkTxRx(BulkTxRxBuffer_t *TxRxBuffer, uint16_t NumBytes){
    
    return FAIL;
  }

  
  event result_t RxDMAChannel.requestChannelDone(){
    call TxDMAChannel.requestChannel(DMAID_I2S_TX,I2S_DEFAULTDMATXPRIORITY, TRUE); 
    
    return SUCCESS;
  }

  async event void RxDMAChannel.endInterrupt(uint16_t numBytesSent){
    //it is the handler's responsibility to call invalidateDCache((uint8_t *)gRxBuffer, gRxNumBytes);
    gRxBuffer = (uint32_t *)signal BulkTxRx.BulkReceiveDone((uint8_t *)gRxBuffer, 
							    gRxNumBytes);
    if(gRxBuffer){
      //we want to do another read of gRxNumBytes)
      //we should still have our DMA channel, so just all set size and run!
      call RxDMAChannel.preconfiguredRun((uint32_t)gRxBuffer, gRxNumBytes, FALSE);  
    }
    
  }
 
  async event void RxDMAChannel.eorInterrupt(uint16_t numBytesSent){

  }
    
  async event void RxDMAChannel.stopInterrupt(uint16_t numBytesSent){

  }
  
  async event void RxDMAChannel.startInterrupt(){

  }

  event result_t TxDMAChannel.requestChannelDone(){
    
    gInitDone = TRUE;
    post signalInitDone();
    
    return SUCCESS;
  }

  async event void TxDMAChannel.endInterrupt(uint16_t numBytesSent){
    gTxBuffer = (uint32_t *)signal BulkTxRx.BulkTransmitDone((uint8_t *)gTxBuffer, 
							     gTxNumBytes);
    if(gTxBuffer){
      //we want to do another read of gRxNumBytes)
      
#if 0
      configureTxDMA(gTxBuffer,gTxNumBytes);
      call TxDMAChannel.run(DMA_ENDINTEN);
#else
      call TxDMAChannel.preconfiguredRun((uint32_t)gTxBuffer, gTxNumBytes, TRUE);  
#endif
    }
    
  }
 
  async event void TxDMAChannel.eorInterrupt(uint16_t numBytesSent){

  }
    
  async event void TxDMAChannel.stopInterrupt(uint16_t numBytesSent){

  }
  
  async event void TxDMAChannel.startInterrupt(){

  }

  async event void I2SInterrupt.fired(){

    return;
  }

  default async event uint8_t *BulkTxRx.BulkReceiveDone(uint8_t *RxBuffer, 
							uint16_t NumBytes){return NULL;}
  default async event uint8_t *BulkTxRx.BulkTransmitDone(uint8_t *TxBuffer, 
							 uint16_t NumBytes){return NULL;}
  default async event BulkTxRxBuffer_t *BulkTxRx.BulkTxRxDone(BulkTxRxBuffer_t *TxRxBuffer, 
							      uint16_t NumBytes){return NULL;}
  
}
