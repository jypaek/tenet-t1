/*
 * Copyright (c) 2002, Vanderbilt University
 * All rights reserved.
 * Author: Brano Kusy (branislav.kusy@vanderbilt.edu)
 * Date last modified: July04
 */

#include "TestTimeSyncMsg.h"

module TestTimeSyncPollerM
{
    provides 
    {
        interface StdControl;
    }
    uses 
    {
        interface SendMsg;
        interface ReceiveMsg;
        interface Timer;
        interface Leds;
    }
}

implementation
{
    TOS_Msg msg;
    uint8_t last_id;
    uint32_t min,max;
        
    #define TimeSyncPollMsg ((TimeSyncPoll *)(msg.data))

    #ifndef TIMESYNC_POLLER_RATE
    #define TIMESYNC_POLLER_RATE 30
    #endif

    command result_t StdControl.init(){
        call Leds.init();
        TimeSyncPollMsg->senderAddr = TOS_LOCAL_ADDRESS;
        TimeSyncPollMsg->msgID = 0;
        return SUCCESS;
    }

    command result_t StdControl.start(){
        call Timer.start(TIMER_REPEAT, (uint32_t)1024 * TIMESYNC_POLLER_RATE);
        return SUCCESS;
    }

    command result_t StdControl.stop(){
        return SUCCESS;
    }
    
    event result_t SendMsg.sendDone(TOS_MsgPtr p, result_t success){
        return SUCCESS;
    }

    event result_t Timer.fired(){
        call Leds.redToggle();
        call SendMsg.send(TOS_BCAST_ADDR, TIMESYNCPOLL_LEN, &msg);
        ++(TimeSyncPollMsg->msgID);
        return SUCCESS;
    }

    event TOS_MsgPtr ReceiveMsg.receive(TOS_MsgPtr p){
        uint16_t *p_diagID  = (uint16_t*) &(p->data[1]);
        uint16_t *p_id      = (uint16_t*) &(p->data[6]);
        uint32_t *p_glob    = (uint32_t*) &(p->data[8]);
        
        if (*p_diagID != 1978)
            return p;
        
        if (*p_id == last_id){
            if (*p_glob<min || min == 0)
                min = *p_glob;
            if (*p_glob>max || max == 0)
                max = *p_glob;
        }
        else{
            if ( (max-min) > 7 )
                call Leds.set(7);
            else
                call Leds.set(max-min);
            max=0;
            min=0;
            last_id=TimeSyncPollMsg->msgID;
        }
        return p;
    }
}
