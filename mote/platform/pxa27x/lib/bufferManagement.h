#ifndef __BUFFER_H__
#define __BUFFER_H__

#include "inttypes.h"

/**********************
The concept of buffer exposed here consists of several main ideas

1.) a structure that contains a pointer to a buffer and an inuse flag called a buffer_t
    an array of buffer_t's is initialized by calling initBufferArray and passing in a pointer to your array of buffers
    and the number of buffers
2.) a structure that contains a pointer to a buffer, the number of bytes that it points to, and it's origin called a
    bufferInfo_t.  This structure is intended for dispatching a buffer once it has been returned from a source that
    needs to record the number of bytes in a buffer and where it came from.  Usage example for the origin 
    field is the case where multiple send functions actually call the same lower level send function, but some state
    keeping info needs to be kept about where the buffer originally came from
3.) a structure that contains a bufferInfo and an inuse flag called a bufferInfoInfo_t.  This structure is intended
    to allow for the allocation of a bufferInfo structure from a pool of bufferInfo structures in the case where a
    memory allocator can not be used to allocate a new bufferInfo_t structure, such as in an ISR.

usage:

BufferInfoInfo's
1.) instantiate an array of bufferInfoInfo_t's of some length.  
2.) Initialize the bufferInfoInfo's by calling initBufferInfo(bufferInfoInfo_t *pBII, uint32_t numBIIs);

Bufferss
1.) instantiate an array of uint8_t buffers[] (i.e. a uint8_t buffer[my length][numbuffers].
2.) instantiate an array of buffer_t's of the same length as numbuffers
3.) Initialize the buffer's by calling initBuffer(buffer_t *pB, uint8_t **buffers, uint32_t numBuffers); 

************************/

//this enumeration type is intended to be extended as new sources get created. This will facilitate tracking of buffers
//in memory

typedef enum {
  originSendData = 0,
  originSendDataAlloc,
} sendOrigin_t;

typedef struct bufferInfo_t{
  uint8_t *pBuf;
  uint32_t numBytes;
  sendOrigin_t origin;
} bufferInfo_t;

typedef struct timestampedBufferInfo_t{
  uint8_t *pBuf;
  uint64_t timestamp;
  uint32_t numBytes;
  sendOrigin_t origin;
} timestampedBufferInfo_t;

typedef struct bufferInfoInfo_t{
  bufferInfo_t BI;
  char inuse;
} bufferInfoInfo_t;

typedef struct timestampedBufferInfoInfo_t{
  timestampedBufferInfo_t BI;
  char inuse;
} timestampedBufferInfoInfo_t;

typedef struct buffer_t{
  uint8_t *buf;
  char inuse;
} buffer_t;
 

/**
 *A buffer set is a structure that contains a pointer to an array of buffer_ts and a unsigned integer
 *that contains the number of buffer_ts that the array points to
 *
 *
 **/
typedef struct bufferSet_t{
  uint32_t numBuffers;
  uint32_t bufferSize;
  buffer_t *pB;
} bufferSet_t;

typedef struct bufferInfoSet_t{
  uint32_t numBuffers;
  bufferInfoInfo_t *pBII;
} bufferInfoSet_t;

typedef struct timestampedBufferInfoSet_t{
  uint32_t numBuffers;
  timestampedBufferInfoInfo_t *pBII;
} timestampedBufferInfoSet_t;

int initBufferSet(bufferSet_t *pBS, buffer_t *pB, uint8_t **buffers, uint32_t numBuffers, uint32_t bufferSize);

uint32_t getBufferLevel(bufferSet_t *pBS);

uint8_t *getNextBuffer(bufferSet_t* pBS);

/**
 * return a buffer to a buffer_t array
 *
 * @ return 1 if successful, 0 if not successful (if this buffer was not part of this buffer_t array
 * 
 **/
 int returnBuffer(bufferSet_t *pBS, uint8_t *buf);


int initBufferInfoSet(bufferInfoSet_t *pBIS, 
		      bufferInfoInfo_t *pBII, 
		      uint32_t numBIIs);

bufferInfo_t *getNextBufferInfo(bufferInfoSet_t *pBII);

/**
 * return a bufferInfo_t to a bufferInfoInfo_t array
 *
 * @ return 1 if successful, 0 if not successful (if this bufferInfo_t  was not part of this bufferInfoInfo_t array
 * 
 **/
int returnBufferInfo(bufferInfoSet_t *pBII, bufferInfo_t *pBI);



int initTimestampedBufferInfoSet(timestampedBufferInfoSet_t *pBIS, 
				 timestampedBufferInfoInfo_t *pBII, 
				 uint32_t numBIIs);

uint32_t getTimestampedBufferInfoLevel(timestampedBufferInfoSet_t *pBS);

timestampedBufferInfo_t *getNextTimestampedBufferInfo(timestampedBufferInfoSet_t *pBII);

/**
 * return a bufferInfo_t to a bufferInfoInfo_t array
 *
 * @ return 1 if successful, 0 if not successful (if this bufferInfo_t  was not part of this bufferInfoInfo_t array
 * 
 **/
int returnTimestampedBufferInfo(timestampedBufferInfoSet_t *pBII, timestampedBufferInfo_t *pBI);


#endif // __BUFFER_H__
