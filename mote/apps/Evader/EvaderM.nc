/*
* "Copyright (c) 2006 University of Southern California.
* All rights reserved.
*
* Permission to use, copy, modify, and distribute this software and its
* documentation for any purpose, without fee, and without written
* agreement is hereby granted, provided that the above copyright
* notice, the following two paragraphs and the author appear in all
* copies of this software.
*
* IN NO EVENT SHALL THE UNIVERSITY OF SOUTHERN CALIFORNIA BE LIABLE TO
* ANY PARTY FOR DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL
* DAMAGES ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS
* DOCUMENTATION, EVEN IF THE UNIVERSITY OF SOUTHERN CALIFORNIA HAS BEEN
* ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*
* THE UNIVERSITY OF SOUTHERN CALIFORNIA SPECIFICALLY DISCLAIMS ANY
* WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
* MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.  THE SOFTWARE
* PROVIDED HEREUNDER IS ON AN "AS IS" BASIS, AND THE UNIVERSITY OF
* SOUTHERN CALIFORNIA HAS NO OBLIGATION TO PROVIDE MAINTENANCE,
* SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS."
*
*/

/**
* This is the part of the Pursuer Evasion Game.
* This is the Evader Application.
* It sends beacon periodically for the network to discover the Evader.
*
*/

//@author Marcos Vieira <mvieira@usc.edu>

//includes EvaderMsg;
includes CountMsg;

module EvaderM
{
  provides interface StdControl;
  uses {
    interface Timer;
    interface StdControl as CommControl;
    interface SendMsg as DataMsg;
    interface Leds;
	interface GlobalTime;
	interface Random;
  }
}
implementation{

enum{
  EVADER_SAMPLE_PERIOD=512,//half second base
};

  TOS_Msg msg;
  uint32_t seqno=0;
  uint32_t globalTime;

  command result_t StdControl.init(){
    call CommControl.init();
    call Leds.init();
    call Leds.yellowOff();call Leds.redOff();call Leds.greenOff();

    return SUCCESS;
  }

  command result_t StdControl.start(){
    //call Timer.start(TIMER_REPEAT,EVADER_SAMPLE_PERIOD);
    call Timer.start(TIMER_ONE_SHOT,EVADER_SAMPLE_PERIOD);
    call CommControl.start();

    return SUCCESS;
  }

  command result_t StdControl.stop(){
    result_t ok1,ok2;

    ok1=call Timer.stop();
    ok2=call CommControl.stop();

    return rcombine(ok1,ok2);
  }


  event result_t DataMsg.sendDone(TOS_MsgPtr sent, result_t success){
    call Leds.set(0);
    return SUCCESS;
  }


  task void dataTask(){
    uint16_t randomTimer;
    CountMsg_t* evaderMsg;
    //EvaderMsg_t* evaderMsg;
    atomic {
      //evaderMsg=(EvaderMsg_t*) msg.data;
		evaderMsg=(CountMsg_t*)msg.data;
    }
  
    seqno++;
    evaderMsg->src=TOS_LOCAL_ADDRESS;
    evaderMsg->seqno=seqno;
    call GlobalTime.getGlobalTime(&globalTime);
    evaderMsg->timestamp=globalTime;
    if(call DataMsg.send(TOS_BCAST_ADDR,sizeof(CountMsg_t),&msg)){
    //if(call DataMsg.send(TOS_BCAST_ADDR, sizeof(EvaderMsg_t),&msg)){
      call Leds.set(7);
    }
 
    randomTimer=(call Random.rand() & 0x03ff);
    call Timer.start(TIMER_ONE_SHOT,EVADER_SAMPLE_PERIOD+randomTimer);
  }


  event result_t Timer.fired(){
    post dataTask();
    return SUCCESS;  
  }

}

