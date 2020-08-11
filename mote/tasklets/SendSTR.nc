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

/*
 * Tasklet for the Stream Transport.
 *  - Similar to SendPkt except that it uses "StreamTransportC".
 *
 *  - Accept only one packet at a time.
 *    It is user's responsibility to do buffering somewhere else
 *    (Jul/5/2007) -jpaek
 *
 * @author Jeongyeup Paek
 * @author Ben Greenstein
 * @author August Joki
 * @modified 7/5/2007
*/

#include "tenet_task.h"

module SendSTR {
    provides {
        interface Element;
        interface StdControl;
    }
    uses {
        interface ConnectionSend as Send;
        interface Schedule;
        interface List;
        interface TenetTask;
        interface TaskError;
        interface Memory;
        interface RoutingTable;
    }
}
implementation {

    typedef struct sendSTR_element_s {
        element_t e;
        task_t *t;
        uint8_t state;
        uint8_t cid; // connection id
    } __attribute__((packed)) sendSTR_element_t;

    typedef enum {
        S_OPEN_WAIT,
        S_CONNECTED,
        S_SENDING
    } str_state_t;

    sched_action_t sendSTR_run(active_task_t *active_task, element_t *e);
    void sendSTR_suicide(task_t *t, element_t *e);

    /* global data */
    list_t m_list;
    list_t m_connlist;

    uint8_t m_buf[TR_DATA_LENGTH];    // packet buffer
    active_task_t *m_sending_atask = NULL;
    active_task_t *m_retry_atask = NULL;
    uint8_t m_retry_len = 0;

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

    list_action_t close_connection(void *item, void *meta){
        sendSTR_element_t *e = (sendSTR_element_t *)item;
        task_t *t = (task_t *)meta;
        if (e->t == t) {
            call Send.close(e->cid); // close connection
            return LIST_REMOVE;
        }
        return LIST_CONT;
    }

    command element_t *Element.construct(task_t *t, void *data, uint16_t length){
        sendSTR_element_t *e;
        uint8_t cid;

        /* this tasklet cannot start if there is no route */
        if (call RoutingTable.getParent() == 0xffff) {
            call TaskError.kill(t, ERR_NO_ROUTE, ELEMENT_SENDSTR, 0xff);
            return NULL;
        }

        /* allocate memory for this tasklet */
        if ((e = (sendSTR_element_t *)call Memory.malloc(sizeof(sendSTR_element_t))) == NULL) {
            call TaskError.kill(t, ERR_MALLOC_FAILURE, ELEMENT_SENDSTR, 0xff);
            return NULL;
        } 

        /* open a connection to the master */
        cid = call Send.open(call TenetTask.get_tid(t), call TenetTask.get_src(t));
        if (cid == 0xff) {
            /* connection open failure */
            call Memory.free(e); // must free here since never gave e ptr to installer
            call TaskError.kill(t, ERR_RESOURCE_BUSY, ELEMENT_SENDSTR, 0xff);
            return NULL;
        }
        if (!call List.push(&m_connlist, e)) {
            /* connection open failure */
            call Memory.free(e); // must free here since never gave e ptr to installer
            return NULL;
        }

        call TenetTask.element_construct(t, (element_t *)e,
                ELEMENT_SENDSTR,
                sendSTR_run,
                sendSTR_suicide);

        e->cid = cid;
        e->state = S_OPEN_WAIT;
        e->t = t;
        t->sendbusy = TRUE;
        return (element_t *)e;
    }

    task void pop_and_send() {
        active_task_t *a;
        sendSTR_element_t *e; 
        result_t ok = FAIL;
        uint16_t len = call Send.maxPayloadLength();

        if (m_sending_atask != NULL)
            return;

        /* retry previously serialized packet. */
        if (m_retry_atask) {
            a = m_retry_atask;
            len = m_retry_len;
            m_retry_atask = NULL;
            m_retry_len = 0;
        } 
        /* pop a packet from the queue */
        else if ((a = (active_task_t *)call List.pop(&m_list)) != NULL) {
            /* serialize bag of attributes into a packet */
            len = call TenetTask.data_serialize(a, m_buf, len);
            if (len == 0) {             
                /* No data to send in this active task */
                a->t->sendbusy = FALSE;
                call Schedule.next(a);
                post pop_and_send();
                return;
            }
        } else {
            /* "nothing more to send" */
            return;
        }

        e = (sendSTR_element_t *)call TenetTask.element_this(a);
        
        if (e->state == S_CONNECTED)
            ok = call Send.send(e->cid, len, m_buf);

        if (ok) {
            m_sending_atask = a;
            e->state = S_SENDING;
        } else {
            m_retry_atask = a;      // must retry... serialized packet
            m_retry_len = len;
            post pop_and_send();
        }
    }

    sched_action_t sendSTR_run(active_task_t *active_task, element_t *e) {
        /* don't bother if there is no data to send */
        if (active_task->data == NULL)
            return SCHED_NEXT;

        /* delete the previously pending active task. */
        // no two active task from the same task can be queued here.
        call List.iterate(&m_list, remove_task, active_task->t); 

        // push active task into 'to-process' queue.
        if (!call List.push(&m_list, active_task)) {
            call TaskError.kill(active_task->t, ERR_QUEUE_OVERFLOW, ELEMENT_SENDSTR, active_task->element_index);
            return SCHED_TERMINATE;
        }
        active_task->t->sendbusy = TRUE;
        
        /* send packet for next active_task in the list */
        post pop_and_send();
        return SCHED_STOP;
    }

    void sendSTR_suicide(task_t *t, element_t *e) {
        if (m_retry_atask && (m_retry_atask->t == t)) {
            call TenetTask.active_task_delete(m_retry_atask);
            m_retry_atask = NULL;
        }
        if (m_sending_atask && (m_sending_atask->t == t)) {
            call TenetTask.active_task_delete(m_sending_atask);
            m_sending_atask = NULL;
        }

        /* delete the active tasks that was waiting to be sent */
        call List.iterate(&m_list, remove_task, t);

        /* close connection */
        call List.iterate(&m_connlist, close_connection, t);
    }

    event void Send.sendDone(uint8_t cid, void *data, result_t success){
        sendSTR_element_t *e; 
        if (m_sending_atask) {
            e = (sendSTR_element_t *)call TenetTask.element_this(m_sending_atask);
            if (e && e->state == S_SENDING)
                e->state = S_CONNECTED;
            if (m_sending_atask->t)
                m_sending_atask->t->sendbusy = FALSE;
            call Schedule.next(m_sending_atask);
            m_sending_atask = NULL;
        }
        post pop_and_send();
    }

    list_action_t opendone_task(void *item, void *meta){
        sendSTR_element_t *e = (sendSTR_element_t *)item;
        uint8_t *pCid = (uint8_t *)meta;
        if (e->cid == *pCid) {
            if (e->state == S_OPEN_WAIT) {
                e->state = S_CONNECTED;
                e->t->sendbusy = FALSE;
            }
        }
        return LIST_CONT;
    }

    event void Send.openDone(uint8_t cid, uint16_t tid, uint16_t dst, result_t success) {
        if (success)
            call List.iterate(&m_connlist, opendone_task, &cid);
        post pop_and_send();
    }
    
    command result_t StdControl.init(){
        call List.init(&m_list);
        return SUCCESS;
    }

    command result_t StdControl.start(){return SUCCESS;}
    command result_t StdControl.stop(){return SUCCESS;}
}

