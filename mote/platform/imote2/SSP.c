/**
 * @author Robbie Adler
 **/

/***
 *
 * standard implentation for all iMote2 SSP modules.  This file is in
 * intended to #included into the respectived SSPXM.nc module
 *
 **/

#include "paramtask.h"

void printNumROR(uint32_t numROR);
DEFINE_PARAMTASK(printNumROR);

  
//declare component state and initialize it to something reasonable just in case the user does something stupid
SSPFrameFormat_t gFrameFormat = SSP_SSP;
SSPDataWidth_t gDataWidth = SSP_16bits;
bool gEnableInvertedSFRM = TRUE;
SSPFifoLevel_t gRxFifoLevel = SSP_8Samples;
SSPFifoLevel_t gTxFifoLevel = SSP_8Samples;
SSPMicrowireTxSize_t gMicrowireSize = SSP_8bitCommands;
uint16_t gClkdivider = 1;
SSPClkMode_t gClkMode = SSP_normalmode; 
bool gSlaveClockFreeRunning = FALSE;
bool gMasterSCLK = TRUE;
bool gMasterSFRM = TRUE;
norace bool gReceiveWithoutTransmit = FALSE;
bool gRxFifoOverrun = TRUE;
bool gTxFifoUnderrun = TRUE;
bool gAudioClockSelect = FALSE;
bool gEnableSPIClkHigh = FALSE;
bool gShiftSPIClk = FALSE;
bool gPortInUse = FALSE;
bool gPortInitialized = FALSE;

bool gManualRxPinCtrl = FALSE;
bool gManualTxPinCtrl = FALSE;
bool gManualSFRMPinCtrl = FALSE;
bool gManualSCLKPinCtrl = FALSE;

  
//NOTE:  ARM HW guarantees that interrupts are disabled upon entering the handler.  This will be true
//       so long as we don't enable nested interrupts.
norace bool gFullDuplex = FALSE;
norace bool gHalfDuplex_Tx = FALSE;
norace bool gDMARxDone = FALSE;
norace bool gDMATxDone = FALSE;
bool gDMARxReady = FALSE;
bool gDMATxReady = FALSE;

uint8_t DummyReceive[32] __attribute__((aligned(32)));

norace uint16_t gNumRxFifoOverruns, gNumTxRequests;
  
//norace hack!!!
norace uint16_t *gRxBuffer;
norace uint16_t gRxNumBytes, gRxBufferPos;
  
//norace hack!!!
norace uint16_t *gTxBuffer;
norace uint16_t gTxNumBytes, gTxBufferPos;
  
//norace hack!!!
norace BulkTxRxBuffer_t *gTxRxBuffer;
norace uint16_t gTxRxNumBytes;
   
uint32_t createSSCR0();
uint32_t createSSCR1();
result_t tryFullDuplex();
result_t TxRxInterruptHelper() __attribute__((always_inline));
  
