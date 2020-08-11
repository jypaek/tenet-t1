
includes eeprom_logger;

module SequentialRLTM {
  provides {
    interface StdControl;
   interface SequentialRLTI;
  }uses {
    interface SequentialPageMetaI;
    interface Leds;
  }
}implementation {

#define UNSET 0xFFFFFFFF
  
enum{
	IDLE,
	LOAD,
	STORE_HEAD,
	UNSTORE_HEAD,
	STORE_TAIL,
	UNSTORE_TAIL
};

enum{
  NO_OP,
  LOAD_META,
  STORE_READ,
  STORE_SET,
};

  // Used to help check the validity of the eeprom.
enum{
  NONE_FOUND,
  ONE_FOUND_FIRST_PAGE,
  ONE_FOUND_NOT_FIRST_PAGE,
  SECOND_FOUND,
  INVALID,
};

  // Used during initial bootup to keep track of the "validity" of the eeprom.
  uint8_t valid_head;
  uint8_t valid_tail;

  uint8_t state;
  uint8_t cmd;
  uint32_t last_stored_head;
  uint32_t last_stored_tail;
  uint16_t set_value;
  pagemeta_t pm;
  rlt_t* rlt;

  uint16_t eeprompage;

  task void taskSuccess();
  task void taskFail();
  
  /**********************************************************************
  Functions
  ***********************************************************************/

  /*
   * Changes the head stored on the EEPROM at page 'eeprompage'.
   * Note that we first need to read the current tail pointer on the eeprom 
   * page in order to keep it around until it is ready to be removed from 
   * eeprom.
   *
   * Input: uint16_t val - The new head offset to write to eeprom.
   */
  result_t setHead(uint16_t val) {
    // To continue execution when the readPageMetaDone callback is called.
    cmd = STORE_READ;
    // Save until ready to be written to EEPROM.
    set_value = val;
    // First read the page meta to maintain the tail offset.
    if (call SequentialPageMetaI.readPageMeta(eeprompage, &pm) == FAIL) {
      post taskFail();
    }
    return SUCCESS;
  }

  /*
   * Whenever the current RLT head pointer is changed, we need to update
   * the head in EEPROM.  Note that these changes are not actually written
   * to EEPROM until a flush buffer is called, they are simply buffered in
   * memory.
   */  
	result_t storeChangedHead(){
		uint16_t currentpage = getEEPROMPage(rlt->currenthead);

		dbg(DBG_USR2,"STORE RTL: changed head: storing eeprom page %i \n",currentpage);

		eeprompage = currentpage;
        // Set the head.
		return setHead(getEEPROMOffset(rlt->currenthead));
	}

  /*
   * After a head pointer has been written on the next page in EEPROM,
   * we can safely remove the previous head pointer.  Do it now.
   */
  result_t unstoreChangedHead() {
    // Which page has the last head?
    uint16_t lastpage = getEEPROMPage(last_stored_head);
    
    dbg(DBG_USR2,"STORE RTL: changed head: unstoring eeprom page %i \n",lastpage);
    
    eeprompage = lastpage;
    // Set the head.
    return setHead(0);
  }
  
  /*
   * Changes the tail pointer of the page meta on the page 'eeprompage'
   * to val.  Note that these changes are buffered and not actually
   * written to EEPROM until a flush buffer is called.  Also note
   * that we first read the current head_offset in eeprom to sustain it through 
   * the write.
   *
   * Input: uint16_t val - The new tail offset to write to eeprom.
   */
  result_t setTail(uint16_t val){
    // To continue execution in readPageMetaDone.
    cmd = STORE_READ;
    // Save the value to be written later in readPageMetaDone.
    set_value = val;
    // First read the head to save it through the write.
    if (call SequentialPageMetaI.readPageMeta(eeprompage, &pm) == FAIL) {
      post taskFail();
    }
    return SUCCESS;
  }

  /*
   * After a tail pointer has been written to the next page in eeprom
   * (not just buffered in memory), it is safe to remove the old tail
   * pointer.  We can deal with two tail pointers, we cannot deal with
   * no pointers.
   */
  result_t unstoreChangedTail() {
    // What page to remove the tail pointer from?
    uint16_t lastpage = getEEPROMPage(last_stored_tail);
    
    dbg(DBG_USR2,"STORE RTL: changed tail: unstoring eeprom page %i \n",lastpage);
    
    eeprompage = lastpage;
    // Remove it.
    return setTail(0);
  }

  /*
   * Called whenever the tail pointer changes to update the tail.
   */
  result_t storeChangedTail(){
    // Which page to write it too?
    uint16_t currentpage = getEEPROMPage(rlt->currenttail);
    
    dbg(DBG_USR2,"STORE RTL: changed tail: storing eeprom page %i \n",currentpage);
    
    eeprompage = currentpage;
    // Update it.
    return setTail(getEEPROMOffset(rlt->currenttail));
	}

  /*
   * Only called when the mote is first booted.  After the entire set of
   * page metas have been read in, we can set the rlt.
   */
  result_t finalizeMeta() {
    

    if(rlt->currenthead == UNSET && rlt->currenttail == UNSET){
      dbg(DBG_USR3,"LOAD RTL: No existing RLT found.  Starting at 0. \n");
      last_stored_head=UNSET;
      last_stored_tail=UNSET;
      rlt->currenthead=0;
      rlt->currenttail=0;
    } else if (rlt->currenthead != UNSET && rlt->currenttail != UNSET){
      dbg(DBG_ERROR,"LOAD RTL: Found an existing RLT (head=%i,tail=%i). \n",rlt->currenthead, rlt->currenttail);
      last_stored_head = rlt->currenthead;
      last_stored_tail = rlt->currenttail;
    }else{
      dbg(DBG_ERROR,"LOAD RTL: Did not find complete head-tail pair (head=%i,tail=%i). reseting to 0. \n",rlt->currenthead, rlt->currenttail);
      last_stored_head=UNSET;
      last_stored_tail=UNSET;
      rlt->currenthead=0;
      rlt->currenttail=0;
    }
    post taskSuccess();
    return SUCCESS;
  }
  
  /*
   * Called in a loop on every page in eeprom.  Simply attempt to
   * read each page meta and load its offset.
   */
  result_t loadMeta(){  
    // We're done, load the metas into the rlt.
    if(eeprompage > RECORD_END_PAGE){
      return finalizeMeta();
    }
    
    dbg(DBG_USR3,"LOAD RTL: loading eeprom page %i out of %d\n", eeprompage,
	RECORD_END_PAGE);
    
    // Read the next pageMeta.
    if(call SequentialPageMetaI.readPageMeta(eeprompage, &pm)==FAIL){
      post taskFail();
    }
    
    return SUCCESS;
  }

  /*
   * Called after a pageMeta has been loaded from eeprom to check
   * its validity.  This is also where the validity of the eeprom
   * as a whole is checked.  A "valid" eeprom is once in which there
   * are ONE or TWO head pointers AND ONE or TWO tail pointers.
   * A perfect eeprom would have exactly ONE of each, but a mote
   * that has been shutdown at an inopertune time could possibly
   * have TWO of one or the other.  If the eeprom is not valid,
   * we will ignore all data and start from scratch.
   * NOTE: (Sorry this is so long) We want to take the FIRST head pointer
   * found in eeprom and the FIRST tail pointer.  However, if the mote
   * happened to be resarted right when we are looping in eeprom back
   * to the beginning page, the order will be opposite.  Since we are using the
   * first pointers, we don't have delete any extraneous pointers as they
   * will be immediately overwritten anyway.
   */
  result_t checkMeta(){
    uint32_t head = UNSET;
    uint32_t tail = UNSET;
    
    // A valid offset must land somewhere inside the eeprom.
    if(pm.head_offset > 0 && pm.head_offset < EEPROM_PAGE_SIZE){
      // Update validity checks.
      switch(valid_head) {
        // First head found, check if on first page or not.
      case NONE_FOUND:
        if (eeprompage == RECORD_START_PAGE) {
          valid_head = ONE_FOUND_FIRST_PAGE;
          // Set it, overwrite it later if a more valid head is found.
          head = getByteOffset(eeprompage, pm.head_offset);
        } else {
          valid_head = ONE_FOUND_NOT_FIRST_PAGE;
          // Set it.
          head = getByteOffset(eeprompage, pm.head_offset);
        }
        break;
        // One was already found, is the new one at the end or not?
      case ONE_FOUND_FIRST_PAGE:
        // If it's on the last page, its actually the FIRST head pointer, use it.
        if (eeprompage == RECORD_END_PAGE) {
          valid_head = SECOND_FOUND;
          head = getByteOffset(eeprompage, pm.head_offset);
          // If its NOT on the last page, its the second pointer, ignore it.
        } else {
          valid_head = SECOND_FOUND;
        }
        break;
        // Always ignore this pointer.
      case ONE_FOUND_NOT_FIRST_PAGE:
        valid_head=SECOND_FOUND;
        break;
        // If we find a third of anything, immediately invalidate all records.
      case SECOND_FOUND:
        rlt->currenthead = UNSET;
        rlt->currenttail = UNSET;
        last_stored_head = UNSET;
        last_stored_tail = UNSET;
        valid_head       = INVALID;
        valid_tail       = INVALID;
        break;
        // We are in an invalid state, ignore all remaining data and start from
        // ..scratch.
      case INVALID:
        break;
      default:
        break;
      }
    }
    // A valid offset must land somewhere inside the eeprom.
    if(pm.tail_offset > 0 && pm.tail_offset < EEPROM_PAGE_SIZE){
      tail = getByteOffset(eeprompage, pm.tail_offset);

      // Update validity checks.
      switch(valid_tail) {
      case NONE_FOUND:
        if (eeprompage == RECORD_START_PAGE) {
          valid_tail = ONE_FOUND_FIRST_PAGE;
          // Set it, overwrite it later if a more valid tail is found.                        
          tail = getByteOffset(eeprompage, pm.tail_offset);
        } else {
          valid_tail = ONE_FOUND_NOT_FIRST_PAGE;
          // Set it.
          tail = getByteOffset(eeprompage, pm.tail_offset);
        }
        break;
      case ONE_FOUND_FIRST_PAGE:
        // If it's on the last page, its actually the FIRST tail pointer, use it.
        if (eeprompage == RECORD_END_PAGE) {
          valid_tail = SECOND_FOUND;
          tail = getByteOffset(eeprompage, pm.tail_offset);
            // If its NOT on the last page, its the second pointer, ignore.    
        } else {
          valid_tail = SECOND_FOUND;
        }
        break;
        // Ignore the second tail no matter what in this case.                  
      case ONE_FOUND_NOT_FIRST_PAGE:
        valid_tail=SECOND_FOUND;
        break;
        // If we find a third of anything, immediately invalidate all records.                
      case SECOND_FOUND:
        rlt->currenthead = UNSET;
        rlt->currenttail = UNSET;
        last_stored_head = UNSET;
        last_stored_tail = UNSET;
        valid_head       = INVALID;
        valid_tail       = INVALID;
        break;
        // We are in an invalid state, ignore all remaining data and start from               
        // ..scratch.                                                                         
      case INVALID:
        break;
      default:
        break;
      }
    }
    
    if(tail != UNSET){
      dbg(DBG_USR3,"LOAD RTL: found tail %i \n", tail);
      rlt->currenttail = tail;
    }
    if(head != UNSET){
      dbg(DBG_USR3,"LOAD RTL: found head %i \n",head);
      rlt->currenthead = head;
    }
    
    eeprompage++;
    return loadMeta();
  }
  
  /*
   * Simple error handling function.
   *
   * Input: result_t result - Either SUCCESS or FAIL.
   */
  void signalResult(result_t result){
    uint8_t ostate = state;
    state = IDLE;
    cmd = NO_OP;
    switch(ostate){
    case LOAD:
      dbg(DBG_ERROR,"Load RLT done signal\n");
      signal SequentialRLTI.loadRLTDone(result);
      break;
    case STORE_HEAD:
    case STORE_TAIL:
    case UNSTORE_HEAD:
    case UNSTORE_TAIL:
      signal SequentialRLTI.storeRLTDone(result);
      break;
    }
  }
  
  
  /**********************************************************************
   * Tasks
   **********************************************************************/

	task void taskSuccess(){
		signalResult(SUCCESS);
	}

	task void taskFail(){
		signalResult(FAIL);
	}


  /**********************************************************************
   * StdControl Interface
   **********************************************************************/

  command result_t StdControl.init(){
    return SUCCESS;
  }

  command result_t StdControl.start() {
    state=IDLE;
    cmd=NO_OP;
    last_stored_head=UNSET;
    last_stored_tail=UNSET;
    valid_head = NONE_FOUND;
    valid_tail = NONE_FOUND;
    memset(&pm, 0,sizeof(pagemeta_t));
    return SUCCESS;
  }

  command result_t StdControl.stop() {
    return SUCCESS;

  }

  /**********************************************************************
   * Load RLT
   **********************************************************************/

  /*
   * Called from SequentialQueueM when the module is first booted.
   * Will read through the eeprom and load the RLT into memory.
   *
   * Input: rlt_t* logger_rlt - A pointer to the RLT stored in 
   *        SequentialQueueM.
   */
  command result_t SequentialRLTI.loadRLT(rlt_t* logger_rlt){
	if(state != IDLE){
		return FAIL;
	}

	state = LOAD;
	cmd = LOAD_META;
	eeprompage = RECORD_START_PAGE;
	rlt = logger_rlt;
	rlt->currenthead = UNSET;
	rlt->currenttail = UNSET;
    last_stored_head=UNSET;
    last_stored_tail=UNSET;

    // Beginning the loading process.
	loadMeta();

	return SUCCESS;

  }

  default event result_t SequentialRLTI.loadRLTDone(result_t success) {
	  return FAIL;
  }


  /**********************************************************************
   * Store RLT
   **********************************************************************/



  /*
   * Called whenever a record is written to or removed from the EEPROM.
   * Checks to see what has changed (if anything), and updates them 
   * appropriately.
   *
   * Input: rlt_t* logger_rlt - A pointer to the RLT stored in
   *        SequentialQueueM.
   */
  command result_t SequentialRLTI.storeRLT(rlt_t* logger_rlt) {
    // If we're doing something, fail out.
    if(state != IDLE){
      return FAIL;
    }
    
    rlt = logger_rlt;
    // If the head has changed, store it to EEPROM.
    if(last_stored_head != rlt->currenthead){
      state=STORE_HEAD;
      storeChangedHead();
      // If the tail has changed, store it to EEPROM.
    }else if(last_stored_tail != rlt->currenttail){
      state=STORE_TAIL;
      storeChangedTail();
    }
    
    return SUCCESS;
    
  }
  
	default event result_t SequentialRLTI.storeRLTDone(result_t success){
		return FAIL;
	}








  /**********************************************************************
  PageMeta Events
  ***********************************************************************/

  event result_t SequentialPageMetaI.readPageMetaDone(result_t success){

    if(success == SUCCESS){
      switch(state){
        // Currently loading something from the EEPROM.
      case LOAD:
        switch(cmd) {
          // In the middle of loading a PageMeta.  Check it to
          // see if it is valid.
	    case LOAD_META:
	      checkMeta();
	      break;
	    default:
	      break;
        }
        break;
        // Currently storing a new head to the eeprom.
      case STORE_HEAD:
        switch(cmd) {
          // Just finished reading the old values to save the tail
          // ..currently in EEPROM.  Now write the new head.
	    case STORE_READ:
	      cmd=STORE_SET;
          // Move the previously saved value into the pm to be written.
	      pm.head_offset = set_value;
          // Write the head offset out to the eeprom buffer.
	      if (call SequentialPageMetaI.writePageMeta(eeprompage, &pm) == FAIL) {
            post taskFail();
	      }
	      break;
	    default:
	      break;
        }
        break;
        // Currently sotring a new tail to the eeprom.
      case STORE_TAIL:
        switch(cmd) {
          // Just finished reading the old values to save the head
          // ..currently in eeprom.  Now write the new tail.
	    case STORE_READ:
	      cmd=STORE_SET;
          // Move teh value to be written into the pm.
	      pm.tail_offset = set_value;
	      if (call SequentialPageMetaI.writePageMeta(eeprompage, &pm) == FAIL) {
            post taskFail();
	      }
	      break;
	    default:
	      break;
	  }
	  break;
      // Removing a head from the EEPROM (setting it to 0).
	case UNSTORE_HEAD:
	  switch(cmd) {
        // Just finished reading the current tail offset value
        // ..so we don't delete that as well.
	    case STORE_READ:
	      cmd=STORE_SET;
          // Write the new tail value (0).
	      pm.head_offset = set_value;
	      if (call SequentialPageMetaI.writePageMeta(eeprompage, &pm) == FAIL) {
            post taskFail();
	      }
	      break;
      default:
        break;
	  }
	  break;
      // Removing a tail from the EEPROM (setting it to 0).
      case UNSTORE_TAIL:
        switch(cmd) {
          // Just finished reading the current head offset value
          // ..so we don't delete that as well.
	    case STORE_READ:
	      cmd=STORE_SET;
          // Write the new head value (0).
	      pm.tail_offset = set_value;
	      if (call SequentialPageMetaI.writePageMeta(eeprompage, &pm) == FAIL) {
            post taskFail();
	      }
	      break;
	    default:
	      break;
        }
        break;
        
      }
    } else {
      post taskFail();
    }
    return SUCCESS;
  }
  
  /*
   * Called after a new page meta has been written.  We do a few checks here
   * to maintian RLT consistency.  
   */  
  event result_t SequentialPageMetaI.writePageMetaDone(result_t success){
    uint16_t lastpage = 0;
    uint16_t currentpage = 0;
    
    if(success == SUCCESS) {
      switch(state) {
      case STORE_HEAD:
        switch(cmd) {
          // The new head has been written.  Now we compare it to the last
          // ..stored head.  If they are on the same page, we check to
          // ..see if the tail needs storing.  If not, we need to unstore
          // ..the old head.  To do this safely, we first need to be sure
          // ..the NEW head written has been flushed to EEPROM (not just buffered).
          // THEN, we can safely remove the old head (and flush that to buffer).
	    case STORE_SET:
	      lastpage = getEEPROMPage(last_stored_head);
	      currentpage = getEEPROMPage(rlt->currenthead);
	      
          // If the two pages are the same, do some baloney stuff.
	      if (lastpage == currentpage || last_stored_head == UNSET) {
            last_stored_head = rlt->currenthead;
            if (last_stored_tail != rlt->currenttail) {
              state=STORE_TAIL;
              storeChangedTail();
            } else {
              post taskSuccess();
            }
            // They are not the same, now its a bit more interesting.
	      } else {
            // First flush the current buffer onto the EEPROM.  The flush needs
            // ..to be done or else if the mote is restarted, there will be no
            // ..head pointer on flash.  Then call unstoreChangedhead.
            if (call SequentialPageMetaI.flushPage(currentpage) == FAIL) {
              post taskFail();
            }
	      }
	      break;
	    default:
	      break;
        }
	  break;
	case UNSTORE_HEAD:
	  switch(cmd){
      case STORE_SET:
        // Now that the head has been unstored, it is necessary to flush the
        // ..eeprom page out onto the eeprom.  This will have to be done
        // ..eventually anyway, so we might as well do it now.
        lastpage = getEEPROMPage(last_stored_head);
        if (call SequentialPageMetaI.flushPage(lastpage) == FAIL) {
          post taskFail();
        }

        break;
      default:
        break;
	  }
	  break;
	  
      case STORE_TAIL:
        switch(cmd){
	    case STORE_SET:
	      lastpage = getEEPROMPage(last_stored_tail);
	      currentpage = getEEPROMPage(rlt->currenttail);
	      if(lastpage == currentpage || last_stored_tail == UNSET){
            last_stored_tail = rlt->currenttail;
            post taskSuccess();
	      }else{
            // First flush the current buffer onto the EEPROM.  The flush needs
            // ..to be done or else if the mote is restarted, there will be no
            // ..tail pointer on flash.  Then call unstoreChangedTail.
            if (call SequentialPageMetaI.flushPage(currentpage) == FAIL) {
              post taskFail();
            }
	      }
	      break;
	    default:
	      break;
        }
        break;
      case UNSTORE_TAIL:
        switch(cmd){
	    case STORE_SET:
          lastpage = getEEPROMPage(last_stored_tail);
          if (call SequentialPageMetaI.flushPage(lastpage) == FAIL) {
            post taskFail();
          }
	      break;
	    default:
	      break;
        }
        break;
      default:
        break;
      }
    }else{
      post taskFail();
    }
    
    return SUCCESS;
  }

  /*
   * A page is only manually flushed when it is imperative to keep the EEPROM
   * in a good state.  A poor state is when no head or tail pointers exist.
   */
  event result_t SequentialPageMetaI.flushPageDone(result_t success){
    if (success == SUCCESS){
      switch(state) {
        // Now that the new head pointer is safely in EEPROM (there are now two
        // ..headers in EEPROM), we can delete the old one.  If, for some
        // ..ungodly reason, we lose power before the old head pointer can
        // ..be removed, we will handle this at startup (which is the reason
        // ..for having both in EEPROM at once in the first place...).
      case STORE_HEAD:
        switch(cmd) {
        case STORE_SET:
          state = UNSTORE_HEAD;
          unstoreChangedHead();
          break;
        default:
          break;
        }
        break;
        /*
         * Now the entire business with changing the head pointer has been
         * done (whew).  Lets check the tail real quick then exit out.
         */
      case UNSTORE_HEAD:
        switch (cmd) {
        case STORE_SET:
          last_stored_head = rlt->currenthead;
          // tail also changed, set the new tail.
          if (last_stored_tail != rlt->currenttail) {
            state=STORE_TAIL;
            storeChangedTail();
          } else {
            post taskSuccess();
          }
          break;
        default:
          break;
        }
        break;
        // Now that the new tail pointer is safely in EEPROM (there are now two
        // ..tails in EEPROM), we can delete the old one.  If, for some
        // ..ungodly reason, we lose power before the old tail pointer can
        // ..be removed, we will handle this at startup (which is the reason
        // ..for having both in EEPROM at once in the first place...).
      case STORE_TAIL:
        switch(cmd) {
        case STORE_SET:
          state = UNSTORE_TAIL;
          unstoreChangedTail();
          break;
        default:
          break;
        }
        /*
         * Now the entire business with changing the head pointer has been
         * done (whew).  Lets exit out.
         */
      case UNSTORE_TAIL:
        switch(cmd) {
        case STORE_SET:
          last_stored_tail = rlt->currenttail;
          post taskSuccess();
        }
        break;
      default:
        break;
      }
    }
    else {
      post taskFail();
    }

    return SUCCESS;
  }
  
}
