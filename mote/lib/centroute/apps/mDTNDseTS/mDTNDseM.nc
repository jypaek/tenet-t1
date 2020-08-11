////////////////////////////////////////////////////////////////////////////
//
// CENS
//
// Copyright (c) 2003 The Regents of the University of California.  All
// rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions
// are met:
//
// - Redistributions of source code must retain the above copyright
//   notice, this list of conditions and the following disclaimer.
//
// - Neither the name of the University nor the names of its
//   contributors may be used to endorse or promote products derived
//   from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS''
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
// THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
// PARTICULAR  PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE REGENTS OR
// CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
// EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
// PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
// PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
// OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
////////////////////////////////////////////////////////////////////////////

includes AM;
includes MultihopTypes;
includes QueryTypes;
includes ConfigConst;
includes eeprom_logger;
includes mDTN;
#ifdef POST_MOTE_RADIO_CONFIG
includes mote_config;
#endif

module mDTNDseM
{
  provides
  {
    interface StdControl;
  }
  uses
  {
    interface QeAcceptQueryI;
    interface ChAcceptCmdI;
    interface Leds;
    //interface NodeI;
    interface mDTNSendI;
    interface mDTNRecvI;
    interface EssSysTimeI;
#ifdef EMSTAR_NO_KERNEL
    interface EmTimerI as JitterTimer;
    interface EmTimerI as LedsTimer;
#else
    interface Timer as JitterTimer;
    interface Timer as LedsTimer;
#endif

    interface Random;
#ifdef USE_SYMPATHY
    interface ProvideCompMetrics;
#endif
    interface CC1000Control;
    interface ResetCountI;

#if defined(TOSH_HARDWARE_MICA2DOT) || defined(TOSH_HARDWARE_MICA2)
    command uint8_t enableHPLPowerM();
#endif

    command result_t SetListeningMode(uint8_t power);
    command result_t SetTransmitMode(uint8_t power);
  }
}
implementation
{
#include "MultihopConstants.h"
#include "protocols.h"
#include "eeprom_logger.h"
#include "QueryConstants.h"

#ifdef POST_MOTE_QUERY_CONFIG
#include "preSensors.c"
#else
#include "mySensors.c"
#endif


#define BUF_SIZE  (2)

  // Time until Leds are permanently disabled.
#define LEDS_DISABLE_TIME 10000

task void sendData();

struct Buf {
  uint8_t head;
  uint8_t tail;
  uint8_t count;
  DsePacket_t buffer[BUF_SIZE];
} gBuf;

uint16_t SeqNo;
uint8_t sendSched;

#ifdef USE_SYMPATHY
  Sympathy_comp_stats_t dseStats = {};
#endif

/**************************/

#define PHASE_TAB 5
#define DEFAULT_PERIOD 1000
#define JIT_PERCENT 80


typedef struct _phaseTab{
  uint8_t qid;
  uint16_t samplePeriod;
  uint32_t nextPhase;
} phaseTab_t;
 
 phaseTab_t pTab[PHASE_TAB];


void printbuffer(uint8_t* buffer, int size){
#ifdef PLATFORM_PC
    int i=0;
    for(i=0;i<size;i++){
      dbg(DBG_ERROR, "%02x ",buffer[i]);
    }
    dbg(DBG_ERROR, "\n");
    fflush(stdout);
#endif
  }
 

 // get the time to the next phase in ms
 uint32_t getExpectedTime() {
   uint8_t i;
   uint32_t mindiff = 0xFFFFFFFF;
   int64_t cus = call EssSysTimeI.getTime();
   
   for(i=0; i < PHASE_TAB; i++){
     if(pTab[i].qid != 0){
       if((pTab[i].nextPhase >= (cus/1000)) && (pTab[i].nextPhase - (cus/1000) < mindiff)) {
         mindiff = pTab[i].nextPhase - (cus/1000);
       }
     }
   }
   
   if(mindiff == 0xFFFFFFFF){
     mindiff = DEFAULT_PERIOD;
   }

   dbg(DBG_USR3, "Next expected time diff is %i \n", mindiff);
   
   return mindiff;
 }
 

  // have to multiply period by 100ms to get actuall ms time
 uint16_t calcJitter(uint16_t samplePeriod) {
   return (call Random.rand() * ((samplePeriod * JIT_PERCENT)/100));
 }
 

void updatePhase(uint8_t qid) {
  uint8_t i;
  int64_t cus = call EssSysTimeI.getTime();
  
  // check if it already is in the table
  for(i = 0; i< PHASE_TAB; i++) {
    if(pTab[i].qid == qid) {
      // already in the table so return
      pTab[i].nextPhase = cus/1000 + (pTab[i].samplePeriod * 100);

      dbg(DBG_USR3, "Updating qid=%i with sp=%i and next phase=%i currtime=%i",pTab[i].qid,pTab[i].samplePeriod,pTab[i].nextPhase,(uint32_t)cus/1000);

      return;
    }
  }
  return;
}
 
 
void insertPhase(QueryHeader_t* q) {
  uint8_t i;
  uint8_t qid = q->queryID;
  uint16_t sp = q->samplingPeriod;
  int64_t cus = call EssSysTimeI.getTime();
  
  // check if this is a delete query
  switch(QUERY_TYPE(q)) {
  case delete_query:
    for(i = 0; i < PHASE_TAB; i++) {
      // if this is a delete remove the phase from the table
      if(pTab[i].qid == qid) {
        memset(&pTab[i], 0, sizeof(phaseTab_t));

        dbg(DBG_USR3, "Deleting qid %i from phase table", pTab[i].qid);

        return;
      }
    }
    break;
  }
  
  
  // not periodic so no need to do anything
  if(sp == 0) {
    return;
  }
  
  // check if it already is in the table
  for(i = 0; i < PHASE_TAB; i++) {
    if(pTab[i].qid == qid) {
      //already in the table so return
      return;
    }
  }
  
  // not in table so lets put it in there
  for(i = 0; i < PHASE_TAB; i++) {
    if(pTab[i].qid == 0) {
      // empty slot so put it in
      pTab[i].qid = qid;
      pTab[i].samplePeriod = sp;
      // convert to ms from us  and also add samplingperiod (*100 to get ms)
      // this is when we expect the next one of these to show up
      pTab[i].nextPhase = cus/1000 + (sp*100);
      
      dbg(DBG_USR3, "Inserting qid=%i with sp=%i and next phase=%i currtime=%i",pTab[i].qid,pTab[i].samplePeriod,pTab[i].nextPhase,(uint32_t)cus/1000);
      
      return;
    }
  }
  return;
}

  // Disable all Leds permanently
  void disable_leds() {
    // Turn off the LEDs.                                 
    call Leds.redOff();
    call Leds.greenOff();
    call Leds.yellowOff();

    // Disable them.                         
    TOSH_MAKE_RED_LED_INPUT();
    TOSH_MAKE_YELLOW_LED_INPUT();
    TOSH_MAKE_GREEN_LED_INPUT();
  } 
 
  // Diable all LEDS.
  event result_t LedsTimer.fired() {
    disable_leds();
    return SUCCESS;
  }


// if the timer fires send the first thing on the list
 event result_t JitterTimer.fired(){
   uint32_t mdiff;
   uint16_t jitter;
   
   if(gBuf.count > 0) {
     // send the data in the queue
     post sendData();

     dbg(DBG_ERROR, "Timer fired.  sending data \n");

     // if there are more packets than the one we're about to send
     // then figure out the jitter
     if(gBuf.count > 1) {

       dbg(DBG_USR3, "Timer fired. more than one data in buffer, reseting timer \n");

       // get the expected time of the next packet to arrive
       mdiff = getExpectedTime();
       jitter = calcJitter(mdiff);
       
       // if our jitter is too small we cant sendData cause
       // something already in the queue...so lets delay 100 milliseconds
       // and see what happens
       if(jitter < 100) {
         jitter = 100;
       }
       call JitterTimer.stop();
       call JitterTimer.start(TIMER_ONE_SHOT,jitter);
     }
   }
   
   return SUCCESS;
 }
 

/**************************/





  command result_t StdControl.init(){

    call Leds.init();
    call Random.init();
    SeqNo = 0;
    sendSched = 0;
    gBuf.head = gBuf.tail = gBuf.count = 0;
#ifdef USE_SYMPATHY
    dseStats.num_pkts_tx = dseStats.num_pkts_rx = 0;
#endif

    return SUCCESS;
  }

  command result_t StdControl.start( ){
     

    // Set radio power
    // Currently broken in EmStar emulation, so dont do it for emstar!
#if defined(TOSH_HARDWARE_MICA2DOT) || defined(TOSH_HARDWARE_MICA2)
#ifdef POST_MOTE_RADIO_CONFIG
    call CC1000Control.SetRFPower(POST_TX_POWER);
    call CC1000Control.TunePreset(POST_MOTE_FREQ);
    call SetListeningMode(POST_LPL_MODE);
    call SetTransmitMode(POST_LPL_MODE);
    call enableHPLPowerM();
#else
    call CC1000Control.SetRFPower(TX_POWER);
    call SetListeningMode(LPL_MODE);
    call SetTransmitMode(LPL_MODE);
    call enableHPLPowerM();
#endif
#endif

#ifdef LONELY_MOTE_ISE
    //post sensorInit_ISE();
    //post queryInit_ISE();
#else
    post sensorInit();
#endif // LONELY_MOTE_ISE

#ifdef ROUTER_MOTE
    dbg(DBG_ERROR, "Setting up router mote query!\n");
    post queryInit();
#endif // ROUTE_MOTE

#ifdef LONELY_MOTE
    // Initialize all available sensors.
    dbg(DBG_ERROR, "Setting up lonely mote query!\n");
    post queryInit();
#endif // LONELY_MOTE

#ifdef NEW_DISABLE_LEDS
    // Enable all LEDs to signify we have power
    call Leds.yellowOn();
    call Leds.greenOn();
    call Leds.redOn();

    // Start the Leds disable timer.
    call LedsTimer.start(TIMER_ONE_SHOT, LEDS_DISABLE_TIME);

#endif

    return SUCCESS;
  }

#ifdef USE_SYMPATHY

  event result_t ProvideCompMetrics.exposeSymStats(Sympathy_comp_stats_t *data, uint8_t *len) {

    data->num_pkts_rx = dseStats.num_pkts_rx;
    data->num_pkts_tx = dseStats.num_pkts_tx;
    data->send_failures = data->max_queue_occupancy = data->num_pkts_dropped = 0;
    dbg(DBG_USR3, "reqs %d tx %d\n", dseStats.num_pkts_rx, dseStats.num_pkts_tx);    
    *len = sizeof(Sympathy_comp_stats_t);
    return SUCCESS;
  }

  event result_t ProvideCompMetrics.exposeGenericStats(uint8_t *data, uint8_t *len) {
    *len = 0;
     return FAIL;
  }
#endif 

  command result_t StdControl.stop( ){
    return SUCCESS;
  }

  event result_t QeAcceptQueryI.sendQueryResult(uint8_t* res, uint8_t length) {
    QueryResponse_t* qr = (QueryResponse_t*) res;
    DsePacket_t *p = &(gBuf.buffer[gBuf.tail]);
    uint32_t mdiff = 0;
    uint16_t jitter = 0;

    dbg(DBG_ERROR,"DSEAPP: Query ID %d, bitmask %d\n", qr->queryID, qr->bitMask);

    // buffers full we need to dump this packet. rare but could happen if more 
    // ..than BUF_SIZE+ packets come before the sendData task can process any 
    // ..of them
    if(gBuf.count == BUF_SIZE){
      dbg(DBG_ERROR,"DSEAPP:No buffer room. Dropping packet");
      printbuffer(res,length);
      return SUCCESS;
    }
    
    // setup DSE packet header
    p->hdr.m_uiSrcAddr = TOS_LOCAL_ADDRESS;
    p->hdr.m_uiSeq = SeqNo++;
    p->hdr.m_uiLen = length;

    // We can't get this info from the QueryResponse struct?
    if(res[1] == 0 && res[2] == 0) {
      p->hdr.m_uiType = CONFIG_DATA;
    } else {
      p->hdr.m_uiType = SENSOR_DATA;
    }

    // set timestamp using ess
    p->hdr.m_timestamp = call EssSysTimeI.getTime();

    // set restart count
    p->hdr.m_resetcount = call ResetCountI.get_count();
    
    // Copy the data over
    memcpy(p->data, res, length);

    dbg(DBG_USR3,"DSEAPP: Dse query data stored to internal buffer slot %i with count %i:", gBuf.tail, gBuf.count+1);
    //printbuffer((uint8_t*)p,sizeof(DseHeader_t)+length);

    // Increment the tail pointer to account for new packet in buffer
    gBuf.tail = (gBuf.tail + 1) % BUF_SIZE;
    gBuf.count++;
 
    // if this is the only packet then start the timer to send it later
    if(gBuf.count == 1) {

      dbg(DBG_USR3, "Scheduling only item in buffer \n");

      // update my next expected sample period
      // must happen before getting expected time
      // or could get diff to the current packet im sending
      updatePhase(qr->queryID);

      // get the expected time of the next packet to arrive
      mdiff = getExpectedTime();
      jitter = calcJitter(mdiff);
      
      dbg(DBG_USR3, "Scheduled jitter %i \n", jitter);

      // not enough jitter so lets just send directly
      if(jitter > 100){
        call JitterTimer.stop();
        call JitterTimer.start(TIMER_ONE_SHOT, jitter);
      } else {
        sendSched = 1;
        post sendData();
      }

      return SUCCESS;

    } else {

      dbg(DBG_USR3, "Somethign already in buffer. sending and rescheduling new pkt \n");

      // if there is already something in the queue then dump it
      // regardless of the timer because something else is ready
      // to go.  if in between the post being executed and
      // another packet comes up we're gonna lose the packet
      // only send if there isn't one already scheduled in the queue
      if(sendSched != 1)
        post sendData();

      // update my next expected sample period
      // must happen before getting expected time
      // or could get diff to the current packet im sending
      updatePhase(qr->queryID);
  
      mdiff = getExpectedTime();
      jitter = calcJitter(mdiff);
      
      dbg(DBG_USR3, "Scheduled jitter %i \n", jitter);

      // if our jitter is too small we cant sendData cause
      // something already in the queue...so lets delay 100 seconds
      // and see what happens
      if(jitter < 100) {
        jitter = 100;
      }
      call JitterTimer.stop();
      call JitterTimer.start(TIMER_ONE_SHOT, jitter);
            
      return SUCCESS;
    }
    
    return SUCCESS;
  }

task void sendData( ) {
    result_t status;

    if (gBuf.count == 0)  
    {
      dbg(DBG_ERROR, "Asked to send packet, but nothing pending!\n");
      return;
    }
    
    dbg(DBG_ERROR, "DSEAPP: Sending packet: Count of buffers = %d\n", gBuf.count);
    
    // Try to send the packet through mDTN
    status = call mDTNSendI.mDTNSend((uint8_t*)&(gBuf.buffer[gBuf.head]), 
                                     sizeof(DseHeader_t) + gBuf.buffer[gBuf.head].hdr.m_uiLen, 
                                     ANY_ROOT,
                                     0,
                                     RELIABLE_SERVICE);

    // If it sent, remove it from the buffer
    if (status == SUCCESS) {
      gBuf.head = (gBuf.head + 1) % BUF_SIZE;
      gBuf.count--;
      sendSched = 0;
    } else {
      dbg(DBG_ERROR, "DSEAPP:Failed to send DSE data.  Posting task again. \n");
    }
  }
 
  
  event result_t ChAcceptCmdI.acceptCmdDone(char *buf){
      return SUCCESS;
  }

  // The packet is already out of the buffer, too late to do anything if it
  // ..happened to fail.
  event result_t mDTNSendI.mDTNSendDone(result_t success){
    if(success != SUCCESS){
      dbg(DBG_ERROR, "DSEAPP:DTN SendDone Failed \n");
      printbuffer((uint8_t*)&(gBuf.buffer[gBuf.head]),
                  sizeof(DseHeader_t) + gBuf.buffer[gBuf.head].hdr.m_uiLen);
    }
#ifdef USE_SYMPATHY
    dseStats.num_pkts_tx++;
#endif
    return SUCCESS;
  }

  
  event result_t mDTNRecvI.mDTNRecv(uint8_t* data, uint8_t datasize, uint16_t to_address, uint16_t from_address){
    // Insert the query information into the phase buffer
    insertPhase((QueryHeader_t*)data);

    // Pass the query into the sampler
    call QeAcceptQueryI.passQuery((void*)data);

#ifdef USE_SYMPATHY
    dseStats.num_pkts_rx++;
#endif
    return SUCCESS;
  }




}