result_t openPort(bool bRxDMAIntEnable, bool bTxDMAIntEnable){
    
  result_t status=SUCCESS;
  
  atomic{
    if(gPortInUse==TRUE){
      status = FAIL;
    }
    else{
      gPortInUse = TRUE;
    }
  }
  if(status==FAIL){
    return FAIL;
  }
    
  //turn on the port's clock
  CKEN |= (MYCKEN);
        
  if(gFrameFormat == SSP_PSP){
    _SSPSP = (SSPSP_SFRMWDTH(0)| SSPSP_SFRMDLY(0) | SSPSP_SCMODE(0));
  }
    
  _SSCR1= createSSCR1() | SSCR1_TRAIL | ((bRxDMAIntEnable==TRUE)?SSCR1_RSRE:0) | ((bTxDMAIntEnable==TRUE)?SSCR1_TSRE:0);
 
  _SSCR0 = createSSCR0();

  //clear the timeout bit in case it is already set (since we might not be handling that interrupts)
  _SSSR = SSSR_TINT;
  _SSTO = 512;
    
  //hack for now to enable testing of this fuunctionality
  if(gAudioClockSelect == TRUE){
    _SSACD = SSACD_ACPS(5) | SSACD_SCDB | SSACD_ACDS(1);
  }
    
  //initialize the port's interrupts and DMA channels if
  //it hasn't happened yet.
  if(gPortInitialized==FALSE){
    call SSPInterrupt.allocate();
    call SSPInterrupt.enable();
    gPortInitialized = TRUE;
  }

  //need to configure SSP pin for correct functionality
  if(gManualRxPinCtrl == FALSE){
    GPIO_SET_ALT_FUNC(MYSSP_RXD, MYSSP_RXD_ALTFN, GPIO_IN);
  }
    
  if(gManualTxPinCtrl == FALSE){
    GPIO_SET_ALT_FUNC(MYSSP_TXD, MYSSP_TXD_ALTFN, GPIO_OUT);
  }
  //configure SCLK to run in the correct direction
    
  if(gManualSCLKPinCtrl == FALSE){
    if(gMasterSCLK){
      GPIO_SET_ALT_FUNC(MYSSP_SCLK, MYSSP_SCLK_ALTFN, GPIO_OUT);
    }
    else{
      GPIO_SET_ALT_FUNC(MYSSP_SCLK, MYSSP_SCLK_ALTFN, GPIO_IN);
    }
  }
  //configure SFRM to run in the correct direction
  if(gManualSFRMPinCtrl == FALSE){
    if(gMasterSFRM){
      GPIO_SET_ALT_FUNC(MYSSP_SFRM, MYSSP_SFRM_ALTFN, GPIO_OUT);
    }
    else{
      GPIO_SET_ALT_FUNC(MYSSP_SFRM, MYSSP_SFRM_ALTFN, GPIO_IN);
    }
  }
    
  return SUCCESS;
}
  
result_t closePort(){
    
  atomic {
    gPortInUse = FALSE;
    gFullDuplex = FALSE;
    gHalfDuplex_Tx = FALSE;
    gDMARxReady = FALSE;
    gDMATxReady = FALSE;
    gDMARxDone = FALSE;
    gDMATxDone = FALSE;
    gRxBuffer = NULL;
    gRxNumBytes = 0;
    gTxBuffer = NULL;
    gTxNumBytes = 0;
    gTxRxBuffer= NULL;
    gTxRxNumBytes = 0;
  }

  _SSCR0 &= ~SSCR0_SSE; 
    
  //turn off the port's clock
  CKEN &= ~(MYCKEN);
  return SUCCESS;
}
   
void configureRxDMA(uint8_t *RxBuffer, uint16_t NumBytes, bool bEnableTargetAddrIncrement){
  call RxDMAChannel.setSourceAddr(MYFIFOADDR);
  call RxDMAChannel.setTargetAddr((uint32_t)RxBuffer);
  call RxDMAChannel.enableSourceAddrIncrement(FALSE);
  call RxDMAChannel.enableTargetAddrIncrement(bEnableTargetAddrIncrement);
  call RxDMAChannel.enableSourceFlowControl(TRUE);
  call RxDMAChannel.enableTargetFlowControl(FALSE);
  call RxDMAChannel.setTransferLength(NumBytes);
  //need to fix to guarantee that this is generic
  call RxDMAChannel.setMaxBurstSize( ((gRxFifoLevel+1) * (gDataWidth + 1)>>3)>>4);
  call RxDMAChannel.setTransferWidth((gDataWidth+1)>>3);
  
}

//default events....Note that the default events are an all or nothing thing.  If you
//implement one of the handlers, you have to implement all of them

default async event uint8_t *BulkTxRx.BulkReceiveDone(uint8_t *RxBuffer, 
						      uint16_t NumBytes){return NULL;}
default async event uint8_t *BulkTxRx.BulkTransmitDone(uint8_t *TxBuffer, 
						       uint16_t NumBytes){return NULL;}
