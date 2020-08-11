#include "paramtask.h"
#include "bufferManagementHelper.h"
#include "assert.h"


typedef enum {
  originSendData = 0,
  originSendDataAlloc,
} sendOrigin_t;

DECLARE_DMABUFFER(receive,NUMBUFFERS,RXLINELEN);

//this implementation relies on having a queue of pointers that represent the current buffer
//to be sent out

bool gTxActive = FALSE;

void transmitDone(uint32_t arg);
DEFINE_PARAMTASK(transmitDone); 

void receiveDone(uint32_t arg);
DEFINE_PARAMTASK(receiveDone); 

  
/*
 * Start of StdControl interface
 */

command result_t StdControl.init() {
  initptrqueue(&outgoingQueue, defaultQueueSize);

  INIT_DMABUFFER(receive, NUMBUFFERS,RXLINELEN);
  
  gTxActive = FALSE;
    
  return SUCCESS;
}

command result_t StdControl.start() {
  
  uint8_t *rxBuffer = getNextBuffer(&receiveBufferSet);
  
  call BulkTxRx.BulkReceive(rxBuffer, RXLINELEN);
  return SUCCESS;
}

command result_t StdControl.stop() {
  return SUCCESS;
}

/*
 * End of StdControl interface
 */

/*
 * Start of SendDataAlloc interface
 */

/**
   * Function to allocate a buffer that is compatible with this interface.
   *
   * @return a non-NULL pointer to a buffer that is compatible with this interface if there is memory available to allocate.  Is no memory is available, NULL will be returned

   */
command uint8_t *SendDataAlloc.alloc(size_t numBytes){
  uint8_t *ptr;
  atomic{
    ptr = memalign(32, DMA_BUFFER_SIZE(numBytes));
  }
  return ptr; 
}

command void SendDataAlloc.free(uint8_t *ptr){
  assert(DMA_ABLE_BUFFER(ptr));
  free(ptr);
}

command result_t SendDataAlloc.send(uint8_t* data, uint32_t numBytes){
  int ret;
  bufferInfo_t *pBI;
  
  if(!numBytes){
    return FAIL;
  }

  assert(DMA_ABLE_BUFFER(data));
  
  atomic{
    pBI = malloc(sizeof(*pBI));
  }
  
  assert(pBI);
    
  pBI->pBuf = data;
  pBI->numBytes = numBytes;
  pBI->origin = originSendDataAlloc;

  //UART.c will no longer clean the buffer for it....it's our responsibility to make sure that main memory and
  //cache are coherent.
  cleanDCache(data, numBytes);
  
  atomic{
    ret = pushptrqueue(&outgoingQueue, pBI);// see if there's enough room for this buffer
    if(gTxActive == FALSE){
      call BulkTxRx.BulkTransmit(pBI->pBuf, pBI->numBytes);
      gTxActive = TRUE;
    }
  }

  assert(ret);
#if 0  
  if(!ret){
    //no room in the queue!
    free(pBI);
    return FAIL;
  }
#endif

  return SUCCESS;
}

default event result_t SendDataAlloc.sendDone(uint8_t* data, uint32_t numBytes, result_t success){

  return success;
}

/*
 *End of SendDataAlloc interface
 */

/*
 * Start of SendData interface
 */

command result_t SendData.send(uint8_t* data, uint32_t length) {
  int ret;
  bufferInfo_t *pBI;
    
  if(!length){
    return FAIL;
  }

  
  atomic{
    pBI = malloc(sizeof(*pBI));
  }

  assert(pBI);
    
  atomic{
    pBI->pBuf = memalign(32, DMA_BUFFER_SIZE(length));
  }
  
  assert(pBI->pBuf);
  if(pBI->pBuf){
    memcpy(pBI->pBuf,data,length);
  }
    
  pBI->numBytes = length;
  pBI->origin = originSendData;

  //UART.c will no longer clean the buffer for it....it's our responsibility to make sure that main memory and
  //cache are coherent.
  cleanDCache(pBI->pBuf, length);


  atomic{
    ret = pushptrqueue(&outgoingQueue, pBI);// see if there's enough room for this buffer
    if(gTxActive == FALSE){
      call BulkTxRx.BulkTransmit(pBI->pBuf, length);
      gTxActive = TRUE;
    }
  }

  if(!ret){
    //no room in the queue!
    //printFatalErrorMsg("BufferedUart.c send() unable to add buffer to outgoing queue. Available Queue size =",getCurrentPtrQueueSize(&outgoingQueue));

    free(pBI->pBuf);

    free(pBI);
    return FAIL;
  }

  return SUCCESS;
}

