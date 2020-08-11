/* 
 * Author:		Josh Herbach
 * Revision:	1.0
 * Date:		09/02/2005
 *
 * Updated by: Robbie Adler and Junaith Ahemed
 * Updated Date: Feb 13, 2007
 * Update Summary:
 * 	The unlock function cleared the satus register using address 0xD0 which was
 *	causing data cache issues, which lead to random data aborts when code optimization
 *	was enabled. The clear status is now written to the block that is unlocked
 *	which is not in the cached area of the flash.
 */
module FlashM {
  provides {
    interface StdControl;
    interface Flash; //does not allow writing into FLASH_PROTECTED_REGION
  }
}
implementation {
  
#include "Flash.h"
  
  //void trace(const char *format, ...) __attribute__ ((C, spontaneous));
  
  uint16_t unlock(uint32_t addr);
  uint16_t lock(uint32_t addr);
  uint16_t eraseFlash(uint32_t addr);
  uint16_t programWord(uint32_t addr, uint16_t data);
  uint16_t programBuffer(uint32_t addr, uint16_t data[], uint8_t datalen);
  uint16_t writeHelper(uint32_t addr, uint8_t* data, uint32_t numBytes,
		       uint8_t prebyte, uint8_t postbyte);
  void writeExitHelper(uint32_t addr, uint32_t numBytes);
  
  uint8_t FlashPartitionState[FLASH_PARTITION_COUNT];
  uint8_t init = 0, programBufferSupported = 2, currBlock = 0;
  extern uint8_t __Flash_Erase(uint32_t addr) __attribute__ ((C,spontaneous,noinline));
  extern uint8_t __GetEraseStatus(uint32_t addr) __attribute__ ((C,spontaneous,noinline));
  extern uint8_t __EraseFlashSpin(uint32_t addr) __attribute__ ((C,spontaneous,noinline));

  extern uint8_t __Flash_Program_Word(uint32_t addr, uint16_t word) __attribute__ ((C,spontaneous,noinline));
  extern uint8_t __Flash_Program_Buffer(uint32_t addr, uint16_t *data, uint8_t datalen) __attribute__ ((C,spontaneous,noinline));
  extern uint32_t __Flash_Erase_true_end __attribute__ ((C));
  extern uint32_t __Flash_Program_Word_true_end __attribute__ ((C));
  extern uint32_t __Flash_Program_Buffer_true_end __attribute__ ((C));
  
  command result_t StdControl.init() {
    int i = 0;
    if(init != 0)
      return SUCCESS;
    init = 1;
    for(i = 0; i < FLASH_PARTITION_COUNT; i++)
      FlashPartitionState[i] = FLASH_STATE_READ_INACTIVE;
    
    asm volatile(
		 ".equ FLASH_READARRAY,(0x00FF);         \
		 .equ FLASH_CFIQUERY,(0x0098);		 \
		 .equ FLASH_READSTATUS,(0x0070);	 \
		 .equ FLASH_CLEARSTATUS,(0x0050);	 \
		 .equ FLASH_PROGRAMWORD,(0x0040);	 \
		 .equ FLASH_PROGRAMBUFFER,(0x00E8);	 \
		 .equ FLASH_ERASEBLOCK,(0x0020);	 \
		 .equ FLASH_DLOCKBLOCK,(0x0060);	 \
		 .equ FLASH_PROGRAMBUFFERCONF,(0x00D0);	 \
		 .equ FLASH_LOCKCONF,(0x0001);		 \
		 .equ FLASH_UNLOCKCONF,(0x00D0);	 \
		 .equ FLASH_ERASECONF,(0x00D0);		 \
                 .equ FLASH_OP_NOT_SUPPORTED,(0x10);");
    //flash_op_not_supported needs to be LSL 1 to be the correct value of 0x100
    return SUCCESS;
  }
  
  command result_t StdControl.start() {    
    return SUCCESS;
  }
  
  command result_t StdControl.stop() {
    return SUCCESS;
  }
  
  uint16_t writeHelper(uint32_t addr, uint8_t* data, uint32_t numBytes,
		       uint8_t prebyte, uint8_t postbyte){
    uint32_t i = 0, j = 0, k = 0;
    uint16_t status;
    uint16_t buffer[FLASH_PROGRAM_BUFFER_SIZE];
    
    if(numBytes == 0)
      return FAIL;
    
    if(addr % 2 == 1){
      status = __Flash_Program_Word(addr - 1, prebyte | (data[i] << 8));
      //atomic status = __Flash_Program_Word(addr - 1, prebyte | (data[i] << 8));
      i++;
      if(status != 0x80)
      { 
        trace (DBG_USR1,"** FS ERROR **: Flash Write Failed with status == %d \r\n", status);    
	return FAIL;
      }
    }

    if(addr % 2 == numBytes % 2){
      if(programBufferSupported == 1)
	for(; i < numBytes; i = k){
	  for(j = 0, k = i; k < numBytes && 
		j < FLASH_PROGRAM_BUFFER_SIZE; j++, k+=2)
	    buffer[j] = data[k] | (data[k + 1] << 8);
	  //atomic status = __Flash_Program_Buffer(addr + i, buffer, j - 1);
	  status = __Flash_Program_Buffer(addr + i, buffer, j - 1);
	  if(status != 0x80)
          {
            trace (DBG_USR1,"** FS ERROR **: Flash Write Failed with status == %d \r\n", status);    
	    return FAIL;
          }
	}
      else
	for(; i < numBytes; i+=2){
	  //atomic status = __Flash_Program_Word(addr + i, (data[i + 1] << 8) | data[i]);
	  status = __Flash_Program_Word(addr + i, (data[i + 1] << 8) | data[i]);
	  if(status != 0x80)
          {
            trace (DBG_USR1,"** FS ERROR **: Flash Write Failed with status == %d \r\n", status);    
	    return FAIL;
          }
	}
    }
    else{
      if(programBufferSupported == 1)
	for(; i < numBytes - 1; i = k){
	  for(j = 0, k = i; k < numBytes - 1 && 
		j < FLASH_PROGRAM_BUFFER_SIZE; j++, k+=2)
	    buffer[j] = data[k] | (data[k + 1] << 8);
	  //atomic status = __Flash_Program_Buffer(addr + i, buffer, j - 1);
	  status = __Flash_Program_Buffer(addr + i, buffer, j - 1);
	  if(status != 0x80)
          {
            trace (DBG_USR1,"** FS ERROR **: Flash Write Failed with status == %d \r\n", status);    
	    return FAIL;
          }
	}
      else
	for(; i < numBytes - 1; i+=2){
	  //atomic status = __Flash_Program_Word(addr + i, (data[i + 1] << 8) | data[i]);
	  status = __Flash_Program_Word(addr + i, (data[i + 1] << 8) | data[i]);
	  if(status != 0x80)
          {
            trace (DBG_USR1,"** FS ERROR **: Flash Write Failed with status == %d \r\n", status);    
	    return FAIL;
          }
	}
      //atomic status = __Flash_Program_Word(addr + i, data[i] | (postbyte << 8));
      status = __Flash_Program_Word(addr + i, data[i] | (postbyte << 8));
      if(status != 0x80)
      {
        trace (DBG_USR1,"** FS ERROR **: Flash Write Failed with status == %d \r\n", status);    
	return FAIL;
      }
    }
    return SUCCESS;
  }
  
  void writeExitHelper(uint32_t addr, uint32_t numBytes){
    uint32_t i = 0;
    for(i = addr / FLASH_PARTITION_SIZE;
	i < (numBytes + addr) / FLASH_PARTITION_SIZE;
	i++)
      FlashPartitionState[i] = FLASH_STATE_READ_INACTIVE;
  }
  
  command result_t Flash.write(uint32_t addr, uint8_t* data, uint32_t numBytes){
    uint32_t i;
    uint16_t status;
    uint8_t blocklen;
    uint32_t blockAddr = (addr / FLASH_BLOCK_SIZE) * FLASH_BLOCK_SIZE;
    
    if(addr + numBytes > 0x02000000) //not in the flash memory space
      return FAIL;
    if(addr < FLASH_PROTECTED_REGION)
      return FAIL;


    for(i = 0; i < FLASH_PARTITION_COUNT; i++)
      if(i != addr / FLASH_PARTITION_SIZE &&
	 FlashPartitionState[i] != FLASH_STATE_READ_INACTIVE &&
	 FlashPartitionState[i] != FLASH_STATE_READ_ACTIVE)
	return FAIL;
    
    
    for(i = addr / FLASH_PARTITION_SIZE;
	i < (numBytes + addr) / FLASH_PARTITION_SIZE;
	i++)
      if(FlashPartitionState[i] != FLASH_STATE_READ_INACTIVE)
	return FAIL;
    
    for(i = addr / FLASH_PARTITION_SIZE;
	i < (numBytes + addr) / FLASH_PARTITION_SIZE;
	i++)
      FlashPartitionState[i] = FLASH_STATE_PROGRAM;



      for(blocklen = 0, i = blockAddr;
	  i < addr + numBytes;
	  i += FLASH_BLOCK_SIZE, blocklen++)
        unlock(i);
      
      if(programBufferSupported == 2){
	uint16_t testBuf[1];
	
	if(addr % 2 == 0){
	  testBuf[0] = data[0] | ((*((uint8_t *)(addr + 1))) << 8);
	  status = __Flash_Program_Buffer(addr, testBuf, 1 - 1);
	}
	else{
	  testBuf[0] = *((uint8_t *)(addr - 1)) | (data[0] << 8);
	  status = __Flash_Program_Buffer(addr - 1, testBuf, 1 - 1);
	}      
	if(status == FLASH_NOT_SUPPORTED)
	  programBufferSupported = 0;
	else 
	  programBufferSupported = 1;
      }

    if(blocklen == 1){
      status = writeHelper(addr,data,numBytes,0xFF,0xFF);
      if(status == FAIL){
	writeExitHelper(addr, numBytes);
	return FAIL;
      }
    }
    else{
      uint32_t bytesLeft = numBytes;
      status = writeHelper(addr,data, blockAddr + FLASH_BLOCK_SIZE - addr,0xFF,0xFF);
      if(status == FAIL){
        trace (DBG_USR1,"** FS ERROR **: Flash Write Failed with status == %d \r\n", status);    
	writeExitHelper(addr, numBytes);
	return FAIL;
      }
      bytesLeft = numBytes - (FLASH_BLOCK_SIZE - (addr - blockAddr));
      for(i = 1; i < blocklen - 1; i++){
	status = writeHelper(blockAddr + i * FLASH_BLOCK_SIZE, (uint8_t *)(data + numBytes - bytesLeft),
				    FLASH_BLOCK_SIZE,0xFF,0xFF);
	bytesLeft -= FLASH_BLOCK_SIZE;
	if(status == FAIL){
          trace (DBG_USR1,"** FS ERROR **: Flash Write Failed with status == %d \r\n", status);    
	  writeExitHelper(addr, numBytes);
	  return FAIL;
	}
      }
      status = writeHelper(blockAddr + i * FLASH_BLOCK_SIZE, data + (numBytes - bytesLeft), bytesLeft, 0xFF,0xFF);
      if(status == FAIL){
        trace (DBG_USR1,"** FS ERROR **: Flash Write Failed with status == %d \r\n", status);    
	writeExitHelper(addr, numBytes);
	return FAIL;
      }
    }
    
    writeExitHelper(addr, numBytes);
    return SUCCESS;
  }

  command bool Flash.isBlockErased (uint32_t addr)
  {
    uint32_t j;
    for(j = 0; j < FLASH_BLOCK_SIZE; j+=2)
    {
      uint32_t tempCheck = *(uint32_t *)(addr + j);
      if(tempCheck != 0xFFFFFFFF)
	return FALSE;
    }
    return TRUE;
  }  

  command result_t Flash.eraseBlk (uint32_t addr)
  {
    uint16_t status, i;
    uint32_t j;
    
    if(addr > 0x02000000) //not in the flash memory space
      return FAIL;
    if(addr < FLASH_PROTECTED_REGION)
      return FAIL;

    addr = (addr / FLASH_BLOCK_SIZE) * FLASH_BLOCK_SIZE;

    for(i = 0; i < FLASH_PARTITION_COUNT; i++)
      if(i != addr / FLASH_PARTITION_SIZE &&
	 FlashPartitionState[i] != FLASH_STATE_READ_INACTIVE &&
	 FlashPartitionState[i] != FLASH_STATE_READ_ACTIVE)
	return FAIL;
    
    if(FlashPartitionState[addr / FLASH_PARTITION_SIZE] != FLASH_STATE_READ_INACTIVE)
      return FAIL;
    
    FlashPartitionState[addr / FLASH_PARTITION_SIZE] = FLASH_STATE_ERASE;
    
    for(j = 0; j < FLASH_BLOCK_SIZE; j++){
      uint32_t tempCheck = *(uint32_t *)(addr + j);
      if(tempCheck != 0xFFFFFFFF)
	break;
      if(j == FLASH_BLOCK_SIZE - 1){
	FlashPartitionState[addr / FLASH_PARTITION_SIZE] = FLASH_STATE_READ_INACTIVE;
	return NOTHING_TO_ERASE;
      }
    }

    atomic{
      unlock(addr);
      status = __Flash_Erase(addr);
    }

    //status = __EraseFlashSpin(addr);
    FlashPartitionState[addr / FLASH_PARTITION_SIZE] = FLASH_STATE_READ_INACTIVE;
    //if(status != 0x80)
    //  return FAIL;

    //return NOTHING_TO_ERASE;
    return SUCCESS;
  }

  command result_t Flash.erase(uint32_t addr)
  {
    uint16_t status, i;
    uint32_t j;
    
    if(addr > 0x02000000){ //not in the flash memory space
    	trace(DBG_USR1,"outside range");
		return FAIL;
	}
    if(addr < FLASH_PROTECTED_REGION)
      	return FAIL;
    
    addr = (addr / FLASH_BLOCK_SIZE) * FLASH_BLOCK_SIZE;
    
    for(i = 0; i < FLASH_PARTITION_COUNT; i++)
      if(i != addr / FLASH_PARTITION_SIZE &&
	 FlashPartitionState[i] != FLASH_STATE_READ_INACTIVE &&
	 FlashPartitionState[i] != FLASH_STATE_READ_ACTIVE)
	return FAIL;
    
    if(FlashPartitionState[addr / FLASH_PARTITION_SIZE] != FLASH_STATE_READ_INACTIVE)
      return FAIL;
    
    FlashPartitionState[addr / FLASH_PARTITION_SIZE] = FLASH_STATE_ERASE;
    
    for(j = 0; j < FLASH_BLOCK_SIZE; j++){
      uint32_t tempCheck = *(uint32_t *)(addr + j);
      if(tempCheck != 0xFFFFFFFF)
	break;
      if(j == FLASH_BLOCK_SIZE - 1){
	FlashPartitionState[addr / FLASH_PARTITION_SIZE] = FLASH_STATE_READ_INACTIVE;
	return SUCCESS;
      }
    }
    atomic{
      unlock(addr);
      status = __Flash_Erase(addr);
      status = __EraseFlashSpin(addr);
    }
    FlashPartitionState[addr / FLASH_PARTITION_SIZE] = FLASH_STATE_READ_INACTIVE;
    if(status != 0x80)
      return FAIL;

    return SUCCESS;
  }

  /**
   * read
   * 
   * Reads data from the flash and copies to the buffer pointer passed as
   * parameter. The starting address and the size of data required must
   * be specified by the user.
   *
   * @param addr Flash address where the read starts.
   * @param data Pointer to the buffer to which the data will be copied to.
   * @param numBytes Number of bytes to read.
   * 
   * @return SUCCESS or FAIL
   */
  command result_t Flash.read (uint32_t addr, uint8_t* data, uint32_t numBytes)  
  {
    uint32_t curPtr = 0;
    uint32_t address = addr;
    uint32_t tmpdata = 0;
    while (curPtr < numBytes)
    {
      if (address % 2)
      {
        address = address - 1;
        tmpdata = (*((uint32_t *)address));
        tmpdata = (tmpdata >> 8) & 0xFFFF;
        memcpy ((data + curPtr), &tmpdata, 1);
        curPtr = curPtr + 1;
      }
      else
      {
        tmpdata = (*((uint32_t *)address));
        memcpy ((data + curPtr), &tmpdata, ((numBytes - curPtr) >= 2)? 2 : 1);
        curPtr = curPtr + 2;
      }
      address += 2;
    }

    return SUCCESS;
  }

  /**
   *
   */
  uint16_t unlock(uint32_t addr)  __attribute__((noinline)){
    //addr <<= 1;
    addr = (addr / FLASH_BLOCK_SIZE) * FLASH_BLOCK_SIZE;
    asm volatile(
		 "ldr r1,=0x0060\n\t"  //FASH_DLOCKBLOCK
		 "ldr r2,=0x00FF\n\t"  //FLASH_READARRAY
		 "ldr r3,=0x00D0\n\t"  //FLASH_UNLOCKCONF
		 "ldr r4,=0x0050\n\t"  //FLASH_CLEARSTATUS
		 "b _goUnlockCacheLine\n\t"
		 ".align 5\n\t"
		 "_goUnlockCacheLine:\n\t"
		 "strh r4,[%0]\n\t"
		 "strh r1,[%0]\n\t"
		 "strh r3,[%0]\n\t"
		 "strh r2,[%0]\n\t"
		 "ldrh r2,[%0]\n\t"
		 "nop\n\t"			      
		 "nop\n\t"			      
		 "nop\n\t"
		 :/*no output info*/
		 :"r"(addr)
		 : "r1", "r2", "r3", "r4","memory");    
    return SUCCESS;
  }
  
  uint16_t lock(uint32_t addr) __attribute__ ((noinline)){
    //addr <<= 1;
    asm volatile(
		 "ldr r1,=FLASH_DLOCKBLOCK\n\t"
		 "ldr r2,=FLASH_READARRAY\n\t"
		 "ldr r3,=FLASH_LOCKCONF\n\t"      
		 "ldr r4,=FLASH_CLEARSTATUS\n\t"   
		 "b _goLockCacheLine\n\t"	      
		 ".align 5\n\t"		      
		 "_goLockCacheLine:\n\t"	      
		 "strh r4,[%0]\n\t"		      
         "strh r1,[%0]\n\t"		      
		 "strh r3,[%0]\n\t"		      
		 "strh r2,[%0]\n\t"		      
		 "ldrh r2,[%0]\n\t"		      
		 "nop\n\t"			      
		 "nop\n\t"			      
		 "nop\n\t"
		 :/*no output info*/
		 :"r"(addr)
		 : "r1", "r2", "r3", "r4", "memory");   
    return SUCCESS;
  }
  
  uint16_t programBuffer(uint32_t addr, uint16_t data[], uint8_t datalen)   __attribute__((noinline)){
    uint16_t status;
    /*    uint32_t programBufferCommands[40];/* even though there are only 33 lines
     * of assembly by my count it seems
     * to work better if I allocate / allow
     * for more lines...no clue but this
     * is an issue*/
    //    memcpy(programBufferCommands,__Flash_Program_Buffer,40 * 4);
    
    datalen -= 1;
    asm volatile("mov r1, %1;                  \
                 mov r2, %2;		       \
                 mov r3, %3;		       \
		 bl __Flash_Program_Buffer;    \
		 mov %0, r0;"		 
		 /*mov r14, PC;		      \
		   mov PC, %4;		      \
		   mov %0, r0;"*/
		 :"=r"(status)
		 :"r"(addr), "r"(data),"r"(datalen)//, "r"(programBufferCommands)
		 : "r0", "r1", "r2", "r3", "r14", "memory");
    return status;
  }
  
  uint16_t programWord(uint32_t addr, uint16_t data)  __attribute__((noinline)){
    uint16_t status;
    /*    uint32_t *binary, *temp;
	  uint32_t binSize = (uint32_t)&__Flash_Program_Word_true_end;
	  binSize -= (uint32_t)__Flash_Program_Word;
	  binary = (uint32_t *)malloc(binSize + 4);
	  temp = (uint32_t *)((uint32_t)binary + 4 - ((uint32_t)binary & 0x3));
	  memcpy(temp,__Flash_Program_Word, binSize);*/
    
    asm volatile(
		 "mov r1, %1;                   \
                 mov r2, %2;			\
                 bl __Flash_Program_Word;       \
		 mov %0, r0;"
		 /*
		   mov r3, %3;			\
		   mov r14, PC;			\
		   mov PC, r3;			\
		   mov %0, r0;"		 */
		 :"=r"(status)
		 :"r"(addr), "r"(data)//,"r"(temp)
		 : "r0", "r1", "r2", "r3", "memory");
    //    free(binary);
    return status;
  }
  
  uint16_t eraseFlash(uint32_t addr)  __attribute__((noinline)){
    uint16_t status;
    
    asm volatile(
		 "mov r1, %1;                   \
                 bl __Flash_Erase;              \
                 mov %0, r0;"
		 /*                
				   mov r2, %2;	\
				   mov r14, PC;	\
				   mov PC, r2;	\
				   mov %0, r0;"*/
		 :"=r"(status)
		 :"r"(addr)//, "r"(temp)
		 : "r0", "r1", "r2", "memory");
    //    free(binary);
    return status;
  }
  
}