default async event BulkTxRxBuffer_t *BulkTxRx.BulkTxRxDone(BulkTxRxBuffer_t *TxRxBuffer, 
							    uint16_t NumBytes){return NULL;}
  
command result_t BulkTxRx.BulkReceive(uint8_t *RxBuffer, uint16_t NumBytes){
           
  //call SSPInterrupt.disable();
    
  if(openPort(TRUE, FALSE)==FAIL){
    return FAIL;
  }
  atomic{
    gRxBuffer = (uint16_t *)RxBuffer;
    gRxNumBytes = NumBytes;
    gRxBufferPos = 0;
    gNumRxFifoOverruns=0;
    gFullDuplex = FALSE;
    gHalfDuplex_Tx = FALSE;
  }
    
  configureRxDMA(RxBuffer, NumBytes, TRUE);

  //request a non-permanent channel
  call RxDMAChannel.requestChannel(DMAID_MYSSP_RX,DEFAULTDMARXPRIORITY, FALSE); 
    
  return SUCCESS;
}

event result_t RxDMAChannel.requestChannelDone(){
  //so we've successfully been cleared to start doing something with our port...go!!
  uint32_t SSCR0;
  bool localFullDuplex, localHalfDuplex_Tx;
  atomic{
    localFullDuplex = gFullDuplex;
    localHalfDuplex_Tx = gHalfDuplex_Tx;
  }
    
  if(localFullDuplex==TRUE || localHalfDuplex_Tx==TRUE){
    atomic{
      gDMARxReady = TRUE;
    }
    tryFullDuplex();
  }
  else{
    call RxDMAChannel.run(DMA_ENDINTEN);  
    SSCR0 = _SSCR0 | SSCR0_SSE;
    _SSCR0 = SSCR0;
  }
    
  return SUCCESS;
}
  
async event void RxDMAChannel.startInterrupt(){

  return;
}
async event void RxDMAChannel.stopInterrupt(uint16_t numBytesSent){

  return;
}
async event void RxDMAChannel.eorInterrupt(uint16_t numBytesSent){

  return;
}
  
void printNumROR(uint32_t arg){
  uint32_t numROR = (uint32_t)arg;
  trace(DBG_USR1,"Num ROR's = %d\r\n",numROR);
}

async event void RxDMAChannel.endInterrupt(uint16_t numBytesSent){
        
  //invlidate the DCache so that we can bring our data in
  gDMARxDone=TRUE;
  if(gReceiveWithoutTransmit==TRUE){
     //we got here because we're in RWOT mode
    //it is the handler's responsibility to call invalidateDCache((uint8_t *)gRxBuffer, gRxNumBytes);
    gRxBuffer = (uint16_t *)signal BulkTxRx.BulkReceiveDone((uint8_t *)gRxBuffer, 
							    gRxNumBytes);
    if(gRxBuffer){
      //we want to do another read of gRxNumBytes)
      //we should still have our DMA channel, so just all set size and run!
#if 0
      call RxDMAChannel.setTargetAddr((uint32_t)gRxBuffer);
      call RxDMAChannel.setTransferLength(gRxNumBytes);
      call RxDMAChannel.run(TRUE);  
#else
      call RxDMAChannel.preconfiguredRun((uint32_t)gRxBuffer, gRxNumBytes);  
#endif
      
    }
    else{
      if(gNumRxFifoOverruns>0){
	POST_PARAMTASK(printNumROR, gNumRxFifoOverruns);
      }
      closePort();
    }    
  }
  else{
    TxRxInterruptHelper();
  }
  return;
}
  
