includes eeprom_logger;

module CleanEEPROMM {
	provides{
		interface StdControl;
	}uses{
		interface Timer;
		interface Leds;
		interface PageEEPROM;
	}
} implementation {

#ifdef PLATFORM_MICA2
#define printf(...);
#define fflush(...);
#endif


uint16_t currpage;

  /*************************************
  StdControl
  **************************************/
  command result_t StdControl.init(){
	call Leds.init();
    return SUCCESS;
  }

  command result_t StdControl.start() {
    call Timer.start(TIMER_ONE_SHOT,100);
    currpage = RECORD_START_PAGE;
    return SUCCESS;
  }

  command result_t StdControl.stop() {
    return SUCCESS;
  }

  task void erasep(){
    if(call PageEEPROM.erase(currpage, TOS_EEPROM_ERASE) == FAIL) {
      call Leds.redOn();
      return;
    }
    
  }


  event result_t Timer.fired(){
	call Leds.yellowOn();
	post erasep();
	return SUCCESS;
  }



  event result_t PageEEPROM.eraseDone(result_t result){
	  if(result == SUCCESS){
		  currpage++;
		  if (currpage > RECORD_END_PAGE){
			  call Timer.stop();
			  call Leds.greenOn();
			  return SUCCESS;
		  }else{
		    post erasep();
		  }

	  }else{
		  call Leds.redOn();
	  }
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

	event result_t PageEEPROM.readDone(result_t result){
	  return SUCCESS;
  	}

  event result_t PageEEPROM.writeDone(result_t result){
	  return SUCCESS;
  }


}
