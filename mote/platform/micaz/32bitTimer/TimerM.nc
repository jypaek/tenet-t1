// $Id: TimerM.nc,v 1.8 2008-05-28 00:30:57 jpaek Exp $

/*                                    tab:4
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
 * Revision:            $Id: TimerM.nc,v 1.8 2008-05-28 00:30:57 jpaek Exp $
 * This implementation assumes that DEFAULT_SCALE is 3.
 */

/**
 * @author Su Ping <sping@intel-research.net>
 */

/*
 * ENL-Timer
 * Author: Krishna Kant Chintalapudi, Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 */

/* The ENLtimer is drastically different from the native tinyos Timer
    in its implementation since it works with ENLClock which lets overflow 
    interrupts happen and disables the re-initialization of timer counter 
    to 0 after a compare and match*/

/* right now since it will take baout 12 days for the 33 bit to some up I
     decided to forget it for the time being*/

 
module TimerM {
    provides {
        interface Timer[uint8_t id];
        interface AbsoluteTimer[uint8_t id];
        interface StdControl;
    }
    uses {
        interface Leds;
        interface Clock;
        interface PowerManagement;
        interface LocalTime as ClockTime;
    }
}

implementation {
    uint32_t mState;        // each bit represent a timer state (alive/dead)
    uint8_t    setIntervalFlag;
    uint8_t mScale, mInterval;
    int8_t queue_head;
    int8_t queue_tail;
    uint8_t queue_size;
    uint8_t queue[NUM_TIMERS];

    // volatile uint16_t interval_outstanding;
    int earliestTimer; // the timer id which is going to expire next
    
    norace bool firePending;

    struct timer_s {
        uint8_t type;        // one-short or repeat timer
        int32_t interval;        // clock ticks for a repeat timer
        uint32_t nextTime;    // system time at which next fire is scheduled
    } mTimerList[NUM_TIMERS];

    enum {
        TIMER_ABSOLUTE = 2,
        maxTimerInterval = 230, //beyond the maximum value of the timer register value
        clk_freq = 32768L //mscale=1
        //clk_freq = 4096L //mscale=2
        //clk_freq = 1024  // mscale=3
    };

    //initializes the ENLtimer
    command result_t StdControl.init() {
        mState = 0;
        setIntervalFlag = 0;
        queue_head = queue_tail = -1;
        queue_size = 0;

        mScale = 1; //this gives 2^15htz
        //mScale = 2; //this gives me 4096 Htz
        //mScale = 3; //this gives me 1024Htz
        mInterval = 128; //arbitrarily chosen to initialize

        earliestTimer = -1; //no timer to expire
        firePending = FALSE;
        return call Clock.setRate(mInterval, mScale);
    }

    command result_t StdControl.start() {
        return SUCCESS;
    }

    command result_t StdControl.stop() {
        mState=0;
        mInterval = maxTimerInterval; // temporarily modified (-1)... -jpaek
        setIntervalFlag = 0;
        return SUCCESS;
    }

//gets the closest approximation to the desired interval
//basically it finds checks till one decimal point and makes
//sure the rouding off is towards the closer interval
//so there may be a slight uncer/over estimation.
    static uint32_t getInterval(uint32_t interval) {
    #ifdef ADJUST_1024_1000_IN_TIMERM
        uint32_t t1,t2,t10;
        t10 = (clk_freq*interval)/100;
        t1 = t10 / 10;
        t2 = t1 + 1;
        if(t10 - (t1*10) > (t2*10) - t10)
            t1 = t2;
    #else
        uint32_t t1;
        t1 = (clk_freq/1024)*interval;
    #endif
        return t1;
     }

    void setTimer(uint8_t id, uint32_t atime) {
        uint8_t intval;
        uint32_t mask;
        uint32_t one = 0x1L;
        mask = 255;

        atomic{
            mTimerList[id].nextTime = atime;
            if (!mState) { //no timer was started before this one
                earliestTimer = (int)id; //set this one as the earliest timer
            } else {
                //is the new timer earliest than the earliest timer, then set it as the earliest one
                if (mTimerList[earliestTimer].nextTime > mTimerList[id].nextTime)
                    earliestTimer = (int)id;
            }
            if (earliestTimer == id){
                intval = ((uint8_t)(mTimerList[id].nextTime & mask)); //take last 8 bits of the time
                call Clock.setInterval(intval); //fill the compare and match with this value
                setIntervalFlag = 0;
                call PowerManagement.adjustPower();
            }
            mState |= (one<<id); //make this timer alive
        }
    }

    command result_t Timer.start[uint8_t id](char type, uint32_t interval) {
        uint32_t cur_time;
        interval = getInterval(interval); //do the conversion to ticks (rate at which system is going)
        if (id >= NUM_TIMERS) return FAIL; //too many timers
        if (type > 1) return FAIL;

        atomic cur_time = call ClockTime.read();

        mTimerList[id].interval = interval;
        mTimerList[id].type = type;

        //calculate the system time when the next timer should fire
        //mTimerList[id].nextTime = cur_time + mTimerList[id].interval;
        setTimer(id, (cur_time + mTimerList[id].interval));

        return SUCCESS;
    }

    command result_t AbsoluteTimer.set[uint8_t id](uint32_t atime) {
        uint32_t cur_time;
        if (id >= NUM_TIMERS) return FAIL; //too many timers

        atomic cur_time = call ClockTime.read();
        if (atime <= cur_time) return FAIL; // asked for time in past

        mTimerList[id].interval = atime - cur_time;
        mTimerList[id].type = TIMER_ABSOLUTE;

        setTimer(id, atime);

        return SUCCESS;
    }

//to figure out who to put next in the compare and match register
    static void adjustInterval() {
        uint32_t nearest_time = 0;
        uint32_t mask;
        uint8_t intval;
        int i;
        uint32_t one = 0x1L;

        //initialize to the max possible time
        mask= 255;
        earliestTimer=-1;
        //find the earliest timer to be fired next
        if (mState) { //any timers are pending at all
            for (i = 0; i < NUM_TIMERS; i++) { //check over all timers
                if (mState & (one<<i)) { //this timer is alive
                    if (earliestTimer == -1) {
                        earliestTimer = (int) i;
                        nearest_time = mTimerList[i].nextTime;
                    } else if (nearest_time > mTimerList[i].nextTime){
                        earliestTimer = (int)i;
                        nearest_time = mTimerList[i].nextTime;
                    }
                }
            }
            //now that we have found the nearest timer to be fired, lets
            //set the compare and match register
            atomic {
                intval = ((uint8_t)(nearest_time & mask)); //takes the smallest 8 bits
                call Clock.setInterval(intval);
                setIntervalFlag = 0;
            }

        } else {
            atomic {
                call Clock.setInterval(mInterval); //set this back to arbitrary value we decided on!!!
                setIntervalFlag = 0;
            }
        }
        call PowerManagement.adjustPower();
    }

    result_t stopTimer(uint8_t id) {

        uint32_t one = 0x1L;
        if (id >= NUM_TIMERS) return FAIL;
        if (mState & (one<<id)) { // if the timer is running
            atomic mState &= ~(one<<id);
            if (!mState) {
                setIntervalFlag = 1;
            }
            return SUCCESS;
        }
        return FAIL; //timer not running
    }

    command result_t Timer.stop[uint8_t id]() {
        return stopTimer(id);
    }

    command result_t AbsoluteTimer.cancel[uint8_t id]() {
        return stopTimer(id);
    }


    default event result_t Timer.fired[uint8_t id]() {
        return SUCCESS;
    }

    default event result_t AbsoluteTimer.fired[uint8_t id]() {
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
        if (queue_size == 0)
            return NUM_TIMERS;
        if (queue_head == NUM_TIMERS - 1)
            queue_head = -1;
        queue_head++;
        queue_size--;
        return queue[(uint8_t)queue_head];
    }

    task void signalOneTimer() {
        uint8_t itimer = dequeue();
        if (itimer < NUM_TIMERS) {
            if (mTimerList[itimer].type == TIMER_ABSOLUTE) {
                signal AbsoluteTimer.fired[itimer]();
            } else {
                signal Timer.fired[itimer]();
            }
        }
    }


//check if indeed signalling needs to be done
//if yes then do it and then schedule the next timer to be fired

    task void HandleFire() {
        uint32_t i;
        uint32_t cur_time;
        uint8_t if_fire;
        uint32_t one = 0x1L;
        setIntervalFlag = 1;

        atomic {
            firePending = FALSE;
        }

        if (mState) { //theres atleast one timer alive
            for (i = 0; i < NUM_TIMERS; i++) { //go over all timers
                if (mState & (one<<i)) {
                    cur_time = call ClockTime.read();
                    if_fire = 0;    //I want to find out if I want to fire this timer
                    
                // cannot tick again within <3ms... so we look 60 ticks in the future
                // 60 tick is around 2ms (32.768KHz)
                    if (mTimerList[i].nextTime <= (cur_time + 60))
                         if_fire = 1;    //set ot fire the timer

                    if (if_fire) {
                        if (mTimerList[i].type == TIMER_REPEAT) { 
                            //reshedule a firing time
                            mTimerList[i].nextTime += mTimerList[i].interval;
                        } else {// one shot timer
                            mState &= ~(one<<i); //byebye to this timer, its job is done
                        }
                        enqueue(i); //enqueue this timer to be fired asap
                        post signalOneTimer();    //dequeue one timer and fire the timer
                    //each time a timer goes it one is scheduled for fire, so divergence =0!!!
                    }
                }
            }
        }
        adjustInterval(); //figure out who is to be fired next and put it in
                //hopefully everything that was done finished in next 1/2 a millisecond
    }

    //processed each time the compare and match is enabled
    async event result_t Clock.fire(){
        atomic {
            if (!firePending)
                post HandleFire();
            firePending = TRUE;
        }
        return SUCCESS;
    }

}

