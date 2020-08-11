// $Id: FormatStorageM.nc,v 1.2 2007/03/05 00:06:07 lnachman Exp $

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

module FormatStorageM 
{
  provides 
  {
    interface FileStorage as FormatStorage;
    interface FileStorageUtil;
    interface StdControl;
  }
  uses 
  {
    interface Crc;
    interface HALPXA27X;
    interface Flash;
    interface Timer as EraseTimer;
    interface FSQueue;
  }
}

implementation
{
#include <FileList.h>
#include <Flash.h>
  #define START_VOLUME_ID 2
  #define MAX_VOLUME_ID 200

  /**
   * struct FileMetaList
   *
   * Structure for metadata linked list for each file.
   */
  typedef struct 
  {
    FileMetadata metadata;
    list_ptr metaList;
  } FileMetaList;

  SectorTable sectorTable;
  FileMetadata metaData;
  FileMetaList fmList;
  FileMetaList deleteList;
  FileMetaList uncommittedList;
  FileMetaList* tmpList;
  uint8_t unCommittedFiles;
  volume_id_t NextVolumeId;
  storage_addr_t curAddr;

  storage_addr_t rwLen;
  volume_id_t NumUnAllocatedBlocks;
  uint8_t OpenFileSectors [FLASH_FS_NUM_SECTORS];
  volatile bool isEraseTimer = FALSE;
  volatile uint8_t FreePartition [FLASH_FS_NUM_SECTORS];
  uint16_t SystemTableErase [NUM_SYS_BLOCKS];

  /**
   * Offset of sector table. The start location is always the
   * current valid sector table.
   */
  storage_addr_t stoffset = sizeof (SectorTable);

  /**
   * Offset for meta data table.
   */
  storage_addr_t mdoffset = 0x0;

  uint8_t state;

  /**
   * Prototype for local functions
   */
  result_t commitSectorTable ();
  void PopulateSectorInfo();
  result_t ReadValidSectorTable (uint32_t STaddr);
  volume_id_t GetFreeSector ();
  result_t CleanUnAllocedBlks ();
  volume_id_t ReadValidMetadata (uint32_t addr);
  result_t cleanupMetaDataBlock ();
  volume_id_t isExisting(const uint8_t* filename);

  /* Threshold for forcing an erase */
  #define FREE_BLOCK_THRESHOLD 20

  /* Erase Timer */
  #define ERASE_INTERVAL 5000

  enum 
  {
    S_UN_INIT,
    S_INIT,
    S_COMMIT,
    S_COMMIT_DONE,
  };

  enum
  {
    VALIDITY_SIZE = 2,
  };

  enum
  {
    VALID_SYS_TABLE_BLOCK = 0xDDCC,
    INVALID_SYS_TABLE_BLOCK = 0xD98C,
  };

  typedef enum ErrCodes
  {
    NO_VALID_SECTOR_TABLE = 2,
    ST_EMPTY_BLOCK = 3,
    MD_EMPTY_BLOCK = 4,
  } ErrCodes;

  void signalDone(storage_result_t result) 
  {
    atomic state = S_COMMIT_DONE;
    signal FormatStorage.commitDone(result);
  }

  command result_t StdControl.init() 
  {
    atomic state = S_UN_INIT;
    return SUCCESS;
  }

  command result_t StdControl.start() 
  {
    return SUCCESS;
  }

  command result_t StdControl.stop() 
  {
    return SUCCESS;
  }

  /**
   * PopulateSectorInfo
   */
  void PopulateSectorInfo()
  {
    volume_id_t i;
    for (i=0;i<FLASH_FS_NUM_SECTORS;i++)
      atomic FreePartition [i] = 0;

    for (i=0; i<FLASH_NUM_BLOCKS;i++)
    {
      volume_id_t id = sectorTable.block[i].volumeId;
      if ((id != FLASH_INVALID_VOLUME_ID) && (id != FLASH_UNALLOCED_BLOCK))
      {
        storage_addr_t paddr = (i * FLASH_BLOCK_SIZE) + FLASH_LOGGER_START_ADDR;
        atomic ++ FreePartition [paddr / FLASH_PARTITION_SIZE];
      }
    }
  }

  /**
   * GetFreeSector
   */
  volume_id_t GetFreeSector ()
  {
    volume_id_t i;
    for (i=1;i<FLASH_FS_NUM_SECTORS;i++)
    {
      if (FreePartition[i] == 0)
        return i;
    }
    return 0;
  }

  /**
   * IsSysBlockValid
   *
   * Check to see if the MD or the ST block is valid.
   */
  bool IsSysBlockValid (uint32_t SysAddr)
  {
    uint16_t peekData = 0x0;
    
    call Flash.read (SysAddr, (uint8_t*)&peekData, VALIDITY_SIZE);
    trace (DBG_USR1, "FS Msg: Data from the System table starting at %ld is %ld \r\n",SysAddr, peekData);
    if (peekData == VALID_SYS_TABLE_BLOCK)
    {
      trace (DBG_USR1, "FS Msg: Valid System Table.\r\n");
      return TRUE;
    }

    return FALSE;
  }

  /**
   * ReadValidSectorTable
   *
   * Scan the ST Blocks and find valid sector table.
   */
  result_t ReadValidSectorTable (uint32_t STaddr)
  {
    storage_addr_t i = STaddr + VALIDITY_SIZE;
    storage_addr_t endAddr = (STaddr + FLASH_BLOCK_SIZE);

    for (; i < endAddr; i+=sizeof(SectorTable))
    {
      if ((call HALPXA27X.read (i,&sectorTable, sizeof(SectorTable))) == SUCCESS)
      {
        if (sectorTable.validity == VALID_SECTOR_TABLE)
        {
          stoffset = (i - SECTOR_TABLE_START_ADDR) + sizeof (SectorTable);
          return SUCCESS;
        }
      }
    }
    return FAIL;
  }

  /**
   * Clean all the blocks 
   */
  result_t CleanAllBlks()
  {
    volume_id_t ic = 0x0;
    bool stateTT = TRUE;
    storage_addr_t alladdr = FLASH_LOGGER_START_ADDR;

    if (call Flash.erase (SECTOR_TABLE_START_ADDR) == FAIL)
      trace (DBG_USR1,"FS ERROR: Could not cleanup ST Block 1 \r\n");
    if (call Flash.erase (SECTOR_TABLE_START_ADDR + FLASH_BLOCK_SIZE) == FAIL)
      trace (DBG_USR1,"FS ERROR: Could not cleanup ST Block 2 \r\n");

    for (ic = 0x0; ic < FLASH_NUM_BLOCKS; ic++)
    {
      if (stateTT)
      {
        TOSH_CLR_RED_LED_PIN();
        stateTT = FALSE;
      }
      else
      {
        TOSH_SET_RED_LED_PIN();
        stateTT = TRUE;
      }
      if (call Flash.erase (alladdr) == SUCCESS)
        sectorTable.block[ic].volumeId = FLASH_INVALID_VOLUME_ID;
      alladdr += FLASH_BLOCK_SIZE;
    }
    return SUCCESS;    
  }

  /**
   * Scan the sector table and cleanup the unallocated block which needs
   * to be erased.
   */
  result_t CleanUnAllocedBlks()
  {
    volume_id_t ic = 0x0;   
    for (ic = 0x0; ic < FLASH_NUM_BLOCKS; ic++)
    {
      if (sectorTable.block[ic].volumeId == FLASH_UNALLOCED_BLOCK)
      {
        storage_addr_t sadr = (ic * FLASH_BLOCK_SIZE) + FLASH_LOGGER_START_ADDR;
        trace (DBG_USR1, "FS Msg: Reclaim unallocated block, Addr %ld\r\n", sadr);
        if (call Flash.erase (sadr) == SUCCESS)
          sectorTable.block[ic].volumeId = FLASH_INVALID_VOLUME_ID;
      }
    }
    return SUCCESS;
  }

  /**
   * initSectorTable
   *
   * The function intializes the sector table block by restoring
   * the default sector table. A copy of the default sector table
   * is maintained in the ram.
   * 
   * @return SUCCESS | FAIL
   */
  result_t initSectorTable()
  {
    //volume_id_t i = 0x0;
    storage_addr_t stblk = 0x0;
    storage_addr_t STCurAddr = 0x0;
    storage_addr_t STEraseAddr = 0x0;
    storage_addr_t STEndAddr = (NUM_ST_BLOCKS * FLASH_BLOCK_SIZE) + SECTOR_TABLE_START_ADDR;
    storage_addr_t ReadFrom = 0xFFFFFFFF;
    uint16_t STValidity = VALID_SYS_TABLE_BLOCK;
    uint16_t STValRead = 0x0;

    for (stblk = SECTOR_TABLE_START_ADDR; stblk < STEndAddr; stblk += FLASH_BLOCK_SIZE)
    {
      if (IsSysBlockValid (stblk))
      //if (!(call Flash.isBlockErased (stblk)))
      {
        ReadFrom = stblk;
        break;
      }
      else
        trace (DBG_USR1, "ERASED BLOCK %ld\r\n",stblk);
    }

    if (ReadFrom == 0xFFFFFFFF)
    {
      trace (DBG_USR1, "FS WARNING: Cannot find sector table in both blocks \r\n");
      return ST_EMPTY_BLOCK;
    }

    if (ReadValidSectorTable(ReadFrom) == FAIL)
    {
      trace (DBG_USR1, "FS WARNING: No Valid Sector table.\r\n");
      return NO_VALID_SECTOR_TABLE;
    }

    switch (ReadFrom)
    {
      case SECTOR_TABLE_START_ADDR:
        STCurAddr = SECTOR_TABLE_START_ADDR + FLASH_BLOCK_SIZE;
        STEraseAddr = SECTOR_TABLE_START_ADDR;
        stoffset = FLASH_BLOCK_SIZE + VALIDITY_SIZE;
      break;
      case (SECTOR_TABLE_START_ADDR + FLASH_BLOCK_SIZE):
        STCurAddr = SECTOR_TABLE_START_ADDR;
        STEraseAddr = SECTOR_TABLE_START_ADDR + FLASH_BLOCK_SIZE;
        stoffset = VALIDITY_SIZE;
      break;
      default:
        return SUCCESS;
    }

    CleanUnAllocedBlks();

    if (!(call Flash.isBlockErased(STCurAddr)))
      call Flash.erase(STCurAddr);

    if (call Flash.write (STCurAddr, (uint8_t*)&STValidity, VALIDITY_SIZE) == FAIL)
      trace (DBG_USR1, "FS ERROR: Could not write Validity Word to ST.\r\n");

    if (call Flash.read(STCurAddr, (uint8_t*)&STValRead, VALIDITY_SIZE) == FAIL)
    {
      if (STValRead != STValidity)
        trace (DBG_USR1, " ** FS ERROR **  : Did not match with written val %d %d\r\n", STValidity, STValRead);
    }

    STCurAddr += VALIDITY_SIZE;
    if (call Flash.write (STCurAddr, (uint8_t*)&sectorTable, sizeof(SectorTable)) == SUCCESS)
    {
      stoffset += sizeof (SectorTable);
      call Flash.erase(STEraseAddr);
    }
    else
      trace (DBG_USR1, "** FS ERROR **: Could not write ST to the block.\r\n");

    return SUCCESS;
  }


  /**
   * ReadValidMetadata
   *
   * Read all the metadata from a given block and add it to the 'fmList'.
   * 
   */
  volume_id_t ReadValidMetadata (uint32_t addr)
  {
    storage_addr_t i = addr + VALIDITY_SIZE;
    uint16_t numfiles = 0;
    storage_addr_t MDendAddr = (addr + FLASH_BLOCK_SIZE);
    mdoffset = ((addr - FILE_META_DATA_START_ADDR) == 0) ? VALIDITY_SIZE : FLASH_BLOCK_SIZE;
    for (;numfiles < sectorTable.numfiles; i+=sizeof(FileMetadata))
    {
      if ((call HALPXA27X.read(i,&metaData, sizeof(FileMetadata))) == SUCCESS)
      {
        if (metaData.validity == VALID_META_DATA)
        {
          /*Allocate space for a new node in the file list*/
          tmpList = (FileMetaList*) malloc (sizeof(FileMetaList));
          if (tmpList == NULL)
          {
            trace (DBG_USR1, " FS FATAL ERROR : Cannot allocate memory for MetaData.\r\n");
            return FAIL;
          }
          else
            MALLOC_DBG(__FILE__,"ReadValidMetadata", tmpList, sizeof(FileMetaList));
          memcpy (&tmpList->metadata, &metaData, sizeof(FileMetadata));
          tmpList->metadata.CurrReadPtr = 0x0;
          tmpList->metadata.IsMounted = FALSE;
          add_node_to_tail (&(tmpList->metaList), &(fmList.metaList));
          ++numfiles;
        }
      }
      if ((i >= MDendAddr) || (metaData.validity == 0xFFFF))
        break;
      mdoffset += sizeof (FileMetadata);
    }

    return numfiles;
  }

  /**
   * cleanupMetaDataBlock
   *
   * For every file created or write operation performed there will be a
   * new entry in the meta data block which will reflect the current status
   * of the file. The old entry for a corresponding file will be invalidated.
   * This function searches for valid meta data entries and refills the block
   * with only valid entries after a block erase. Additionally it forms a
   * linked list of valid entries to be used by the program, It is an 
   * operation done during the startup phase.
   * 
   * @return SUCCESS | FAIL
   */
  result_t cleanupMetaDataBlock ()
  {
    //volume_id_t i = 0x0;
    volume_id_t numfiles = 0;
    storage_addr_t mdblk = 0x0;
    storage_addr_t MDCurAddr = 0x0;
    storage_addr_t MDEraseAddr = 0x0;
    storage_addr_t MDEndAddr = (NUM_ST_BLOCKS * FLASH_BLOCK_SIZE) + FILE_META_DATA_START_ADDR;
    storage_addr_t ReadFrom = 0xFFFFFFFF;
    uint16_t MDValidity = VALID_SYS_TABLE_BLOCK;

    INIT_LIST (&fmList.metaList);
    INIT_LIST (&uncommittedList.metaList);

    for (mdblk = FILE_META_DATA_START_ADDR; mdblk < MDEndAddr; mdblk += FLASH_BLOCK_SIZE)
    {
      if (IsSysBlockValid (mdblk))
      //if (!(call Flash.isBlockErased (mdblk)))
      {
        ReadFrom = mdblk;
        break;
      }
      else
        trace (DBG_USR1, "FS Msg: Skipping Meta-Data Block %ld\r\n", mdblk);
    }

    if (ReadFrom == 0xFFFFFFFF)
    {
      trace (DBG_USR1, "FS Msg: Both Meta-Data Blocks are empty\r\n");
      return MD_EMPTY_BLOCK;
    }

    if ((numfiles = ReadValidMetadata (ReadFrom)) != sectorTable.numfiles)
      trace (DBG_USR1, "**FS ERROR**: Corrupted MDCnt %ld, STCnt %ld.\r\n", numfiles, sectorTable.numfiles);

    if ((numfiles > 0))
    {
      list_ptr *tmp1, *tmp2; /*temporary list headers*/

      switch (ReadFrom)
      {
        case FILE_META_DATA_START_ADDR:
          MDCurAddr = FILE_META_DATA_START_ADDR + FLASH_BLOCK_SIZE;
          MDEraseAddr = FILE_META_DATA_START_ADDR;
          mdoffset = FLASH_BLOCK_SIZE + VALIDITY_SIZE;
        break;
        case (FILE_META_DATA_START_ADDR + FLASH_BLOCK_SIZE):
          MDCurAddr = FILE_META_DATA_START_ADDR;
          MDEraseAddr = FILE_META_DATA_START_ADDR + FLASH_BLOCK_SIZE;
          mdoffset = VALIDITY_SIZE;
        break;
        default:
        return SUCCESS;
      }

      if (!(call Flash.isBlockErased(MDCurAddr)))
        call Flash.erase(MDCurAddr);

      if (call Flash.write(MDCurAddr, (uint8_t*)&MDValidity, VALIDITY_SIZE) == FAIL)
        trace (DBG_USR1,"** FS ERROR **: Couldnt Write validity field for MD Table. Reboot might cause issues\r\n");
      MDCurAddr += VALIDITY_SIZE;

      for_each_node_in_list(tmp1, tmp2, &(fmList.metaList))
      {
        tmpList = get_list_entry(tmp1, FileMetaList, metaList);
        tmpList->metadata.CurrLoc = MDCurAddr;
        if (call Flash.write(MDCurAddr, (uint8_t*)&(tmpList->metadata), 
                                   sizeof(FileMetadata)) == SUCCESS)
        {
          MDCurAddr += sizeof(FileMetadata);
          mdoffset += sizeof (FileMetadata);
        }
      }
      call Flash.erase(MDEraseAddr);
    }

    return SUCCESS;
  }

  /**
   * The function checks if the current sector table is overflowing.
   */
  bool isSTTableOverflow ()
  {
    uint8_t currSTBlock = 0;
    int32_t currBlkChk = 0;
    storage_addr_t endAddr = 0x0;
    curAddr = SECTOR_TABLE_START_ADDR + stoffset;

    currBlkChk = (stoffset - FLASH_BLOCK_SIZE);
    //trace(DBG_USR1,"FS Msg: CURRENT ST_OFFSET = %ld. Differene = %ld\r\n",stoffset, currBlkChk);
    /* Figure out the current block that we are writing to and
     * set the end address accordingly
     */
    if (currBlkChk <= 0)
    {
      currSTBlock = 1;
      endAddr = SECTOR_TABLE_START_ADDR + FLASH_BLOCK_SIZE;
      //trace(DBG_USR1,"FS Msg: CURRENT BLOCK = 1, endAddr = %ld.\r\n",endAddr);
    }
    else
    {
      currSTBlock = 2;
      endAddr = SECTOR_TABLE_START_ADDR + (2 * FLASH_BLOCK_SIZE);
      //trace(DBG_USR1,"FS Msg: CURRENT BLOCK = 2, endAddr = %ld.\r\n",endAddr);
    }

    if ((curAddr + sizeof(SectorTable)) < endAddr)
      return FALSE;

    return TRUE;
  }

  /**
   * The function checks if the current meta-data table is overflowing.
   */
  bool isMDTableOverflow ()
  {
    int32_t mdblk = 0x0;
    uint32_t ofChk = 0x0;
    storage_addr_t MDEndAddr = 0x0;
    storage_addr_t MDCurAddr = FILE_META_DATA_START_ADDR + mdoffset;

    mdblk = (mdoffset - FLASH_BLOCK_SIZE);
    //trace(DBG_USR1,"FS Msg: CURRENT MD_OFFSET = %ld. Difference = %ld\r\n", mdoffset, mdblk);
    /* Figure out the current block that we are writing to and
     * set the end address accordingly
     */
    if (mdblk <= 0)
    {
      MDEndAddr = FILE_META_DATA_START_ADDR + FLASH_BLOCK_SIZE;
      //trace(DBG_USR1,"FS Msg: CURRENT MD BLOCK = 1, endAddr = %ld.\r\n", MDEndAddr);
    }
    else
    {
      MDEndAddr = FILE_META_DATA_START_ADDR + (2 * FLASH_BLOCK_SIZE);
      //trace(DBG_USR1,"FS Msg: CURRENT MD BLOCK = 2, endAddr = %ld.\r\n", MDEndAddr);
    }

    ofChk = (MDCurAddr + sizeof (FileMetadata));
    //trace(DBG_USR1,"FS Msg: CHK MD OFFSET + MDCURRENT = %ld.\r\n", ofChk);
    if (ofChk < MDEndAddr)
      return FALSE;

    return TRUE;
  }

  /**
   * HandleMDTableOverflow
   * 
   * Function which handles the Metadata table overflow. It places the existing MetaData
   * entries to the overflow block and invalidated the old block and places it for
   * garbage collection.
   */
  storage_addr_t HandleMDTableOverflow ()
  {
    int32_t mdblk = 0x0;
    storage_addr_t currAddr = 0x0;
    storage_addr_t curErsAddr = 0x0;
    uint8_t currMDBlock = 0x0;
    uint16_t ValidBlk1 = VALID_SYS_TABLE_BLOCK;
    uint16_t InValidBlk1 = INVALID_SYS_TABLE_BLOCK;

    list_ptr *tmp1, *tmp2; /*temporary list headers*/
    trace(DBG_USR1,"FS Msg: Restoring Metadata Table Block.\r\n");

    mdblk = (mdoffset - FLASH_BLOCK_SIZE);

    if (mdblk <= 0)
      currMDBlock = 1;
    else
      currMDBlock = 2;

    switch (currMDBlock)
    {
      case 1:
        currAddr = FILE_META_DATA_START_ADDR + FLASH_BLOCK_SIZE;
        curErsAddr = FILE_META_DATA_START_ADDR;
        atomic SystemTableErase [0] = MD_ST_ERASE;
        atomic mdoffset = FLASH_BLOCK_SIZE + VALIDITY_SIZE; /* Add bytes for validity */
      break;
      case 2:
        currAddr = FILE_META_DATA_START_ADDR;
        curErsAddr = FILE_META_DATA_START_ADDR + FLASH_BLOCK_SIZE;
        atomic SystemTableErase [1] = MD_ST_ERASE;
        atomic mdoffset = VALIDITY_SIZE; /* Add bytes for the validity */
      break;
      default:
        trace (DBG_USR1, "FATAL ERROR: Unknown Current MD Block, Might currupt FS\r\n");
        return FAIL;
      break;
    }

    if (!(call Flash.isBlockErased (currAddr)))
    {
      trace (DBG_USR1, "FS WARNING: Block not ready when trying to switch MD block\r\n");
      if ((call Flash.erase (currAddr)) == FAIL)
      {
        trace (DBG_USR1, "FS ERROR: Cannot Erase Block to contiue MD storage\r\n");
        return FAIL;
      }
    }

    if (call Flash.write(currAddr, (uint8_t*)&ValidBlk1, VALIDITY_SIZE) == FAIL)
      trace (DBG_USR1,"** FS ERROR **: Couldnt Write validity field for MD Table. Reboot might cause issues\r\n");

    currAddr += VALIDITY_SIZE;

    for_each_node_in_list(tmp1, tmp2, &(fmList.metaList))
    {
      tmpList = get_list_entry(tmp1, FileMetaList, metaList);
      tmpList->metadata.CurrLoc = currAddr;
      if (call Flash.write(currAddr, (uint8_t*)&(tmpList->metadata), 
                                 sizeof(FileMetadata)) == SUCCESS)
      {
        currAddr += sizeof(FileMetadata);
        mdoffset += sizeof(FileMetadata);
      }
    }

    if (call Flash.write(curErsAddr, (uint8_t*)&InValidBlk1, VALIDITY_SIZE) == FAIL)
      trace (DBG_USR1,"** FS ERROR **: Couldnt invalidate old MD Table. Reboot might cause issues\r\n");

    trace(DBG_USR1,"FS Msg: Cur Address of MD Table after restoring is %ld\r\n",currAddr);

    if (!(isEraseTimer))
    {
      call EraseTimer.start (TIMER_REPEAT, 5000);
      isEraseTimer = TRUE;
    }

    return currAddr;
  }

 /**
  * FileStorage.init
  *
  * This function initalizes the logger file system, by intializing
  * the global variables, the metadata linked list, the sector
  * table block and meta data block.
  *
  * @return SUCCESS | FAIL
  */
  command result_t FormatStorage.init()
  {
    //uint32_t peekdata = 0x0;
    result_t res = SUCCESS;
    uint8_t syst = 0x0;
    unCommittedFiles = 0;
    NextVolumeId = 0x2;
    isEraseTimer = FALSE;
    atomic NumUnAllocatedBlocks = 0x0;
    INIT_LIST (&deleteList.metaList);
    call FSQueue.queueInit (); /*initialize the file system Queue*/

    for (syst = 0x0; syst < NUM_SYS_BLOCKS; syst++)
      atomic SystemTableErase [syst] = MD_ST_NO_ERASE;

    if (state == S_COMMIT)
    {
      trace (DBG_USR1,"** FS ERROR **: Cannot Initialize flash logger in S_COMMIT state.\r\n");       
      return FAIL;
    }
    state = S_INIT;
    /* Check if there is sector table, if not then create a
     * sector table and load it in to the flash.
     */
    //peekdata = (*((uint32_t *)SECTOR_TABLE_START_ADDR));
    res = initSectorTable ();

    switch (res)
    {
      case ST_EMPTY_BLOCK:
      case NO_VALID_SECTOR_TABLE:
      {
        volume_id_t vid = 0x0;
        uint16_t strAddr = VALID_SYS_TABLE_BLOCK;
        CleanAllBlks();
        sectorTable.validity = VALID_SECTOR_TABLE;
        sectorTable.numfiles = 0x0;
        for (vid = 0; vid < FLASH_NUM_BLOCKS; vid++)
          sectorTable.block[vid].volumeId = FLASH_INVALID_BLOCK;

        if (call Flash.write(SECTOR_TABLE_START_ADDR, (uint8_t*)&strAddr, VALIDITY_SIZE) == FAIL)
          trace (DBG_USR1,"** FS ERROR **: Couldnt Write validity field for ST Table.\r\n");       

        if (call HALPXA27X.pageProgram(SECTOR_TABLE_START_ADDR + VALIDITY_SIZE, &sectorTable,
                                   sizeof(SectorTable)) == SUCCESS)
          trace (DBG_USR1,"FS Msg: Sector Table replaced \r\n");
        stoffset = sizeof (SectorTable) + VALIDITY_SIZE;
      }
      break;
    }

    res = cleanupMetaDataBlock ();
    switch (res)
    {
      case MD_EMPTY_BLOCK:
      {
        uint16_t strAddr = VALID_SYS_TABLE_BLOCK;
        if (sectorTable.numfiles > 0)
          trace (DBG_USR1, "**FS ERROR**: Number of files in MD doesnt match with ST.\r\n");
        call Flash.erase (FILE_META_DATA_START_ADDR);
        call Flash.erase (FILE_META_DATA_START_ADDR + FLASH_BLOCK_SIZE);
        if (call Flash.write(FILE_META_DATA_START_ADDR, (uint8_t*)&strAddr, VALIDITY_SIZE) == FAIL)
          trace (DBG_USR1,"** FS ERROR **: Couldnt Write validity field for MD Table. Reboot might cause issues\r\n");
        mdoffset = VALIDITY_SIZE;
      }
      break;
      case SUCCESS:
      case FAIL:
      break;
      default:
        trace (DBG_USR1, "**FS ERROR**: Unknown return value from cleanupMetaDataBlock.\r\n");
      break;
    }
    PopulateSectorInfo ();
    return res;
  }

  /**
   * FileStorageUtil.updateMountStatus
   *
   * The mount status of a file is updated when the file is opened
   * or closed for read/write. TRUE means that is file is currently
   * mounted, and FALSE means that the file is not mounted.
   *
   * @param id Volume Id of the file.
   * @param status Boolean value to update the current mount status.
   * 
   * @return SUCCESS | FAIL
   */
  command result_t FileStorageUtil.updateMountStatus (volume_id_t id, volume_id_t bid, bool status)
  {
    list_ptr *pos, *tmp;
    volume_id_t vid = id;
    uint32_t saddr = 0x0;
    uint32_t sec = 0x0;

    if (state == S_UN_INIT)
      return FAIL;

    if (!is_list_empty(&(fmList.metaList)))
    {
      for_each_node_in_list(pos, tmp, &(fmList.metaList))
      {
        tmpList = get_list_entry(pos, FileMetaList, metaList);
        if (tmpList->metadata.volumeId == vid)
        {
          tmpList->metadata.IsMounted = status;

          /* Update the status of the sector that file belongs to */
          saddr = (bid * FLASH_BLOCK_SIZE) + FLASH_LOGGER_START_ADDR;
          sec = saddr / FLASH_PARTITION_SIZE;
          if (status)
          {
            atomic ++OpenFileSectors [sec]; /* Mounting a File*/
            //trace (DBG_USR1, "FS Msg: Mounted a file in Sector %ld, Block %ld\r\n",sec,bid);
          }
          else
          {
            atomic --OpenFileSectors [sec]; /* UnMounting a File*/
            //trace (DBG_USR1, "FS Msg: UNMounted a file in Sector %ld, Block %ld\r\n",sec,bid);
          }
          return SUCCESS;
        }
      }
    }

    if (!is_list_empty(&(deleteList.metaList)))
    {
      for_each_node_in_list(pos, tmp, &(deleteList.metaList))
      {
        tmpList = get_list_entry(pos, FileMetaList, metaList);
        if (tmpList->metadata.volumeId == vid)
        {
          if (!(status))
          {
            tmpList->metadata.IsMounted = status;
            /* Update the status of the sector that file belongs to */
            saddr = (bid * FLASH_BLOCK_SIZE) + FLASH_LOGGER_START_ADDR;
            sec = saddr / FLASH_PARTITION_SIZE;
            atomic --OpenFileSectors [sec]; /* UnMounting a File*/
            return SUCCESS;
          }
          else
          {
            trace (DBG_USR1, "FS WARNING: Cannot Mount a Deleted file\r\n");
            return FAIL;
          }
        }
      }
    }

    return FAIL;
  }

  /**
   * FileStorage.getSectorTable
   *
   * Sector table is the back bone of the flash logger file system,
   * it keeps track of the correlation between the volumeId and
   * the block number.
   * The sector table is populated during the init process and is
   * used by StorageManger module for different file operations. This
   * function serves as an access routine to get access to the
   * sector table.
   *
   * @return sectorTable The current valid sector table after file system init.
   */
  command SectorTable* FormatStorage.getSectorTable()
  {
    if (state == S_UN_INIT)
      return NULL;
    return &sectorTable;
  } 

  /**
   * FileStorage.getFileName
   *
   * The function returns the file name of the requested index in
   * the list of valid files. The index must range from 0 - CurrNumFiles.
   * This function is usefull for listing the names of the currently
   * valid files.
   *
   * @param indx Index in the file list, range from 0 - NumFiles.
   *
   * @return SUCCESS | FAIL
   */
  command char* FormatStorage.getFileName (uint16_t indx)
  {
    list_ptr *pos;
    volume_id_t cnt = 0x0;

    if (state == S_UN_INIT)
      return FAIL;

    if (indx > sectorTable.numfiles)
      return NULL;

    if (!is_list_empty(&(fmList.metaList)))
    {
      move_list_ptr(pos, &(fmList.metaList), indx, cnt);
      tmpList = get_list_entry(pos, FileMetaList, metaList);
      return tmpList->metadata.fileName;
    }
    return NULL;
  }

  /**
   * FileStorage.isFileMounted
   *
   * Check if a file is open or closed using its file name.
   * The functions scans the list of valid files and returns
   * the mount status on a name match. If the file name
   * does not exist in the list then it returns TRUE to prevent
   * mounting of a wrong file.
   *
   * FIXME Needs a new error code for unknown file.
   *
   * @param filename Name of the file for which the mount status is required.
   *
   * @return status TRUE | FALSE
   */
  command bool FormatStorage.isFileMounted (const char* filename)
  {
    list_ptr *pos, *tmp;

    if (state == S_UN_INIT)
      return TRUE;

    if (!is_list_empty(&(fmList.metaList)))
    {
      for_each_node_in_list(pos, tmp, &(fmList.metaList))
      {
        tmpList = get_list_entry(pos, FileMetaList, metaList);
        if (strcmp (tmpList->metadata.fileName, filename) == 0)
          return tmpList->metadata.IsMounted;
      }
    }

    if (!is_list_empty(&(deleteList.metaList)))
    {
      for_each_node_in_list(pos, tmp, &(deleteList.metaList))
      {
        tmpList = get_list_entry(pos, FileMetaList, metaList);
        if (strcmp (tmpList->metadata.fileName, filename) == 0)
        {
          trace (DBG_USR1," ** FS MSG **: Checking Mount Status of File %s in DELETE LIST.\r\n",filename);
          return tmpList->metadata.IsMounted;
        }
      }
    }

    /* This is an interesting failure case, its hard to notify the user
     * because of the return type. For now the function return TRUE
     * for a failure case, FIXME.
     */
    trace (DBG_USR1,"FS WARNING: %s is not in the file system. Create might be Queued\r\n",filename);
    return FALSE;
  }

  /**
   * isAnyFileMounted
   *
   * The function scans the list of files and returns TRUE if any of the files are mounted.
   */
  bool isAnyFileMounted ()
  {
    list_ptr *pos, *tmp;
    FileMetaList *flst, *tmplst;
    atomic flst = &fmList;

    if (!is_list_empty(&(flst->metaList)))
    {
      for_each_node_in_list(pos, tmp, &(flst->metaList))
      {
        tmplst = get_list_entry(pos, FileMetaList, metaList);
        if (tmplst->metadata.IsMounted)
          return TRUE;
      }
    }

    return FALSE;
  }

  result_t HandleDeleteRequest (const uint8_t* filename)
  {
    result_t res = FAIL;
    volume_id_t i = 0;
    volume_id_t tmpVolId = 0;
    volume_id_t tmpBlkId = FLASH_INVALID_BLOCK;
    bool FoundFile = FALSE;

    list_ptr *pos, *tmp;
    storage_addr_t oldLoc = 0x0;
    storage_addr_t ebAddr = 0x0;

    if (state == S_UN_INIT)
      return FAIL;

    tmpVolId = call FormatStorage.getVolumeId(filename);
    if (tmpVolId == FLASH_INVALID_VOLUME_ID)
    {
      trace (DBG_USR1,"FS ERROR: Trying to delete file %s with Invalid ID %d\r\n",filename,tmpVolId);
      return FAIL;
    }

    /*Unmount the file*/
    signal FileStorageUtil.filedeleted (tmpVolId, filename);

    for (i = 0; i < FLASH_NUM_BLOCKS; i++)
    {
      if (sectorTable.block[i].volumeId == tmpVolId)
      {
        tmpBlkId = i;
        sectorTable.block[i].volumeId = FLASH_UNALLOCED_BLOCK;
        ebAddr = (i * FLASH_BLOCK_SIZE) + FLASH_LOGGER_START_ADDR;
      }
    }

    if (tmpBlkId == FLASH_INVALID_BLOCK)
    {
      trace (DBG_USR1,"** FS Warning **: Couldnt find a valid block for deleted file %s \r\n",filename);
    }

    atomic -- sectorTable.numfiles;

    if (commitSectorTable () == FAIL)
    {
      trace (DBG_USR1,"FS ERROR: Couldnt commit sector table while deleting file \r\n");
      return FAIL;
    }

    /* For Debug Purposes*/
    atomic ++NumUnAllocatedBlocks;

    if (!is_list_empty(&(deleteList.metaList)))
    {
      for_each_node_in_list(pos, tmp, &(deleteList.metaList))
      {
        tmpList = get_list_entry(pos, FileMetaList, metaList);
        if (tmpList->metadata.volumeId == tmpVolId)
        {
          FoundFile = TRUE;
          if (tmpList->metadata.IsMounted)
            call FileStorageUtil.updateMountStatus (tmpVolId, tmpBlkId, FALSE);

          oldLoc = tmpList->metadata.CurrLoc;
          res = call HALPXA27X.wordProgram(oldLoc, INVALID_SECTOR_TABLE);
          FREE_DBG(__FILE__,"DEL_LIST",tmpList);
          delete_node(pos);
          free(tmpList);
        }
      }
    }

    if (!(FoundFile))
    {
      for_each_node_in_list(pos, tmp, &(fmList.metaList))
      {
        tmpList = get_list_entry(pos, FileMetaList, metaList);
        if (tmpList->metadata.volumeId == tmpVolId)
        {
          FoundFile = TRUE;
          oldLoc = tmpList->metadata.CurrLoc;
          res = call HALPXA27X.wordProgram(oldLoc, INVALID_SECTOR_TABLE);
          /** FIXME **/
          delete_node(pos);
          //trace (DBG_USR1,"FS Msg: Invalidated metadata for %s @ %ld \r\n", filename, oldLoc);
          FREE_DBG(__FILE__,"FS_LIST",tmpList);
          free(tmpList);
        }
      }
    }

    if (!(FoundFile))
    {
      trace (DBG_USR1,"** FS ERROR **: Cannot find file %s in the list, could be accumulating memory",filename);
    }

    //res = call HALPXA27X.bulkErase (ebAddr);

    if (!(isEraseTimer))
    {
      call EraseTimer.start (TIMER_REPEAT, 5000);
      isEraseTimer = TRUE;
    }

    return res;
  }


  /**
   * FileStorage.fdelete
   *
   * Delete a file by passing its file name as the first parameter. The
   * function clears the entries in the sector table, removes the
   * meta data from the linked list and invalidates the meta data entry
   * for the file. The file blocks are not erased because every create
   * will clean up the blocks during allocation.
   *
   * @param filename Name of the file to be deleted.
   * @return SUCCESS | FAIL
   */
  command result_t FormatStorage.fdelete (const uint8_t* filename)
  {
    result_t res = FAIL;

    if (call HALPXA27X.isErasing())
    {
      list_ptr *pos, *tmp;
      FileMetaList *tmpl;
      volume_t tmpVolId = FLASH_INVALID_VOLUME_ID; 
      //trace (DBG_USR1,"FS MSG: FileSystem if BUSY erasing, DELETE operation Queued\r\n");
      tmpVolId = call FormatStorage.getVolumeId(filename);
      if (tmpVolId == FLASH_INVALID_VOLUME_ID)
        return FAIL;
      for_each_node_in_list(pos, tmp, &(fmList.metaList))
      {
        tmpl = get_list_entry(pos, FileMetaList, metaList);
        if (tmpl->metadata.volumeId == tmpVolId)
        {
          delete_node(pos);
          add_node_to_tail (pos, &(deleteList.metaList));
        }
      }

      res = call FSQueue.queueDelete (filename);
      return res;
    }

    res = HandleDeleteRequest (filename);
    return res;
  }

  result_t DBG_CompareFlashST ()
  {
    storage_addr_t ebAddr = 0x0;
    storage_addr_t localSTOffset = 0x0;
    SectorTable localST;

    atomic localSTOffset = stoffset;
    ebAddr = SECTOR_TABLE_START_ADDR + localSTOffset - sizeof (SectorTable);
    
    call Flash.read (ebAddr, (uint8_t*)&localST, sizeof(SectorTable));
    if (memcmp (&localST, &sectorTable, sizeof(SectorTable)) != 0)
    {
      trace (DBG_USR1,"**** FS ERROR ****: The Sector table in flash doesnt match with RAM\r\n");
      trace (DBG_USR1,"RAM %x %d \r\n",sectorTable.validity,sectorTable.numfiles);
      trace (DBG_USR1,"READ %x %d \r\n",localST.validity,localST.numfiles);
    }
    else
      trace (DBG_USR1,"FS Msg: The Sector table match with RAM\r\n");
    return SUCCESS;
  }

  event result_t EraseTimer.fired() 
  {
    volume_id_t er = 0x0;
    volume_id_t er1 = 0x0;
    uint32_t ebAddr = 0x0;
    volume_id_t numFree = 0x0;
    volume_id_t numDirty = 0x0;
    volume_id_t numAlloc = 0x0;
    volume_id_t lastDirty = 0x0;
    result_t res = FAIL;
    volume_id_t first_er = FLASH_NUM_BLOCKS;
    bool SYSTABLE = FALSE;

    for (er1 = 0; er1 < FLASH_NUM_BLOCKS; er1++) 
    {
      if (sectorTable.block[er1].volumeId == FLASH_UNALLOCED_BLOCK)
        ++ numDirty;
      else if (sectorTable.block[er1].volumeId == FLASH_INVALID_BLOCK)
        ++ numFree;
      else
        ++ numAlloc;
    }

    trace (DBG_USR1, "FS Msg: Erase Timer Fired. UNALLOCATED = %ld , FREE = %ld , ALLOCATED = %ld\r\n",numDirty, numFree, numAlloc);

    if (call HALPXA27X.isErasing())
    {
      trace (DBG_USR1, "FS Msg: Busy Erasing a different block\r\n");
      return SUCCESS;
    }

    for (er = 0; er < NUM_SYS_BLOCKS; er++) 
    {
      if (SystemTableErase [er] == MD_ST_ERASE)
      {
        first_er = er;
        SYSTABLE = TRUE;
      }
    }

    if (!(SYSTABLE))
    {
      uint32_t secE = 0x0;
      numFree = 0x0;
      numDirty = 0x0;
      numAlloc = 0x0;

      for (er = 0; er < FLASH_NUM_BLOCKS; er++) 
      {
        if (sectorTable.block[er].volumeId == FLASH_UNALLOCED_BLOCK) 
        {
          lastDirty = er;
          ++ numDirty;
          ebAddr = (er * FLASH_BLOCK_SIZE) + FLASH_LOGGER_START_ADDR;
          secE = ebAddr / FLASH_PARTITION_SIZE;
          if (OpenFileSectors [secE] <= 0)
          {
            first_er = er;
            er = FLASH_NUM_BLOCKS;
          }
          else
            trace (DBG_USR1,"** FS MSG **: Skipping Block %d, Sector %ld, status %ld\r\n", er, secE, OpenFileSectors [secE]);
        }
        else if (sectorTable.block[er].volumeId == FLASH_INVALID_BLOCK)
          ++ numFree;
      }

      // No blocks to erase
      if (first_er == FLASH_NUM_BLOCKS)
      {
        /**
         * FIXME Lama's logic for a forced Erase
         */
        if ((numFree < FREE_BLOCK_THRESHOLD) && (numDirty > numFree)) 
        {
          trace (DBG_USR1, "** FS Msg **: Forcing Garbage collecting. NumFree = %d and NumDirty = %d\r\n", numFree, numDirty);
          first_er = lastDirty;
        }
        else
        {
          return SUCCESS;
        }
      }

      ebAddr = (first_er * FLASH_BLOCK_SIZE) + FLASH_LOGGER_START_ADDR;
    }
    else
    {
      /*CAUTION: the assumption is that the MD and ST tables are continuous*/
      ebAddr = (first_er * FLASH_BLOCK_SIZE) + FILE_META_DATA_START_ADDR;
      trace (DBG_USR1, "FS Msg: Garbage collecting system table. Address = %ld\r\n", ebAddr);
    }

    //DBG_CompareFlashST ();
    res = call HALPXA27X.bulkErase (ebAddr);
    if (res == FAIL)
    {
      trace (DBG_USR1, "FS ERROR: Erase Failed %ld\r\n",ebAddr);
      if (!(isEraseTimer))
      {
        isEraseTimer = TRUE;
        call EraseTimer.start(TIMER_REPEAT, 5000);
      }
      return SUCCESS;
    }
    else
    {
      if (SYSTABLE)
        atomic SystemTableErase [first_er] = MD_ST_NO_ERASE;
    }
    return SUCCESS;
  }

  /**
   * isExisting
   *
   * The function is more for utility purposes at the higher level since
   * the VolumeId is hidden from the user level. The function returns
   * the volume id of a file given the file name. 
   *
   * @param filename Name of the file.
   *
   * @return SUCCESS | FAIL
   */
  volume_id_t isExisting(const uint8_t* filename)
  {
    list_ptr *pos, *tmp;

    if (state == S_UN_INIT)
    {
      trace (DBG_USR1,"FS ERROR: FS not initialize \r\n");
      return FAIL;
    }
 
    if (!is_list_empty(&(fmList.metaList)))
    {
      for_each_node_in_list(pos, tmp, &(fmList.metaList))
      {
        tmpList = get_list_entry(pos, FileMetaList, metaList);
        if (strcmp (tmpList->metadata.fileName, filename) == 0)
          return tmpList->metadata.volumeId;
      }
    }
    return FLASH_INVALID_VOLUME_ID;
  }

  /**
   * FormatStorage.getVolumeId
   *
   * The function is more for utility purposes at the higher level since
   * the VolumeId is hidden from the user level. The function returns
   * the volume id of a file given the file name.
   *
   * @param filename Name of the file.
   *
   * @return SUCCESS | FAIL
   */
  command volume_id_t FormatStorage.getVolumeId(const uint8_t* filename)
  {
    list_ptr *pos, *tmp;
    list_ptr *pos1, *tmp1;

    if (state == S_UN_INIT)
      return FAIL;

    if (!is_list_empty(&(deleteList.metaList)))
    {
      for_each_node_in_list(pos1, tmp1, &(deleteList.metaList))
      {
        tmpList = get_list_entry(pos1, FileMetaList, metaList);
        if (strcmp (tmpList->metadata.fileName, filename) == 0)
          return tmpList->metadata.volumeId;
      }
    }
    
    if (!is_list_empty(&(fmList.metaList)))
    {
      for_each_node_in_list(pos, tmp, &(fmList.metaList))
      {
        tmpList = get_list_entry(pos, FileMetaList, metaList);
        if (strcmp (tmpList->metadata.fileName, filename) == 0)
          return tmpList->metadata.volumeId;
      }
    }
    return FLASH_INVALID_VOLUME_ID;
  }

  /**
   * allocate
   *
   * Allocate space for a file and clean up the newly allocated blocks. The
   * sector table is updated with the latest volume id in the corresponding
   * block if successfully allocated. The <I>addr</I> is vestigial for create
   * function and is useful only for allocate fixed. The space allocated is
   * in multiples of flash block size. The flash blocks allocated to a file
   * are always contiguous.
   *
   * @param id VolumeId for the new file.
   * @param addr Usually 0x0 for create and is decided by the existing sector table.
   * @parma size File size in multiples of block size.
   *
   * @return SUCCESS | FAIL
   */
  result_t allocate (volume_id_t id, storage_addr_t addr, storage_addr_t size)
  {
    volume_id_t freeSectors;
    uint8_t base;
    volume_id_t i;
    volume_id_t avaSector;

    //if (state != S_INIT)
    //  return FAIL;

    if (addr % FLASH_BLOCK_SIZE)
      return FAIL;

    // size must be a multiple of block size
    if (size % FLASH_BLOCK_SIZE)
      return FAIL;

    addr /= FLASH_BLOCK_SIZE;
    size /= FLASH_BLOCK_SIZE;

    // check if id is already taken
    for (i = 0; i < FLASH_NUM_BLOCKS; i++) 
    {
      if (sectorTable.block[i].volumeId == id)
        return FAIL;
    }

    avaSector = GetFreeSector ();
    if (avaSector > 1)
    {
      volume_id_t secStart;
      secStart = ((avaSector * FLASH_PARTITION_SIZE) - FLASH_LOGGER_START_ADDR) / FLASH_BLOCK_SIZE;
      trace (DBG_USR1, "Allocating in Sector starting with Block %d \r\n", secStart);
      addr = secStart;
    }
    
    // count number of free blocks
    for (i = addr, freeSectors = 0, base = addr; 
             i < FLASH_NUM_BLOCKS && freeSectors < size; i++) 
    {
      if (sectorTable.block[i].volumeId == FLASH_INVALID_VOLUME_ID) 
      {
        freeSectors++;
      }
      else
      {
        freeSectors = 0;
        base = i + 1;
      }
    }

    // check if there are enough free blocks
    if (freeSectors < size)
      return FAIL;

    atomic ++ FreePartition [avaSector];
    // allocate space
    for (i = base; i < FLASH_NUM_BLOCKS && size > 0; i++, size--)
    {
#ifndef FAKE_FILE_SYSTEM
        trace (DBG_USR1, "Allocating Block %d \r\n", i);
        sectorTable.block[i].volumeId = id;
#else
      sectorTable.block[i].volumeId = id;
#endif

    }
    return SUCCESS;
  }

  /**
   * FormatStorage.allocate
   *
   * This is external interface function exposed to the user for
   * allocating space for a new file.
   * The funciton uses the allocate routine to check for space
   * availability and makes sure that the file name is unique.
   * If the allocation is successful then the meta data for the
   * newly created file is added to the uncommited list, waiting
   * for the user to call commit.
   *
   * @param id VolumeId for the new file.
   * @parma size File size in multiples of block size.
   * @param name Name of the new file.
   *
   * @return SUCCESS | FAIL
   */
  command result_t FormatStorage.allocate(volume_id_t id, 
                                          storage_addr_t size, 
                                          const uint8_t* name)
  {
    result_t res = FAIL;
    volume_id_t i;
    i = isExisting(name);
    if (i != FLASH_INVALID_VOLUME_ID)
    {
      trace (DBG_USR1,"FS ERROR: File name %s already exists in the FS.\r\n", name);
      return FAIL;
    }

    res = allocate(id, 0, size);
    if (res == SUCCESS)
    {
      memset (metaData.fileName, 0, FILE_NAME_SIZE);
      metaData.validity = VALID_META_DATA;
      metaData.volumeId = id;
      /*FIXME check that strlen < FILE_NAME_SIZE*/
      memcpy (metaData.fileName, name, strlen(name));
      metaData.NumBlocks = (uint8_t) (size/FLASH_BLOCK_SIZE);
      metaData.CurrWritePtr = 0x0;
      metaData.CurrReadPtr = 0x0;
      metaData.IsMounted = FALSE;
      tmpList = (FileMetaList*) malloc (sizeof(FileMetaList));
      if (tmpList == NULL)
      {
        trace (DBG_USR1, " FS FATAL ERROR : Cannot allocate memory for MetaData.\r\n");
        return FAIL;
      } 
      else
        MALLOC_DBG(__FILE__,"FormatStorage.allocate", tmpList, sizeof(FileMetaList));

      memcpy (&tmpList->metadata, &metaData, sizeof(FileMetadata));
      add_node (&(tmpList->metaList), &(uncommittedList.metaList));
      ++ unCommittedFiles;
    }
    else
      trace (DBG_USR1,"FS ERROR: Allocate failed for file %s.\r\n", name);
     
    return res;
  }

  /**
   * FormatStorage.allocateFixed
   *
   * This is a legacy function, it will work but doesnt make
   * the job any easier for the user.
   * FIXME Remove this function if the app doesnt use it.
   *
   * @param id VolumeId for the new file.
       * @parma addr Starting physical address for the file.
   * @parma size File size in multiples of block size.
   *
   * @return SUCCESS | FAIL
   */
  command result_t FormatStorage.allocateFixed(volume_id_t id, 
                           storage_addr_t addr, storage_addr_t size)
  {
    return allocate(id, addr, size);
  }

  /**
   * FormatStorage.updateWritePtr
   *
   * This function will update the write pointer in the meta data
   * entry of a particular file. For every write operation the 
   * write pointer is added with the corresponding length and a
   * new entry is added to the meta data block after invalidating
   * the old one for the file. The write pointer is the virtual
   * address of the current write location in the file.
   *
   * @param id VolumeId for the new file.
   * @parma vaddr Current virtual address for writing.
   * @param vlen Length of data written in to the file.
   *
   * @return SUCCESS | FAIL
   */
  command result_t FormatStorage.updateWritePtr(volume_id_t id, 
                                                storage_addr_t vaddr,
                                                storage_addr_t vlen)
  {
    result_t res = FAIL;
    list_ptr *pos, *tmp;
    storage_addr_t oldLoc;
    storage_addr_t oldWPtr;
    bool EraseRequired = FALSE;
    storage_addr_t mCurAddr = mdoffset + FILE_META_DATA_START_ADDR;
    //storage_addr_t mendAddr = (FILE_META_DATA_START_ADDR + FLASH_BLOCK_SIZE);

    if ((isMDTableOverflow ()))
    {
      if ((mCurAddr = HandleMDTableOverflow()) == FAIL)
      {
        trace(DBG_USR1,"FS ERROR: HandleOverflow failed at line %d.\r\n", __LINE__);
        return FAIL;
      }
      EraseRequired = TRUE;
    }

    if (!is_list_empty(&(fmList.metaList)))
    {
      for_each_node_in_list(pos, tmp, &(fmList.metaList))
      {
        tmpList = get_list_entry(pos, FileMetaList, metaList);
        if (tmpList->metadata.volumeId == id)
        {
          oldLoc = tmpList->metadata.CurrLoc;
          oldWPtr = tmpList->metadata.CurrWritePtr;
          if (((vaddr == 0) && (vlen==0)) ||(tmpList->metadata.CurrWritePtr <= vaddr))
          {
            tmpList->metadata.CurrWritePtr = vaddr + vlen;
            if ((tmpList->metadata.NumBlocks * FLASH_BLOCK_SIZE) >= (vaddr + vlen))
            {
      	      tmpList->metadata.CurrLoc = FILE_META_DATA_START_ADDR + mdoffset;
              res = call HALPXA27X.pageProgram(tmpList->metadata.CurrLoc, 
                                             &(tmpList->metadata), 
                                             sizeof(FileMetadata));
              if (res == SUCCESS)
              {
                res = call HALPXA27X.wordProgram(oldLoc, INVALID_SECTOR_TABLE);
                mdoffset += sizeof(FileMetadata);
                //trace (DBG_USR1,"Updated Write Ptr to %ld. Curr MDOffset %ld, Invalidated %ld \r\n", tmpList->metadata.CurrWritePtr, mdoffset, oldLoc);
              }
              else
              {
                trace (DBG_USR1,"FS Warning: Couldnt update Write Ptr, rolling back the location\r\n");
                tmpList->metadata.CurrLoc = oldLoc;
                tmpList->metadata.CurrWritePtr = oldWPtr;
              }
            }
            else
            {
	      trace (DBG_USR1,"** FS ERROR **: Trying to write past the file size \r\n");
              tmpList->metadata.CurrLoc = oldLoc;
              tmpList->metadata.CurrWritePtr = oldWPtr;
              res = FAIL;
            }
          }
          else
          {
	    trace (DBG_USR1,"** FS ERROR **: CurrWritePtr < vaddr, possible overwirte\r\n");
            res = FAIL;
          }
        }
      }
    }

    return res;
  }

  /**
   * FormatStorage.updateReadPtr
   *
   * The function updates the read pointer of a file in its meta
   * data entry. The read pointer is maintained only in the linked
   * list entry and is not update to the meta data block, it will
   * be reset to 0x0 during reset. The function returns fail if
   * the volume id is invalid.
   *
   * @param id VolumeId for the file.
   * @parma vaddr Current virtual address for reading.
   * @param vlen Length of data read from the file.
   *
   * @return SUCCESS | FAIL
   */
  command result_t FormatStorage.updateReadPtr (volume_id_t id,
                                                storage_addr_t vaddr,
                                                storage_addr_t vlen)
  {
    result_t res = FAIL;
    list_ptr *pos, *tmp;
    if (!is_list_empty(&(fmList.metaList)))
    {
      for_each_node_in_list(pos, tmp, &(fmList.metaList))
      {
        tmpList = get_list_entry(pos, FileMetaList, metaList);
        if (tmpList->metadata.volumeId == id)
        {
          if ((tmpList->metadata.NumBlocks * FLASH_BLOCK_SIZE) >= (vaddr + vlen))
          {
            tmpList->metadata.CurrReadPtr = vaddr + vlen;
            res = SUCCESS;
          }
          else
            res = FAIL;
        }
      }
    }

    return res;
  }

  /**
   * FileStorage.getWritePtr
   *
   * The function returns the current logical address of the write pointer
   * for a given file name. The logical address could range from 0 - Allocated 
   * Size of the file. The logical position also represents the number of
   * bytes written to the file. If the file name does not exist in the
   * valid file list then an INVALID_PTR will be returned.
   *
   * @param filename Name of the file for which the write pointer is requested.
   *
   * @return Current write pointer or INVALID_PTR
   */
  command storage_addr_t FormatStorage.getWritePtr (const uint8_t* filename)
  {
    list_ptr *pos, *tmp; /*temporary list headers*/
    
    if (state == S_UN_INIT)
      return FAIL;

    if (!is_list_empty(&(fmList.metaList)))
    {
      for_each_node_in_list(pos, tmp, &(fmList.metaList))
      {
        tmpList = get_list_entry(pos, FileMetaList, metaList);
        if (strcmp(tmpList->metadata.fileName, filename) == 0)
          return tmpList->metadata.CurrWritePtr;
      }
    }
    return INVALID_PTR;
  }
  
  /**
   * FileStorage.getWritePtr1
   *
   * The function returns the current logical address of the write pointer
   * for a given volume id. The logical address could range from 0 - Allocated 
   * Size of the file. The logical position also represents the number of
   * bytes written to the file. If the requested volme id does not exist in the
   * valid file list then an INVALID_PTR will be returned.
   *
   * @param filename Name of the file for which the write pointer is requested.
   *
   * @return Current write pointer or INVALID_PTR
   */
  command storage_addr_t FormatStorage.getWritePtr1 (volume_id_t id)
  {
    list_ptr *pos, *tmp;

    if (state == S_UN_INIT)
      return FAIL;

    if (!is_list_empty(&(fmList.metaList)))
    {
      for_each_node_in_list(pos, tmp, &(fmList.metaList))
      {
        tmpList = get_list_entry(pos, FileMetaList, metaList);
        if (tmpList->metadata.volumeId == id)
          return tmpList->metadata.CurrWritePtr;
      }
    }
    return INVALID_PTR;
  }

  /**
   * FileStorage.getReadPtr
   *
   * The function returns the current read pointer for a give file. Read
   * pointer is a logical position in the file based on the previous read
   * calls and the length of data read. The value of read pointer represents
   * the number of bytes read from the file after the file was opened.
   * If the file name does not exist in the valid file list then an INVALID_PTR
   * will be returned.
   *
   * @parma filename Name of the file for which the read pointer is required.
   *
   * @return Current read pointer of the file or INVALID_PTR
   */
  command storage_addr_t FormatStorage.getReadPtr (const uint8_t* filename)
  {
    list_ptr *pos, *tmp;
    
    if (state == S_UN_INIT)
      return FAIL;

    if (!is_list_empty(&(fmList.metaList)))
    {
      for_each_node_in_list(pos, tmp, &(fmList.metaList))
      {
        tmpList = get_list_entry(pos, FileMetaList, metaList);
        if (strcmp(tmpList->metadata.fileName, filename) == 0)
          return tmpList->metadata.CurrReadPtr;
      }
    }
    return INVALID_PTR;
  }

  /**
   * FileStorage.getReadPtr1
   *
   * The function returns the current read pointer for a give file. Read
   * pointer is a logical position in the file based on the previous read
   * calls and the length of data read. The value of read pointer represents
   * the number of bytes read from the file after the file was opened.
   * If the volume id does not exist in the valid file list then an INVALID_PTR
   * will be returned.
   *
   * @parma id VolumeId of the file for which the read pointer is required.
   *
   * @return Current read pointer of the file or INVALID_PTR
   */  
  command storage_addr_t FormatStorage.getReadPtr1 (volume_id_t id)
  {
    list_ptr *pos, *tmp;

    if (state == S_UN_INIT)
      return FAIL;

    if (!is_list_empty(&(fmList.metaList)))
    {
      for_each_node_in_list(pos, tmp, &(fmList.metaList))
      {
        tmpList = get_list_entry(pos, FileMetaList, metaList);
        if (tmpList->metadata.volumeId == id)
          return tmpList->metadata.CurrReadPtr;
      }
    }
    return INVALID_PTR;
  }

  /**
   * FileStorage.cleanAllFiles
   *
   * The function deletes all the files, cleans the sector table, erases
   * the meta data block and deletes the linked list of valid files.
   * The whole file system is completely reset.
   *
   * @return SUCCESS | FAIL
   */
  command result_t FormatStorage.cleanAllFiles()
  {
    result_t res = FAIL;
    volume_id_t i;
    uint16_t STValidity = VALID_SYS_TABLE_BLOCK;
    list_ptr *pos, *tmp; /*temporary list headers*/

    if (state == S_UN_INIT)
      return FAIL;

    /**
     * Clean up the blocks used by the existing files and initialize the sector table.
     * Note that if erase fails the sector table entry will be marked unallocated and
     * could be reclaimed after reboot.
     */
    for (i = 0; i < FLASH_NUM_BLOCKS; i++)
    {
      if (sectorTable.block[i].volumeId != FLASH_INVALID_VOLUME_ID)
      {
        storage_addr_t bAddr = (i * FLASH_BLOCK_SIZE) + FLASH_LOGGER_START_ADDR;
        if (call HALPXA27X.blockErase (bAddr) == SUCCESS)
          sectorTable.block[i].volumeId = FLASH_INVALID_VOLUME_ID;
        else
          sectorTable.block[i].volumeId = FLASH_UNALLOCED_BLOCK;
      }
    }

    sectorTable.numfiles = 0;

    if ((res = call HALPXA27X.blockErase (SECTOR_TABLE_START_ADDR)) == FAIL)
      return FAIL;
    else if ((res = call HALPXA27X.blockErase (SECTOR_TABLE_START_ADDR + FLASH_BLOCK_SIZE)) == FAIL)
      return FAIL;

    if (call Flash.write (SECTOR_TABLE_START_ADDR, (uint8_t*)&STValidity, VALIDITY_SIZE) == FAIL)
      trace (DBG_USR1, "FS ERROR: Could not write Validity Word to ST.\r\n");

    if ((res = call HALPXA27X.pageProgram(SECTOR_TABLE_START_ADDR + VALIDITY_SIZE, &sectorTable, 
                                   sizeof(SectorTable))) == FAIL)
      return FAIL;

    if (res == SUCCESS)
      if ((res = call HALPXA27X.blockErase (FILE_META_DATA_START_ADDR)) == SUCCESS)
        res = call HALPXA27X.blockErase (FILE_META_DATA_START_ADDR + FLASH_BLOCK_SIZE);

    if (res == FAIL)
    {
      trace (DBG_USR1, "FS ERROR: Could not Erase MD Table.\r\n");
      return FAIL;
    }

    if (call Flash.write (FILE_META_DATA_START_ADDR, (uint8_t*)&STValidity, VALIDITY_SIZE) == FAIL)
      trace (DBG_USR1, "FS ERROR: Could not write Validity Word to MD.\r\n");

    if (res == SUCCESS)
    {
      if (!is_list_empty(&(fmList.metaList)))
      {
        for_each_node_in_list(pos, tmp, &(fmList.metaList))
        {
          tmpList = get_list_entry(pos, FileMetaList, metaList);
          FREE_DBG(__FILE__,"FormatStorage.cleanAllFiles",tmpList);
          delete_node(pos);
          free(tmpList);
        }
      }
    }

    return res;
  }

  /**
   * FileStorage.getFileCount
   *
   * Returns the number of valid files in the current context. The
   * function scans the list of valid files to get the count.
   *
   * @return Number of valid files.
   */
  command volume_id_t FormatStorage.getFileCount()
  {
    list_ptr *pos, *tmp; /*temporary list headers*/
    volume_id_t totfiles = 0;
    if (state == S_UN_INIT)
      return FAIL;
    for_each_node_in_list(pos, tmp, &(fmList.metaList))
    {
      ++totfiles;
    }
    return totfiles;
  }

  /**
   * FileStorage.getNextId
   *
   * Generate the Next Volume id for creating a new file. The current
   * method is to scan through a valid set of id's to identify an
   * unused volume id.
   *
   * @return Unique volume id for file creation.
   */
  command volume_id_t FormatStorage.getNextId()
  {
    bool isUsed = FALSE;
    list_ptr *pos, *tmp; /*temporary list headers*/
    volume_id_t NextId = START_VOLUME_ID;

    if (state == S_UN_INIT)
      return FAIL;
    /**
     * FIXME Find a better algorithm to generate unique id's
     */
    for (;NextId < MAX_VOLUME_ID; NextId ++)
    {
      isUsed = FALSE;
      for_each_node_in_list(pos, tmp, &(fmList.metaList))
      {
        tmpList = get_list_entry(pos, FileMetaList, metaList);
        if (tmpList->metadata.volumeId == NextId)
        {
          isUsed = TRUE;
	  break;
        }
      }
      if (!isUsed)
      {
        /*FIXME Work around for cannot create file problem. Once the
         * the meta-data and sector table compatibility problem is
         * solved then we have to remove this.
         */
        uint16_t ivb = 0;
        for (ivb = 0;ivb < FLASH_NUM_BLOCKS && 
           sectorTable.block[ivb].volumeId != NextId; ivb++);
        if (ivb == (FLASH_NUM_BLOCKS))
          return NextId;
      }
    }
    return FAIL; 
  }

  result_t HandlePendingCreate ()
  {
    result_t res = SUCCESS;

    if (!is_list_empty(&(uncommittedList.metaList)))
    {
      res = call FormatStorage.commit ();
      if (res == FAIL)
        trace (DBG_USR1, "FS ERROR: Commit failed for pending create request \r\n");
    }
    return res;
  }

  result_t HandleCreateRequest (const uint8_t* filename, storage_addr_t size)
  {
    result_t res = FAIL;

    NextVolumeId = call FormatStorage.getNextId();

    if (NextVolumeId == FAIL)
    {
      trace (DBG_USR1,"FS ERROR: Could not get VolumeID for allocation, FS might be full.\r\n");
      return FAIL;
    }

    if (size < FLASH_BLOCK_SIZE)
      size = FLASH_BLOCK_SIZE;

    if ((res = call FormatStorage.allocate (NextVolumeId, size, filename)) == FAIL)
    {
      trace (DBG_USR1,"FS ERROR: Allocation failed for file %s\r\n", filename);
      return FAIL;
    }

    if (call HALPXA27X.isErasing())
    {
      //trace (DBG_USR1,"FS MSG: FileSystem if BUSY erasing, CREATE operation Queued\r\n");
      res = call FSQueue.queueCreate (filename, size);
      return res;
    }

    if (res == SUCCESS)
      res = call FormatStorage.commit ();

    if (res == FAIL)
      trace (DBG_USR1, "FS ERROR: Could not commit Sector Table \r\n");
    return res;
  }

  /**
   * FileStorage.fcreate
   *
   * Create a new file with a given file name and size and update the
   * required tables and lists with the new file details.
   * This function calls the getNextId to receive a unique id for
   * the file. The file name must be unique, otherwise create will fail.
   * The size of the file must be multiples of FLASH_BLOCK_SIZE.
   * 
   * @param filename Name of the new file to be created
   * @param size Size of the file in FLASH_BLOCK_SIZE.
   *
   * @return SUCCESS | FAIL
   */
  command result_t FormatStorage.fcreate(const uint8_t* filename,
                          storage_addr_t size)
  {
    result_t res = FAIL;
    res = HandleCreateRequest (filename, size);

    return res;
  }

  /**
   * computeSectorTableCrc
   *
   * The function calculated a 16-bit crc of the sector table
   * and returns the value.
   *
   * @return CRC of the sector table.
   */
  uint16_t computeSectorTableCrc() 
  {
    uint16_t len = sizeof(SectorTable)-2;
    return call Crc.crc16(&sectorTable, len);
  }

  /**
   * invalidateTableEntry
   *
   * The functions invalidates a sector table entry or a meta
   * data entry by changing the validity field of the entry.
   *
   * @param staddr The address of the validity field of a meta data entry.
   *
   * @return SUCCESS | FAIL
   */
  result_t invalidateTableEntry (storage_addr_t staddr)
  {
    //trace (DBG_USR1,"FS Msg: Invalidating Sector Table @ %ld \r\n", staddr);
    return call HALPXA27X.wordProgram (staddr, INVALID_SECTOR_TABLE);
  }

  /**
   * commitMetaData
   *
   * The function will merge the uncommitted list with the
   * main file list and updates the meta data block with
   * the meta data of new files.
   *
   * @return SUCCESS | FAIL 
   */
  result_t commitMetaData ()
  {
    storage_addr_t mCurAddr = FILE_META_DATA_START_ADDR + mdoffset;
    list_ptr *pos, *tmp; /*temporary list headers*/
    bool EraseRequired = FALSE;

    /**
     * The meta data block is full, clean it up and restore the
     * valid meta data informations.
     */
    if ((isMDTableOverflow ()))
    {
      if ((mCurAddr = HandleMDTableOverflow()) == FAIL)
      {
        trace(DBG_USR1,"FS ERROR: HandleOverflow failed at line %d.\r\n", __LINE__);
        return FAIL;
      }
      EraseRequired = TRUE;
    }

    //mCurAddr += mdoffset;

    /**
     * Write all the metadata for the uncommited files in to the
     * FILE_META_DATA_START_ADDR.
     */
    if (!is_list_empty(&(uncommittedList.metaList)))
    {
      for_each_node_in_list(pos, tmp, &(uncommittedList.metaList))
      {
        tmpList = get_list_entry(pos, FileMetaList, metaList);
        tmpList->metadata.CurrLoc = mdoffset + FILE_META_DATA_START_ADDR;
        //if (call Flash.write(mCurAddr, (uint8_t*) &tmpList->metadata, 
        //                           sizeof(FileMetadata)) == FAIL)
        if (call HALPXA27X.pageProgram(mCurAddr, (uint8_t*) &tmpList->metadata, 
                                 sizeof(FileMetadata)) == FAIL)
        {
          trace(DBG_USR1,"** FS ERROR **: Failed Address %ld\r\n", mCurAddr);
          return FAIL;
        }
        else
        {
          mdoffset += sizeof(FileMetadata);
          mCurAddr += sizeof(FileMetadata);
        }
      }

      join_lists (&uncommittedList.metaList, &(fmList.metaList));
      INIT_LIST (&uncommittedList.metaList);
    }

    return SUCCESS;
  }

  /**
   * commitSectorTable
   *
   * The updated sector table with the new files will be added to the
   * sector table block, the old entry of the sector table will be
   * invalidated. The function also checks for the overflow of the
   * sector table block and takes required actions.
   *
   * @return SUCCESS | FAIL
   */
  result_t commitSectorTable ()
  {
    uint8_t currSTBlock = 0;
    int32_t currBlkChk = 0;
    uint8_t currers = 0;
    curAddr = SECTOR_TABLE_START_ADDR + stoffset;
    currBlkChk = (stoffset - FLASH_BLOCK_SIZE);

    if (currBlkChk <= 0)
      currSTBlock = 1;
    else
      currSTBlock = 2;

    if (!(isSTTableOverflow ()))
    {
      if (call HALPXA27X.pageProgram(curAddr, &sectorTable, 
                                   sizeof(SectorTable)) == FAIL)
      {
        trace(DBG_USR1,"FS ERROR: Cannot update sector table to addr %ld\r\n",curAddr);
        return FAIL;
      }
      else
      {
        //trace (DBG_USR1,"FS Msg: Successfully written new SectorTable @ %ld\r\n",curAddr);
        invalidateTableEntry ((curAddr - sizeof(SectorTable)));
        stoffset += sizeof(SectorTable);
      }
    }
    else
    {
      storage_addr_t curErsAddr = 0x0;
      uint16_t ValidBlk = VALID_SYS_TABLE_BLOCK;
      uint16_t InValidBlk = INVALID_SYS_TABLE_BLOCK;

      /* The latest sector table cannot be placed on the sector table block,
       * so the whole block has to be cleaned to accomodate the latest
       * sector table.
       */
      trace(DBG_USR1,"FS Msg: Restoring Sector Table Block.\r\n");

      switch (currSTBlock)
      {
        case 1:
          curAddr = SECTOR_TABLE_START_ADDR + FLASH_BLOCK_SIZE;
          curErsAddr = SECTOR_TABLE_START_ADDR;
          currers = 2;
          stoffset = sizeof(SectorTable) + FLASH_BLOCK_SIZE + VALIDITY_SIZE; /* Add bytes for validity field*/
        break;
        case 2:
          curAddr = SECTOR_TABLE_START_ADDR;
          curErsAddr = SECTOR_TABLE_START_ADDR + FLASH_BLOCK_SIZE;
          currers = 3;
          stoffset = sizeof(SectorTable) + VALIDITY_SIZE; /* Add bytes for validity field*/
        break;
        default:
          trace (DBG_USR1, "FATAL ERROR: Unknown Current ST Block, Might currupt FS\r\n");
          return FAIL;
        break;
      }

      if (!(call Flash.isBlockErased (curAddr)))
      {
        trace (DBG_USR1, "FS WARNING: Block 2 not ready when trying to switch ST block\r\n");
        if ((call Flash.erase (curAddr)) == FAIL)
        {
          trace (DBG_USR1, "FS ERROR: Cannot Erase Block 2 to contiue ST storage\r\n");
          return FAIL;
        } 
      }

      if (call Flash.write(curAddr, (uint8_t*)&ValidBlk, VALIDITY_SIZE) == FAIL)
        trace (DBG_USR1,"** FS ERROR **: Couldnt Write validity field for ST Table. Reboot might cause issues\r\n");

      curAddr += VALIDITY_SIZE;

      if (call HALPXA27X.pageProgram(curAddr, &sectorTable, 
                                  sizeof(SectorTable)) == FAIL)
      {
        trace (DBG_USR1, "FATAL ERROR: Unable to switch ST Block to 2\r\n");
        return FAIL;
      }
      else
      {
        trace (DBG_USR1, "FS Msg: ST Block placed to erase %ld\r\n",curErsAddr);
        if (call Flash.write(curErsAddr, (uint8_t*)&InValidBlk, VALIDITY_SIZE) == FAIL)
          trace (DBG_USR1,"** FS ERROR **: Couldnt invalidate old ST Table. Reboot might cause issues\r\n");

        SystemTableErase [currers] = MD_ST_ERASE;
        if (!(isEraseTimer))
        {
          call EraseTimer.start (TIMER_REPEAT, 5000);
          isEraseTimer = TRUE;
        }
      }
    }
    return SUCCESS;
  }

  /**
   * FormatStorage.commit
   *
   * The file created has to be commited using this function for
   * completing creation of the file.
   *
   * @return SUCCESS | FAIL
   */
  command result_t FormatStorage.commit () 
  {
    state = S_COMMIT;
    sectorTable.crc = computeSectorTableCrc();

    if (commitMetaData() == FAIL)
    {
      trace (DBG_USR1, "** FS ERROR **: Could not commit metadata info \r\n");
      signalDone(STORAGE_FAIL);
      return FAIL;
    }

    sectorTable.numfiles += unCommittedFiles;
    if (commitSectorTable() == FAIL)
    {
      trace (DBG_USR1, "** FS ERROR **: Could not commit sector table \r\n");
      state = S_INIT;
      signalDone(STORAGE_FAIL);
      return FAIL;
    }
    else
    {
      NextVolumeId += unCommittedFiles;
      unCommittedFiles = 0;
      signalDone(STORAGE_OK);
    }
    return SUCCESS;
  }

  void pageProgramDone() 
  {
    return;
  }

  event void HALPXA27X.blockEraseDone() 
  {
    return;
  }

  event void HALPXA27X.pageProgramDone() 
  {
  }

  event void HALPXA27X.bulkEraseDone(result_t code, uint32_t aaddr) 
  {
    uint32_t eBlk = 0x0;
    uint32_t partition = 0x0;
    if (code == SUCCESS)
    {
      eBlk = (uint16_t)((aaddr - FLASH_LOGGER_START_ADDR ) / FLASH_BLOCK_SIZE);
      partition = aaddr / FLASH_PARTITION_SIZE;
      if ((eBlk < 201))
      {
        if (sectorTable.block[eBlk].volumeId == FLASH_UNALLOCED_BLOCK)
        {
          sectorTable.block[eBlk].volumeId = FLASH_INVALID_VOLUME_ID;
          trace (DBG_USR1,"FS Msg: Erase Completed for addr %ld Block %d\r\n",aaddr, eBlk);

          if (commitSectorTable () == FAIL)
          {
            trace (DBG_USR1,"FS Msg: Could not commit sector table after erasing %ld\r\n",aaddr);
            sectorTable.block[eBlk].volumeId = FLASH_UNALLOCED_BLOCK;
            return;
          }
          else
          {
            atomic --NumUnAllocatedBlocks; /* debug purposes*/
            atomic --FreePartition[partition];
          }
        }
      }
      else
          trace (DBG_USR1,"FS Msg: Erase Completed MD or ST Block %ld\r\n",aaddr);
    }

    if (!(isEraseTimer))
    {
      call EraseTimer.start (TIMER_REPEAT, 5000);
      isEraseTimer = TRUE;
    }

    return;
  }


  event void FSQueue.pendingReq (uint8_t request, void* data, PendingRequest* req)
  {
    if (state == S_COMMIT)
      trace (DBG_USR1, "FS WARNING: There is a pending FS operation\r\n");
      
    //trace (DBG_USR1, "FS Msg: Executing Pending request at FSM, req type %d \r\n", request);
    switch (request)
    {
      case WRITE_REQUEST:
      break;
      case CREATE_REQUEST:
        //if (HandleCreateRequest (req->preq.creq.FileName, req->preq.creq.FileSize) == FAIL)
        if (HandlePendingCreate() == FAIL)
          trace (DBG_USR1, "FS ERROR: Pending CREATE request for %s failed.\r\n", req->preq.creq.FileName);
      break;
      case DELETE_REQUEST:
        if (HandleDeleteRequest (req->preq.dreq.FileName) == FAIL)
          trace (DBG_USR1, "FS ERROR: Pending DELETE request for %s failed.\r\n", req->preq.creq.FileName);
      break;
      default:
          trace (DBG_USR1,"FS WARNING: Unknown task in the QUEUE %d\r\n",req->ReqType);
      break;        
    }
    return;
  }

  event void HALPXA27X.writeSRDone() {}
}
