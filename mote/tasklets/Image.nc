/*
* "Copyright (c) 2006~2007 University of Southern California.
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
 * Image tasklet that uses Cyclops.
 *
 * - This will only work on Micaz and Mica2.
 *
 * @author Jeongyeup Paek (jpaek@enl.usc.edu)
 * Embedded Networks Laboratory, University of Southern California
 * @modified 7/1/2007
 **/

#if !defined(PLATFORM_MICAZ) && !defined(PLATFORM_MICA2)
    # This will only work on Micaz and Mica2.
#endif

#include "tenet_task.h"
#include "cyclops_query.h"

module Image {
    provides {
        interface StdControl;
        interface Element;
    }
    uses {
        interface TenetTask;
        interface TaskError;
        interface Memory;
        interface Schedule;
        interface List;
        interface Timer as WaitTimer;
        interface Leds;

        //Neuron interfaces
        interface neuronH;
        interface StdControl as neuronControl;
    }
}
implementation {

    typedef struct image_element_s {
        element_t e;
        tag_t outName;
        uint8_t nModule;  //Neuron module (snapN, activeN, etc)
        uint8_t length;
        uint8_t slaveQuery[TOSH_DATA_LENGTH - 14];
    } __attribute__((packed)) image_element_t;

    /* global data */
    list_t m_list;

    // currently running active task (whether Image tasklet is busy or not)
    active_task_t *m_current_atask;
    // whether more fragments exist. Valid only when m_current_atask != NULL
    uint8_t m_sendmore;
    // buffer for fetching image fragment
    char imageRbuf[TOSH_DATA_LENGTH - 14];


    sched_action_t image_run(active_task_t *active_task, element_t *e);
    void image_suicide(task_t *t, element_t *e);
    task void execute_atask();


    /* stop execution of current active task */
    void stop_current_atask() {
        /* No need to schedule the original active task (we're done imaging)
           We only schedule cloned atasks that has the 'data' */
        if (m_current_atask) {
            m_current_atask->t->block_cloning = FALSE;
            call TenetTask.active_task_delete(m_current_atask);
            m_current_atask = NULL;
        }
        m_sendmore = 0;
        call Leds.yellowOff();
        call Leds.greenOff();
        post execute_atask();
    }

    /* remove active tasks (whose task matches t) in the waiting list */
    list_action_t remove_task(void *item, void *meta){
        active_task_t *i = (active_task_t *)item;
        task_t *t = (task_t *)meta;
        if (i->t == t) {
            call TenetTask.active_task_delete(i);
            return LIST_REMOVE;
        }
        return LIST_CONT;
    }

    void image_suicide(task_t *t, element_t *e) {
        call List.iterate(&m_list, remove_task, t); 
        if ((m_current_atask != NULL) && (m_current_atask->t == t)) {
            // TODO: how can I tell the cyclops to abort current execution?
            //image_element_t *e = (image_element_t *)call TenetTask.element_this(m_current_atask);
            //call neuronH.neuronSignalWrite(e->nModule, 0, e->slaveQuery);
            stop_current_atask();
        }
    }

    command element_t *Element.construct(task_t *t, void *data, uint16_t length) {
        image_element_t *e;
        image_params_t *p = (image_params_t *)data;

        if ((e = (image_element_t *)call Memory.malloc(sizeof(image_element_t))) == NULL)
            return NULL;

        call TenetTask.element_construct(t, (element_t *)e,
                ELEMENT_IMAGE,
                image_run,
                image_suicide);

        e->outName = p->outputName;
        e->nModule = p->nModule;
        e->length = p->length;
        memcpy(e->slaveQuery, p->slaveQuery, e->length);
        return (element_t *)e;
    }

    task void execute_atask() {
        image_element_t *e;
        active_task_t *a;
       
        if (m_current_atask != NULL)    // something is already running
            return;
        else if ((a = (active_task_t *)call List.pop(&m_list)) == NULL)
            return;

        e = (image_element_t *)call TenetTask.element_this(a);
        m_current_atask = a;
        m_current_atask->t->block_cloning = TRUE;

        if (call neuronH.neuronSignalWrite(e->nModule, e->length, e->slaveQuery)) {
            call Leds.yellowOn();
        } else {
            call TaskError.report(m_current_atask->t, ERR_SENSOR_ERROR, 
                    ELEMENT_IMAGE, m_current_atask->element_index);
            stop_current_atask();
        }
    }
    
    sched_action_t image_run(active_task_t *active_task, element_t *e) {

        /* Let's NOT have two active_tasks from same task within this tasklet.
           - Even if repeat is requested, do only one picture taking at a time.
           - But let's not disturb the current active_task. 
             Delete the new one if duplicate is the m_current_atask. */
        call List.iterate(&m_list, remove_task, active_task->t); 

        if ((m_current_atask != NULL) && (m_current_atask->t == active_task->t))
            return SCHED_TERMINATE;
        
        // push active task into 'to-process' queue.
        if (!call List.push(&m_list, active_task)) {
            call TaskError.kill(active_task->t, ERR_QUEUE_OVERFLOW, ELEMENT_IMAGE, active_task->element_index);
            return SCHED_TERMINATE;
        }
        
        post execute_atask();
        return SCHED_STOP;
    }

    task void readCyclopsResponse() {
        image_element_t *e;

        if ((m_sendmore == 0) || (m_current_atask == NULL)) {
            stop_current_atask();
            return;
        } else if (m_current_atask->t->sendbusy == TRUE) { // Temporary HACK for now
            call WaitTimer.start(TIMER_ONE_SHOT, 20);
            return;
        }

        call Leds.greenToggle();
        e = (image_element_t *)call TenetTask.element_this(m_current_atask);
        if (e) call neuronH.neuronSignalRead(e->nModule, (char *)imageRbuf);
        else call Leds.redOn();
    }

    event result_t neuronH.neuronSignalReadDone(uint8_t type, uint8_t len, char *data) {
        active_task_t *a_clone = NULL;
        image_element_t *e;
        cyclops_response_t *cr = (cyclops_response_t *)(data);

        if ((m_current_atask == NULL) || (data != imageRbuf)) {
            stop_current_atask();
            return SUCCESS;
        } 
        
        e = (image_element_t *)call TenetTask.element_this(m_current_atask);
       
        /* clone an active task so that we can send data down the task chain */
        a_clone = call TenetTask.active_task_clone(m_current_atask);
        if (a_clone == NULL) {
            call Leds.redOn();
            return SUCCESS;
        }

        /* RESPONSE_FAIL means that cyclops failed executing last query, 
           and it has returned some error */
        if (cr->type == CYCLOPS_RESPONSE_FAIL) {
            uint16_t data16 = 0;
            if (e->outName)
                call TenetTask.data_push(a_clone,
                    call TenetTask.data_new_copy(e->outName, sizeof(uint16_t), &data16));
        } 
        /* special processing for result_response_t */
        else if (cr->type == CYCLOPS_RESPONSE_RESULT) {
            result_response_t* dr = (result_response_t*)cr->data;
            uint16_t data16 = dr->result;
            call TenetTask.data_push(a_clone,
                    call TenetTask.data_new_copy(e->outName, sizeof(uint16_t), &data16));
        } 
        /* usual case: put 'data' into cloned active task */
        else {
            call TenetTask.data_push(a_clone,
                    call TenetTask.data_new_copy(e->outName, len, data));
        }

        /* send the cloned active task down the task chain */
        call Schedule.next(a_clone); // schedule the cloned task for transmission

        /* check to see if there are more packets to be sent */
        if (cr->more_left == 1) {
            m_sendmore = 1;
            post readCyclopsResponse();
        } else {  // fragNum == fragTotal
            m_sendmore = 0;
            stop_current_atask();
        }
        return SUCCESS;
    } 

    event result_t neuronH.neuronSignalWriteDone(result_t result) {
        if (result == FAIL)
            call Leds.redOn();
        m_sendmore = 1;     // I should have at least one thing to get
        post readCyclopsResponse();
        return SUCCESS;
    }

    event result_t WaitTimer.fired() {
        post readCyclopsResponse();
        return SUCCESS;
    }

    command result_t StdControl.init() {
        m_current_atask = NULL;
        m_sendmore = 0;
        call List.init(&m_list);
        return call neuronControl.init();
    }
    command result_t StdControl.start() {
        return call neuronControl.start();
    }
    command result_t StdControl.stop() {
        return call neuronControl.stop();
    }

}