void configureTxDMA(uint8_t *TxBuffer, uint16_t NumBytes){
  call TxDMAChannel.setSourceAddr((uint32_t)TxBuffer);
  call TxDMAChannel.setTargetAddr(MYFIFOADDR);
  call TxDMAChannel.enableSourceAddrIncrement(TRUE);
  call TxDMAChannel.enableTargetAddrIncrement(FALSE);
  call TxDMAChannel.enableSourceFlowControl(FALSE);
  call TxDMAChannel.enableTargetFlowControl(TRUE);
  call TxDMAChannel.setTransferLength(NumBytes);
  //need to fix to guarantee that this is generic
  call TxDMAChannel.setMaxBurstSize( ((gTxFifoLevel+1) * (gDataWidth + 1)>>3)>>4);
  call TxDMAChannel.setTransferWidth((gDataWidth+1)>>3);
   
}
  
command result_t BulkTxRx.BulkTransmit(uint8_t *TxBuffer, uint16_t NumBytes){
  result_t ret = SUCCESS;
  atomic{
    if(gReceiveWithoutTransmit==TRUE){
      ret = FAIL;
    } 
  }
  if(ret== FAIL){
    //the user want to configure the port to be in receive without transmit mode...this won't work well
    return ret;
  }

  if(openPort(TRUE, TRUE)==FAIL){
    //port was already open
    return FAIL;
  }
  //port has now been opened
  atomic{
    gTxBuffer = (uint16_t *)TxBuffer;
    gTxNumBytes = NumBytes;
    gFullDuplex = FALSE;
    gHalfDuplex_Tx = TRUE;
    gDMARxDone = FALSE;
    gDMATxDone = FALSE;
    gDMARxReady = FALSE;
    gDMATxReady = FALSE;
  }
    
  //flush the data back to memory
  cleanDCache(TxBuffer, NumBytes);
  configureTxDMA(TxBuffer,NumBytes);
  configureRxDMA(DummyReceive,NumBytes, FALSE);
       
  //request a non-permanent channel
  call TxDMAChannel.requestChannel(DMAID_MYSSP_TX,DEFAULTDMATXPRIORITY, FALSE); 
  call RxDMAChannel.requestChannel(DMAID_MYSSP_RX,DEFAULTDMARXPRIORITY, FALSE); 
    
  return SUCCESS;
}
  
event result_t TxDMAChannel.requestChannelDone(){
  //so we've successfully been cleared to start doing something with our port...go!!
    
  atomic{
    gDMATxReady = TRUE;
  }
  tryFullDuplex();
  return SUCCESS;
}

async event void TxDMAChannel.startInterrupt(){
  
  return;
}

async event void TxDMAChannel.stopInterrupt(uint16_t numBytesSent){
  
  return;
}

async event void TxDMAChannel.eorInterrupt(uint16_t numBytesSent){
  
  return;
}

async event void TxDMAChannel.endInterrupt(uint16_t numBytesSent){
  gDMATxDone=TRUE;
  if(TxRxInterruptHelper() == FAIL){
    if(gFullDuplex == FALSE && gHalfDuplex_Tx == FALSE){
      //catastrophic error...not sure why we have this interrupt
      closePort();
    }
  }
  return;
}
  
