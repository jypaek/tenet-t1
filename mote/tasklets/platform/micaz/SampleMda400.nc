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
* MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE SOFTWARE
* PROVIDED HEREUNDER IS ON AN "AS IS" BASIS, AND THE UNIVERSITY OF
* SOUTHERN CALIFORNIA HAS NO OBLIGATION TO PROVIDE MAINTENANCE,
* SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS."
*
*/

/**
 * Sample tasklet for MDA400 vibration board.
 *
 * This tasklet is only for MDA400, and will not work with any other board.
 * Only one task can use this at a time.
 * May have some bugs (unknown, but observed unstable)
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 2/5/2007
 **/

#include "tenet_task.h"

module SampleMda400 {
    provides {
        interface StdControl;
        interface Element;
    }
    uses {
        interface MDA400I;
        interface Schedule;
        interface TenetTask;
        interface Memory;
        interface Timer;
        interface StdControl as SubControl;
    #ifdef GLOBAL_TIME
        interface GlobalTime;
    #else
        interface LocalTime;
    #endif
    }
}
implementation {
#include "tenet_debug.h"

    enum {
        NUM_CHANNELS = 3,
    }; 

    typedef struct sampleMda400_element_s {
        element_t e;
        uint16_t interval;
        uint16_t numKiloSamples;
        tag_t typeOut[ NUM_CHANNELS ];
        tag_t time_tag;
        uint8_t channelSelect; // bitmap for channel selection
        uint8_t samplesPerBuffer;
        uint32_t msBetweenFetches;
        uint32_t curr_offset[ NUM_CHANNELS ]; // not for continuous
        uint8_t curr_channel; // channel is {1,2,3} in MDA400 (not {0,1,2})
    } __attribute__((packed)) sampleMda400_element_t;

    enum {
        SAMPLE_MDA400_BEFORE_INIT = 1, // must power on
        SAMPLE_MDA400_IDLE,
        SAMPLE_MDA400_SAMPLING
    }; 

    sched_action_t sampleMda400_run(active_task_t *active_task, element_t *e);

    uint8_t mState;
    active_task_t *mATask;
    sampleMda400_element_t *mElement;
    uint8_t mGetDataBusy;

    void initMda400(){
        mState = SAMPLE_MDA400_IDLE;
        mATask = NULL;
        mElement = NULL;
        mGetDataBusy = FALSE;
    }

    task void stop_sampling() {
        if (!call MDA400I.stopSampling())
            post stop_sampling();
    }
    
    void resetMda400(){
        call Timer.stop();
        post stop_sampling();
        if (mATask) call TenetTask.active_task_delete(mATask);
        initMda400();
    }

    void sampleMda400_suicide(task_t *t, element_t *e) {
        resetMda400();
    }

    uint32_t getFetchPeriod(uint32_t uSecInterval, uint8_t numChannels,
                            uint16_t samplesPerBuffer){
        uint32_t result = uSecInterval;
        result *= samplesPerBuffer;
        result /= numChannels;
        result /= 1000; // usec to msec
        return result;
    }

    command element_t *Element.construct(task_t *t, void *data, uint16_t length) {
        sampleMda400_element_t *e;
        sampleMda400_params_t *p;
        uint8_t i;
        if (data == NULL || length < sizeof(sampleMda400_params_t)) {
            return NULL;
        }
        if ((e = (sampleMda400_element_t *)call Memory.malloc(sizeof(sampleMda400_element_t))) == NULL) {
            return NULL;
        }
        p = (sampleMda400_params_t *)data;
        call TenetTask.element_construct(t, (element_t *)e,
                                         ELEMENT_SAMPLEMDA400,
                                         sampleMda400_run,
                                         sampleMda400_suicide);
        e->interval = p->interval;
        e->channelSelect = p->channelSelect;
        e->numKiloSamples = p->numKiloSamples;
        e->samplesPerBuffer = p->samplesPerBuffer;
        e->time_tag = p->time_tag;
        e->curr_offset[0] = 0;
        e->curr_offset[1] = 0;
        e->curr_offset[2] = 0;
        e->curr_channel = NUM_CHANNELS; // increment before running
        for (i = 0; i < NUM_CHANNELS; i++) {
            e->typeOut[i] = p->typeOut[i]; // data type for each channel
        }
        e->msBetweenFetches = getFetchPeriod(p->interval, 
                                             p->channelSelect, 
                                             p->samplesPerBuffer);
        return (element_t *)e;
    }

    task void start_sampling() {
        sampleMda400_element_t *se = mElement;
        result_t ok;
        if (mATask == NULL || // not supposed start
            mElement == NULL ||
            mState != SAMPLE_MDA400_SAMPLING) {
            return;
        }
        if (se->numKiloSamples == 0) // continuous sampling
            ok = call MDA400I.startContinuousSampling(se->interval, se->channelSelect, 0);
        else
            ok = call MDA400I.startSampling(se->interval, se->channelSelect, 
                                           se->numKiloSamples, 0);
        if (!ok)
            post start_sampling();
    }
    
    sched_action_t sampleMda400_run(active_task_t *active_task, element_t *e) {
        sampleMda400_element_t *se = (sampleMda400_element_t *)e;

        if (mATask != NULL || // one-at-a-time
            mState != SAMPLE_MDA400_IDLE ||
            active_task == NULL) {
            return SCHED_NEXT;
        }
        mATask = active_task;
        mElement = se;

        post start_sampling();
        /* Zero at the last argument of above calls are for 'onset_detection'
           which the functionality resides inside the MDA400 vibecard.
           It was used for Wisden, but we do not use it for Tenet */
                                       
        mState = SAMPLE_MDA400_SAMPLING;
        return SCHED_STOP;
    }

    event void MDA400I.startSamplingDone(result_t success){
        data_t *dt;
        uint32_t curr_time;
        active_task_t *at;
        at = call TenetTask.active_task_clone(mATask);
        if (!at){
            call Schedule.next(mATask);
            resetMda400();
            return;
        }
      #ifdef GLOBAL_TIME
        if (call GlobalTime.getGlobalTime(&curr_time) == FAIL)
      #else
            curr_time = call LocalTime.read();
      #endif
        if ((dt = call TenetTask.data_new_copy(
                       mElement->time_tag + 1,
                       sizeof(uint32_t), &curr_time )) != NULL) {
            call TenetTask.data_push(at, dt); // push data to the cloned task, and
        }
        call Schedule.next(at); // send down the cloned task

        if (mElement->numKiloSamples == 0) { // continuous mode
            call Timer.start(TIMER_ONE_SHOT,mElement->msBetweenFetches);
        }
    }

    event void MDA400I.samplingComplete(){
        // only called when in non-continuous mode
        if (mElement->numKiloSamples != 0) { // non-continuous mode
            call Timer.start(TIMER_ONE_SHOT,mElement->msBetweenFetches);
        }
    }

    result_t incrementChannel(){
        uint8_t mask = mElement->channelSelect;
        uint8_t chan = mElement->curr_channel; //{1,2,3}
        if (mask == 0) return FAIL;
        do {
            chan++; // chan is {1,2,3} in MDA400 (not {0,1,2})
            if (chan > NUM_CHANNELS ) chan = 1;
        } while (!(mask & (0x01<<(chan-1))));
        mElement->curr_channel = chan;
        return SUCCESS;
    }

    result_t getNextData() {
        result_t ok;
        uint8_t prev_chan = mElement->curr_channel;
        
        if (incrementChannel() == SUCCESS) {

            if (mElement->numKiloSamples == 0) { // continuous
                ok = call MDA400I.getNextAvailData(mElement->curr_channel,
                                              mElement->samplesPerBuffer);
            }
            else { // non-continuous
                uint16_t num_req = mElement->numKiloSamples*1000 
                                   - mElement->curr_offset[mElement->curr_channel-1];
                if (num_req > mElement->samplesPerBuffer)
                    num_req = mElement->samplesPerBuffer;

                ok = call MDA400I.getData(mElement->curr_channel,
                                     num_req,
                                     mElement->curr_offset[mElement->curr_channel-1]);
            }
            if (ok)
                mGetDataBusy = TRUE;
            else {
                call Timer.start(TIMER_ONE_SHOT, 99);
                mElement->curr_channel = prev_chan;
            }
            return SUCCESS;
        }
        return FAIL;
    }
  
    task void power_on() {
        if (!call MDA400I.powerOn())
            post power_on();
    }

    event result_t Timer.fired(){
        if (mState == SAMPLE_MDA400_BEFORE_INIT) {
            post power_on();
        } 
        else if (mGetDataBusy == TRUE) {
            call Timer.start(TIMER_ONE_SHOT,mElement->msBetweenFetches);
            // do nothing
        }
        else if (getNextData() == FAIL) {
            resetMda400();
        }
        return SUCCESS;
    }

    void addDataToTask(uint8_t bytes, uint8_t *data){
        data_t *dt, *dt2;
        active_task_t *at;
        uint8_t samples = bytes/2;
        uint32_t sample_time;
        bool data_to_send = FALSE;

        mGetDataBusy = FALSE;

        if (bytes > 0) {
            at = call TenetTask.active_task_clone(mATask);
            if (!at) {
                call Schedule.next(mATask);
                resetMda400();
                return;
            }

            sample_time = mElement->curr_offset[mElement->curr_channel-1];

            if ((dt = call TenetTask.data_new_copy(
                                    mElement->typeOut[mElement->curr_channel-1], // tag type
                                    bytes, data)) != NULL) {
                if ((dt2 = call TenetTask.data_new_copy(
                                        mElement->time_tag,
                                        4, &sample_time )) != NULL) {
                    call TenetTask.data_push(at, dt); // push data to the cloned task, and
                    call TenetTask.data_push(at, dt2); // push data to the cloned task, and
                    data_to_send = TRUE;
                } else {
                    call TenetTask.data_delete(dt);
                }
            }
            if (data_to_send == TRUE) { // there is data to send
                call Schedule.next(at); // send down the cloned task

                /* update data offset (and clear channel if done) */
                mElement->curr_offset[mElement->curr_channel-1] += samples;
                if ((mElement->numKiloSamples != 0) &&
                    (mElement->curr_offset[mElement->curr_channel-1] >= mElement->numKiloSamples * 1000)) {
                    mElement->channelSelect &= ~(1<<(mElement->curr_channel-1));
                }
            } else {
                call TenetTask.active_task_delete(at);
            }
        }

        /* set the next timer fire time (to fetch next data) */
        if (samples < mElement->samplesPerBuffer){
            if (mElement->msBetweenFetches < 3000)
                mElement->msBetweenFetches += 20;
            else
                mElement->msBetweenFetches = 3000;
        }
        else {
            if (mElement->msBetweenFetches > 100)
                mElement->msBetweenFetches -= 2;
            else
                mElement->msBetweenFetches = 100;
        }      
        call Timer.start(TIMER_ONE_SHOT, mElement->msBetweenFetches);
    }

    event void MDA400I.nextAvailDataReady(uint8_t num_bytes, uint8_t *data) {
        addDataToTask(num_bytes, data);
    }
    event void MDA400I.dataReady(uint8_t num_bytes, uint8_t *data){
        addDataToTask(num_bytes, data);
    }

    command result_t StdControl.init() {
        call SubControl.init();
        initMda400();
        mState = SAMPLE_MDA400_BEFORE_INIT;
        return SUCCESS;
    }
    command result_t StdControl.start() {
        call Timer.start(TIMER_ONE_SHOT, 3000);
        call SubControl.start();
        call MDA400I.init();
        post stop_sampling();
        return SUCCESS;
    }

    command result_t StdControl.stop() {
        resetMda400();
        call SubControl.stop();
        return SUCCESS;
    }

    event void MDA400I.nextEventDataReady(uint8_t num_bytes, uint8_t *data, 
                                 uint32_t timestamp) {/* don't support this for now */}
    event void MDA400I.stopSamplingDone(result_t success) {}
    event void MDA400I.powerOnDone(result_t success) {
        /* No pre-run for now */
        initMda400();
        //call MDA400I.init();
    }
    event void MDA400I.powerOffDone(result_t success) {}

}