default event result_t SendData.sendDone(uint8_t* data, uint32_t numBytes, result_t suc) {
  return suc;
}

void transmitDone(uint32_t arg){
  int status;
  bufferInfo_t *pBI = (bufferInfo_t *)arg;
  
  switch(pBI->origin){
  case originSendDataAlloc:
    signal SendDataAlloc.sendDone(pBI->pBuf, pBI->numBytes, SUCCESS);
    break;
  case originSendData:
    signal SendData.sendDone(pBI->pBuf, pBI->numBytes, SUCCESS);

    free(pBI->pBuf);

    break;
  default:
    printFatalErrorMsg("BufferedUart.c found unknown interface origin = ",pBI->origin);
  }

  free(pBI);
  atomic{
    pBI = peekptrqueue(&outgoingQueue, &status);
    if(status == 1){
      //we still have buffers in the queue
      call BulkTxRx.BulkTransmit(pBI->pBuf, pBI->numBytes);
    }
    else{
      gTxActive = FALSE;
    }
  }
}


void receiveDone(uint32_t arg){
  bufferInfo_t *pBI = (bufferInfo_t *)arg;
  if(pBI == NULL){
    return;
  }

#if 0  
  if(pBI->numBytes != RXLINELEN){
    trace(DBG_USR1,"BufferedFFUARTM received different amount of data than requested (%d)\r\n", pBI->numBytes);
  }
#endif  

  invalidateDCache(pBI->pBuf, pBI->numBytes);
  signal ReceiveData.receive(pBI->pBuf, pBI->numBytes);
  returnBuffer(&receiveBufferSet,pBI->pBuf);
  returnBufferInfo(&receiveBufferInfoSet,pBI);
}
  
/*
 * Start of ReceiveData interface
 */
  
default event result_t ReceiveData.receive(uint8_t* Data, uint32_t Length) {
  return SUCCESS;
}
  
/*
 * End of ReceiveData interface
 */
  
  

/*
 * End of SendData interface
 */

async event uint8_t *BulkTxRx.BulkReceiveDone(uint8_t *RxBuffer, 
					      uint16_t NumBytes){
  
  bufferInfo_t *pBI;
  uint8_t *newBuffer;
  
  pBI = getNextBufferInfo(&receiveBufferInfoSet);
  assert(pBI);

  pBI->pBuf = RxBuffer;
  pBI->numBytes = NumBytes;
  
  POST_PARAMTASK(receiveDone,pBI);
  
  newBuffer = getNextBuffer(&receiveBufferSet);
  
  assert(newBuffer);

  return newBuffer;
}
  
async event BulkTxRxBuffer_t *BulkTxRx.BulkTxRxDone(BulkTxRxBuffer_t *TxRxBuffer, uint16_t NumBytes){
  return NULL;
}
  
async event uint8_t *BulkTxRx.BulkTransmitDone(uint8_t *TxBuffer, uint16_t NumBytes){
    
  bufferInfo_t *pBI;
  int status;
  pBI = popptrqueue(&outgoingQueue, &status);
  if(status == 1){
    //got a buffer out of the queue...make sure that it's the same as what we just got back
    if((pBI->pBuf == TxBuffer) && (pBI->numBytes == NumBytes)){
      //got the right buffer back!!
      POST_PARAMTASK(transmitDone,pBI);
    }
    else{
      printFatalErrorMsg("BufferedUART.c found unexpected buffer in queue",0);
    }
  }
  else{
    printFatalErrorMsg("BufferedUART.c found tranmit queue empty after sending data",0);
  }
  return NULL;
}


  





  