result_t TxRxInterruptHelper(){
  if(gDMATxDone==TRUE && gDMARxDone==TRUE){
    if(gFullDuplex == TRUE){
      invalidateDCache((uint8_t *)gTxRxBuffer->RxBuffer, gTxRxNumBytes);
      gTxRxBuffer = signal BulkTxRx.BulkTxRxDone(gTxRxBuffer,gTxRxNumBytes);
      
      if(gTxRxBuffer && gTxRxBuffer->RxBuffer && gTxRxBuffer->TxBuffer){
	cleanDCache(gTxRxBuffer->TxBuffer, gTxRxNumBytes);
	gDMARxDone=FALSE;
	gDMATxDone=FALSE;
	
	call RxDMAChannel.setTargetAddr((uint32_t)gTxRxBuffer->RxBuffer);
	call RxDMAChannel.setTransferLength(gTxRxNumBytes);
	call RxDMAChannel.run(TRUE);  
	call TxDMAChannel.setSourceAddr((uint32_t)gTxRxBuffer->TxBuffer);
	call TxDMAChannel.setTransferLength(gTxRxNumBytes);
	call TxDMAChannel.run(TRUE);  
      }
      else{
	closePort();
      }
      return SUCCESS;
    }
    else if(gHalfDuplex_Tx == TRUE){
      gTxBuffer = (uint16_t *)signal BulkTxRx.BulkTransmitDone((uint8_t *)gTxBuffer, 
							       gTxNumBytes);
      if(gTxBuffer){
	//we want to do another writeof gTxNumBytes)
	//we should still have our DMA channel, so just all set size and run!
	cleanDCache((uint8_t *)gTxBuffer, gTxNumBytes);
	gDMARxDone=FALSE;
	gDMATxDone=FALSE;
	
	call RxDMAChannel.setTransferLength(gTxNumBytes);
	call RxDMAChannel.run(TRUE);
	call TxDMAChannel.setSourceAddr((uint32_t)gTxBuffer);
	call TxDMAChannel.setTransferLength(gTxNumBytes);
	call TxDMAChannel.run(TRUE);  
      }
      else{
	closePort();
      }
      return SUCCESS;
    }
  }
  return FAIL;
}
  
  
command result_t BulkTxRx.BulkTxRx(BulkTxRxBuffer_t *TxRxBuffer, uint16_t NumBytes){
  
  result_t ret = SUCCESS;
  
  atomic{
    if(gReceiveWithoutTransmit==TRUE){
      ret = FAIL;
    } 
  }
  if(ret== FAIL){
    //the user want to configure the port to be in receive without transmit mode...this won't work well
    return ret;
  }
    
  if(openPort(TRUE, TRUE)==FAIL){
    //port was already open
    return FAIL;
  }
  //port has now been opened
  atomic{
    gTxRxBuffer = TxRxBuffer;
    gTxRxNumBytes = NumBytes;
    gFullDuplex = TRUE;
    gHalfDuplex_Tx = FALSE;
    gDMARxDone = FALSE;
    gDMATxDone = FALSE;
    gDMARxReady = FALSE;
    gDMATxReady = FALSE;
  }
    
  //flush the buffer back to memory
  cleanDCache(TxRxBuffer->TxBuffer, NumBytes);

  configureRxDMA(TxRxBuffer->RxBuffer, NumBytes, TRUE);
  configureTxDMA(TxRxBuffer->TxBuffer, NumBytes);

  //request 2 non-permanent channels
  call RxDMAChannel.requestChannel(DMAID_MYSSP_RX,DEFAULTDMARXPRIORITY, FALSE); 
  call TxDMAChannel.requestChannel(DMAID_MYSSP_TX,DEFAULTDMATXPRIORITY, FALSE); 
    
  return SUCCESS;
}

result_t tryFullDuplex(){
  bool local_TxReady, local_RxReady;
  atomic{
    local_TxReady = gDMATxReady;
    local_RxReady = gDMARxReady;
  }
    
  if(local_TxReady == TRUE && local_RxReady == TRUE){
    uint32_t SSCR0;
    call TxDMAChannel.run(TRUE);  
    call RxDMAChannel.run(TRUE);
    SSCR0 = _SSCR0 | SSCR0_SSE;
    _SSCR0 = SSCR0;
    return SUCCESS;
  }
  return FAIL;
}
  
