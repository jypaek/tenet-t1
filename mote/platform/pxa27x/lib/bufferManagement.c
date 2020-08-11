#include "bufferManagement.h"
#include "assert.h"
#include "criticalSection.h"
#include "systemUtil.h"
#include <stdlib.h>

#define TRUE 1
#define FALSE 0

int initBufferSet(bufferSet_t *pBS, buffer_t *pB, uint8_t **buffers, uint32_t numBuffers, uint32_t bufferSize){
  int i;
  
  DECLARE_CRITICAL_SECTION();
  
  assert(pBS);
  assert(pB);
  assert(buffers);
  
  CRITICAL_SECTION_BEGIN();
  
  pBS->pB = pB;
  pBS->numBuffers = numBuffers;
  pBS->bufferSize = bufferSize;
  
  for(i=0;i<numBuffers; i++){
    buffer_t *currentBufferStruct;
    uint8_t *currentBuffer;

    currentBufferStruct = &(pBS->pB[i]);
    currentBuffer = ((uint8_t*)buffers) + i*bufferSize;
    currentBufferStruct->inuse = FALSE;
    currentBufferStruct->buf = currentBuffer;
  }
  CRITICAL_SECTION_END();
  
  return 1;
}

uint32_t getBufferLevel(bufferSet_t *pBS){
  int i;
  uint32_t ret =0;
  DECLARE_CRITICAL_SECTION();
  
  CRITICAL_SECTION_BEGIN();
  for(i=0;i< (pBS->numBuffers); i++){
    assert(pBS->pB);
    assert(pBS->pB[i].buf);
    if(pBS->pB[i].inuse == FALSE){
      ret++;
    }
  }
  CRITICAL_SECTION_END();
  return ret;
}

uint8_t *getNextBuffer(bufferSet_t* pBS){
  int i;
  
  assert(pBS);
  assert(pBS->pB);


  DECLARE_CRITICAL_SECTION();
  uint8_t *ret = NULL;
  
  CRITICAL_SECTION_BEGIN();  
  for(i=0;i < (pBS->numBuffers) ; i++){
    if(pBS->pB[i].inuse == FALSE){
      pBS->pB[i].inuse = TRUE;
      ret = pBS->pB[i].buf;
      //only assert if we're going to actually return this buffer
      assert(pBS->pB[i].buf);
      break;
    }
  }
  CRITICAL_SECTION_END();
  return ret;
}


int returnBuffer(bufferSet_t *pBS, uint8_t *buf){
  int i,ret=0; 
  DECLARE_CRITICAL_SECTION();
  
  assert(pBS);
  assert(pBS->pB);
  

  CRITICAL_SECTION_BEGIN();
  for(i=0;i < (pBS->numBuffers); i++){
    assert(pBS->pB[i].buf);
    if(pBS->pB[i].buf == buf){
      pBS->pB[i].inuse = FALSE;
      ret = 1;
    }
  }
  CRITICAL_SECTION_END();
  if(ret==0){
    printFatalErrorMsgHex("Attempted to return buffer to wrong bufferSet [buf bufferSet]=",2, buf, (uint32_t)pBS);
  }
  
  return ret;
}

int initBufferInfoSet(bufferInfoSet_t *pBIS, bufferInfoInfo_t *pBII, uint32_t numBIs){
  int i;
  DECLARE_CRITICAL_SECTION();
  
  assert(pBIS);
  assert(pBII);
  
  CRITICAL_SECTION_BEGIN();
  pBIS->numBuffers = numBIs;
  pBIS->pBII = pBII;
  for(i=0;i<numBIs; i++){
    pBIS->pBII[i].inuse = FALSE;
  }
  CRITICAL_SECTION_END();

  return 1;
}

