
includes mDTN;
includes eeprom_logger;
includes MultihopTypes;
includes protocols;

module ESS_mDTNM {
  provides {
    interface StdControl;
    interface mDTNSendI[uint8_t id];
    interface mDTNRecvI[uint8_t id];
    interface mDTNSendRawI;
    interface mDTNRecvRawI;
  }uses {
#ifdef USE_ROUTE_ADAPTATION
    interface ApplicationI;
#else
    interface mDTNRoutingI;
    //interface SequentialQueueI as RecvQueueI;
#endif // USE_ROUTE_ADAPTATION
    interface SequentialQueueI as SendQueueI;
    interface Leds;
#ifdef EMSTAR_NO_KERNEL
    interface EmTimerI as ForwardTimer;
#else
    interface Timer as ForwardTimer;
#endif
#ifdef STAT_TRACKER
    interface FreeSpaceQueryI;
#endif
#ifdef USE_SYMPATHY
    interface ProvideCompMetrics;
#endif
#ifdef NODE_HEALTH
      interface NodeHealthI;
#endif
  }
}implementation {



#if defined PLATFORM_MICA2 || defined PLATFORM_MICAZ
#define printf(...);
#define fflush(...);
#endif

#include "QueryTypes.h"

#ifdef NODE_HEALTH
#include "NodeHealth.h"
#endif  

// maximum number of pending events we will record
#define MAX_PENDING_EVENTS 3

// set the application ID to this if it is not needed
#define NO_VALID_APPID 0xde
  
// state machine states
typedef enum _dtnState_t {
    IDLE,
    PENDING_ROUTE_FORWARD,
    PENDING_ROUTE_SEND,
    FORWARDING,
    SENDING,
    READING,
    UNREADING,
    STORING,
    STORING_FORWARDED
} dtnState_t;

// types of action that can be taken on incoming packets
typedef enum _dtnPacketActions_t
{
    INVALID_ACTION,
    PENDING_SEND,
    PENDING_FORWARD,
    PENDING_STORE
} dtnPacketActions_t; 

// the information to be stored with a packet awaiting action
typedef struct _pendingRecord_t
{
    // the data we will store
    uint8_t sendbuffer[MAX_RECORD_PAYLOAD];
    // how long the buffer is
    uint8_t sbsize;
    // the type of action which is required
    dtnPacketActions_t pending_action;
} pendingRecord_t;

// current send state machine state
dtnState_t send_state;

// queue of pending events
static pendingRecord_t pending_records[MAX_PENDING_EVENTS];

// count of how many events are pending
static uint8_t pending_count;
// position of the next event to handle
static uint8_t pending_position_head;
// position to write the next pending position to
static uint8_t pending_position_tail;

//sympathy recorded values
uint16_t my_stored_pkt_count;
uint16_t others_stored_pkt_count;
uint16_t current_pkts_stored;

//forward var
uint32_t fwd_chk_period;


task void HandlePending();
result_t GetFromStorage(uint8_t **data, uint8_t *length, 
                          dtnPacketActions_t *action);
result_t RemoveFromStorage();
void SendDone(result_t status, uint8_t appid);
result_t PrepareToSend(uint8_t *data, uint8_t length, uint16_t addr, 
                         uint8_t cst, uint8_t rel, uint8_t id);
result_t StoreToEEPROM();

  void printbuffer(uint8_t* buffer, int size){
    int i=0;
    for(i=0;i<size;i++){
      dbg(DBG_ERROR, "%02x ",buffer[i]);
    }
    dbg(DBG_ERROR, "\n");
    //fflush(stdout);
  }
  
  
  /**********************************************************************
  Functions
  ***********************************************************************/

  uint8_t setACR(uint8_t id, uint8_t cst, uint8_t rel){
    uint8_t acr = 0;
    
    acr = acr | (id & APPID_MSK);
    acr = acr << 1;
    acr = acr | (cst & COST_MSK);
    acr = acr << 1;
    acr = acr | (rel & RELIABLE_MSK);
    
    dbg(DBG_USR2,"DTN:: setACR appid=%i, cost=%i, reliable=%i -> acr=%02x\n", id,cst,rel,acr);
    
    return acr;
  }
  
  
  uint8_t getReliable(uint8_t acr){
    uint8_t temp = acr;
    return temp & RELIABLE_MSK;
  }

  uint8_t getCost(uint8_t acr){
    uint8_t temp = acr;
    //mv over reliable bit msk
    temp = temp >> 1;
    return temp & COST_MSK;
  }
  
  uint8_t getAppId(uint8_t acr){
    uint8_t temp = acr;
    //mv over reliable bit msk
    temp = temp >> 1;
    //mv over cost bit msk
    temp = temp >> 1;
    return temp & APPID_MSK;
  }
  
  
 
  void update_send_state(uint8_t new_send_state)
  {
      dbg(DBG_USR3, "Old send state = %d, New send state = %d\n", send_state,
	new_send_state);

      send_state = new_send_state;

      if (new_send_state == IDLE)
      {
          // returning to idle, will check if there are other
          // packets that need handling
          post HandlePending();
      }

  }


  /**********************************************************************
  Tasks
  ***********************************************************************/
 
 
  task void HandlePending(){
      uint8_t *data;
      uint8_t storage_size;
      dtnPacketActions_t action;
      result_t res;  
      mDTN_pkt_t *mdtnpkt; 
      DseHeader_t *dse;

      if (pending_count == 0)
      {
          // no pending packet transactions
          return;
      }       
      if (send_state != IDLE)
      {
          // another action still in progress, try again later
          return;
      }
      
      // grab the appid for a packet generated here
      res = GetFromStorage(&data, &storage_size, &action);
      if (res != SUCCESS)
      {
          dbg(DBG_ERROR, "DTN::Couldn't get packet from storage\n");
          update_send_state(IDLE);
          return;
      }

      mdtnpkt = (mDTN_pkt_t*)data;
      dse = (DseHeader_t *)(mdtnpkt->data);

      dbg(DBG_ERROR, "DTN::Handling pending event %d action, From %d, Seq number = %d\n", 
	action, dse->m_uiSrcAddr, dse->m_uiSeq);

      if (action == PENDING_SEND)
      {
          PrepareToSend(data, storage_size, mdtnpkt->address, 
                        getCost(mdtnpkt->acr), getReliable(mdtnpkt->acr), 
                        getAppId(mdtnpkt->acr));
      }
      else if (action == PENDING_STORE)
      {
          update_send_state(STORING_FORWARDED);
          StoreToEEPROM();
      }
      else
      {
          dbg(DBG_ERROR, "DTN::Invalid action %d!\n", action);
      }

  }
  
  
  /**********************************************************************
  StdControl Interface
  ***********************************************************************/

  command result_t StdControl.init(){
    return SUCCESS;
  }
  
  command result_t StdControl.start() {
    update_send_state(IDLE);

    memset(&pending_records[0], 0, sizeof(pending_records));
    
    pending_count = 0;
    pending_position_head = 0;
    pending_position_tail = 0;
    fwd_chk_period = ROUTE_CHECK_PERIOD;
    if (call ForwardTimer.start(TIMER_REPEAT,fwd_chk_period) == FAIL)
    {
      dbg(DBG_ERROR, "Oh noes, couldn't start forward timer!\n");
    }

#ifdef NODE_HEALTH
    // data storage module always active, at least every
    // maximum route check period
    call NodeHealthI.SetParameters(DATA_STORAGE, 
                                   DEFAULT_PROCESSING_TIME,
                                   ROUTE_CHECK_PERIOD_MAX,
                                   FLAG_RESERVED);
    call NodeHealthI.Enable(DATA_STORAGE, ENABLE); 
#endif 

    return SUCCESS;
  }

  command result_t StdControl.stop() {
    return SUCCESS;

  }

  /**********************************************************************
  Timer
  ***********************************************************************/
  
  void updateForwardTimer(result_t pkt_result){
    //first things first stop the current timer
    call ForwardTimer.stop();

    //now figure out what the new period should be
    if(pkt_result == SUCCESS){
      //in a successful fwd do an additive decrease in 
      //time required before next forward send
      if (fwd_chk_period > 2*ROUTE_CHECK_PERIOD){
        fwd_chk_period = fwd_chk_period - ROUTE_CHECK_PERIOD;
        dbg(DBG_USR3, "Modified Forward Timer to %i", fwd_chk_period);
        
      }else{
        //check to make sure we can't decrease under one check period block     
        fwd_chk_period = ROUTE_CHECK_PERIOD;
      }
    }else{
      //in failure case additively increase the time required before
      //next forward send....maybe want to do multiplicative increase like TCP
      
      fwd_chk_period = fwd_chk_period + ROUTE_CHECK_PERIOD;
      //check to make sure we don't increase over the max
      if(fwd_chk_period > ROUTE_CHECK_PERIOD_MAX){
        fwd_chk_period = ROUTE_CHECK_PERIOD_MAX;
        dbg(DBG_USR3, "Modified Forward Timer to %i", fwd_chk_period);
	    
      }
    }
      
    //now start the timer at the new period
    if (call ForwardTimer.start(TIMER_REPEAT,fwd_chk_period) == FAIL)
    {
      dbg(DBG_ERROR, "Oh noes, couldn't start forward timer 2!\n");
    }
  }

// NOTE: Don't end this event if we have data to send: need to check
// that we can search for a path to the sink correctly.
// If we fail to start the route check, don't end the event, this
// is a serious error and could mean the routing layer is stalled.
  result_t forwardHandler(){
#ifdef NODE_HEALTH
    call NodeHealthI.ActionStart(DATA_STORAGE);
#endif
    // take no action unless we are in the idle state
    if(send_state != IDLE){
      goto DoneSuccess;
      return SUCCESS;
    }
    //nothing in the queue
    if(call SendQueueI.isQueueEmpty() == 1){
      //if nothing is in my queue then i want to slowly move
      //back to lowest time
      updateForwardTimer(SUCCESS);
      goto DoneSuccess;
    }

    update_send_state(PENDING_ROUTE_FORWARD);
  
    // check if there is a path to the sink yet
#ifdef USE_ROUTE_ADAPTATION
    if ((call ApplicationI.CheckRouteAvailable()) == FAIL) {
#else
    if(call mDTNRoutingI.routeAvailable()==FAIL){
#endif
       dbg(DBG_ERROR,"DTN::Unable to check for path to sink\n");
       updateForwardTimer(FAIL);
       update_send_state(IDLE);
       return FAIL;
    }
 
    return SUCCESS;
DoneSuccess:
#ifdef NODE_HEALTH
    call NodeHealthI.ActionEnd(DATA_STORAGE);
#endif  
    return SUCCESS;
  }

  
  event result_t ForwardTimer.fired(){
    return forwardHandler();
  }
  

  result_t StoreToEEPROM()
  {
    result_t res;    
    DseHeader_t *dse;
    mDTN_pkt_t* mdtnpkt;
    uint8_t storage_size;
    dtnPacketActions_t action;
    uint8_t appid;   
    uint8_t *temp_ptr; 

    res = GetFromStorage(&temp_ptr, &storage_size, &action);
    if (res != SUCCESS)
    {
        dbg(DBG_ERROR,"DTN::Unable to get packet from storage!\n");
        return FAIL;
    }
    if ((action != PENDING_STORE) && (action != PENDING_SEND))
    {
        dbg(DBG_ERROR,"DTN::Uh oh - packet from storage incorrect action %d!\n",
            action);
        return FAIL;
    }
    
    mdtnpkt = (mDTN_pkt_t *)temp_ptr;

    appid = getAppId(mdtnpkt->acr);

    dse = (DseHeader_t *)(mdtnpkt->data);
    //qresp = (QueryResponse_t *)(dse->m_pData);

    dbg(DBG_ERROR,"DTN::STORING... From %d, Seq number = %d, Size %d\n", 
	dse->m_uiSrcAddr, dse->m_uiSeq, storage_size);

    //can't send so store
    dbg(DBG_USR2,"DTN::NO ROUTE. STORING...\n");
    send_state = STORING;
    res = call SendQueueI.writeTail((uint8_t *)mdtnpkt, storage_size);
    if (res == FAIL)
    {
      dbg(DBG_ERROR,"DTN::STORE FAILED\n");
      call Leds.greenToggle();
      SendDone(FAIL, appid);
      return FAIL;
    }

    else if (res==EEPROM_FULL) {
      dbg(DBG_ERROR,"DTN::EEPROM FULL - STORE FAILED\n");
      call Leds.greenToggle();
      SendDone(FAIL, appid);
      return FAIL;
    }

    return res;

  } 

  result_t UnwriteFromEEPROM(uint8_t appid)
  {
        
    dbg(DBG_USR2,"DTN::UNREADING HEAD... \n");

    send_state = UNREADING;
    if(call SendQueueI.unreadHead()==FAIL){
      //cant unread head so have to drop a packet!!
      call Leds.redToggle();
      dbg(DBG_ERROR,"DTN::STORE FAILED\n");
      SendDone(FAIL, appid);
    }

    return SUCCESS;
  }

  result_t StorePacket(uint8_t current_send_state, uint8_t appid)
  {
    result_t res;

    if (current_send_state == SENDING)
    {
      res = StoreToEEPROM();
    }
    else if (current_send_state == FORWARDING)
    {
      res = UnwriteFromEEPROM(appid);
    }
    else
    {
      dbg(DBG_ERROR,"DTN::ASKED TO STORE, NOT IN CORRECT STATE %d... \n", current_send_state);
      res = FAIL;
    }

    return res;
  }

  void SendDone(result_t status, uint8_t appid)
  {
      if ((send_state == SENDING) || (send_state == STORING))
      {
          signal mDTNSendI.mDTNSendDone[appid](status);
          signal mDTNSendRawI.mDTNSendDone(status, appid);
      }   
      else if ((send_state == FORWARDING) || (send_state == UNREADING))
      {
          updateForwardTimer(status);
      }
      else
      {
          dbg(DBG_ERROR, "DTN::Send done, but not in correct state %d\n", 
              send_state);
          return;
      }
      
      if ((send_state != UNREADING) && (send_state != FORWARDING))
      {
          // remove the packet entry from the queue of pending transactions
          RemoveFromStorage();
      }
 
      update_send_state(IDLE);

#ifdef NODE_HEALTH
    call NodeHealthI.ActionEnd(DATA_STORAGE);
#endif

  }

  result_t SendPacket(uint8_t current_send_state, uint8_t *data, 
                      uint8_t datasize, uint16_t address, uint8_t cost, 
                      uint8_t reliable, uint8_t appid)
  {
    result_t res = SUCCESS;

    //route is there so try to send
#ifdef USE_ROUTE_ADAPTATION
    if (call ApplicationI.SendFromApplication(data, datasize, 
	address, cost, 1, appid) == FAIL) {
#else
    dbg(DBG_ERROR, "Sending to 1 ESS_m %d!\n", address);
    if(call mDTNRoutingI.send(data, datasize, address, cost, appid)==FAIL){
#endif
      if(reliable == RELIABLE_SERVICE){
        res = StorePacket(current_send_state, appid);              
      }else{
        dbg(DBG_ERROR,"DTN::Unreliable service, couldn't send\n");
        SendDone(FAIL, appid);
        
      }
    }

    return res;
  }

  void increment_position(uint8_t *ptr)
  {
    if (*ptr < MAX_PENDING_EVENTS - 1)
    {
        *ptr = (*ptr) + 1;
    }
    else
    {
        *ptr = 0;
    }
  }

  uint8_t *AddToStorage(uint8_t* data, uint8_t datasize, uint8_t offset,
                        //dtnPacketActions_t action, uint8_t appid)
                        dtnPacketActions_t action)
  { 
      uint8_t *ret = &pending_records[pending_position_tail].sendbuffer[0];
      //mDTN_pkt_t* mdtnpkt = (mDTN_pkt_t *)&pending_records[pending_position_tail].sendbuffer[0];
      //DseHeader_t *dse = (DseHeader_t *)&pending_records[pending_position_tail].sendbuffer[offset];

      //dse = (DseHeader_t *)(mdtnpkt->data);
    
    

      if (pending_count >= MAX_PENDING_EVENTS)
      {
           // no space to store another pending event!
           dbg(DBG_ERROR,"DTN::No space for another packet! current %d, max %d\n", 
               pending_count, MAX_PENDING_EVENTS);
           return NULL;
      }

      if (MAX_RECORD_PAYLOAD < datasize + offset) {
          dbg(DBG_ERROR,"DTN::datasize %i is larger than max size %i\n", 
              datasize + offset, MAX_RECORD_PAYLOAD);
          return NULL;
      }

      // increase count of pending events
      pending_count++;
      

      pending_records[pending_position_tail].sbsize = datasize + offset;
      memcpy(&pending_records[pending_position_tail].sendbuffer[offset], data, 
             datasize);
      pending_records[pending_position_tail].pending_action = action;
      //pending_records[pending_position_tail].appid = appid;

      //dbg(DBG_ERROR,"DTN::STORING in temporary storage... From %d, Seq number = %d offset %d\n", 
	//dse->m_uiSrcAddr, dse->m_uiSeq, offset);

      increment_position(&pending_position_tail);

      return ret;
    
  }

  result_t RemoveFromStorage()
  {
      if (pending_count <= 0)
      {
          dbg(DBG_ERROR,"DTN::Asked to remove packet from queue, but nothing queued\n");
          return FAIL;
      }

      // decrease count of pending events
      pending_count--;

      // clear the pending action
      pending_records[pending_position_head].pending_action = INVALID_ACTION;

      // increment the head of the queue
      increment_position(&pending_position_head);

      return SUCCESS;
  }

  result_t GetFromStorage(uint8_t **data, uint8_t *length, 
                          //dtnPacketActions_t *action, uint8_t *appid)
                          dtnPacketActions_t *action)
  {
      if (pending_count <= 0)
      {
          dbg(DBG_ERROR,"DTN::Asked to get packet from queue, but nothing queued\n");
          return FAIL;
      }
      if (pending_position_head >= MAX_PENDING_EVENTS)
      {
          dbg(DBG_ERROR,"DTN::Asked to get packet from queue, but head pointer is bad! %d\n", pending_position_head);
          return FAIL;

      }

      *data = &pending_records[pending_position_head].sendbuffer[0];
      *length = pending_records[pending_position_head].sbsize;
      *action = pending_records[pending_position_head].pending_action;
      //*appid = pending_records[pending_position_head].appid;

      return SUCCESS;
  }

  /**********************************************************************
  Send Record
  ***********************************************************************/

  result_t PrepareToSend(uint8_t *data, uint8_t length, uint16_t addr, 
                         uint8_t cst, uint8_t rel, uint8_t id)
  {
      dbg(DBG_USR3,"DTN::SENDING PKT FOR %i\n",id);

      if(rel == RELIABLE_SERVICE){

      //check if route available
      update_send_state(PENDING_ROUTE_SEND);
#ifdef USE_ROUTE_ADAPTATION
      if ((call ApplicationI.CheckRouteAvailable()) == FAIL) {
#else
      if (call mDTNRoutingI.routeAvailable()==FAIL){
#endif
          return StoreToEEPROM();
      }
        
      }else{

          //if service is unreliable then try to send msg
          update_send_state(SENDING);
#ifdef USE_ROUTE_ADAPTATION
          dbg(DBG_USR3,"DTN::Sending as unreliable\n");
          return call ApplicationI.SendFromApplication(data, 
                  length, 
		  addr, cst, 1, id);
#else
          dbg(DBG_ERROR, "Sending to 2 ESS_m %d!\n", addr);
          return call mDTNRoutingI.send(data, 
                  length, 
		  addr, cst, id);
#endif

      }
    
    
    return SUCCESS;

  }

  result_t sendHandler(uint8_t* data, uint8_t datasize, uint16_t addr, uint8_t cst, uint8_t rel, uint8_t id){
    
    //result_t res;
    mDTN_pkt_t* mdtnpkt;
    uint8_t length = datasize + sizeof(mDTN_pkt_t);
    
#ifdef NODE_HEALTH
    call NodeHealthI.ActionStart(DATA_STORAGE);
#endif

    //return FAIL;

    mdtnpkt = (mDTN_pkt_t*)AddToStorage(data, datasize, sizeof(mDTN_pkt_t),
                                        PENDING_SEND);
    if (mdtnpkt == NULL)
    {
       dbg(DBG_ERROR,"DTN::No space to send packet!\n");
       return FAIL;
    } 

    //set header information and state information
    mdtnpkt->address = addr;
    mdtnpkt->acr = setACR(id,cst,rel);

    if(send_state != IDLE) {
        // we will deal with this packet when we are finished with our 
        // current packet     
        
        post HandlePending();
        return SUCCESS;
    }
       
    return PrepareToSend((uint8_t *)mdtnpkt, length, addr, cst, rel, id);
         
    
  }

  command result_t mDTNSendI.mDTNSend[uint8_t id](uint8_t* data, uint8_t datasize, uint16_t addr, uint8_t cst, uint8_t rel){
    return sendHandler(data,datasize,addr,cst,rel,id);
  }
  
command result_t mDTNSendRawI.mDTNSend(uint8_t* data, uint8_t datasize, uint16_t addr, uint8_t cst, uint8_t rel, uint8_t type){
    return sendHandler(data,datasize,addr,cst,rel,type);
  }

default event result_t mDTNSendRawI.mDTNSendDone(result_t success,uint8_t type){
    return FAIL;
}


  default event result_t mDTNSendI.mDTNSendDone[uint8_t id](result_t success){

    return FAIL;
  }
  
void CheckRouteForward(result_t success)
{
    if (success == FAIL)
    {
        // still no path
        updateForwardTimer(FAIL);
        update_send_state(IDLE);  
  
        dbg(DBG_USR1,"DTN::No path to sink still, going back to sleep...\n");

#ifdef NODE_HEALTH
        call NodeHealthI.ActionEnd(DATA_STORAGE);
#endif
    }
    else
    {
        update_send_state(READING);
        // path to sink exists, read the packet to send
        if(call SendQueueI.readHead() == FAIL){
          dbg(DBG_ERROR,"DTN::Unable to read head\n");
          update_send_state(IDLE);  
        }
    }    
}  


void CheckRouteSend(result_t success)
{
    uint8_t *data;
    uint8_t storage_size;
    dtnPacketActions_t action;
    result_t res;  
    mDTN_pkt_t *mdtnpkt; 

    // grab the appid for a packet generated here
    res = GetFromStorage(&data, &storage_size, &action);
    

    if (res != SUCCESS)
    {
         dbg(DBG_ERROR, "DTN::Couldn't get packet from storage\n");
         update_send_state(IDLE);
         return;
    }

    mdtnpkt = (mDTN_pkt_t*)data;
    update_send_state(SENDING); 

    if (success == SUCCESS)
    {
        
        
        
        // route exists, send packet
        SendPacket(send_state, data, 
                   storage_size, mdtnpkt->address, getCost(mdtnpkt->acr), 
                   1, getAppId(mdtnpkt->acr));
    }
    else
    {
        StorePacket(send_state, getAppId(mdtnpkt->acr));
    }

}

#ifdef USE_ROUTE_ADAPTATION
  event result_t ApplicationI.CheckRouteAvailableDone(result_t success){
#else
  event result_t mDTNRoutingI.routeAvailableDone(result_t success){
#endif 

    if (send_state == PENDING_ROUTE_FORWARD)
    {
        CheckRouteForward(success);
    }
    else if (send_state == PENDING_ROUTE_SEND)
    {
        CheckRouteSend(success);    
    }
    else
    {
        dbg(DBG_ERROR, "DTN::Wrong state %d\n", send_state);
        return FAIL;
    }    

    return SUCCESS;
  }
  
event result_t SendQueueI.readHeadDone(uint8_t* data, uint8_t datasize, result_t success){
    mDTN_pkt_t* mdtnpkt = (mDTN_pkt_t*)data;
    DseHeader_t *dse;
    uint8_t cost;
    uint8_t reliable;
    uint8_t appid;

    if (send_state != READING)
    {
        dbg(DBG_ERROR, "DTN::Wrong state %d\n", send_state);
        return FAIL;
    }    

    if (success == FAIL)
    {
        dbg(DBG_ERROR, "DTN::Could not read from EEPROM\n");
        update_send_state(IDLE);  
        return FAIL;
    }

    dse = (DseHeader_t *)(mdtnpkt->data);
    
    cost = getCost(mdtnpkt->acr);
    reliable = getReliable(mdtnpkt->acr);
    appid = getAppId(mdtnpkt->acr);

/*
    if (AddToStorage(data, datasize, 0, PENDING_FORWARD, appid) == NULL)
    {
        dbg(DBG_ERROR, "DTN::Not enough space to store packet!\n"); 
        update_send_state(IDLE);  
        return FAIL;
    }   
*/      
    dbg(DBG_ERROR,"DTN::READ HEAD... From %d, Seq number = %d\n", 
	dse->m_uiSrcAddr, dse->m_uiSeq);

    update_send_state(FORWARDING);

    SendPacket(send_state, data, datasize, mdtnpkt->address, cost, 
               reliable, appid);

    return SUCCESS;
}  


#ifdef USE_ROUTE_ADAPTATION
  event result_t ApplicationI.SendFromApplicationDone(result_t success){
#else  
  event result_t mDTNRoutingI.sendDone(result_t success){
#endif
    uint8_t appid;

    
    if ((send_state != SENDING) && (send_state != FORWARDING))
    {
        dbg(DBG_ERROR, "DTN::Wrong state %d\n", send_state);
        return FAIL;
    }    
    
    if (send_state == SENDING)
    {
        uint8_t *data;
        uint8_t storage_size;
        dtnPacketActions_t action;
        result_t res; 
        mDTN_pkt_t *mdtnpkt;       

        // grab the appid for a packet generated here
        res = GetFromStorage(&data, &storage_size, &action);
        if (res != SUCCESS)
        {
             dbg(DBG_ERROR, "DTN::Couldn't get packet from storage\n");
             return FAIL;
        }
        mdtnpkt = (mDTN_pkt_t*)data;
        appid = getAppId(mdtnpkt->acr);

    }
    else
    {
        // no appid needed for forwarded packets
        appid = NO_VALID_APPID;  
    } 

    if (success == SUCCESS)
    {
        SendDone(SUCCESS, appid);

    }
    else 
    {
        StorePacket(send_state, appid);
    }

    return SUCCESS;
  }
  
  event result_t SendQueueI.unreadHeadDone(result_t success){
    if (send_state != UNREADING)
    {
        dbg(DBG_ERROR,"DTN::Wrong state %d\n", send_state);
        return FAIL; 
    }

    if(success == SUCCESS){
      dbg(DBG_USR2,"DTN::SUCCESSFULLY UNREAD HEAD\n");
      
    }else{
      dbg(DBG_ERROR,"DTN::FAILED UNREAD HEAD\n");
      call Leds.greenToggle();
    }

    dbg(DBG_USR2,"DTN::Send done, unread head\n");
    SendDone(success, NO_VALID_APPID);    
    return SUCCESS;
  }
  
  event result_t SendQueueI.writeTailDone(result_t success){
    uint8_t appid;

    if ((send_state != STORING) && (send_state != STORING_FORWARDED))
    {
        dbg(DBG_ERROR,"DTN::Wrong state %d\n", send_state);
        return FAIL;
    }

    if (send_state == STORING)
    {
        uint8_t *data;
        uint8_t storage_size;
        dtnPacketActions_t action;
        result_t res;        
        mDTN_pkt_t *mdtnpkt;

        // grab the appid for a packet generated here
        res = GetFromStorage(&data, &storage_size, &action);
        if (res != SUCCESS)
        {
             dbg(DBG_ERROR, "DTN::Couldn't get packet from storage\n");
             return FAIL;
        }

        my_stored_pkt_count++;
        mdtnpkt = (mDTN_pkt_t*)data;
        appid = getAppId(mdtnpkt->acr);
    }
    else
    {
        // no appid needed for forwarded packets
        appid = NO_VALID_APPID;  

        others_stored_pkt_count++;
    } 

    

    if(success == SUCCESS){
      dbg(DBG_USR2,"DTN::SUCCESSFULLY WROTE TAIL\n");
      current_pkts_stored++;
      
    }else{
      dbg(DBG_ERROR,"DTN::FAILED TO WRITETAIL\n");
      call Leds.redToggle();
      
    }
    
    SendDone(success, appid);
    
    return SUCCESS;
  }

result_t StoreForwardFailedPacket(uint8_t *data, uint8_t datasize)
{
    DseHeader_t *dse;
    mDTN_pkt_t* mdtnpkt = (mDTN_pkt_t *)data;
 
#ifdef NODE_HEALTH
    call NodeHealthI.ActionStart(DATA_STORAGE);
#endif
   
    if (AddToStorage(data, datasize, 0, PENDING_STORE) == NULL)
    {
        dbg(DBG_ERROR,"DTN::FAILED TO ADD TO STORAGE\n");
        return FAIL;
    }

    dse = (DseHeader_t *)(mdtnpkt->data);
    
    dbg(DBG_ERROR,"DTN::Failed to forward... From %d, Seq number = %d\n", 
	dse->m_uiSrcAddr, dse->m_uiSeq);

    if (send_state != IDLE)
    { 
        // we will handle when we are idle again
        post HandlePending();
    }    
    else
    {    
        update_send_state(STORING_FORWARDED);
        StoreToEEPROM();
    }

    return SUCCESS;


}


#ifdef USE_ROUTE_ADAPTATION
event result_t ApplicationI.RouteForwardFailed(uint8_t *data, uint8_t datasize)
{
    return StoreForwardFailedPacket(data, datasize);
}
#endif 
/*  
  /**********************************************************************
    Recv Record
    ***********************************************************************/
#ifdef USE_ROUTE_ADAPTATION
    event result_t ApplicationI.RecvToApplication(uint8_t* data,uint8_t datasize,uint16_t to_address,uint16_t from_address, uint8_t type) {
#else
    event result_t mDTNRoutingI.recv(uint8_t *data, uint8_t datasize,uint16_t to_address,uint16_t from_address, uint8_t type){
#endif
      mDTN_pkt_t* mdtnpkt = (mDTN_pkt_t*) data;

      
      //check if the received packet goes to the current node
      if(to_address == TOS_LOCAL_ADDRESS){
	//dbg(DBG_ERROR,"DTN::SENDING DATA UP TO APP, Type = %d, Should be %d or %d\n",
	    //type, MULTIHOP_DSE, TIMESYNC_APP);
	
	signal mDTNRecvI.mDTNRecv[type](mdtnpkt->data,datasize-sizeof(mDTN_pkt_t),to_address,from_address);

	signal mDTNRecvRawI.mDTNRecv(mdtnpkt->data,datasize-sizeof(mDTN_pkt_t),to_address,from_address,type);
	return SUCCESS;
      }
#ifndef USE_ROUTE_ADAPTATION      
      //if i got this and its not for this node that means routing wasn't able to send it
      //check if this is reliable
      if(getReliable(mdtnpkt->acr) == RELIABLE_SERVICE) {

            return StoreForwardFailedPacket(data, datasize);
	}else{
	  call Leds.yellowToggle();
	  dbg(DBG_ERROR,"DTN::RECVD PKT FOR OTHER NODE %i. TOO BUSY TO STORE, MUST DROP!!!!!!!!!!!\n", from_address);
          return SUCCESS;
	}
#endif
      return SUCCESS;
    }

    
 default event result_t mDTNRecvI.mDTNRecv[uint8_t id](uint8_t *data, uint8_t datasize,uint16_t to_address, uint16_t from_address){

      return FAIL;  
  }
  
  default event result_t mDTNRecvRawI.mDTNRecv(uint8_t *data, uint8_t datasize,uint16_t to_address, uint16_t from_address, uint8_t type){
    return FAIL;
  } 
  
#if 0
event result_t RecvQueueI.unreadHeadDone(result_t success){
    if(success == SUCCESS){
      post recvTaskSuccess();
    }else{
      post recvTaskFail();
    }
    return SUCCESS;
  }
  
  event result_t RecvQueueI.writeTailDone(result_t success){
    if(success == SUCCESS){
      //increment stored counters is write tail was success and not a local address
      if(recvFromLocal == 0){
        others_stored_pkt_count++;
      }
      current_pkts_stored++;
      post recvTaskSuccess();
    }else{
      call Leds.yellowToggle();
      dbg(DBG_ERROR,"DTN::RECV UNREAD FAILED\n");
      post recvTaskFail();
    }
    
    //regardless reset from local
    recvFromLocal = 0;
	
    return SUCCESS;
  }
  
  event result_t RecvQueueI.readHeadDone(uint8_t* data, uint8_t datasize, result_t success){
    if(success == SUCCESS){
      post recvTaskSuccess();
    }else{
      call Leds.yellowToggle();
      dbg(DBG_ERROR,"DTN::RECV WRITETAIL FAILED\n");
      post recvTaskFail();
    }
    return SUCCESS;
  }
#endif // USE_ROUTE_ADAPTATION
  
  
#ifdef USE_SYMPATHY
  
  typedef struct _mdtnsym{
    uint16_t my_stored_pkt_count;
    uint16_t others_stored_pkt_count;
    uint16_t current_pkts_stored;    
    uint32_t bytesUsed;
  } __attribute__ ((packed)) mDTN_Sym_t;
  
  
  event result_t ProvideCompMetrics.exposeSymStats(Sympathy_comp_stats_t *data, uint8_t *len) {  
    *len = 0;
    return FAIL;
  }
  
  event result_t ProvideCompMetrics.exposeGenericStats(uint8_t *data, uint8_t *len) {
    mDTN_Sym_t* d = (mDTN_Sym_t*) data;
    d->my_stored_pkt_count = my_stored_pkt_count;
    d->others_stored_pkt_count = others_stored_pkt_count;
    d->current_pkts_stored = current_pkts_stored;
    d->bytesUsed = 0;
    
#ifdef STAT_TRACKER
    d->bytesUsed = call FreeSpaceQueryI.bytesUsed();;
#endif
    
    dbg(DBG_USR3, "SENDING GEN STATS: my_stored=%d, other_stored=%d, curr_stored=%d, bytes_used=%d", my_stored_pkt_count, others_stored_pkt_count,
        current_pkts_stored, d->bytesUsed);
    
    *len = sizeof(mDTN_Sym_t);
    return SUCCESS;
  }
  
  
#endif
  
  
  
}