async event void SSPInterrupt.fired(){
  uint32_t SSSR;
  uint32_t SSCR1;
  uint32_t SSCR0;
  //get the status register
  SSSR = _SSSR;
  SSCR1 = _SSCR1;
  SSCR0 = _SSCR0;

  if((SSSR & SSSR_BCE) && (SSCR1 & SSCR1_EBCEI) ){
    //bit count interrupt
    _SSSR = SSSR_BCE;
  }
    
  if((SSSR & SSSR_TUR) && ( (SSCR0 & SSCR0_TIM) == 0)){
    //transmit underrun
    _SSSR = SSSR_TUR;
  }
    
  if(SSSR & SSSR_EOC){
    //end of DMA Chain interrupt
    _SSSR = SSSR_EOC;
  }

  if((SSSR & SSSR_TINT) && (SSCR1 & SSCR1_TINTE)){
    //Rx timeout interrupt
    _SSSR = SSSR_TINT;
  }

  if((SSSR & SSSR_PINT) && (SSCR1 & SSCR1_PINTE)){
    //peripheral trailing byte interrupt
    _SSSR = SSSR_PINT;
  }

  if((SSSR & SSSR_ROR) && ( (SSCR0 & SSCR0_RIM) == 0)){
    //Rx FIFO overrrun
    //while(1);
    gNumRxFifoOverruns++;
    //gRxBufferPos=0;
    _SSSR = SSSR_ROR;
  }
    
  if((SSSR & SSSR_RFS) && (SSCR1 & SSCR1_RIE)){
    //atomic
    //uint16_t data;
    {
      while(SSSR_1 & SSSR_RNE){
	//while fifo not empty
	//data = SSDR_1;
	//*gRxBuffer++ =(uint16_t)~data;
	if(gRxBuffer){
	  *gRxBuffer++ = SSDR_1;
	  gRxBufferPos++;
	}
	//gRxBuffer[gRxBufferPos++] = _SSDR
	if(gRxBufferPos == gRxNumBytes){
	  //got all the data that we want....turn things off for now
	  //call SingleTxRx.stopReceive();
	  //post signalBulkTxRxReceiveDone();
	}
      }
    }      //have data to read...let's read it out!!
  }
    
  if((SSSR & SSSR_TFS) && (SSCR1 & SSCR1_TIE)){
    //post signalSingleTxRxTransmitDone();
    gNumTxRequests++;//stupid thing wants data to send out...i.e the last set of sends are done!
  }
}
 
/**
 *SSP Port configuration commands
 **/

command result_t SSP.setSSPFormat(SSPFrameFormat_t format){
  gFrameFormat = format;
  return SUCCESS;
}

command result_t SSP.setDataWidth(SSPDataWidth_t width){
  gDataWidth = width;
  return SUCCESS;
}
  
command result_t SSP.enableInvertedSFRM(bool enable){
  gEnableInvertedSFRM= enable;
  return SUCCESS;
}

command result_t SSP.enableSPIClkHigh(bool enable){
  gEnableSPIClkHigh = enable;
  return SUCCESS;
}

command result_t SSP.shiftSPIClk(bool enable){
  gShiftSPIClk = enable;
  return SUCCESS;
}
  
command result_t SSP.setRxFifoLevel(SSPFifoLevel_t level){
  gRxFifoLevel = level;
  return SUCCESS;
}

command result_t SSP.setTxFifoLevel(SSPFifoLevel_t level){
  gTxFifoLevel = level;
  return SUCCESS;
}
  
command result_t SSP.setMicrowireTxSize(SSPMicrowireTxSize_t size){
  gMicrowireSize = size;
  return SUCCESS;
}
//clk specific configuration routines
  
command result_t SSP.setClkRate(uint16_t clkdivider){
  gClkdivider = clkdivider;
  return SUCCESS;
}
  
command result_t SSP.setClkMode(SSPClkMode_t mode){
  gClkMode = mode;
  return SUCCESS;
}
    
command result_t SSP.enableManualRxPinCtrl(bool enable){
  gManualRxPinCtrl = enable;
  return SUCCESS;
}
command result_t SSP.enableManualTxPinCtrl(bool enable){
  gManualTxPinCtrl = enable;
  return SUCCESS;
}
command result_t SSP.enableManualSFRMPinCtrl(bool enable){
  gManualSFRMPinCtrl = enable;
  return SUCCESS;
}
command result_t SSP.enableManualSCLKPinCtrl(bool enable){
  gManualSCLKPinCtrl = enable;
  return SUCCESS;
}