bufferInfo_t *getNextBufferInfo(bufferInfoSet_t *pBIS){
  int i;
  DECLARE_CRITICAL_SECTION();
  bufferInfo_t *ret = NULL;
  
  assert(pBIS);
  assert(pBIS->pBII);
    
  CRITICAL_SECTION_BEGIN();
  for(i=0;i < (pBIS->numBuffers); i++){
    if(pBIS->pBII[i].inuse == FALSE){
      pBIS->pBII[i].inuse = TRUE;
      ret = &(pBIS->pBII[i].BI);
      break;
    }
  }
  CRITICAL_SECTION_END();
  return ret;
}


int returnBufferInfo(bufferInfoSet_t *pBIS, bufferInfo_t *pBI){
  int i, ret=0;
  DECLARE_CRITICAL_SECTION();
  assert(pBIS);
  assert(pBIS->pBII);
  assert(pBI);
  
  CRITICAL_SECTION_BEGIN();
  for(i=0;i < (pBIS->numBuffers); i++){
    if(&(pBIS->pBII[i].BI) == pBI){
      pBIS->pBII[i].inuse = FALSE;
      ret = 1;
      break;
    }
  }
  CRITICAL_SECTION_END();
  
  if(ret==0){
    printFatalErrorMsgHex("Attempted to return bufferInfo to wrong bufferInfoSet [bufferInfoSet bufferInfo] = ",2, pBIS, pBI);
  }
  
  return ret;
}

int initTimestampedBufferInfoSet(timestampedBufferInfoSet_t *pBIS, timestampedBufferInfoInfo_t *pBII, uint32_t numBIs){
  int i;
  DECLARE_CRITICAL_SECTION();
  
  assert(pBIS);
  assert(pBII);
  
  CRITICAL_SECTION_BEGIN();
  pBIS->numBuffers = numBIs;
  pBIS->pBII = pBII;
  for(i=0;i<numBIs; i++){
    pBIS->pBII[i].inuse = FALSE;
  }
  CRITICAL_SECTION_END();

  return 1;
}

uint32_t getTimestampedBufferInfoLevel(timestampedBufferInfoSet_t *pBIS){
  int i;
  uint32_t ret = 0;
  DECLARE_CRITICAL_SECTION();
  
  assert(pBIS);
  assert(pBIS->pBII);
  
  CRITICAL_SECTION_BEGIN();
  for(i=0;i<  (pBIS->numBuffers); i++){
    if(pBIS->pBII[i].inuse == FALSE){
      ret++;
    }
  }
  CRITICAL_SECTION_END();
  return ret;
}

timestampedBufferInfo_t *getNextTimestampedBufferInfo(timestampedBufferInfoSet_t *pBIS){
  int i;
  DECLARE_CRITICAL_SECTION();
  timestampedBufferInfo_t *ret = NULL;
  
  assert(pBIS);
  assert(pBIS->pBII);
    
  CRITICAL_SECTION_BEGIN();
  for(i=0;i < (pBIS->numBuffers); i++){
     if(pBIS->pBII[i].inuse == FALSE){
      pBIS->pBII[i].inuse = TRUE;
      ret = &(pBIS->pBII[i].BI);
      assert(ret);
      break;
     }
  }
  CRITICAL_SECTION_END();
  return ret;
}


int returnTimestampedBufferInfo(timestampedBufferInfoSet_t *pBIS, timestampedBufferInfo_t *pBI){
  int i, ret=0;
  DECLARE_CRITICAL_SECTION();
  assert(pBIS);
  assert(pBIS->pBII);
  assert(pBI);
  
  CRITICAL_SECTION_BEGIN();
  for(i=0;i < (pBIS->numBuffers); i++){
    if(&(pBIS->pBII[i].BI) == pBI){
      pBIS->pBII[i].inuse = FALSE;
      ret = 1;
      break;
    }
  }
  CRITICAL_SECTION_END();
  
  if(ret==0){
    printFatalErrorMsg("Attempted to return timestamedBufferInfo to wrong timestampdBufferInfoSet [bufferInfoSet bufferInfo] = ",2, pBIS, pBI);
  }
  
  return ret;
}


