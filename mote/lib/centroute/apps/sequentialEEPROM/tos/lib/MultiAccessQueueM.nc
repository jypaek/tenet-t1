
includes eeprom_logger;

module MultiAccessQueueM {
  provides {
    interface StdControl;
    interface SequentialQueueI[uint8_t id];
  }uses {
    interface SequentialQueueI as SingleQueueI;
    interface Leds;
    
#ifdef DIST_STORAGE
    interface DistControllerI;
#endif

  }
}implementation {


#define NUM_ACCESS 4

enum
  {
    IDLE,
    WORKING
  };
 
 enum
   {
     READHEAD,
     UNREADHEAD,
     WRITETAIL,
     ISEMPTY
   };
 
 
 typedef struct _macmd{
   uint8_t cmd;
   uint8_t id;
   uint8_t* data;
   uint8_t  datasize;
   
 } __attribute__ ((packed)) ma_cmd_t;
 
 uint8_t state;
 ma_cmd_t malist[NUM_ACCESS];
 uint8_t listhead;
 uint8_t listtail;
 
 
 task void signalSuccess();
 task void signalFail();
 
  

 
  /**********************************************************************
  Functions
  ***********************************************************************/
  
  uint8_t incListPtr(uint8_t lp){
    lp++;
    if(lp >= NUM_ACCESS){
      lp=0;
    }
    return lp;
  }
  
  void signalResult(result_t res){
    uint8_t donecmd = malist[listhead].cmd;
    uint8_t doneid = malist[listhead].id;
    uint8_t* donedata = malist[listhead].data;
    uint8_t donedsize = malist[listhead].datasize;
    int more_in_list;
    
    dbg(DBG_USR2,"MultiAccess:: Signalling %i to %i\n",donecmd,doneid);
    
    
    listhead = incListPtr(listhead);
    if (listhead == listtail)
    {
        // nothing more in list, we will return after signalling
        more_in_list = 0;
    }
    else
    {
        // there are more items in the queue, we process them after signalling
        more_in_list = 1;
    }
    
    dbg(DBG_USR3,"Signal result: head=%i tail=%i\n",listhead,listtail);

    switch(donecmd){
      case READHEAD: dbg(DBG_USR3,"MultiAccess::ReadHead Done\n"); signal SequentialQueueI.readHeadDone[doneid](donedata,donedsize,res);break;
      case UNREADHEAD: dbg(DBG_USR3,"MultiAccess::UnReadHead Done\n"); signal SequentialQueueI.unreadHeadDone[doneid](res);break;
      case WRITETAIL: dbg(DBG_USR3,"MultiAccess::WriteTail Done\n"); signal SequentialQueueI.writeTailDone[doneid](res);break;
      default: dbg(DBG_ERROR,"MultiAccess::Unknown Donecmd: %d\n", donecmd); break;

    }
    
    //check if there are any remaining items in the list
    if(more_in_list == 1){
      result_t reslocal;
      dbg(DBG_USR3,"MultiAccess:: Processing next cmd in list %i head=%i,tail=%i\n",malist[listhead].cmd,listhead,listtail);
      
      switch(malist[listhead].cmd){
	case READHEAD:
	  if(call SingleQueueI.readHead()==FAIL){
	    post signalFail();
	  }
	  break;
	case UNREADHEAD:
          dbg(DBG_USR3,"Unreading from single queue\n");
	  if(call SingleQueueI.unreadHead()==FAIL){
	    post signalFail();
	  }
	  break;
	case WRITETAIL:
	  
#ifdef DIST_STORAGE
	  //check if we should distribute this
	  if(call DistControllerI.shouldDistribute() == SUCCESS){
	    reslocal = call DistControllerI.distribute(malist[listhead].data,malist[listhead].datasize);
	    //failed to send then try to store
	    if(reslocal != SUCCESS){
	      //else store it
	      reslocal = call SingleQueueI.writeTail(malist[listhead].data,malist[listhead].datasize);
	      if(reslocal!=SUCCESS){
		post signalFail();
	      }
	    }
	    
	  }else{
	    //else store it
	    reslocal = call SingleQueueI.writeTail(malist[listhead].data,malist[listhead].datasize);
	    if(reslocal!=SUCCESS){
	      post signalFail();
	    }
	  }
#else
	  //store data
	  reslocal = call SingleQueueI.writeTail(malist[listhead].data,malist[listhead].datasize);
	  if(reslocal!=SUCCESS){
	    post signalFail();
	  }
#endif  
	  break;
      }
    }
    dbg(DBG_USR3,"Signal result: Returning!\n");  
  }
  

  /**********************************************************************
  Tasks
  ***********************************************************************/
  task void signalSuccess(){
    signalResult(SUCCESS);
  }
  
  task void signalFail(){
    signalResult(FAIL);
  }
  
  /**********************************************************************
  StdControl Interface
  ***********************************************************************/

  command result_t StdControl.init(){
    return SUCCESS;
  }
  
  command result_t StdControl.start() {
    state = IDLE;
    listhead=0;
    listtail=0;
    memset(malist, 0,sizeof(malist));

    return SUCCESS;
  }
  
  command result_t StdControl.stop() {
    return SUCCESS;
    
  }
  
  
  /**********************************************************************
  Empty Queue?
  ***********************************************************************/
  /*
  This command is misleading.  It gives you the instantaneous empty status
  not the one that considers the events queued before it.  If you want a queued
  response use readHead and the NO_MORE_RECORDS response
  */
  command uint8_t SequentialQueueI.isQueueEmpty[uint8_t id](){
    return call SingleQueueI.isQueueEmpty();
  }
  
  
  /**********************************************************************
  Write Log
  ***********************************************************************/
  command result_t SequentialQueueI.writeTail[uint8_t id](uint8_t *data, uint8_t numBytesWrite){
    //buffer is full
    if(incListPtr(listtail) == listhead){
      dbg(DBG_ERROR,"MultiAccess:: No space in temporary storage\n");
      return FAIL;
    }
    
    //add entry into list
    malist[listtail].cmd=WRITETAIL;
    malist[listtail].id=id;
    malist[listtail].data = data;
    malist[listtail].datasize = numBytesWrite;
    
    dbg(DBG_USR3,"MultiAccess:: Storing writeTail at head=%i tail=%i\n",listhead,listtail);
    
    //check if empty list
    if(listhead == listtail){
      result_t res;
      listtail = incListPtr(listtail);
      
      
#ifdef DIST_STORAGE
      //check if we should distribute this
      if(call DistControllerI.shouldDistribute() == SUCCESS){
	res = call DistControllerI.distribute(data,numBytesWrite);
	//if failed to send store it
	if(res != SUCCESS){
	  res = call SingleQueueI.writeTail(data,numBytesWrite);
	  if(res != SUCCESS){
	    listhead = incListPtr(listhead);
	  }
	}
	
      }else{
	//else store it
	res = call SingleQueueI.writeTail(data,numBytesWrite);
	if(res != SUCCESS){
	  listhead = incListPtr(listhead);
	}
      }
      return res;
#else
      //store data
      res = call SingleQueueI.writeTail(data,numBytesWrite);
      if(res != SUCCESS){
	listhead = incListPtr(listhead);
      }
      return res;
#endif

    }else{
      listtail = incListPtr(listtail);
    }

    return SUCCESS;
    
  }
  
  default event result_t SequentialQueueI.writeTailDone[uint8_t id](result_t success){
    return FAIL;
  }
  
  event result_t SingleQueueI.writeTailDone(result_t success){
    
    dbg(DBG_USR2,"MultiAccess:: Storing writeTail Done \n");
    
    if(success==SUCCESS){
      post signalSuccess();
    }else{
      post signalFail();
    }
    return SUCCESS;
  }
  
  
  /**********************************************************************
  Read Head
  ***********************************************************************/
  
  
  command result_t SequentialQueueI.readHead[uint8_t id](){
    
    //buffer is full
    if(incListPtr(listtail) == listhead){
      dbg(DBG_ERROR,"MultiAccess:: Can't read, buffer full\n");
      return FAIL;
    }
    
    //add entry into list
    malist[listtail].cmd=READHEAD;
    malist[listtail].id=id;
    malist[listtail].data = 0;
    malist[listtail].datasize = 0;
    
    dbg(DBG_USR3,"MultiAccess:: Storing readHead at head=%i tail=%i\n",listhead,listtail);
    
    //check if empty list
    if(listhead == listtail){
      result_t res;
      listtail = incListPtr(listtail);
      res = call SingleQueueI.readHead();
      if(res != SUCCESS){
	listhead = incListPtr(listhead);
      }
      return res;
    }else{   
      listtail = incListPtr(listtail);
    }
    
    return SUCCESS;
  }

  default event result_t SequentialQueueI.readHeadDone[uint8_t id](uint8_t* data, uint8_t datasize, result_t success){
    return FAIL;
  }
  
  event result_t SingleQueueI.readHeadDone(uint8_t* data, uint8_t datasize, result_t success){
    dbg(DBG_USR2,"MultiAccess:: Storing readHead Done \n");
    
    malist[listhead].data = data;
    malist[listhead].datasize = datasize;
    
    if(success==SUCCESS){
      post signalSuccess();
    }else{
      post signalFail();
    }
    return SUCCESS;
  }
  
  
  /**********************************************************************
  UnRead Head
  ***********************************************************************/
  command result_t SequentialQueueI.unreadHead[uint8_t id](){
    //buffer is full
    if(incListPtr(listtail) == listhead){
      dbg(DBG_ERROR,"MultiAccess:: Can't unread, buffer full\n");
      return FAIL;
    }
    
    //add entry into list
    malist[listtail].cmd=UNREADHEAD;
    malist[listtail].id=id;
    malist[listtail].data = 0;
    malist[listtail].datasize = 0;
    
    dbg(DBG_USR3,"MultiAccess:: Storing unreadHead at head=%i tail=%i\n",listhead,listtail);
    
    //check if empty list
    if(listhead == listtail){
      result_t res;
      listtail = incListPtr(listtail);
      dbg(DBG_USR3,"Unreading from single queue: head=%i tail=%i\n",listhead,listtail);
      res = call SingleQueueI.unreadHead();
      if(res != SUCCESS){
	listhead = incListPtr(listhead);
      }
      return res;
    }else{
      listtail = incListPtr(listtail);
    }
    
    return SUCCESS;
    
  }
  
  default event result_t SequentialQueueI.unreadHeadDone[uint8_t id](result_t res){
    return FAIL;
  }

  event result_t SingleQueueI.unreadHeadDone(result_t success){
    
    dbg(DBG_USR3,"MultiAccess:: Storing unreadHead Done \n");
    
    if(success==SUCCESS){
      post signalSuccess();
    }else{
      post signalFail();
    }
    return SUCCESS;
  }

#ifdef DIST_STORAGE
  
  /**********************************************************************
  Distribute interface
  ***********************************************************************/
  
  event result_t DistControllerI.distributeDone(result_t success){
    result_t reslocal;

    dbg(DBG_USR2,"MultiAccess:: Distribution Done \n");
    
    if(success==SUCCESS){
      post signalSuccess();
    }else{
      //if fail then try to write locally
      //code still has control of eeprom and queue
      //so dont need to schedule a write i can just write 
      //directly to the queue
      reslocal = call SingleQueueI.writeTail(malist[listhead].data,malist[listhead].datasize);
      if(reslocal!=SUCCESS){
	//if can't write then post failure
	post signalFail();
      }
    }
    return SUCCESS;

    return FAIL;
  }


#endif
  
  

}