command result_t SSP.setMasterSCLK(bool enable){
  gMasterSCLK = enable;
  return SUCCESS;
}

command result_t SSP.setMasterSFRM(bool enable){
  gMasterSFRM = enable;
  return SUCCESS;
}

command result_t SSP.setReceiveWithoutTransmit(bool enable){
  atomic{
    gReceiveWithoutTransmit = enable;
  }  
  return SUCCESS;
}
  
uint32_t createSSCR0(){

  uint32_t temp;
  //MOD:
  temp = (gClkMode == SSP_normalmode)? 0 : SSCR0_MOD;
    
  //ACS
  temp |= (gAudioClockSelect == TRUE)? SSCR0_ACS : 0;
    
  //FRDC
  // temp |= FRDC(gFRDC);
    
  //TIM (leave at the default for now)
   temp |= (gTxFifoUnderrun == TRUE)? 0 : SSCR0_TIM;
    
  //RIM (leave at the default for now)
  temp |= (gRxFifoOverrun == TRUE)? 0 : SSCR0_RIM;
    
  //NCS
  // temp |= (gNCS == TRUE)? 0 : SSCR0_NCS;
    
  //EDSS
  temp |= (gDataWidth <= SSP_16bits)? 0 : SSCR0_EDSS;
    
  //SCR
  temp |= SSCR0_SCR(gClkdivider);
  
  //SSE--> don't set it here in order to allow us to be a little more flexible
  //temp |= SSCR0_SSE;
    
  //ECS--> always 0 for iMote2
    
  //FRF
  temp |= SSCR0_FRF(gFrameFormat);
    
  //DSS
  temp |= SSCR0_DSS(gDataWidth); 
    
  return temp;
}

uint32_t createSSCR1(){

  uint32_t temp;

  //TTELP:
  //temp = (gClkMode == SSP_normalmode)? 0 : SSCR0_MOD;
  temp = 0;

  //TTE
  // temp |= (gTTE == SSP_ACS)? 0 : SSCR1_TTE;
    
  //EBCEI
  // temp |= (gEBCEI == SSP_ACS)? 0 : SSCR1_EBCEI;
    
  //SCFR 
  temp |= (gSlaveClockFreeRunning == TRUE) ? 0: SSCR1_SCFR;
    
  //ECRA
  // temp |= (gECRA == TRUE)? 0 : SSCR1_ECRA;
  //ECRB
  // temp |= (gECRB == TRUE)? 0 : SSCR1_ECRB;

  //SCLKDIR
  temp |= (gMasterSCLK == TRUE)? 0: SSCR1_SCLKDIR;

  //SFRMDIR
  temp |= (gMasterSFRM == TRUE)? 0: SSCR1_SFRMDIR;
    
  //RWOT
  atomic{
    temp |= (gReceiveWithoutTransmit == TRUE)? SSCR1_RWOT : 0;
  }
  //TRAIL
  // temp |= (gTRAIL == TRUE)? 0 : SSCR1_TRAIL;
    
  //TSRE
  //RSRE
  //TINTE
  //PINTE
  // temp |= (gNCS == TRUE)? 0 : SSCR0_NCS;
    
  //IFS
  temp |= (gEnableInvertedSFRM == TRUE)? SSCR1_IFS : 0;
    
  //STRF
  //EFWR
    
  //RFT
  temp |= SSCR1_RFT(gRxFifoLevel);
    
  //TFT
  temp |= SSCR1_TFT(gTxFifoLevel);
    
  //MWDS
  temp |= (gMicrowireSize == SSP_8bitCommands)? 0 : SSCR1_MWDS;

  //SPH
  temp |= (gShiftSPIClk == TRUE) ? SSCR1_SPH : 0;

  temp |= (gEnableSPIClkHigh == TRUE) ? SSCR1_SPO : 0;
  //LBM
  //TIE
  //RIE
     
  return temp;
}


