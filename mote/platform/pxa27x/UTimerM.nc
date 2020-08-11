// $Id: UTimerM.nc,v 1.1 2007/03/05 00:06:07 lnachman Exp $

/*									tab:4
 * "Copyright (c) 2000-2003 The Regents of the University  of California.  
 * All rights reserved.
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose, without fee, and without written agreement is
 * hereby granted, provided that the above copyright notice, the following
 * two paragraphs and the author appear in all copies of this software.
 * 
 * IN NO EVENT SHALL THE UNIVERSITY OF CALIFORNIA BE LIABLE TO ANY PARTY FOR
 * DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES ARISING OUT
 * OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN IF THE UNIVERSITY OF
 * CALIFORNIA HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 * 
 * THE UNIVERSITY OF CALIFORNIA SPECIFICALLY DISCLAIMS ANY WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE.  THE SOFTWARE PROVIDED HEREUNDER IS
 * ON AN "AS IS" BASIS, AND THE UNIVERSITY OF CALIFORNIA HAS NO OBLIGATION TO
 * PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS."
 *
 * Copyright (c) 2002-2003 Intel Corporation
 * All rights reserved.
 *
 * This file is distributed under the terms in the attached INTEL-LICENSE     
 * file. If you do not find these files, copies can be found by writing to
 * Intel Research Berkeley, 2150 Shattuck Avenue, Suite 1300, Berkeley, CA, 
 * 94704.  Attention:  Intel License Inquiry.
 */

/*
 *
 * Authors:             Joe Polastre <polastre@cs.berkeley.edu>
 *                      Rob Szewczyk <szewczyk@cs.berkeley.edu>
 *                      David Gay <dgay@intel-research.net>
 *                      David Moore
 *
 *                      Heavily modified by Robbie Adler for PXA27X 
 Revision:            $Id: UTimerM.nc,v 1.1 2007/03/05 00:06:07 lnachman Exp $
 * 
 */

/**
 * @author Su Ping <sping@intel-research.net>
 */


module UTimerM {
  provides interface UTimer[uint8_t id];
  provides interface StdControl;
  uses {
    interface Leds;
    interface UClock;
    interface PowerManagement;
  }
}

