/**
 * @author Robbie Adler
 **/

/***
 *
 * standard implentation for all iMote2 UART modules.  This file is in
 * intended to be #included into the respectived XUARTM.nc module
 *
 **/

#ifndef LOWPOWER_UART
#define LOWPOWER_UART 0
#endif

#ifdef ST_UART
#define MYFIFOADDR 0x40700000
#define MYCKEN  (CKEN_CKEN5)
#define DMAID_MYUART_TX DMAID_STUART_TX
#define DMAID_MYUART_RX DMAID_STUART_RX

#endif

#ifdef BT_UART
#define MYFIFOADDR 0x40200000
#define MYCKEN  (CKEN_CKEN7)
#define DMAID_MYUART_TX DMAID_BTUART_TX
#define DMAID_MYUART_RX DMAID_BTUART_RX
#endif

#ifdef FF_UART
#define MYFIFOADDR 0x40100000
#define MYCKEN  (CKEN_CKEN6)
#define DMAID_MYUART_TX DMAID_FFUART_TX
#define DMAID_MYUART_RX DMAID_FFUART_RX

#endif

  
//declare component state and initialize it to something reasonable just in case the user does something stupid
norace bool gTxPortInUse = FALSE;
norace bool gRxPortInUse = FALSE;
bool gPortInitialized = FALSE;
  
norace uint16_t gNumRxFifoOverruns;
  
norace uint8_t *gRxBuffer;
norace uint16_t gRxNumBytes, gRxBufferPos;
  
norace uint8_t *gTxBuffer;
norace uint16_t gTxNumBytes, gTxBufferPos;

norace bool bInSingleByteRxMode = FALSE;

void initPort(){
  //configure the GPIO Alt functions and directions
#ifdef ST_UART
  GPIO_SET_ALT_FUNC(46,2,GPIO_IN);
  GPIO_SET_ALT_FUNC(47,1,GPIO_OUT);
#endif
#ifdef BT_UART
  
#endif
  
#ifdef FF_UART
  GPIO_SET_ALT_FUNC(96,3, GPIO_IN);
  GPIO_SET_ALT_FUNC(99,3, GPIO_OUT); //FFTXD
#endif

  call UARTInterrupt.allocate();
#ifdef NO_DMA
  call UARTInterrupt.enable();
#endif
}

void configPort(){
 
  //turn on the port's clock
  CKEN |= (MYCKEN);
#ifdef NO_DMA
  _IER |= IER_RAVIE;
  _IER |= IER_TIE;
  _IER |= IER_RLSE;

#else
  _IER = IER_DMAE; 
#endif 

  _IER |= IER_UUE; //enable the UART
  
  
  _LCR |=LCR_DLAB; //turn on DLAB so we can change the divisor
  _DLL = 8;  //configure to 115200;
  _DLH = 0;
  _LCR &= ~(LCR_DLAB);  //turn off DLAB
    
  _LCR |= 0x3; //configure to 8 bits

  //STMCR |= MCR_AFE; //Auto flow control enabled;
  //STMCR |= MCR_RTS;
#ifdef NO_DMA
  _FCR = FCR_ITL(0) | FCR_TIL | FCR_RESETTF | FCR_TRFIFOE;
#else
  _FCR = FCR_ITL(2) | FCR_BUS | FCR_TRAIL | FCR_TIL | FCR_RESETTF | FCR_TRFIFOE;
#endif

  _MCR &= ~MCR_LOOP;
  _MCR |= MCR_OUT2;

}



result_t openTxPort(bool bTxDMAIntEnable){
    
  result_t status=SUCCESS;
  
  atomic{
    if(gTxPortInUse==TRUE){
      status = FAIL;
    }
    else{
      gTxPortInUse = TRUE;
    }
  }
  if(status==FAIL){
    return FAIL;
  }
  
  if(gPortInitialized==FALSE){
    initPort();
    gPortInitialized = TRUE;
  }      
   
  atomic{
    if(gRxPortInUse == FALSE){
      //other side does not have the port open
      configPort();
    }
  }
          
  return SUCCESS;
}


