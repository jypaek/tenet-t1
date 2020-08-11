
includes eeprom_logger;

module SequentialPageMetaM {
  provides {
  	interface StdControl;
	interface SequentialPageMetaI;

  }uses{
    interface PageEEPROM;
    interface Leds;
  }
}implementation {

enum{
  IDLE,
  WRITE,
  READ,
  FLUSH
};

  uint8_t state;
  pagemeta_t* pagemeta;
  pagemetacompressed_t pmcomp;


  /**********************************************************************
  Function
  ***********************************************************************/

	void compressPageMeta(pagemeta_t* pm, pagemetacompressed_t* pagemetacomp){
		uint32_t compdata = 0;
		uint8_t compblob[4];
		compdata = pm->head_offset & 0x1FF;
		compdata = compdata << 9;
		compdata = compdata | (pm->tail_offset & 0x1FF);
		compdata = compdata << 14;
		compdata = compdata | (pm->num_writes & 0x3FFF);

		memcpy(compblob,&compdata,4);

		pagemetacomp->blob[0]=compblob[3];
		pagemetacomp->blob[1]=compblob[2];
		pagemetacomp->blob[2]=compblob[1];
		pagemetacomp->blob[3]=compblob[0];


		dbg(DBG_USR2,"Compressing: head_offset=%i, tail_offset=%i, num_writes=%i to %02x%02x%02x%02x \n", 
		    pm->head_offset, pm->tail_offset,pm->num_writes, pagemetacomp->blob[0],pagemetacomp->blob[1],pagemetacomp->blob[2],pagemetacomp->blob[3]);


	}

	void uncompressPageMeta(pagemeta_t* pm, pagemetacompressed_t* pagemetacomp){
		uint32_t compdata = 0;
		uint8_t compblob[4];
		compblob[3]=pagemetacomp->blob[0];
		compblob[2]=pagemetacomp->blob[1];
		compblob[1]=pagemetacomp->blob[2];
		compblob[0]=pagemetacomp->blob[3];

		memcpy(&compdata,compblob,4);
		pm->num_writes = compdata & 0x3FFF;
		compdata = compdata >> 14;
		pm->tail_offset = compdata & 0x1FF;
		compdata = compdata >> 9;
		pm->head_offset = compdata & 0x1FF;
		
	       
		dbg(DBG_USR2,"Uncompressing: head_offset=%i, tail_offset=%i, num_writes=%i to %02x%02x%02x%02x \n", 
		    pm->head_offset, pm->tail_offset,pm->num_writes,pagemetacomp->blob[0],pagemetacomp->blob[1],pagemetacomp->blob[2],pagemetacomp->blob[3]);

	}


	result_t writePageMeta(uint16_t eeprompage, pagemeta_t* pm){
		//check if eeprompage is in valid range
		if(eeprompage < RECORD_START_PAGE || eeprompage > RECORD_END_PAGE){
			state=IDLE;
			return FAIL;
		}
		compressPageMeta(pm,&pmcomp);

		if(call PageEEPROM.write(eeprompage,0,(void*)&pmcomp, sizeof(pagemetacompressed_t))==FAIL){
			state=IDLE;
			return FAIL;
		}

		return SUCCESS;
	}

	result_t readPageMeta(uint16_t eeprompage, pagemeta_t* pm){
		//check if eeprompage is in valid range
		if(eeprompage < RECORD_START_PAGE || eeprompage > RECORD_END_PAGE){
			state=IDLE;
			return FAIL;
		}

		//save pagemeta pointer across read call
		pagemeta = pm;

		if(call PageEEPROM.read(eeprompage,0,(void*)&pmcomp, sizeof(pagemetacompressed_t))==FAIL){
			state=IDLE;
			return FAIL;
		}

		return SUCCESS;

	}

  result_t flushPage(uint16_t eeprompage) {
    	//check if eeprompage is in valid range
		if(eeprompage < RECORD_START_PAGE || eeprompage > RECORD_END_PAGE){
			state=IDLE;
			return FAIL;
		}

        if (call PageEEPROM.flush(eeprompage) == FAIL) {
          state = IDLE;
          return FAIL;
        }

    return SUCCESS;
  }


	void signalResult(result_t result){
		uint8_t ostate = state;
		state = IDLE;
		switch(ostate){
          case WRITE: signal SequentialPageMetaI.writePageMetaDone(result); break;
          case READ:  signal SequentialPageMetaI.readPageMetaDone(result); break;
          case FLUSH: signal SequentialPageMetaI.flushPageDone(result); break;
		}
	}


  /**********************************************************************
  Tasks
  ***********************************************************************/

	task void taskSuccess(){
		signalResult(SUCCESS);
	}

	task void taskFail(){
		signalResult(FAIL);
	}

  /**********************************************************************
  StdControl Interface
  ***********************************************************************/

  command result_t StdControl.init(){
    return SUCCESS;
  }

  command result_t StdControl.start() {
    state=IDLE;
  	memset(&pmcomp,0,sizeof(pagemetacompressed_t));
    return SUCCESS;
  }

  command result_t StdControl.stop() {
    return SUCCESS;
  }


  /**********************************************************************
  Write Page Meta Interface
  ***********************************************************************/

   command result_t SequentialPageMetaI.writePageMeta(uint16_t eeprompage, pagemeta_t* pm){
		if(state != IDLE){
			return FAIL;
		}
		state = WRITE;
		return writePageMeta(eeprompage,pm);
   }

   default event result_t SequentialPageMetaI.writePageMetaDone(result_t success){
	   return FAIL;
   }


  event result_t PageEEPROM.writeDone(result_t result){

	  if(state != WRITE){
		return FAIL;
	  }
	  if(result == FAIL){
	  	post taskFail();
	  }else{
		post taskSuccess();
	  }
	  memset(&pmcomp,0,sizeof(pagemetacompressed_t));
	  return SUCCESS;

  }



  /**********************************************************************
  Read Page Meta Interface
  ***********************************************************************/

   command result_t SequentialPageMetaI.readPageMeta(uint16_t eeprompage, pagemeta_t* pm){
	   if(state != IDLE){
		   return FAIL;
	   }

	   state = READ;
   	   return readPageMeta(eeprompage,pm);
   }

  command result_t SequentialPageMetaI.flushPage(uint16_t eeprompage) {
    if (state != IDLE) {
      return FAIL;
    }

    state = FLUSH;
    return flushPage(eeprompage);
  }

   default event result_t SequentialPageMetaI.readPageMetaDone(result_t success){
	   return FAIL;
   }


   event result_t PageEEPROM.readDone(result_t result){
	   if(state != READ){
		   return FAIL;
	   }
	   if(result == FAIL){
		   post taskFail();
	   }else{
			uncompressPageMeta(pagemeta,&pmcomp);
			post taskSuccess();
	   }
	   memset(&pmcomp,0,sizeof(pagemetacompressed_t));
	   return SUCCESS;
   }

  event result_t PageEEPROM.flushDone(result_t result) {
    if (state != FLUSH) {
      return FAIL;
    }

    if (result == FAIL) {
      post taskFail();
    } else {      
      post taskSuccess();
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
  event result_t PageEEPROM.computeCrcDone(result_t result, uint16_t crc){
  	return SUCCESS;
  }

}
