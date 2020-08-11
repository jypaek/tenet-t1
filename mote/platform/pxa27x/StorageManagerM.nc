// $Id: StorageManagerM.nc,v 1.2 2007/03/05 00:06:07 lnachman Exp $

/*									tab:2
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
includes trace;

module StorageManagerM 
{
  provides 
  {
    interface SectorStorage[volume_t volume];
    interface FileMount as Mount[volume_t volume];
    interface StdControl;
    interface StorageManager[volume_t volume];
  }
  uses 
  {
    interface Crc;
    interface HALPXA27X;
    interface FileStorage as FormatStorage;
    interface FileStorageUtil;
    interface Leds;
    interface FSQueue as WriteQueue;
  }
}

implementation 
{
  enum 
  {
    //NUM_VOLUMES = uniqueCount("StorageManager"),
    NUM_VOLUMES = uniqueCount("FlashLogger"),
  };

  enum 
  {
    S_NEVER_USED,
    S_READY,
    S_MOUNT,
    S_READ,
    S_COMPUTE_CRC,
    S_WRITE,
    S_ERASE,
  };

  bool FSInited = FALSE;
  uint8_t state;

  SectorTable* sectorTable;
  uint8_t baseSector[NUM_VOLUMES + 1];  /* Add one for the DelayedTask occured due to file erase*/
  volume_t clientVolume;
  volume_id_t curVolumeId;
  uint16_t crcScratch;
  
  storage_addr_t rwAddr;
  storage_addr_t rwLen;
  void* rwData;

  command result_t StdControl.init() 
  {
    uint8_t i;
    state = S_NEVER_USED;
    FSInited = FALSE;
    for ( i = 0; i < NUM_VOLUMES; i++)
      baseSector[i] = FLASH_INVALID_BLOCK;
    return SUCCESS; 
  }

  command result_t StdControl.start() 
  { 
    if (!(FSInited))
    {
      call FormatStorage.init ();
      FSInited = TRUE;
    }
    return SUCCESS; 
  }

  command result_t StdControl.stop()
  {
    return SUCCESS; 
  }

  void signalDone(storage_result_t result) 
  {
    uint8_t tmpState = state;
    state = S_READY;

    switch(tmpState) 
    {
      case S_MOUNT: 
        signal Mount.mountDone[clientVolume](result, curVolumeId); 
      break;
      case S_WRITE: 
        signal SectorStorage.writeDone[clientVolume](result); 
      break;
      case S_ERASE: 
        signal SectorStorage.eraseDone[clientVolume](result); 
      break;
    } 
  }

  uint16_t computeSectorTableCrc() 
  {
    return call Crc.crc16(sectorTable, sizeof(SectorTable)-2);
  }

  void actualMount() 
  {
    volume_id_t i;

    // find base block
    for (i = 0; i < FLASH_NUM_BLOCKS; i++)
    {
      if (sectorTable->block[i].volumeId == curVolumeId) 
      {
        atomic baseSector[clientVolume] = i;
        call FileStorageUtil.updateMountStatus(curVolumeId, i, TRUE);
        signalDone(STORAGE_OK);
        //state = S_READY;
        return;
      }
    }
    //state = S_READY;
    signalDone(STORAGE_FAIL);
  }

  task void mount() 
  {
    actualMount();
  }

  storage_addr_t physicalAddr(storage_addr_t volumeAddr) 
  {
    return FLASH_LOGGER_START_ADDR + FLASH_BLOCK_SIZE*baseSector[clientVolume] + volumeAddr;
  }

  storage_addr_t calcNumBytes() 
  {
    uint32_t numBytes = rwLen;
    return numBytes;
  }

  /**
   * continueOp
   *
   * 
   */
  result_t continueOp()
  {
    storage_addr_t pAddr = physicalAddr(rwAddr);

    switch(state) 
    {
      case S_READ: 
      {
        result_t res = FAIL;
	
        volume_id_t i = baseSector[clientVolume];
        res = call FormatStorage.updateReadPtr(sectorTable->block[i].volumeId, 
                                                rwAddr, rwLen);
	
#ifndef FAKE_FILE_SYSTEM
        if (res == SUCCESS)
        {
          //trace (DBG_USR1,"FS Msg: Reading from %ld Logical Addr %ld\r\n",pAddr, rwAddr);
          res = call HALPXA27X.read(pAddr, rwData, rwLen);
          if (res == FAIL)
            trace (DBG_USR1,"FS ERROR: Read failed for Address %ld\r\n", pAddr);
        }
        else
          trace (DBG_USR1,"FS ERROR: Update read ptr failed for Client %ld at Block %ld\r\n", clientVolume, i);
#else
	{
          uint8_t Dummy = 0xDD;
          uint32_t ic = 0;
	  for (ic=0; ic<rwLen; ic++)
            memcpy ((rwData+ic), &Dummy, 1);
          signalDone (STORAGE_OK);
        }
#endif
        return res;
      }
      break;
      case S_COMPUTE_CRC:
        return call HALPXA27X.computeCrc(&crcScratch, crcScratch, pAddr, rwLen);
      case S_MOUNT:
        pAddr = rwAddr;
      break;
      case S_ERASE:
        trace (DBG_USR1, "Erasing Block with address %ld \r\n", pAddr);

#ifndef FAKE_FILE_SYSTEM
        return call HALPXA27X.bulkErase(pAddr);
#else
        signalDone (STORAGE_OK);
	return SUCCESS;
#endif
      case S_WRITE:
      {
        result_t res = FAIL;
        volume_id_t i = baseSector[clientVolume];
        uint8_t wrtBuff [32];
        uint32_t cmp_size = 0x4; /*Compare size starts with 4*/
        cmp_size = (rwLen > 32)? 32 : rwLen;
        res = call FormatStorage.updateWritePtr(sectorTable->block[i].volumeId, 
                                                rwAddr, rwLen);
#ifndef FAKE_FILE_SYSTEM
        memcpy (wrtBuff, rwData, cmp_size);
        //trace (DBG_USR1,"FS Msg: WRITE BUFFER %x %x %x %x\r\n", wrtBuff [0],wrtBuff [1],wrtBuff [2],wrtBuff [3]);
        if (res == SUCCESS)
        {
          uint8_t rdBuff [32];
          res = call HALPXA27X.pageProgram(pAddr, rwData, calcNumBytes());
          if (res == SUCCESS)
          {
            call HALPXA27X.read(pAddr, rdBuff, cmp_size);
            //assert (memcmp(wrtBuff, rdBuff, 4) == 0);
            if (memcmp(wrtBuff, rdBuff, cmp_size) != 0)
              trace (DBG_USR1,"** FATAL ERROR **: WRITE CORRUPTED at SectorStorageM. Bytes Read %x %x %x %x\r\n", rdBuff [0],rdBuff [1],rdBuff [2],rdBuff [3]);
            //trace (DBG_USR1,"FS Msg: READ BACK BUFFER %x %x %x %x\r\n", rdBuff [0],rdBuff [1],rdBuff [2],rdBuff [3]);
          }
          else
            trace (DBG_USR1, "** FS ERROR **: Write to Failed \r\n");
        }
        else
          trace (DBG_USR1, "** FS ERROR **: Write pointer update Failed \r\n");
#else
        res = SUCCESS;
        signalDone (STORAGE_OK);
#endif
        return res;
      }
      break;
      default:
      break;
    }
    return FAIL;
  }

  command result_t Mount.mount[volume_t volume](volume_id_t volumeID) 
  {
    if (baseSector[volume] != FLASH_INVALID_BLOCK)
      return FAIL;

    if (state != S_READY && state != S_NEVER_USED)
      return FAIL;

    curVolumeId = volumeID;
    clientVolume = volume;

    if (state == S_NEVER_USED) 
    {
      sectorTable = call FormatStorage.getSectorTable();
      if (sectorTable == NULL)
        return FAIL;
    }
    state = S_MOUNT;
    actualMount ();

    return SUCCESS;
  }


  result_t HandleOpenRequest (volume_t volume, const uint8_t* filename)
  {
    if (baseSector[volume] != FLASH_INVALID_BLOCK)
    {
      trace (DBG_USR1, "The interface has mounted a different file. VolID = %d\r\n",baseSector[volume]);
      return FAIL;
    }

    if (state != S_READY && state != S_NEVER_USED)
    {
      trace (DBG_USR1, "Invalid State\r\n");
      return FAIL;
    }

    if (call FormatStorage.isFileMounted(filename) == TRUE)
    {
      trace (DBG_USR1, "The file is already mounted.\r\n");
      return FAIL;
    }

    clientVolume = volume;

    if (state == S_NEVER_USED) 
      sectorTable = call FormatStorage.getSectorTable();
    if (sectorTable == NULL)
    {
      trace (DBG_USR1, "Sector Table is NULL in %s.\r\n", __FILE__);
      return FAIL;
    }

    curVolumeId = call FormatStorage.getVolumeId(filename);
    if (curVolumeId == FLASH_INVALID_VOLUME_ID)
    {
      trace (DBG_USR1, "Invalid File Name.\r\n");
      return FAIL;
    }
    /* Reset the read pointer of the file to 0*/
    call FormatStorage.updateReadPtr(curVolumeId,0,0);

    state = S_MOUNT;
    actualMount ();
    return SUCCESS;
  }

  command result_t Mount.fopen[volume_t volume](const uint8_t* filename) 
  {
    result_t ret = SUCCESS;

    if (call HALPXA27X.isErasing())
    {
      result_t res = FAIL;
      trace (DBG_USR1,"FS MSG: FileSystem is BUSY erasing, FILE OPEN operation Queued\r\n");
      res = call WriteQueue.queueOpen (volume, filename);
      return res;
    }

    ret = HandleOpenRequest (volume, filename);
    return ret;
  }

  result_t HandleCloseRequest (volume_t volume, const uint8_t* filename)
  {
    result_t res = SUCCESS;
    uint16_t i = baseSector[volume];
    volume_id_t tmpVolumeId = sectorTable->block[i].volumeId;

    volume_id_t vol = call FormatStorage.getVolumeId (filename);

    if ((vol == FLASH_INVALID_VOLUME_ID) || (vol != tmpVolumeId))
    {
      trace (DBG_USR1, "** FS ERROR **: Volume ID was invalid %ld %ld\r\n", vol, tmpVolumeId);
      return FAIL;
    }

    if (call FormatStorage.isFileMounted(filename) == FALSE)
    {
      trace (DBG_USR1, "** FS ERROR **: The file %s is not mounted \r\n",filename);
      return FAIL;
    }

    state = S_READY;
    res = call FileStorageUtil.updateMountStatus(tmpVolumeId, baseSector[volume], FALSE);
    baseSector[volume] = FLASH_INVALID_BLOCK;
    return res;
  }

  /**
   * Mount.fclose
   *
   */
  command result_t Mount.fclose[volume_t volume] (const uint8_t* filename)
  {
    result_t ret = SUCCESS;

    if (call HALPXA27X.isErasing())
    {
      result_t res = FAIL;
      trace (DBG_USR1,"FS MSG: FileSystem is BUSY erasing, FILE CLOSE operation Queued\r\n");
      res = call WriteQueue.queueClose (volume, filename);
      return res;
    }

    ret = HandleCloseRequest (volume, filename);
    return ret;
  }

  command uint8_t StorageManager.getNumSectors[volume_t volume]() 
  {
    uint16_t i = baseSector[volume];
    uint16_t tmpVolumeId = sectorTable->block[i].volumeId;

    if (baseSector[volume] == FLASH_INVALID_BLOCK)
      return FLASH_INVALID_BLOCK;

    for (;i < FLASH_NUM_BLOCKS && sectorTable->block[i].volumeId == tmpVolumeId; i++);

    return (i - baseSector[volume]);
  }

  command storage_addr_t StorageManager.getVolumeSize[volume_t volume]() 
  {
    if (baseSector[volume] == FLASH_INVALID_BLOCK)
      return FLASH_INVALID_ADDR;
    return FLASH_BLOCK_SIZE * call StorageManager.getNumSectors[volume]();
  }

  result_t newRequest(uint8_t newState, volume_t volume, 
                      storage_addr_t addr, void* data, storage_addr_t len) 
  {
    result_t result;

    if (state != S_READY)
      return FALSE;

    state = newState;
    clientVolume = volume;

    rwAddr = addr;
    rwData = data;
    rwLen = len;

    result = continueOp();

    if (result == FAIL || state == S_READ || state == S_COMPUTE_CRC)
      state = S_READY;

    return result;
  }

  command result_t SectorStorage.read[volume_t volume](storage_addr_t addr, 
                                                       void* data, 
                                                       storage_addr_t len) 
  {
    return newRequest(S_READ, volume, addr, data, len);
  }

  command result_t SectorStorage.write[volume_t volume](storage_addr_t addr, 
                                                        void* data, 
                                                        storage_addr_t len) 
  {
    return newRequest(S_WRITE, volume, addr, data, len);
  }

  command result_t SectorStorage.erase[volume_t volume](storage_addr_t addr, 
                                                        storage_addr_t len) 
  {
    return newRequest(S_ERASE, volume, addr, NULL, len);
  }

  command storage_addr_t SectorStorage.getWritePtr[volume_t volume]() 
  {
    uint8_t i = baseSector[volume];
    uint16_t tmpVolumeId = sectorTable->block[i].volumeId;
    storage_addr_t WritePtr = INVALID_PTR;
    return call FormatStorage.getWritePtr1(tmpVolumeId);
  }

  command result_t SectorStorage.resetWritePtr[volume_t volume]() 
  {
    storage_addr_t len = call StorageManager.getNumSectors[volume]();
    return newRequest(S_ERASE, volume, 0, NULL, len);
  }

  command result_t SectorStorage.fread[volume_t volume](void* data, storage_addr_t len)
  {
    uint8_t i = baseSector[volume];
    uint16_t tmpVolumeId = sectorTable->block[i].volumeId;
    storage_addr_t ReadPtr = INVALID_PTR;
    storage_addr_t WritePtr = INVALID_PTR;

    ReadPtr = call FormatStorage.getReadPtr1 (tmpVolumeId);
    if (ReadPtr == INVALID_PTR)
    {
      trace (DBG_USR1,"FS WARNING: Invalid Read Pointer.\r\n");
      return FAIL;
    }

    WritePtr = call FormatStorage.getWritePtr1 (tmpVolumeId);
    if ((WritePtr == INVALID_PTR) || (WritePtr <= 0))
    {
      trace (DBG_USR1,"FS ERROR: Invalid Write Pointer or Write pointer is zero.\r\n");
      return FAIL;
    }

    if (ReadPtr >= WritePtr)
      return FAIL;

    /* Adjust the length of data to be read based on the write pointer.*/
    len = ((ReadPtr + len) < WritePtr)? len: (WritePtr - ReadPtr);

    return newRequest(S_READ, volume, ReadPtr, data, len);
  }

  command storage_addr_t SectorStorage.getReadPtr[volume_t volume]()
  {
    uint8_t i = baseSector[volume];
    uint16_t tmpVolumeId = sectorTable->block[i].volumeId;
    storage_addr_t ReadPtr = INVALID_PTR;
    ReadPtr = call FormatStorage.getReadPtr1 (tmpVolumeId);
    return ReadPtr;
  }

  command result_t SectorStorage.resetReadPtr[volume_t volume]()
  {
    uint8_t i = baseSector[volume];
    uint16_t tmpVolId = sectorTable->block[i].volumeId;
    if (call FormatStorage.updateReadPtr(tmpVolId,0,0) == SUCCESS)
      return SUCCESS;
    return FAIL;
  }

  command result_t SectorStorage.rseek[volume_t volume](storage_addr_t addr)
  {
    //uint8_t i = baseSector[clientVolume];
    uint8_t i = baseSector[volume];
    uint16_t tmpVolId = sectorTable->block[i].volumeId;

    if (addr >= call StorageManager.getVolumeSize[volume]())
      return FAIL;

    if (call FormatStorage.updateReadPtr(tmpVolId,addr,0) == SUCCESS)
      return SUCCESS;
    return FAIL;
  }

  result_t HandleAppendRequest (volume_t volume, void* data, storage_addr_t len)
  {
    uint8_t i = baseSector[volume];
    uint16_t tmpVolumeId = sectorTable->block[i].volumeId;
    storage_addr_t WritePtr = INVALID_PTR;

    WritePtr = call FormatStorage.getWritePtr1 (tmpVolumeId);

    if (WritePtr == INVALID_PTR)
      return FAIL;

    return newRequest(S_WRITE, volume, WritePtr, data, len);
  }

  command result_t SectorStorage.append[volume_t volume](void* data, storage_addr_t len) 
  {
    result_t res = SUCCESS;

    if (call HALPXA27X.isErasing())
    {
      trace (DBG_USR1,"FS MSG: FileSystem if BUSY erasing, Write operation Queued\r\n");
      res = call WriteQueue.queueWrite (0x0, volume, data, len);
      return res;
    }

    res = HandleAppendRequest (volume, data, len);
    return res;
  }

  command result_t SectorStorage.computeCrc[volume_t volume](uint16_t* crcResult, 
                                                             uint16_t crc, 
                                                             storage_addr_t addr, 
                                                             storage_addr_t len) 
  {
    result_t result;
    crcScratch = crc;
    result = newRequest(S_COMPUTE_CRC, volume, addr, NULL, len);
    *crcResult = crcScratch;
    return result;
  }

  void pageProgramDone() 
  {
    storage_addr_t lastBytes;

    lastBytes = calcNumBytes();
    rwAddr += lastBytes;
    rwData += lastBytes;
    rwLen -= lastBytes;
    if (rwLen == 0) 
    {
      if (state == S_MOUNT)
        actualMount();
      else
        signalDone(STORAGE_OK);
      return;
    }

    if (continueOp() == FAIL)
      signalDone(STORAGE_FAIL);
  }

  event void HALPXA27X.pageProgramDone() 
  {
    pageProgramDone();
  }

  event void HALPXA27X.blockEraseDone() 
  {

  }

  /**
   * FileStorageUtil.filedeleted
   *
   * Event which is signaled after a successfull file delete. This event
   * is usedful to notify the storage manager after a file delete.
   *
   * @param filename Name of the file that was deleted.
   */
  event void FileStorageUtil.filedeleted (volume_id_t id, const uint8_t* filename)
  {
    uint8_t i = 0;
    uint8_t j = 0;
    uint16_t tmpId = FLASH_INVALID_BLOCK;

    for (i = 0; i < NUM_VOLUMES; i++)
    {
      j = baseSector[i];
      tmpId = sectorTable->block[j].volumeId;
      if (id == tmpId)
      {
        baseSector [i] = FLASH_INVALID_BLOCK;
        return;
      }
    }
  }

  event void HALPXA27X.bulkEraseDone(result_t scode, uint32_t addr) 
  {
    return;
#if 0
    if (rwLen > 1)
    {
      state = S_READY;
      -- rwLen;
      rwAddr += FLASH_BLOCK_SIZE;
      if (newRequest(S_ERASE, clientVolume, rwAddr, NULL, rwLen) == FAIL)
        signalDone(STORAGE_FAIL);
    }
    else
    {
      uint8_t i = baseSector[clientVolume];
      uint16_t tmpVolId = sectorTable->block[i].volumeId;
      if (call FormatStorage.updateWritePtr(tmpVolId,0,0) == SUCCESS)
        signalDone(STORAGE_OK);
      else
        signalDone(STORAGE_FAIL);
    }
#endif
  }

  event void WriteQueue.pendingReq (uint8_t request, void* data, PendingRequest* req)
  {
    if (state != S_READY)
      trace (DBG_USR1, "FS WARNING: There is a pending FS operation\r\n");
      
    //trace (DBG_USR1, "FS Msg: Executing Pending request of type %d \r\n", request);
    switch (request)
    {
      case WRITE_REQUEST:
      {
        if (HandleAppendRequest (req->preq.wreq.ClientVolume, data, req->preq.wreq.DataLen) == FAIL)
          trace (DBG_USR1, "FS ERROR: Pending Append operation failed \r\n");
      }
      break;
      case CREATE_REQUEST:
      break;
      case DELETE_REQUEST:
      break;
      case FOPEN_REQUEST:
        if (HandleOpenRequest(req->preq.ocreq.ClientVolume, req->preq.ocreq.FileName) == FAIL)
          trace (DBG_USR1, "FS ERROR: Pending Open operation failed for %s\r\n", req->preq.ocreq.FileName);
        return;
      break;
      case FCLOSE_REQUEST:
        if (HandleCloseRequest(req->preq.ocreq.ClientVolume, req->preq.ocreq.FileName) == FAIL)
          trace (DBG_USR1, "FS ERROR: Pending Close operation failed for %s\r\n", req->preq.ocreq.FileName);
      break;
      default:
          trace (DBG_USR1,"FS WARNING: Unknown task in the QUEUE %d\r\n",req->ReqType);
      break;
    }
    return;
  }

  event void HALPXA27X.writeSRDone() {}
  event void FormatStorage.commitDone(storage_result_t result) {}


  default event void Mount.mountDone[volume_t volume](storage_result_t result, volume_id_t id) {}
  default event void SectorStorage.eraseDone[volume_t volume](result_t result) {}
  default event void SectorStorage.writeDone[volume_t volume](result_t result) {}
}