result_t openRxPort(bool bRxDMAIntEnable){
    
  result_t status=SUCCESS;
  
  atomic{
    if(gRxPortInUse==TRUE){
      status = FAIL;
    }
    else{
      gRxPortInUse = TRUE;
    }
  }
  if(status==FAIL){
    return FAIL;
  }

  if(gPortInitialized==FALSE){
    initPort();
    gPortInitialized = TRUE;
  }      
  
  atomic{
    if(gTxPortInUse == FALSE){
      //other side does not have the port open
      configPort();
    }
  }
  
  return SUCCESS;
}
  
result_t closeTxPort(){
    
  //this function will only be called from interrupt context
  //ARM guarantees that our interrupt will be disabled
  gTxPortInUse = FALSE;
  gTxBuffer = NULL;
  gTxNumBytes = 0;

#if LOWPOWER_UART 
  //wait until we've shifted out all of our data
  while(!(_LSR & LSR_TEMT)); 
  
  if(gRxPortInUse == FALSE){
    //turn off the port's clock
    _IER &= ~IER_UUE; //enable the UART
    CKEN &= ~(MYCKEN);
  }
#endif

  return SUCCESS;
}

result_t closeRxPort(){
    
  //this function will only be called from interrupt context
  //ARM guarantees that our interrupt will be disabled
  gRxPortInUse = FALSE;
  gRxBuffer = NULL;
  gRxNumBytes = 0;
  
#if LOWPOWER_UART
  if(gTxPortInUse == FALSE){
    //turn off the port's clock
    _IER &= ~IER_UUE; //enable the UART
    CKEN &= ~(MYCKEN);
  }
#endif
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
  call RxDMAChannel.setMaxBurstSize(DMA_8ByteBurst);
  call RxDMAChannel.setTransferWidth(DMA_4ByteWidth);
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
    
  if(!RxBuffer || !NumBytes){
    return FAIL;
  }
  
#ifndef NO_DMA
  call UARTInterrupt.disable();
#endif  
    
  if(openRxPort(TRUE)==FAIL){
    return FAIL;
  }
  atomic{
    gRxBuffer = RxBuffer;
    gRxNumBytes = NumBytes;
    gNumRxFifoOverruns=0;
    gRxBufferPos = 0;
  }
  
#ifndef NO_DMA
  configureRxDMA(RxBuffer, NumBytes, TRUE);
    //request a non-permanent channel
  call RxDMAChannel.requestChannel(DMAID_MYUART_RX,DEFAULTDMARXPRIORITY, FALSE); 
#endif
  
  return SUCCESS;
}

event result_t RxDMAChannel.requestChannelDone(){
  //so we've successfully been cleared to start doing something with our port...go!!
  call RxDMAChannel.run(DMA_ENDINTEN | DMA_EORINTEN);  
  
  return SUCCESS;
}

void handleRxDMADone(uint16_t numBytesSent){
  //it is the user's responsibility to invalidate the dcache
  gRxBuffer = signal BulkTxRx.BulkReceiveDone(gRxBuffer, 
					      numBytesSent);
  if(gRxBuffer){
    //we want to do another read of gRxNumBytes)
    //we should still have our DMA channel, so just all set size and run!
    call RxDMAChannel.setTargetAddr((uint32_t)gRxBuffer);
    call RxDMAChannel.setTransferLength(gRxNumBytes);
    call RxDMAChannel.run(DMA_ENDINTEN | DMA_EORINTEN);  
  }
  else{
    if(gNumRxFifoOverruns>0){
      //FIXME
      //trace(DBG_USR1,"Num ROR's = %d\r\n",gNumRxFifoOverruns);
    }
    closeRxPort();
  }    
}

async event void RxDMAChannel.startInterrupt(){
}

async event void RxDMAChannel.stopInterrupt(uint16_t numbBytesSent){
}

task void goteor(){
  trace(DBG_USR1,"gotEOR");
}

task void gotend(){
  trace(DBG_USR1,"gotEND");
}

async event void RxDMAChannel.eorInterrupt(uint16_t numBytesSent){
  //post goteor();
  handleRxDMADone(numBytesSent);
}

