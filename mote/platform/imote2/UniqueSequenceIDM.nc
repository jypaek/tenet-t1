/**
 * Author 	Junaith Ahemed
 * Date		January 25, 2007
 */

includes PXAFlash;
includes UniqueSequenceID;

module UniqueSequenceIDM
{
  provides
  {
    interface StdControl;
    interface UniqueSequenceID;
  }
  
  uses
  {
    interface FileStorage as FCreate;
    interface FileMount as FOpen;
    interface FileWrite as FWrite;
    interface FileRead as FRead;
  }
}

implementation
{
/*
  #define DEFAULT_VALUE 1
  #define FileNameSize 4
*/

  uint8_t UIDFiles[2][FileNameSize];
  
  /* Size of the SequenceID variable which is a uint32*/
  #define FieldSize 4
  uint8_t currFile [FileNameSize];
  uint32_t currSeqId = 0x0;
  bool SIDLoadErr = FALSE;
  bool Initialized = FALSE;

/*
  enum
  {
    NOFILE = 2,
    OERR = 3,
    WERR = 4,
    RERR = 5,
    SERR = 6,
  };
*/

  uint8_t LoadSeqID ()
  {
    uint16_t numfiles = 0x0;
    result_t res = SUCCESS;
    char* fmdata;
    uint16_t i = 0x0;
    uint32_t WPtr = 0x0;
    
    numfiles = call FCreate.getFileCount();
    for (i=0; i<numfiles; i++)
    {
      fmdata = call FCreate.getFileName (i);
      //trace(DBG_USR1,"FileName %s\r\n",fmdata);
      if (memcmp(fmdata,UIDFiles[0], FileNameSize) == 0)
      {
        memcpy(currFile, UIDFiles[0], FileNameSize);
        break;
      }
      else if (memcmp(fmdata,UIDFiles[1], FileNameSize) == 0)
      {
        memcpy(currFile, UIDFiles[1], FileNameSize);
        break;
      }
    }

    if ((currFile [0x0] == 0) && (currFile [0x1] == 0))
      return NOFILE;

    if (call FOpen.fopen(currFile) == FAIL)
      return OERR;

    WPtr = call FCreate.getWritePtr (currFile);
    if ((WPtr >= FieldSize) && (WPtr != INVALID_PTR))
    {
      if (call FRead.rseek(WPtr - FieldSize) == SUCCESS)
      {
        if (call FRead.fread (&currSeqId, FieldSize) == SUCCESS)
          res = SUCCESS;
      }
      else
        res = SERR;
    }
    else
    {
      res = FAIL;
      trace (DBG_USR1,"ERROR: Bad Write Pointer for sequence ID File\r\n");
    }

    if (call FOpen.fclose(currFile) == FAIL)
      trace (DBG_USR1,"ERROR: Cannot close SeqID File - %s\r\n", currFile);

    return res;
  }

  result_t HandleLoadErr (result_t ret)
  {
    if (ret == SUCCESS)
      return ret;

    switch (ret)
    {
      case NOFILE:
      {
        memcpy(currFile, UIDFiles[0], FileNameSize);
        if (call FCreate.fcreate(currFile, STORAGE_BLOCK_SIZE) == SUCCESS)
        {
          if (call FOpen.fopen(currFile) == SUCCESS)
          {
            if (call FWrite.append (&currSeqId, FieldSize) == FAIL)
              trace (DBG_USR1,"ERROR: Could not WRITE the file that was created for SeqID - %s.\r\n", currFile);
            if (call FOpen.fclose(currFile) == FAIL)
              trace (DBG_USR1,"ERROR: Cannot close SeqID File - %s\r\n", currFile);
            Initialized = TRUE;
          } 
          else
            trace (DBG_USR1,"ERROR: Could not open the file that was created for SeqID - %s.\r\n", currFile);
        }
      }
      break;
      case OERR:
        trace (DBG_USR1,"ERROR: Cannot open the SeqID file.\r\n");
        SIDLoadErr = TRUE;
      break;
      case SERR:
        trace (DBG_USR1,"ERROR: Cannot Seek to the right offset in SeqID file.\r\n");
        SIDLoadErr = TRUE;
      break;
      default:
        trace (DBG_USR1,"ERROR: Unknown Error while reading SeqID file.\r\n");
        SIDLoadErr = TRUE;
      break;
    }
    return SUCCESS;
  }

  result_t SwitchFileNames()
  {
    if (memcmp(currFile,UIDFiles[0], FileNameSize) == 0)
      memcpy(currFile, UIDFiles[1], FileNameSize);
    else if (memcmp(currFile, UIDFiles[1], FileNameSize) == 0)
      memcpy(currFile, UIDFiles[0], FileNameSize);
    return SUCCESS;
  }

  command result_t StdControl.init() 
  {
    Initialized = FALSE;
    memcpy (UIDFiles[0], "sys_UID1", FileNameSize);
    memcpy (UIDFiles[1], "sys_UID2", FileNameSize);
    return SUCCESS;
  }

  command result_t StdControl.start() 
  {
    uint8_t retVal = SUCCESS;
    if (!Initialized)
    {
      currSeqId = 0x0;
      SIDLoadErr = FALSE;
      memset (currFile, 0x0, FileNameSize);
      retVal = LoadSeqID();
      if (retVal == SUCCESS)
      {
        //trace (DBG_USR1,"Initialized UniqueSequenceID component.\r\n");
        Initialized = TRUE;
      }
      HandleLoadErr (retVal);
    }
    else
      trace (DBG_USR1,"UniqueSequenceID already Initialized.\r\n");

    return SUCCESS;
  }

  command result_t StdControl.stop() 
  {
    return SUCCESS;
  }

  /**
   * UniqueSequenceID.GetNextSequenceID
   *
   * The command returns the next available Sequence ID to the caller. If
   * there is a load error then a 0x0 will be returned and 0x0 is not
   * a valid sequence number.
   */
  command uint32_t UniqueSequenceID.GetNextSequenceID ()
  {
    uint32_t WPtr = 0x0;
    uint8_t oldFile [FileNameSize];

    if (!Initialized)
    {
      trace (DBG_USR1,"ERROR: UniqueSequenceID component not Initialized.\r\n");
      return 0;
    }

    if (SIDLoadErr)
      return 0;

    ++ currSeqId;    
    if (currFile != NULL)
    {
      if (call FOpen.fopen(currFile) == SUCCESS)
      {
        WPtr = call FCreate.getWritePtr (currFile);
        if ((WPtr + FieldSize) >= STORAGE_BLOCK_SIZE)
        {
          /* Switching Files due to overflow*/
          if (call FOpen.fclose(currFile) == FAIL)
            trace (DBG_USR1,"ERROR: Couldnt close OLD SeqID File - %s\r\n", currFile);
          memcpy (oldFile, currFile, FileNameSize);
          oldFile[FileNameSize] = 0x0; /*FIXME set the last byte to NULL*/
          SwitchFileNames();
          trace (DBG_USR1,"FS Msg: Overflow detected in SeqID File switching to - %s\r\n", currFile);
          if (call FCreate.fcreate(currFile, STORAGE_BLOCK_SIZE) == SUCCESS)
          {
            if (call FOpen.fopen(currFile) == SUCCESS)
            {
              if (call FWrite.append (&currSeqId, FieldSize) == FAIL)
                trace (DBG_USR1,"ERROR: Could not write SeqID File - %s\r\n", currFile);
            }
            else    
              trace (DBG_USR1,"ERROR: Could not open SeqID File %s.\r\n", currFile);

            if (call FOpen.fclose(currFile) == FAIL)
              trace (DBG_USR1,"ERROR: Could not close SeqID File - %s\r\n", currFile);

            if (call FCreate.fdelete (oldFile) == SUCCESS)
              trace (DBG_USR1,"FS Msg: Old SeqID File %s deleted from Flash.\r\n", oldFile);
            else    
              trace (DBG_USR1,"ERROR: Could not delete Old SeqID File %s.\r\n", oldFile);
          }
          else
          {
            SwitchFileNames();
            trace (DBG_USR1,"ERROR: Could not create SeqID File - %s\r\n", currFile);
          }
        }
        else
        {
          if (call FWrite.append (&currSeqId, FieldSize) == FAIL)
            trace (DBG_USR1,"ERROR: Could not write SeqID File - %s\r\n", currFile);
          if (call FOpen.fclose(currFile) == FAIL)
            trace (DBG_USR1,"ERROR: Cannot close SeqID File - %s\r\n", currFile);
        }
      }
      else
        trace (DBG_USR1,"ERROR: Couldnt open SeqID File - %s.\r\n", currFile);
    }
    else
      trace (DBG_USR1,"ERROR: Invalid SeqID File Name.\r\n");

    return currSeqId;
  }

  /**
   * UniqueSequenceID.ResetSequenceID
   *
   * Reset the sequence ID and write the value to the flash. Note that
   * the sequence ID always starts at 0x1 and the GetNextSequenceID function
   * returns a pre incremented value to the caller.
   */
  command result_t UniqueSequenceID.ResetSequenceID ()
  {
    result_t res = SUCCESS;
    uint8_t oldFile [4];
    if (!Initialized)
    {
      trace (DBG_USR1,"ERROR: UniqueSequenceID component not Initialized.\r\n");
      return 0;
    }
    currSeqId = 0x0;
    if (currFile != NULL)
    {
      memcpy (oldFile, currFile, FileNameSize);
      oldFile[FileNameSize] = 0x0; /* FIXME set the last byte to NULL*/
      SwitchFileNames();
      if (call FCreate.fcreate(currFile, STORAGE_BLOCK_SIZE) == SUCCESS)
      {
        if (call FOpen.fopen(currFile) == SUCCESS)
        {
          if (call FWrite.append (&currSeqId, FieldSize) == FAIL)
          {
            trace (DBG_USR1,"ERROR: Could not write SeqID File - %s\r\n", currFile);
            res = FAIL;
          }

          if (call FOpen.fclose(currFile) == FAIL)
          {
            trace (DBG_USR1,"ERROR: Could close SeqID File - %s\r\n", currFile);
            res = FAIL;
          }
        }
        else
        {
          trace (DBG_USR1,"ERROR: Could not open SeqID File - %s.\r\n", currFile);
          res = FAIL;
        }
        if (call FCreate.fdelete (oldFile) == SUCCESS)
          trace (DBG_USR1,"FS Msg: Old SeqID File %s deleted from Flash.\r\n", oldFile);
        else    
          trace (DBG_USR1,"ERROR: Could not delete Old SeqID File %s.\r\n", oldFile);
      }
      else
      {
        trace (DBG_USR1,"ERROR: Cannot Create SeqID File - %s.\r\n", currFile);
        //SwitchFileNames();
        res = FAIL;
      }
    }
    else
    {
      res = FAIL;
      trace (DBG_USR1,"ERROR: SeqID File does not exist or component is not initialized.\r\n", currFile);
    }
    return res;
  }

  event void FOpen.mountDone(storage_result_t result, volume_id_t id) 
  {
    return;
  }

  event void FWrite.writeDone(storage_result_t result, 
                                  block_addr_t addr, 
                                  void* buf, block_addr_t len)
  {
  }

  event void FWrite.eraseDone(storage_result_t result)
  {
    return;
  }

  event void FCreate.commitDone(storage_result_t result)
  {
    return;
  }

  event void FWrite.commitDone(storage_result_t result)
  {
    return;
  }

  event void FRead.readDone(storage_result_t result, block_addr_t addr, 
                                void* buf, block_addr_t len)
  {
    return;
  }

  event void FRead.verifyDone(storage_result_t result)
  {
    return;
  }

  event void FRead.computeCrcDone(storage_result_t result, uint16_t crc, 
                                      block_addr_t addr, block_addr_t len)
  {
    return;
  }
}