implementation {
  norace uint32_t mState;		// each bit represent a timer state 
  norace uint32_t mCurrentInterval;
  
  norace int8_t queue_head;
  norace int8_t queue_tail;
  norace uint8_t queue_size;
  norace uint8_t queue[NUM_TIMERS];
  uint16_t interval_outstanding;

  norace struct timer_s {
    uint8_t type;		// one-short or repeat timer
    int32_t ticks;		// clock ticks for a repeat timer 
    int32_t ticksLeft;	// ticks left before the timer expires
  } mTimerList[NUM_TIMERS];

  command result_t StdControl.init() {
    atomic{
      mState=0;
      queue_head = queue_tail = -1;
      queue_size = 0;
      
      mCurrentInterval = 0;
    }
    return call UClock.setRate(0, 0);
  }

  command result_t StdControl.start() {
    return SUCCESS;
  }

  command result_t StdControl.stop() {
    atomic{
      mState=0;
      mCurrentInterval = 0;
    }
    return SUCCESS;
  }
  
  command result_t UTimer.start[uint8_t id](char type, 
					   uint32_t interval) {
    uint32_t countRemaining, currentCount;
    
    if (id >= NUM_TIMERS){
      return FAIL;
    }
    if (type > TIMER_ONE_SHOT){
       return FAIL;
    }

    //	if ((type == TIMER_REPEAT) && interval <= 2) return FAIL;
	
    atomic {
      //interrupts are disabled here.  This means that it is possible for us
      //to read a counter value that is equal to its match value.  If this
      //is the case, it simply means that we beat the interrupt to the atomic
      //section.
      
      mTimerList[id].ticks = interval;
      mTimerList[id].ticksLeft = interval;
      mTimerList[id].type = type;
      
      //get the current counter value
      currentCount = call UClock.readCounter();
      //this is how much is left
      countRemaining = mCurrentInterval - currentCount; 
        
      //enable this timer
      mState|=(0x1L<<id);

      // there are 3 cases to consider:
      //1: no timer is started...start one
      //2: new timer is longer than the existing one....enqueue it
      //3: new timer is shorter or equal to the existing one:
      //   if(interval < mCurrentInterval)
      //      what we need will happen before the current interval expires
      //      if(mCurrentInterval-interval == mCurrrentInterval - originterval - diff == mCurrentInterval -interval -mcurrentInterval + currentcount ==  currentcount - interval 
 
      //        we're about to expire...t
      //   

      if(mCurrentInterval == 0){
	//we currently don't have a timer running
	
	//this is how much is left on our current interval
	mCurrentInterval=interval;
	call UClock.setInterval(interval);
      }
      else{
	//we have a timer actively running
	if( interval < countRemaining){
	  if(((countRemaining - interval) > 1  ) ){
	    //enough time remains for us to change the interval
	    
	    //let timer expired detection routing deal with negative arguments
	    mCurrentInterval = interval + currentCount;  
	    call UClock.setInterval(mCurrentInterval);
	  }
	  else{
	    //we're too close in time, but we won't miss this timer since, if a timer is running, it's interval must
	    //have been at least 1.  Thus, we'll fire off this timer the next time we interrupt
	  }
	}
	else{
	  //what's left is greater than what we need..add in what's already elapsed so that we're more accurate
	  mTimerList[id].ticksLeft += currentCount;
	} 
      }
    }
    return SUCCESS;
  }
 
  command result_t UTimer.stop[uint8_t id]() {
    
    result_t ret = FAIL;
    if (id>=NUM_TIMERS) return FAIL;
    
    atomic{
      if(mState&(0x1L<<id)) { // if the timer is running 
	mState &= ~(0x1L<<id);
       	ret = SUCCESS;
      }
    }
    return ret; //timer not running
  }


  default event result_t UTimer.fired[uint8_t id]() {
    return SUCCESS;
  }

  void enqueue(uint8_t value) {
    if (queue_tail == NUM_TIMERS - 1)
      queue_tail = -1;
    queue_tail++;
    queue_size++;
    queue[(uint8_t)queue_tail] = value;
  }

  uint8_t dequeue() {
    uint8_t ret;
    atomic{
      if (queue_size == 0){
	ret = NUM_TIMERS;
      }
      else if (queue_head == NUM_TIMERS - 1)
	queue_head = -1;
      queue_head++;
      queue_size--;
      ret = queue[(uint8_t)queue_head];
      }
    return ret;
  }
  
  task void signalOneUTimer() {
    uint8_t itimer = dequeue();
    if (itimer < NUM_TIMERS)
      signal UTimer.fired[itimer]();
  }
  
  async event result_t UClock.fire() {
    // no need for atomicc statements due to arm ISA guarantees
    uint32_t newInterval = ~((uint32_t) 0);
    uint32_t i;
    
    if (mState) {
      for (i=0;i<NUM_TIMERS;i++)  {
	if (mState&(0x1L<<i)) {
	  mTimerList[i].ticksLeft -= mCurrentInterval; 
	  if(mTimerList[i].ticksLeft < newInterval){
	    newInterval = mTimerList[i].ticksLeft;
	  }
	  if (mTimerList[i].ticksLeft<=0) {
	    /* DCM: only update the timer structure if the
	     * signalOneUTimer() task was able to be posted. */
	    if (post signalOneUTimer()) {
	      if (mTimerList[i].type==TIMER_REPEAT) {
		mTimerList[i].ticksLeft = mTimerList[i].ticks;
	      } else {// one shot timer 
		mState &=~(0x1L<<i); 
	      }
	      enqueue(i);
	    }
	    else {
	      trace(DBG_USR1,"FATAL ERROR:  UTimerM found Task queue full\r\n");
	      return FAIL;
	    }
	  }
	}
      }
    }
    
    if(newInterval != ~((uint32_t) 0)){
      //found a new timer interval to set
      mCurrentInterval = newInterval;
      call UClock.setInterval(mCurrentInterval);
    }
    else{
      mCurrentInterval = 0;
    }
    return SUCCESS;
  }
}
