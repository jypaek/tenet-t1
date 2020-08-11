
includes eeprom_logger;

module SequentialIntegratedM {
  provides {
    interface StdControl;
    interface SequentialQueueI;

#ifdef STAT_TRACKER
	interface FreeSpaceQueryI;
#endif

  }uses {
    interface PageEEPROM;
    interface SequentialRLTI;
    interface Leds;
  }
}implementation {

#define UNSET 0xFFFFFFFF

enum{
	INIT,
	IDLE,
	WRITE,
	READ_HEADER,
        READ_BODY,
	UNREAD
};

enum{
	NO_OP,
	WRITE_REC,
	WRITE_RLT,
	READ_REC
};

  uint8_t state;
  uint8_t cmd;
  rlt_t logger_rlt;
  uint8_t databuffer[sizeof(record_t)+MAX_RECORD_PAYLOAD];
  uint32_t last_read_head;

  // the number of bytes that will be read or written when we are done
  // includes size of the record_t header
  uint16_t global_bytes_to_rw;
  // the number of bytes that have been read or written so far
  // includes size of the record_t header
  uint16_t global_bytes_rw;
  // number of bytes to read or write during the current operation
  uint16_t global_bytes_rw_now;

  result_t WriteBuffer(rlt_t* lrlt, uint8_t* data, uint8_t dsize);

  /**********************************************************************
  Functions
  ***********************************************************************/

        void ReturnIdleState()
        {
            state = IDLE;
            cmd = NO_OP;
        }

        uint32_t getAmountUsed(){
		if(logger_rlt.currenthead > logger_rlt.currenttail){
			return (getByteEEPROMSize() - logger_rlt.currenthead) + (logger_rlt.currenttail);
		}
		if(logger_rlt.currenthead < logger_rlt.currenttail){
			return logger_rlt.currenttail - logger_rlt.currenthead;
		}
		return 0;
	}

        int8_t GetBytesToReadWrite(uint32_t current_ptr, uint16_t *eeprompage, 
                                   uint16_t *eepromoffset, uint8_t bwrite)
        {
            uint16_t epage = getEEPROMPage(current_ptr);
            uint16_t eoffset = getEEPROMOffset(current_ptr);

            if(epage < RECORD_START_PAGE || epage > RECORD_END_PAGE){
                dbg(DBG_ERROR, "eeprompage out of range %d, %d, %d\n", 
                    epage, RECORD_START_PAGE, RECORD_END_PAGE);
	        return -1;
            }

            if(eoffset < sizeof(pagemetacompressed_t) || eoffset >= EEPROM_PAGE_SIZE){
                dbg(DBG_ERROR, "eeprompageoffset out of range %d, %d, %d\n", 
                    eoffset, sizeof(pagemetacompressed_t), 
                    EEPROM_PAGE_SIZE);
	        return -1;
            }

            *eeprompage = epage;
            *eepromoffset = eoffset;

            if(eoffset + bwrite <= EEPROM_PAGE_SIZE){
                return bwrite;
            }else{
                return (EEPROM_PAGE_SIZE - eoffset);
            }
        }

     
    result_t SplitAndWriteRecord(uint16_t tail, uint8_t bytes_to_write, 
                                 uint8_t *data)
    {
        uint8_t bytesToRW;
        uint16_t eeprompage = 0;
        uint16_t eepromoffset = 0;

        bytesToRW = GetBytesToReadWrite(tail, &eeprompage, 
                                        &eepromoffset, bytes_to_write);

        // Commented out to stop the compiler warning, can never happen anyway
        /*if (bytesToRW == -1)
        {
            dbg(DBG_ERROR,"SequentialRW: can't get bytes to write \n");   
            return FAIL;
            }*/

        dbg(DBG_USR3,"Split and write: total bytes to write %d, bytes written %d, bytes to write this time %d, tail %d, page %d, offset %d\n", global_bytes_to_rw, global_bytes_rw, bytesToRW, tail, eeprompage, eepromoffset);

        global_bytes_rw_now = bytesToRW;

        if (call PageEEPROM.write(eeprompage, eepromoffset, 
                                  data, global_bytes_rw_now) == FAIL){
            dbg(DBG_ERROR,"PageEEPROM.write failed\n");
            return FAIL;
	}

        return SUCCESS;

    }


	result_t loadRLT(){
		return call SequentialRLTI.loadRLT(&logger_rlt);
	}


/* KAREN: Fix this */

	void signalResult(uint8_t size, result_t result){
		uint8_t ostate = state;
                ReturnIdleState();
		
		switch(ostate){
		  case INIT:
		  	break;
		  case WRITE:
		  	signal SequentialQueueI.writeTailDone(result);
		  	break;
		  case READ_BODY:
                        signal SequentialQueueI.readHeadDone(&databuffer[sizeof(record_t)], 
                                                     global_bytes_to_rw - sizeof(record_t), 
                                                     result);
		  	//signal SequentialQueueI.readHeadDone(databuffer,size,result);
		  	break;
		  case UNREAD:
		  	signal SequentialQueueI.unreadHeadDone(result);
		  	break;
                  default:
                        dbg(DBG_ERROR, "signalResult: Unknown State: %d\n", ostate);

		}
	}


  /**********************************************************************
  Tasks
  ***********************************************************************/

	task void taskSuccess(){
		signalResult(global_bytes_to_rw, SUCCESS);
	}

	task void taskFail(){
		signalResult(0,FAIL);
	}


  /**********************************************************************
  StdControl Interface
  ***********************************************************************/

  command result_t StdControl.init(){
    return SUCCESS;
  }

  command result_t StdControl.start() {
        state = INIT;
        cmd = NO_OP,
	last_read_head = UNSET;
        memset(&databuffer, 0,sizeof(databuffer));

	if(loadRLT() == FAIL){
	    ReturnIdleState();
	}

    return SUCCESS;
  }

  command result_t StdControl.stop() {
    return SUCCESS;

  }


  /**********************************************************************
  Empty Queue?
  ***********************************************************************/
  command uint8_t SequentialQueueI.isQueueEmpty(){
	  if(logger_rlt.currenthead == logger_rlt.currenttail){
		  return 1;
	  }
	  return 0;
  }


  /**********************************************************************
  Write Log
  ***********************************************************************/
  command result_t SequentialQueueI.writeTail(uint8_t *data, uint8_t numBytesWrite){
    result_t res;

    if(state != IDLE){
      dbg(DBG_ERROR, "writeTail: Attempting sequential write, but another action in progress %d\n", state); 
      return FAIL;
    }
    state = WRITE;
    cmd = WRITE_REC;
    
    res =  WriteBuffer(&logger_rlt, data, numBytesWrite);
    if(res != SUCCESS){
        dbg(DBG_ERROR, "writeTail: Failed\n");
        ReturnIdleState();
    }
    return res;

  }

  

  result_t WriteBuffer(rlt_t* lrlt, uint8_t* data, uint8_t dsize){
	//result_t res;
        record_t* rec = (record_t*)databuffer;
        int i;

	if(dsize + sizeof(record_t) > sizeof(databuffer)){
	    dbg(DBG_ERROR,"SequentialRW: data size %i is larger than max size %i \n",
                dsize, sizeof(databuffer)-sizeof(record_t));
            return FAIL;
	}

	if(getAmountUsed() + dsize + sizeof(record_t) >= getByteEEPROMSize()){
	    dbg(DBG_ERROR,"SequentialRW: EEPROM is full \n");
	    return EEPROM_FULL;
	}

        // set the number of bytes we will write, and reset the count of
        // bytes written
        global_bytes_to_rw = dsize + sizeof(record_t);
        global_bytes_rw = 0;

	rec->length = dsize;
	memcpy(rec->data, data, dsize);

        dbg(DBG_USR3,"Starting write: ");
        for (i=0; i<dsize; i++)
        {
            dbg(DBG_USR3, "%d ", databuffer[i+1]);

        }

        dbg(DBG_USR3, "\n");

        dbg(DBG_USR3,"Starting write: Current Tail: %d, Current Head %d, bytes to write %d\n", 
            logger_rlt.currenttail, logger_rlt.currenthead, 
            dsize + sizeof(record_t));

        return SplitAndWriteRecord(logger_rlt.currenttail, 
                                   dsize + sizeof(record_t),
                                   &databuffer[0]);

        

  }

  default event result_t SequentialQueueI.writeTailDone(result_t success){
	  return FAIL;
  }

  /**********************************************************************
  Read Head
  ***********************************************************************/

        result_t readRecordHdr (uint32_t head_ptr) {
                uint8_t bytesRW;
                uint16_t eeprompage;
                uint16_t eepromoffset;

                bytesRW = GetBytesToReadWrite(head_ptr, &eeprompage, 
                                              &eepromoffset, sizeof(record_t));

                if (bytesRW == 255)
                {
                    dbg(DBG_ERROR, "Can't get bytes to write %d\n", bytesRW);
                    return FAIL;
                }

		//buffer too small
		if(sizeof(databuffer) < bytesRW){
                        dbg(DBG_ERROR,"Asked to read, but buffer too small %d, %d\n", 
                            bytesRW, sizeof(record_t));
			return FAIL;
		}

                dbg(DBG_ERROR, "Reading from head %d, page %d, offset %d, Bytes to read: %d, actually %d\n",
                    head_ptr, eeprompage, eepromoffset, sizeof(record_t), bytesRW);

                global_bytes_rw = 0;
                global_bytes_to_rw = sizeof(record_t);
                global_bytes_rw_now = bytesRW;

                if(call PageEEPROM.read(eeprompage, eepromoffset, 
                                        databuffer, bytesRW)==FAIL){
                                        dbg(DBG_ERROR, "PageRead failed\n");
                    dbg(DBG_ERROR,"Call PageEEPROM read failed\n");
		    return FAIL;
		}

                return SUCCESS; 
	}

	void readRecordBody(uint32_t head_ptr) {
		record_t* rhdr = (record_t*)databuffer;
		uint8_t datalength = rhdr->length;
		uint8_t hdrsize = sizeof(record_t);

                uint8_t bytesRW;
                uint16_t eeprompage;
                uint16_t eepromoffset;
                result_t res;

                // increment the total bytes we will read
                global_bytes_to_rw += datalength;
                
                bytesRW = GetBytesToReadWrite(head_ptr, &eeprompage, 
                                              &eepromoffset, datalength);
                if (bytesRW == 255)
                {
                    dbg(DBG_ERROR, "Can't get bytes to write %d, %d\n", 
                        bytesRW, datalength);
                    post taskFail();
                    return;
                }

		// not enough space in the buffer for the record 
		if (sizeof(databuffer) < sizeof(record_t) + datalength){
                        dbg(DBG_ERROR,"Asked to read, but buffer too small %d, %d\n", 
                            datalength,
                            sizeof(record_t));
			post taskFail();
			return;
		}

                global_bytes_rw_now = bytesRW;
                
                dbg(DBG_USR3,"Read record body: Reading from head %d, page %d, offset %d, bytes to read total %d, now %d\n",
                    head_ptr, eeprompage, eepromoffset, datalength, bytesRW);

                state = READ_BODY;
		cmd = READ_REC;
		res = call PageEEPROM.read(eeprompage, eepromoffset, 
                                         &databuffer[hdrsize], 
                                         bytesRW);
                if (res == FAIL){
		    dbg(DBG_ERROR,"RecordM: eeprom read body called fail %d\n",
                        res);
		    post taskFail();
		}
		return;
	}


  command result_t SequentialQueueI.readHead(){
          result_t res;	  

          if(state != IDLE){
                  dbg(DBG_ERROR, "readHead: Attempting sequential read, but another action in progress %d\n", state); 
		  return FAIL;
	  }

	  state = READ_HEADER;
	  cmd = READ_REC;
	  
          if (logger_rlt.currenthead == logger_rlt.currenttail) {
              dbg(DBG_ERROR,"Asked to read, but no more records\n");
              ReturnIdleState();
	      return NO_MORE_RECORDS;
	  }

          last_read_head = logger_rlt.currenthead;
          

          res = readRecordHdr(logger_rlt.currenthead);
          if (res != SUCCESS)
          {
              ReturnIdleState();
          }

          return res;
  }

  default event result_t SequentialQueueI.readHeadDone(uint8_t* data, uint8_t datasize, result_t success){
	  return FAIL;
  }

  
  /**********************************************************************
  UnRead Head
  ***********************************************************************/
  command result_t SequentialQueueI.unreadHead(){
	  uint32_t temp;

	  if(state != IDLE){
                  dbg(DBG_ERROR, "unreadHead: Attempting sequential unread, but another action in progress %d\n", state); 
		  return FAIL;
	  }

	  if(last_read_head == UNSET){
                  dbg(DBG_ERROR, "unreadHead: Attempting sequential unread, but no head set to unread\n");
		  return FAIL;
	  }

	  state = UNREAD;
	  cmd = WRITE_RLT;

	  //if i try to unread the head but the tail
	  //has crept up behind me then i can't unread
	  if ((logger_rlt.currenttail < logger_rlt.currenthead) &&
              (logger_rlt.currenttail > last_read_head)) {
            dbg(DBG_ERROR, "unreadHead: Attempting sequential unread, but tail has caught up to head\n");
	    last_read_head = UNSET;
            ReturnIdleState();
	    return FAIL;
	  }


	  temp = logger_rlt.currenthead;
	  logger_rlt.currenthead = last_read_head;
	  last_read_head = temp;

	  if(call SequentialRLTI.storeRLT(&logger_rlt) == FAIL){
                dbg(DBG_ERROR, "unreadHead: Attempting sequential unread, but storeRLT failed\n");
		temp = logger_rlt.currenthead;
		logger_rlt.currenthead = last_read_head;
		last_read_head = temp;
                ReturnIdleState();
		return FAIL;
	  }

	  return SUCCESS;
  }


  /**********************************************************************
  RLT Interface Events
  ***********************************************************************/
   event result_t SequentialRLTI.loadRLTDone(result_t success){
       if (success != SUCCESS) {
           dbg(DBG_ERROR, "Unable to loadRLT\n");
			
           memset(&logger_rlt,0,sizeof(rlt_t));
       }

       dbg(DBG_ERROR, "Completely loaded RLT\n");	

       ReturnIdleState();
       return SUCCESS;
   }

   event result_t SequentialRLTI.storeRLTDone(result_t success){
	   uint8_t temp;

	   if(success == SUCCESS){
		   switch(state){
			   case WRITE:
			   	break;
			   case READ_HEADER:
                           case READ_BODY:
			   	break;
			   case UNREAD:
				last_read_head = UNSET;
			   	break;
                           default:
                                dbg(DBG_ERROR, "storeRLT: Unknown state %d\n", state);
			}
		    post taskSuccess();
	   }else{
                   dbg(DBG_ERROR, "storeRLTDone: Failed\n");
		   switch(state){
			   case WRITE:
			   	logger_rlt.currenttail = decByteEEPROM(logger_rlt.currenttail, global_bytes_to_rw);
			   	break;
			   case READ_HEADER:
                            case READ_BODY:
				last_read_head = UNSET;
				logger_rlt.currenthead = decByteEEPROM(logger_rlt.currenthead, global_bytes_to_rw);
			   	break;
			   case UNREAD:
				temp = logger_rlt.currenthead;
				logger_rlt.currenthead = last_read_head;
				last_read_head = temp;
			   	break;
                           default:
                                dbg(DBG_ERROR, "storeRLT: Unknown state on failure: %d\n", 
                                    state);
		   }
		   post taskFail();
	   }
	   return SUCCESS;
   }



  /**********************************************************************
  Stat Tracker Interface
  ***********************************************************************/

#ifdef STAT_TRACKER

  command uint32_t FreeSpaceQueryI.bytesUsed(){
	if(logger_rlt.currenthead > logger_rlt.currenttail){
		return (uint32_t)((getByteEEPROMSize() - logger_rlt.currenthead) + (logger_rlt.currenttail));
	}
	if(logger_rlt.currenthead < logger_rlt.currenttail){
		return (uint32_t)(logger_rlt.currenttail - logger_rlt.currenthead);
	}
	return 0;
  }

  command uint32_t FreeSpaceQueryI.bytesFree(){
	  uint32_t bused = call FreeSpaceQueryI.bytesUsed();
	  return (uint32_t)(getByteEEPROMSize() - bused);

  }

#endif


  event result_t PageEEPROM.readDone(result_t result){
        uint16_t epage, eoffset;
        uint32_t i;

        dbg(DBG_USR3, "Read done, head %d, bytes to read %d, total bytes to read %d, Bytes read so far %d\n",
            logger_rlt.currenthead, global_bytes_rw_now, global_bytes_to_rw, global_bytes_rw_now + global_bytes_rw);

	if ((state != READ_HEADER) && (state != READ_BODY)) {
          dbg(DBG_ERROR, "Read done, but in wrong state %d\n", state);
          post taskFail();
	  return FAIL;
	}

        if(result==FAIL) {
            dbg(DBG_ERROR, "Page eeprom read done failed\n");
	    post taskFail();
	    return FAIL;
        }

        global_bytes_rw += global_bytes_rw_now;

        // in also so need to inc pointer by that value also
        logger_rlt.currenthead = incByteEEPROM(logger_rlt.currenthead, 
                                               global_bytes_rw_now);

        if (global_bytes_rw == global_bytes_to_rw)
        {
            dbg(DBG_USR3, "Read done and finished!\n");

            // we read everything we were supposed to
            if (state == READ_HEADER)
            {
                // we read the header, now time to read the rest of the record
                readRecordBody(logger_rlt.currenthead);
            }
            else
            {
                
                dbg(DBG_USR3, "Ending read: ");
                for (i=0; i<global_bytes_to_rw-1; i++)
                {
                    dbg(DBG_USR3, "%d ", databuffer[i+1]);

                }

                dbg(DBG_USR3, "\n");

		  cmd = WRITE_RLT;
		  if(call SequentialRLTI.storeRLT(&logger_rlt) == FAIL){
                        dbg(DBG_ERROR, "writeTail: storeRLT Failed\n");
			last_read_head = UNSET;
			logger_rlt.currenthead = 
                            decByteEEPROM(logger_rlt.currenthead, 
                                          global_bytes_to_rw);
			post taskFail();
                        return FAIL;
		  }

                // we read the whole record, signal to the caller    
                
            }

        }
        else
        {
            

            global_bytes_rw_now = global_bytes_to_rw - global_bytes_rw;

            epage = getEEPROMPage(logger_rlt.currenthead);
            eoffset = getEEPROMOffset(logger_rlt.currenthead);

            dbg(DBG_USR3, "Read done and not finished, %d done, %d to go, page %d, offset %d, head %d!\n",
                global_bytes_rw, global_bytes_to_rw - global_bytes_rw,
                epage, eoffset, logger_rlt.currenthead);

            // didn't finish reading the whole record, finish it
            if (call PageEEPROM.read(epage, eoffset,
                                     &databuffer[global_bytes_rw], 
                                     global_bytes_rw_now) == FAIL){
                    dbg(DBG_ERROR,"Call PageEEPROM read failed 2\n");
                    post taskFail();
		    return FAIL;
	    } 
        }

	return SUCCESS;
  }


  event result_t PageEEPROM.writeDone(result_t result){
        result_t res;

	if(state != WRITE) {
            dbg(DBG_ERROR,"Call PageEEPROM write done, not in write state %d\n",
                state);
	    return FAIL;
	}

        if (result != SUCCESS)
        {
            dbg(DBG_ERROR,"Call PageEEPROM write done failed\n");
            post taskFail();
	    return FAIL;

        }

        global_bytes_rw += global_bytes_rw_now;

        // the size value here is equal to the lenght of the data sent 
        // into the queue + size of the record header attached to it
	logger_rlt.currenttail = incByteEEPROM(logger_rlt.currenttail, 
                                               global_bytes_rw_now);

        dbg(DBG_USR3,"Ending write: Current Tail: %d, Current Head %d, bytes to write %d\n", 
            logger_rlt.currenttail, logger_rlt.currenthead, 
            global_bytes_to_rw - global_bytes_rw);

	dbg(DBG_USR3,"QUEUE: after write currenttail was incremented by %i to %i \n",
            global_bytes_to_rw, logger_rlt.currenttail);

        if (global_bytes_rw != global_bytes_to_rw)
        {
            // we didn't write the entire record
            res = SplitAndWriteRecord(logger_rlt.currenttail, 
                                      global_bytes_to_rw - global_bytes_rw,
                                      &databuffer[global_bytes_rw]);
            if (res != SUCCESS)
            {
                post taskFail();
            }
            return res;
        }

	cmd = WRITE_RLT;
	if (call SequentialRLTI.storeRLT(&logger_rlt) == FAIL){
	    dbg(DBG_ERROR, "storeRLT: Failed\n");
            logger_rlt.currenttail = decByteEEPROM(logger_rlt.currenttail, 
                                                   global_bytes_to_rw);
	    post taskFail();
            return FAIL;
	}

        return SUCCESS;
  }


  /**********************************************************************
  Remaining Page EEPROM Interfaces
  ***********************************************************************/

  event result_t PageEEPROM.eraseDone(result_t result){
  	return SUCCESS;
  }
  event result_t PageEEPROM.syncDone(result_t result){
  	return SUCCESS;
  }
  event result_t PageEEPROM.flushDone(result_t result){
  	return SUCCESS;
  }
  event result_t PageEEPROM.computeCrcDone(result_t result, uint16_t crc){
  	return SUCCESS;
  }


}


