/*
* "Copyright (c) 2006 2007 University of Southern California.
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
 * This tasklet work as a radio sensor.
 * When receiving a packet, it stores the RSSI value.
 * It is used for the Pursuer Evasion Game application.
 **/

#include "tenet_task.h"

module SampleRSSI {
    provides {
        interface Element;
    }
    uses {
        interface TenetTask;
        interface Memory;
        interface ReceiveMsg;
        interface Timer;
    }
}
implementation {

    typedef struct sampleRssi_element_s {
        element_t e;
        tag_t type;
    } __attribute__((packed)) sampleRssi_element_t;

    typedef struct {
        uint16_t n;
        uint16_t src;
        uint32_t seqno;
        uint32_t timestamp;
    } CountMsg_t;

    sched_action_t sampleRssi_run(active_task_t *active_task, element_t *e);
    void sampleRssi_suicide(task_t *t, element_t *e) {} // nothing to do

    enum {
        RSSI_TIMEOUT = 256,
    };

    uint16_t m_rssi = 0;
    uint16_t radio_data[2];

    command element_t *Element.construct(task_t *t, void *data, uint16_t length) {
        sampleRssi_element_t *e;
        sampleRssi_params_t *p;
        if ((data == NULL || length < sizeof(sampleRssi_params_t)) ||
            ((e = (sampleRssi_element_t *)call Memory.malloc(sizeof(sampleRssi_element_t))) == NULL)) {
            return NULL;
        }
        p = (sampleRssi_params_t *)data;
        call TenetTask.element_construct(t, (element_t *)e,
                ELEMENT_SAMPLERSSI,
                sampleRssi_run,
                sampleRssi_suicide);
        e->type = p->type;
        return (element_t *)e;
    }

    sched_action_t sampleRssi_run(active_task_t *active_task, element_t *e) {
        sampleRssi_element_t *se = (sampleRssi_element_t *)e;

        //call TenetTask.data_push(active_task,
        //           call TenetTask.data_new_copy(e->type, sizeof(uint16_t), &m_rssi));
        call TenetTask.data_push(active_task,
                call TenetTask.data_new_copy(se->type, sizeof(uint32_t), &radio_data[0]));

        return SCHED_NEXT;
    }

    event TOS_MsgPtr ReceiveMsg.receive(TOS_MsgPtr msg){
        CountMsg_t* evaderMsg;
        if (msg != NULL) {
            m_rssi = (uint16_t)((msg->strength - 60)&255);
            radio_data[0] = m_rssi;
            evaderMsg=(CountMsg_t*)msg->data;
            radio_data[1] = evaderMsg->src;
            call Timer.stop();
            call Timer.start(TIMER_ONE_SHOT, RSSI_TIMEOUT);
        }
        return msg;
    }

    event result_t Timer.fired() {
        m_rssi = 0;
        radio_data[0]=0;
        radio_data[1]=0;
        return SUCCESS;
    }
}


