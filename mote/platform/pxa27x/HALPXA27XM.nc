// $Id: HALPXA27XM.nc,v 1.2 2007/03/05 00:06:07 lnachman Exp $

/*									tab:4
 * "Copyright (c) 2000-2005 The Regents of the University  of California.  
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
 */

/*
 * @author: Jonathan Hui <jwhui@cs.berkeley.edu>
 */

module HALPXA27XM {
  provides {
    interface StdControl;
    interface HALPXA27X[volume_t volume];
    interface FSQueueUtil;
  }
  uses {
    interface Flash;
    interface Leds;
    interface Timer;
  }
}

implementation 
{
#include <Flash.h>
  //volume_t curVolume;
  //uint8_t curCmd;
  stm25p_sig_t signature;
  uint16_t crcScratch;

  volume_t eraseVolume;
  storage_addr_t ErasingBlock = 0xFFFFFFFF;
  volatile uint8_t PartitionState [FLASH_FS_NUM_SECTORS];

  extern uint8_t __GetEraseStatus(uint32_t addr) __attribute__ ((C,spontaneous,noinline));
  extern uint8_t __EraseFlashSpin(uint32_t addr) __attribute__ ((C,spontaneous,noinline));
  extern uint8_t __Flash_Suspend(uint32_t addr) __attribute__ ((C,spontaneous,noinline));
  extern uint8_t __Flash_Suspend_Resume(uint32_t addr) __attribute__ ((C,spontaneous,noinline));

  command result_t StdControl.init() 
  {
    uint8_t i = 0x0;
    signature = FLASH_INVALID_SIG;
    for (i=0;i<FLASH_FS_NUM_SECTORS;i++)
      PartitionState [i] = FLASH_NOOP;
    return SUCCESS;
  }

  command result_t StdControl.start() { return SUCCESS; }
  command result_t StdControl.stop() { return SUCCESS; }

  //task void signalDone() 
  void signalDone(result_t ret, volume_t curVolume, uint8_t curCmd) 
  {
    uint8_t tmpCmd = curCmd;
    switch(tmpCmd)
    {
      case FLASH_PP: signal HALPXA27X.pageProgramDone[curVolume](); break;
      case FLASH_SE: signal HALPXA27X.blockEraseDone[curVolume](); break;
      case FLASH_BE:
      {
        uint32_t ersAddr = 0x0;
        atomic ersAddr = ErasingBlock;
        ErasingBlock = 0xFFFFFFFF;
        signal FSQueueUtil.eraseCompleted();
        signal HALPXA27X.bulkEraseDone[curVolume](ret, ersAddr);
      }
      break;
      case FLASH_WRSR: signal HALPXA27X.writeSRDone[curVolume](); break;
    }
  }

#if 0
  bool isWriting() 
  {
    uint8_t status;
    sendCmd(FLASH_RDSR, 0, &status, sizeof(status));
    return !!(status & 0x1);
  }
#endif

  event result_t Timer.fired() 
  {
    uint16_t status = 0xFFFF;
    status = __GetEraseStatus(ErasingBlock);
    if (!(status & 0x80))
      call Timer.start(TIMER_ONE_SHOT, 200);
    else
    {
      status = __EraseFlashSpin (ErasingBlock);
      if (status != 0x80)
      {
        trace (DBG_USR1, "** FS ERROR **: Erase Failed for addr %ld\r\n", ErasingBlock);
        signalDone (FAIL, eraseVolume, FLASH_BE);
      }
      else
      {
        trace (DBG_USR1, "FS: Erase Completed successfully \r\n");
        signalDone (SUCCESS, eraseVolume, FLASH_BE);
      }
    }

    return SUCCESS;
  }

  result_t newRequest(uint8_t cmd, volume_t volume, stm25p_addr_t addr, 
                                   uint8_t* data, stm25p_addr_t len) 
  {
    result_t res = SUCCESS;
    volume_t curVolume;
    uint8_t curCmd;
    uint8_t partition = addr / FLASH_PARTITION_SIZE;
    //uint16_t SusStatus = 0x0;

    if ((PartitionState [partition] != FLASH_NOOP) || (ErasingBlock != 0xFFFFFFFF))
    {
      trace (DBG_USR1, "FS Msg: Partition is in BUSY state. Erasing Block %ld\r\n", ErasingBlock);
      signalDone (FAIL, volume, cmd);
      return FAIL;
    }

    curVolume = volume;
    curCmd = cmd;
    switch(curCmd) 
    {
      case FLASH_PP:
        atomic PartitionState [partition] = FLASH_WRITE_BUSY;
        res = call Flash.write (addr, data, len);
        if (res == FAIL)
           trace (DBG_USR1, "FS ERROR; FALSH WRITE FAILED\r\n");
        
        atomic PartitionState [partition] = FLASH_NOOP;
      break;
      case FLASH_SE:
        atomic PartitionState [partition] = FLASH_ERASE_BUSY;
        res = call Flash.erase (addr);
        atomic PartitionState [partition] = FLASH_NOOP;
      break;
      case FLASH_BE:
        if (ErasingBlock == 0xFFFFFFFF)
        {
          atomic eraseVolume = curVolume;
          res = call Flash.eraseBlk (addr);
          if (res == NOTHING_TO_ERASE)
            res = SUCCESS;
          else if (res == SUCCESS)
          {
            atomic ErasingBlock = addr;
            call Timer.start(TIMER_ONE_SHOT, 200);
          }
          else
            res = FAIL;
        }
        else
          return FAIL;
      break;
      case FLASH_READ:
        res = call Flash.read (addr, data, len);
      break;
      case FLASH_WRSR:
      break;
      default:
      return FAIL;
    }

      //res = post signalDone ();
    if ((res == SUCCESS) && (curCmd != FLASH_BE))
      signalDone (res, curVolume, curCmd);

    return res;
  }

  command bool HALPXA27X.isErasing[volume_t volume] ()
  {
    if (ErasingBlock != 0xFFFFFFFF)
      return TRUE;
    return FALSE;
  }

  //command result_t HALPXA27X.clearBlock[volume_t volume](storage_addr_t block)
  command result_t HALPXA27X.clearBlock[volume_t volume](uint16_t block)
  {
    result_t ret = FAIL;
    storage_addr_t Addr = FLASH_LOGGER_START_ADDR + (block * FLASH_BLOCK_SIZE);

    uint8_t partition = Addr / FLASH_PARTITION_SIZE;

    if (PartitionState [partition] == FLASH_NOOP)
    {
      trace (DBG_USR1, "** FS ERROR **: Trying to Erase from a Sector with pending Erase or Write\r\n");
      return FAIL;
    }

    ret = call Flash.erase (Addr);
    return ret;
  }
  
  command result_t HALPXA27X.wordProgram[volume_t volume](stm25p_addr_t addr, 
                                                          uint16_t word)
  {
    return call Flash.write (addr, (void*)&word, 2);
  }
  
  command result_t HALPXA27X.read[volume_t volume](stm25p_addr_t addr, 
                                                   void* data, 
                                                   stm25p_addr_t len)
  {
    uint8_t partition = addr / FLASH_PARTITION_SIZE;

    if (PartitionState [partition] != FLASH_NOOP)
    {
      trace (DBG_USR1, "** FS ERROR **: Trying to read from a Sector with pending Erase or Write\r\n");
      return FAIL;
    }

    return call Flash.read (addr, data, len);
    //return newRequest (FLASH_READ, volume, addr, data, len);
  }

  command result_t HALPXA27X.pageProgram[volume_t volume](stm25p_addr_t addr, 
                                                          void* data, 
                                                          stm25p_addr_t len) 
  {
    return newRequest(FLASH_PP, volume, addr, data, len);
  }

  command result_t HALPXA27X.blockErase[volume_t volume](stm25p_addr_t addr)
  {
    return newRequest(FLASH_SE, volume, addr, NULL, 0);
  }

  command result_t HALPXA27X.bulkErase[volume_t volume](stm25p_addr_t addr) 
  {
    return newRequest(FLASH_BE, volume, addr, NULL, 0);
  }

  command result_t HALPXA27X.readSR[volume_t volume](void* value) 
  {
    return newRequest(FLASH_RDSR, volume, 0, value, 1);
  }

  command result_t HALPXA27X.writeSR[volume_t volume](uint8_t value) 
  {
    return newRequest(FLASH_WRSR, volume, 0, &value, 1);
  }

  command result_t HALPXA27X.computeCrc[volume_t volume](uint16_t* crcResult, 
                                                         uint16_t crc, 
                                                         stm25p_addr_t addr, 
                                                         stm25p_addr_t len) 
  {
    result_t result;
    crcScratch = crc;
    result = newRequest(FLASH_CRC, volume, addr, NULL, len);
    *crcResult = crcScratch;
    return result;
  }

  command stm25p_sig_t HALPXA27X.getSignature[volume_t volume]() 
  { 
    return signature; 
  }

  default event void HALPXA27X.pageProgramDone[volume_t volume]() {}
  default event void HALPXA27X.blockEraseDone[volume_t volume]() {}
  default event void HALPXA27X.bulkEraseDone[volume_t volume](result_t scode, uint32_t addr) {}
  default event void HALPXA27X.writeSRDone[volume_t volume]() {}

}
