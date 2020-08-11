/* 
 * Author:		Josh Herbach
 * Revision:	1.0
 * Date:		09/02/2005
 */

includes mmu;

module TrickleM {
  provides interface StdControl as Control;
  uses{
    interface Flash;
    interface ReceiveBData;
    interface SendJTPacket;
    interface StdControl as USBControl;
  }
}
implementation {

  extern void __Binary_Mover() __attribute__ ((C,spontaneous));
  extern uint32_t __Binary_Mover_true_end __attribute__ ((C));

#include "Flash.h"
#include "PXA27XUSBClient.h"
  void verifyData(uint32_t addr, uint32_t numBytes);
  void reboot(uint32_t imageAddr, uint32_t imageSize);

  uint32_t startWriteAddr, lastWriteAddr, busy = 0;

  command result_t Control.init() {
    return SUCCESS;
  }
  
  command result_t Control.start() {    
    return SUCCESS;
  }
  
  command result_t Control.stop() {
    return SUCCESS;
  }

  void verifyData(uint32_t addr, uint32_t numBytes){
    atomic busy = 1;
    call SendJTPacket.send((uint8_t *)addr, numBytes,
			   IMOTE_HID_TYPE_CL_BINARY);
  }

  event result_t SendJTPacket.sendDone(uint8_t* packet, uint8_t type, result_t success){
    uint8_t impType = IMOTE_HID_TYPE_CL_BINARY | 
		       (IMOTE_HID_TYPE_MSC_BLOADER << IMOTE_HID_TYPE_MSC);
    if((type & impType) == impType)
      free(packet);
    return SUCCESS;
  }

  event result_t ReceiveBData.receive(uint8_t* buffer, uint8_t numBytesRead,
				      uint32_t i, uint32_t n, uint8_t type){
    uint32_t j;
    uint8_t status;
    if((type >> IMOTE_HID_TYPE_MSC) == IMOTE_HID_TYPE_MSC_BLOADER){
      switch(buffer[0]){
      case 0:
	startWriteAddr = ((buffer[1] << 24) | (buffer[2] << 16) |
			  (buffer[3] << 8) | buffer[4]);
	break;
      case 1:
	atomic busy = 0;
	break;
      case 2:
	j = (buffer[1] << 24) | (buffer[2] << 16) | (buffer[3] << 8) | buffer[4];
	reboot(j + 4,*(uint32_t*)j);
	break;
      }
      return SUCCESS;
    }
    if(busy == 1)
      return SUCCESS;
    
    if(i == 0){
      for(j = 0; j < numBytesRead * (n + 1) + 4; j += FLASH_BLOCK_SIZE){//4 extra bytes for size
	status = call Flash.erase(startWriteAddr + j);
	if(status == FAIL){
	  uint8_t *temp = (uint8_t *)malloc(5);
	  *(uint32_t *)temp = 1;
	  call SendJTPacket.send(temp, 5, IMOTE_HID_TYPE_CL_BINARY |
				 (IMOTE_HID_TYPE_MSC_BLOADER <<
				  IMOTE_HID_TYPE_MSC));
	  return SUCCESS;
	}
      }
      lastWriteAddr = startWriteAddr + 4;//save the first 4 bytes for size
    }
    status = call Flash.write(lastWriteAddr, buffer, numBytesRead);
    if(status == FAIL){
	  uint8_t *temp = (uint8_t *)malloc(5);
	  *(uint32_t *)temp = 2;
	  call SendJTPacket.send(temp, 5, IMOTE_HID_TYPE_CL_BINARY |
				 (IMOTE_HID_TYPE_MSC_BLOADER <<
				  IMOTE_HID_TYPE_MSC));
	  return SUCCESS;
    }
    
    lastWriteAddr += numBytesRead;
    if(i % 5 == 0 || i - n < 5){
	uint8_t *temp = (uint8_t *)malloc(4);
	*(uint32_t *)temp = i;
	call SendJTPacket.send(temp, 4, IMOTE_HID_TYPE_CL_BINARY |
			       (IMOTE_HID_TYPE_MSC_BLOADER << 
				IMOTE_HID_TYPE_MSC));
	if(n==i){
	  uint32_t size[1];
	  size[0] = lastWriteAddr - (startWriteAddr + 4);
	  status = call Flash.write(startWriteAddr, (uint8_t *)size, 4);
	  if(status == FAIL){
	    temp = (uint8_t *)malloc(5);
	    *(uint32_t *)temp = 3;
	    call SendJTPacket.send(temp, 5, IMOTE_HID_TYPE_CL_BINARY |
				   (IMOTE_HID_TYPE_MSC_BLOADER <<
				    IMOTE_HID_TYPE_MSC));
	    return SUCCESS;
	  }
	  verifyData(startWriteAddr + 4, size[0]);
	}
    }
    return SUCCESS;
  }

  typedef  uint8_t (*binaryMoverFunc)(uint32_t addr, uint32_t size) __attribute__((long_call));
  binaryMoverFunc binaryMover;
 
  void reboot(uint32_t imageAddr, uint32_t imageSize) __attribute__((noinline)){
    uint32_t binSize = (uint32_t)&__Binary_Mover_true_end;
    uint8_t *rebootBinary;
    //  uint8_t (*binaryMover)(uint32_t addr, uint32_t size); 

    disableDCache();
    binSize -= (uint32_t)__Binary_Mover;
    rebootBinary = (uint8_t *)malloc(binSize);
    memcpy(rebootBinary, __Binary_Mover, binSize);
    //binaryMover = (uint8_t (*)(uint32_t, uint32_t))rebootBinary;
    binaryMover = (binaryMoverFunc)rebootBinary;
    //call USBControl.stop();
    (*binaryMover)(imageAddr,imageSize);
  }
}