async event void RxDMAChannel.endInterrupt(uint16_t numBytesSent){
  //post gotend();
  handleRxDMADone(numBytesSent);
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
  call TxDMAChannel.setMaxBurstSize(DMA_8ByteBurst);
  call TxDMAChannel.setTransferWidth(DMA_4ByteWidth);
   
}
  
command result_t BulkTxRx.BulkTransmit(uint8_t *TxBuffer, uint16_t NumBytes){
      
  if(!TxBuffer || !NumBytes){
    return FAIL;
  }
  
  if(openTxPort(TRUE)==FAIL){
    //port was already open
    return FAIL;
  }
    
  //port has now been opened
  atomic{
    gTxBuffer = TxBuffer;
    gTxNumBytes = NumBytes;
    gTxBufferPos = 0;
  }
    
#ifdef NO_DMA
  _THR = gTxBuffer[0];
  gTxBufferPos = 1;
#else
  
  //it is the user's responsibility to have properly cleaned the dcache first
  configureTxDMA(TxBuffer,NumBytes);
    
  //request a non-permanent channel
  call TxDMAChannel.requestChannel(DMAID_MYUART_TX,DEFAULTDMATXPRIORITY, FALSE); 
  
#endif
  return SUCCESS;
}
  
event result_t TxDMAChannel.requestChannelDone(){
  //so we've successfully been cleared to start doing something with our port...go!!
  call TxDMAChannel.run(TRUE);  
  
  return SUCCESS;
}
  
async event void TxDMAChannel.startInterrupt(){

  return;
}

async event void TxDMAChannel.stopInterrupt(uint16_t numBytesLeft){
  
  return;
}

async event void TxDMAChannel.eorInterrupt(uint16_t numBytesLeft){
  
  return;
}

async event void TxDMAChannel.endInterrupt(uint16_t numBytesSent){

  gTxBuffer = signal BulkTxRx.BulkTransmitDone(gTxBuffer, 
					       gTxNumBytes);
  if(gTxBuffer){
    //we want to do another write of gTxNumBytes)
    //we should still have our DMA channel, so just all set size and run!
    //we assume that the user properly cleaned the dcache first
    call TxDMAChannel.setSourceAddr((uint32_t)gTxBuffer);
    call TxDMAChannel.setTransferLength(gTxNumBytes);
    call TxDMAChannel.run(TRUE);  
  }
  else{
    closeTxPort();
  }    
  return;
}

command result_t BulkTxRx.BulkTxRx(BulkTxRxBuffer_t *TxRxBuffer, uint16_t NumBytes){
    
  //this mode is not supported by a UART
  return FAIL;
}

task void printUARTError(){
  trace(DBG_USR1,"UART ERROR\r\n");
}

async event void UARTInterrupt.fired(){
  uint8_t error,intSource = _IIR;
  intSource = (intSource >> 1) & 0x3;
  switch(intSource){
  case 0:
    //MODEM STATUS
    break;
  case 1:
    //TRANSMIT FIFO Wants data
    //    signal UART.putDone();
    if(gTxBuffer){
      if(gTxBufferPos < gTxNumBytes){
	//still have more to send
	_THR = gTxBuffer[gTxBufferPos];
	gTxBufferPos++;
      }
      else{
	//we're done...signal
	gTxBuffer = signal BulkTxRx.BulkTransmitDone(gTxBuffer, 
					       gTxNumBytes);
	if(gTxBuffer){
	  _THR = gTxBuffer[0];
	  gTxBufferPos = 1;
	}
	else{
	  gTxBufferPos = 0;
	  closeTxPort();
	}     
      }
    }
    break;
  case 2:
    //Received Data Available
    if(gRxBuffer){
      while(_LSR & LSR_DR){
	gRxBuffer[gRxBufferPos] = _RBR;
	gRxBufferPos++;
	if(gRxBufferPos == gRxNumBytes){
	  gRxBuffer= signal BulkTxRx.BulkReceiveDone(gRxBuffer, 
						     gRxNumBytes);
	  gRxBufferPos = 0;
	  if(gRxBuffer == NULL){
	    closeRxPort();
	  }
	}
      }
      //signal UART.get(STRBR);
    }
    break;
  case 3:
    //Receive Error
    error = _LSR;
    post printUARTError();
    break;
  }
  return;
}
  



