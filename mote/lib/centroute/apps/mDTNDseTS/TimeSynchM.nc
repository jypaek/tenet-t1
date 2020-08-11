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
// Contents: This file contains the test driver for the TdMatchM module.
//
// Purpose: This represents the timesync receiving application.
//          When any pkt is received the local time is collected. If the pkt 
//          is a timesync packet then the time in the packet + the time diff
//          between when the packet was recv'd and when the pkt is being processed.
//          Once the time is set, multihop will forward the packet along to the next
//          hop.  When the pkt is ready send the radiosendcoordinator restamps the
//          the packet with the current time on this node.
//          This way error in sync is on a perhop basis instead of being dependent 
//          on the depth of the tree.
//
//
////////////////////////////////////////////////////////////////////////////


/*
Theoretically the error should be the following:
  radio bit rate*bits in packet + propogation time of one byte over the air.
 
  In testing over the ceiling array we saw ~100 microsecond skew.


*/



includes AM;
includes MultihopTypes;
includes TimeSyncTypes;
includes EmStar;
includes protocols;
includes mDTN;

module TimeSynchM
{
  provides
  {
    interface StdControl;
  }
  uses
  {
    interface mDTNRecvI;
    interface Leds;
    interface EssSysTimeI;
#ifdef USE_SYMPATHY
    interface ProvideCompMetrics;
#endif
#ifndef PLATFORM_EMSTAR
    interface RadioCoordinator as RadioReceiveCoordinator;
    //interface RadioCoordinator as RadioSendCoordinator;
#endif
#ifdef TIMESYNC_DEBUG
    interface EmStatusServerI;
#endif
  }
}
implementation
{

#include "MultihopConstants.h"
//#include "EmStar_Strings.h"


#ifndef PLATFORM_EMSTAR
#define sprintf(...)
#define printf(...)
#define fflush(...)
#endif


#ifdef TIMESYNC_DEBUG 
  timeDbgPkt_t synchDbgOut;
#endif
  
  // Changed to 64 bits to reflect the new absolute time.
  //  -John H
  int64_t recvPktTime;

#ifdef USE_SYMPATHY
  uint8_t tsPacketsRcvd; //comp-level metrics to send through sympathy
#endif

  
  /*************************************/ 
  //StdControl Interface
  /**************************************/

  command result_t StdControl.init( ){
    call Leds.init();
#ifdef USE_SYMPATHY
    tsPacketsRcvd = 0; //this needs to be changed later to 0!!!
#endif
    return SUCCESS;
  }

  command result_t StdControl.start( ){
    atomic recvPktTime=0;    
#ifdef TIMESYNC_DEBUG
    call EmStatusServerI.Init("/dev/tos/debug/ess_timesync");
#endif
    
    return SUCCESS;
  }

  command result_t StdControl.stop( ){
    return SUCCESS;
  }


  /*************************************/ 
  //Functions
  /**************************************/
  void recvFromTree(void *data, uint8_t len, mote_id_t src){
    
    timeSynchPkt_t* tpkt = (timeSynchPkt_t*) data;
    int64_t timevalue;
    int64_t currTime;
    int64_t tmpRecvPktTime;

    timevalue = tpkt->time;
    currTime=call EssSysTimeI.getTime();

#ifdef PLATFORM_EMSTAR
    atomic recvPktTime = currTime;
#endif
    atomic tmpRecvPktTime = recvPktTime;
    
    call EssSysTimeI.setTime(timevalue + (currTime-tmpRecvPktTime));

    //dbg(DBG_USR3,"RECV: Successfully received time %d. Updated old time %d \n", (timevalue + (currTime-tmpRecvPktTime)), currTime );

#ifdef TIMESYNC_DEBUG  
    synchDbgOut.from = TOS_LOCAL_ADDRESS;
    synchDbgOut.oldtime=currTime;
    synchDbgOut.newtime=timevalue + (currTime-tmpRecvPktTime);
    call EmStatusServerI.Notify();
#endif
  }


  /*************************************/ 
  //mDTNRecvI Interface
  /**************************************/

  event result_t mDTNRecvI.mDTNRecv(uint8_t* data,uint8_t datasize,uint16_t to_address,uint16_t from_address){
#ifdef USE_SYMPATHY
    tsPacketsRcvd++;
#endif
    //dbg(DBG_ERROR,"TS Packets rcvd = %d\n",tsPacketsRcvd);

    recvFromTree(data,datasize,from_address);
    return SUCCESS;
  }


  /*************************************/ 
  //RadioReceiveCoordinator Interface
  /**************************************/
#ifndef PLATFORM_EMSTAR  
  async event void RadioReceiveCoordinator.blockTimer(){
    //called for every state transition
    //dont do anything
  }

  async event void RadioReceiveCoordinator.startSymbol(uint8_t bitsPerBlock, uint8_t offset, TOS_MsgPtr msgBuff){
    //done need to do anything when we get the start symbol
    recvPktTime = call EssSysTimeI.getTime();
  }

  async event void RadioReceiveCoordinator.byte(TOS_MsgPtr msg, uint8_t byteCount){
    //called per byte received.
    //don't do anything here
 }


  /*************************************/ 
  //RadioSendCoordinator Interface
  /**************************************/
 /*
  Need to implement send function on sender because reciever will be a sender if in multihop 
  route to another node.  Multihop will implicitely call this function when it forwards a pkt.
  
  NOTE:  This works because multihop signals the fromTree functions directly instead of through
  a post task.  This allows the node to set the current time before the packet is fwd to the next
  node.  That way when this code is called the new time is already  set for this node and getTime
  will stamp the packet with the correct time.
  */ 

 /*
  Turned off:  We don't want MAC level time stamping.  Instead the sink will stamp at the app layer
  and we will be skewed by the underministic time the host can actually send the message out after the 
  time has been stamped.

  If we need that prescision then uncomment this and if running on emstar make sure to compile transceiver 
  with USE_ESSTIMESYNC flag.

  Reason it is turned off is to simply component connectability in ESS since when stamping at the mac layer
  you need to explicitly know the headers added to the packet between the app layer and the mac layer.  In 
  this case its mDTN and multihop but with transceiver it makes the code difficult to manage

  */

 /*  
  async event void RadioSendCoordinator.blockTimer(){
    //called for every state transition
    //dont do anything
  }
 
  async event void RadioSendCoordinator.startSymbol(uint8_t bitsPerBlock, uint8_t offset, TOS_MsgPtr msgBuff){

    multihop_hdr_t *mhdr;
    timeSynchPkt_t *tpkt;
    mDTN_pkt_t *mpkt;
    uint8_t byteoff = 0;
    uint32_t timevalue=0;
    
    
    //first check if this is a Multihop Type message
    if(msgBuff->type == TAG_TREE_DISPATCH){
      
      //peel off multihop header
      mhdr = (multihop_hdr_t *)msgBuff->data;
      byteoff = sizeof(multihop_hdr_t);
      
      //then check if this is a timesync packet
      if(mhdr->type == TIMESYNC_APP){
	
	
	//peel off the dtn header
	mpkt = (mDTN_pkt_t*)&(msgBuff->data[byteoff]);
	//now get the timesync packet
	tpkt = (timeSynchPkt_t*)mpkt->data;
	
	timevalue =  call EssSysTimeI.getTime();
	tpkt->time = timevalue;
	
	
      }
      
    }
    
  }

  async event void RadioSendCoordinator.byte(TOS_MsgPtr msg, uint8_t byteCount){
    //we could do it here if we counted all the bytes, but then if someone changed any of the packets
    //then we would have to revisit this
    //its more precise here by baudrate*bitperpkt
  }
*/
#endif


  /*************************************/ 
  //Status Server Debug Interface
  /**************************************/

#ifdef TIMESYNC_DEBUG
  event void EmStatusServerI.Write(buf_t *buf){
  }
  event void EmStatusServerI.Printable(buf_t *buf){
  }
  event void EmStatusServerI.Binary(buf_t *buf){
  }

  event int8_t EmStatusServerI.CompressedBinary(char *buf, uint8_t *type, uint8_t length){

    *type = HM_ATTR_TYPE_TIMESYNC;

    //if not enough space then return the remaining length
    if(length < sizeof(timeDbgPkt_t)){
      return length;
    }
    
    memcpy(buf,&synchDbgOut,sizeof(timeDbgPkt_t));
    
    //return sizeof(timeDbgPkt_t);
    return length;
  }

  
#endif
 
#ifdef USE_SYMPATHY
  event result_t ProvideCompMetrics.exposeSymStats(Sympathy_comp_stats_t *data, uint8_t *len) {
      dbg(DBG_USR3,"TS Packets rcvd = %d\n",tsPacketsRcvd);
      memset(data, 0, sizeof(Sympathy_comp_stats_t));
      data->num_pkts_rx = tsPacketsRcvd;
      *len = sizeof(Sympathy_comp_stats_t);
      return SUCCESS;
  }

  event result_t ProvideCompMetrics.exposeGenericStats(uint8_t *data, uint8_t *len) {
    int64_t timevalue=0;

    timevalue =  call EssSysTimeI.getTime();
    *data = timevalue;
    *len = sizeof(int64_t);
    return SUCCESS;
  }
#endif 

  

}



