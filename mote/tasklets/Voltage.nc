/*
* "Copyright (c) 2006~2008 University of Southern California.
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
 * Tasklet for reading mote voltage level
 *
 * @author Jeongyeup Paek
 *
 * @modified Jun/25/2008
 **/

#include "tenet_task.h"

module Voltage {
    provides {
        interface StdControl;
        interface Element;
    }
    uses {
        interface ADC as Voltage;
        interface StdControl as ADCControl;
        interface Schedule;
        interface List;
        interface TenetTask;
        interface Memory;
    }
}


implementation {

    typedef struct voltage_element_s {
        element_t e;
        tag_t outputName;
    } __attribute__((packed)) voltage_element_t;

    sched_action_t voltage_run(active_task_t *active_task, element_t *e);

    list_t m_list;                      /* list of active tasks currently waiting for ADC */
    norace uint16_t m_data;
    active_task_t *m_pending_atask = NULL;   /* active task currently accessing ADC */

    task void handle_data();


/*************************************************************************/
    list_action_t remove_task(void *item, void *meta) {
        task_t *t = (task_t *)meta;
        active_task_t *at = (active_task_t *)item;

        if (at->t == t) {
            if (m_pending_atask == at)
                m_pending_atask = NULL;
            call TenetTask.active_task_delete(at);
            return LIST_REMOVE;
        }
        return LIST_CONT;
    }

    void voltage_suicide(task_t *t, element_t *e) {
        call List.iterate(&m_list, remove_task, t);
    }

/*************************************************************************/

    command element_t *Element.construct(task_t *t, void *data, uint16_t length) {
        voltage_element_t *e;
        voltage_params_t *p = (voltage_params_t *)data;

        if ((e = (voltage_element_t *)call Memory.malloc(sizeof(voltage_element_t))) == NULL)
            return NULL;

        call TenetTask.element_construct(t, (element_t *)e,
                ELEMENT_VOLTAGE,
                voltage_run,
                voltage_suicide);

        e->outputName = p->outputName;
        return (element_t *)e;
    }

/*************************************************************************/

    task void get_next_voltage() {  // get or wait for next item (set timer for next item)
        active_task_t *a;
        if ((a = (active_task_t *)call List.pop(&m_list)) != NULL) {
            m_pending_atask = a;
            if (call Voltage.getData() != SUCCESS) {
                post handle_data();
            }
        }
    }

/*************************************************************************/

    sched_action_t voltage_run(active_task_t *active_task, element_t *e) {

        call List.push(&m_list, active_task);

        if (m_pending_atask == NULL)
            post get_next_voltage();

        return SCHED_STOP;
    }

/*************************************************************************/

    task void handle_data() {
        voltage_element_t *se;
        
        if (m_pending_atask != NULL) {
            se = (voltage_element_t *)call TenetTask.element_this(m_pending_atask);

            call TenetTask.data_push(m_pending_atask,
                    call TenetTask.data_new_copy(se->outputName, sizeof(uint16_t), &m_data));

            call Schedule.next(m_pending_atask); // schedule the original active task
            m_pending_atask = NULL;
        }

        post get_next_voltage();
    }

/*************************************************************************/

    async event result_t Voltage.dataReady(uint16_t data){
        m_data = data;
        post handle_data();
        return SUCCESS;
    }

/*************************************************************************/
    command result_t StdControl.init() {
        call List.init(&m_list);
        return call ADCControl.init();
    }
    command result_t StdControl.start() {
        return call ADCControl.start();
    }
    command result_t StdControl.stop() { return SUCCESS; }

}

