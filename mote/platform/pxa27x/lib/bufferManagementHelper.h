#ifndef __BUFFERMANAGEMENTHELPER_H__
#define __BUFFERMANAGEMENTHELPER_H__


#define DMA_BUFFER_SIZE(_x) ((((_x)+31)>>5)<<5)
#define DMA_ABLE_BUFFER(_x)  (  (((uint32_t)(_x)) > 0x5c00000) &&  (((uint32_t)(_x)) < 0x5c040000) &&  ((((uint32_t)(_x))& 0x1f)== 0) )

#define DECLARE_BUFFER(_name, _number,_size) \
bufferInfoSet_t _name##BufferInfoSet; \
bufferInfoInfo_t _name##BufferInfoInfo[_number]; \
bufferSet_t _name##BufferSet; \
buffer_t _name##BufferStructs[_number]; \
uint8_t _name##Buffers[_number][_size];

#define DECLARE_DMABUFFER(_name, _number,_size) \
bufferInfoSet_t _name##BufferInfoSet; \
bufferInfoInfo_t _name##BufferInfoInfo[_number]; \
bufferSet_t _name##BufferSet; \
buffer_t _name##BufferStructs[_number]; \
uint8_t _name##Buffers[_number][DMA_BUFFER_SIZE(_size)] __attribute__((aligned(32)));

#define DECLARE_TIMESTAMPEDDMABUFFER(_name, _number,_size) \
timestampedBufferInfoSet_t _name##TimestampedBufferInfoSet; \
timestampedBufferInfoInfo_t _name##TimestampedBufferInfoInfo[_number]; \
bufferSet_t _name##BufferSet; \
buffer_t _name##BufferStructs[_number]; \
uint8_t _name##Buffers[_number][DMA_BUFFER_SIZE(_size)] __attribute__((aligned(32)));


#define INIT_BUFFER(_name, _number,_size) \
do{ \
initBufferInfoSet(& _name##BufferInfoSet, _name##BufferInfoInfo, _number); \
initBufferSet(& _name##BufferSet, \
	      _name##BufferStructs, \
	      (uint8_t **) _name##Buffers, \
	      _number, \
	      _size);} \
while(0)

#define INIT_DMABUFFER(_name, _number,_size) \
do { \
initBufferInfoSet(& _name##BufferInfoSet, _name##BufferInfoInfo, _number); \
initBufferSet(& _name ## BufferSet, \
	      _name ## BufferStructs, \
	      (uint8_t **) _name ## Buffers, \
	      _number, \
	      DMA_BUFFER_SIZE(_size));} \
while(0) 



#define INIT_TIMESTAMPEDDMABUFFER(_name, _number,_size) \
do { \
initTimestampedBufferInfoSet(& _name##TimestampedBufferInfoSet, _name##TimestampedBufferInfoInfo, _number); \
initBufferSet(& _name ## BufferSet, \
	      _name ## BufferStructs, \
	      (uint8_t **) _name ## Buffers, \
	      _number, \
	      DMA_BUFFER_SIZE(_size));} \
while(0) 


#endif // __BUFFERMANAGEMENTHELPER_H__

