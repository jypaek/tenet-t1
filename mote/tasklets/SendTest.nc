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
 * 1-hop Send tasklet for testing the task libarary
 * - no multihop, no transport : send TOS_Msg directly to the link
 *
 * @author Jeongyeup Paek
 * @modified Mar/11/2008
 **/

#include "tenet_task.h"

module SendTest {
    provides {
        interface StdControl;
        interface Element;
        interface TransportSend as SneakSend; // for ErrorHandler reports
    }
    uses {
        interface SendMsg;
        interface Schedule;
        interface List;
        interface TenetTask;
        interface Memory;
        interface TaskError;
    }
}
implementation {
#include "../lib/tenet_debug.h"
#include "transport.h"

    typedef struct sendTest_element_s {
        element_t e;
    } __attribute__((packed)) sendTest_element_t;

    typedef struct {
        sendTest_element_t *e;
        active_task_t *a;
        uint16_t tid;
    } sendTest_item_t;   // active task queued in this tasklet

    typedef enum {
        SEND_IDLE,
        SEND_SENDING
    } send_state_t;

    typedef enum {
        SNEAK_IDLE,
        SNEAK_PENDING,
        SNEAK_SENDING
    } sneak_state_t;

    sched_action_t sendTest_run(active_task_t *active_task, element_t *e);
    void sendTest_suicide(task_t *t, element_t *e);

    list_t m_list;          /* list of active tasks that are waiting to send packet */
    list_t m_sendinglist;   /* list of tasks that are waiting for sendDone event */
    
    send_state_t m_be_state;/* whether we are busy sending Best-effort delivery packet */
    uint8_t m_buf[TR_DATA_LENGTH];  /* buffer share by all best effort transport */
    
    active_task_t *m_retry_atask;   /* an active task that should retry sending */
    uint8_t m_retry_len;            /* length of the packet that we should retry */
    
    /* 'sneak-send' is back-door access to this SendTest element.
       This is used for the ErrorHandler to report the error message back to the master.
       This has priority over the normal access by tasks */
    sneak_state_t m_sneak_state;
    void *m_sneak_data_ptr;
    uint8_t m_sneak_data_len;
    uint16_t m_sneak_tid, m_sneak_dst;

    TOS_Msg m_msg;
   
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

    /* construct the tasklet */
    command element_t *Element.construct(task_t *t, void *data, uint16_t length){
        sendTest_element_t *e;
        if ((e = (sendTest_element_t *)call Memory.malloc(sizeof(sendTest_element_t))) == NULL) {
            return NULL;
        }
        call TenetTask.element_construct(t, (element_t *)e,
                ELEMENT_SENDPKT,
                sendTest_run,
                sendTest_suicide);
        return (element_t *)e;
    }

    /* send the next queued packet */
    task void pop_and_send(){
        result_t ok;
        active_task_t *a;
        sendTest_element_t *e; 
        uint16_t tid, src;
        uint16_t len = 0;
        link_hdr_t *l = (link_hdr_t *)m_msg.data;

        if (m_sneak_state == SNEAK_PENDING) {
            memcpy(l->data, &m_sneak_data_ptr, m_sneak_data_len);
            l->src = TOS_LOCAL_ADDRESS;
            l->tid = m_sneak_tid;
            len = m_sneak_data_len + offsetof(link_hdr_t, data);
            ok = call SendMsg.send(m_sneak_dst, len, &m_msg);
            if (ok == SUCCESS) m_sneak_state = SNEAK_SENDING;
            else post pop_and_send();
            return;
        }
        
        if (m_be_state != SEND_IDLE) // temporarily, this is for sendbe only
            return;

        /* an already-serialized packet needs to be retried */
        if (m_retry_atask) {
            // data is already serialized...
            a = m_retry_atask;
            len = m_retry_len;
            m_retry_atask = NULL;
            m_retry_len = 0;
            e = (sendTest_element_t *)call TenetTask.element_this(a);
        }
        /* pop a packet from the queue */
        else if ((a = (active_task_t *)call List.pop(&m_list)) != NULL) {
            e = (sendTest_element_t *)call TenetTask.element_this(a);
            /* serialize linked-list of attributes into a packet */
            len = call TenetTask.data_serialize(a, m_buf, len);
            
            if (len == 0) {             
                /* No data to send in this active task */
                a->t->sendbusy = FALSE;
                call Schedule.next(a);
                post pop_and_send();
                return;
            }
        } else {
            /* No active task is waiting to send */
            return;
        }

        tid = call TenetTask.get_tid(a->t);
        src = call TenetTask.get_src(a->t); /* the address of the master that we send response to */

        memcpy(l->data, &m_buf, len);
        l->src = TOS_LOCAL_ADDRESS;
        l->tid = tid;
        len = len + offsetof(link_hdr_t, data);
        ok = call SendMsg.send(src, len, &m_msg);

        /* we are sending... waiting for senddone */
        if (ok == SUCCESS) {
            sendTest_item_t *tc;
            m_be_state = SEND_SENDING;

            /* maintain state to wait for senddone */
            if ((tc = (sendTest_item_t *)call Memory.malloc(sizeof(sendTest_item_t))) == NULL) {
                call TaskError.kill(a->t, ERR_MALLOC_FAILURE, ELEMENT_SENDPKT, a->element_index);
                a->t->sendbusy = FALSE;
                call TenetTask.active_task_delete(a);
            } else {
                tc->e = e;
                tc->a = a;
                tc->tid = tid;
                if (!call List.push(&m_sendinglist, tc)) {
                    call Memory.free(tc);
                    a->t->sendbusy = FALSE;
                    call TaskError.kill(a->t, ERR_MALLOC_FAILURE, ELEMENT_SENDPKT, a->element_index);
                    call TenetTask.active_task_delete(a);
                }
            }
        } else { /* call to .send failed... need to retry */
            m_retry_atask = a;
            m_retry_len = len;
        }
        post pop_and_send();
    }

    /* run: process next new active task */
    sched_action_t sendTest_run(active_task_t *active_task, element_t *e) {
        if (active_task->data == NULL) { // no data to send in this active_task
            return SCHED_NEXT;
        }
        
        // no two active task from the same task can be queued here.
        call List.iterate(&m_list, remove_task, active_task->t); 
        
        // push active task into 'to-process' queue.
        if (!call List.push(&m_list, active_task)) {
            call TaskError.kill(active_task->t, ERR_QUEUE_OVERFLOW, ELEMENT_SENDPKT, active_task->element_index);
            return SCHED_TERMINATE;
        }
        active_task->t->sendbusy = TRUE;
        post pop_and_send(); /* process next active task in the queue */
        return SCHED_STOP;
    }

    void sendTest_suicide(task_t *t, element_t *e) {
        if (m_retry_atask && (m_retry_atask->t == t)) {
            call TenetTask.active_task_delete(m_retry_atask);
            m_retry_atask = NULL;
        }
        call List.iterate(&m_list, remove_task, t);
    }

    /**
     * Back-door send interface for the task ErrorHandler to send error reports
     * back to the master. This was made so that it does not collide with 
     * the normal task-chain send action.
     **/
    command result_t SneakSend.send(uint16_t tid, uint16_t dst, uint8_t len, void *data) {
        if (m_sneak_state != SNEAK_IDLE)
            return FAIL;
        m_sneak_tid = tid;
        m_sneak_dst = dst;
        m_sneak_data_ptr = data;
        m_sneak_data_len = len;
        m_sneak_state = SNEAK_PENDING;
        post pop_and_send();
        return SUCCESS;
    }

    command uint8_t SneakSend.maxPayloadLength() {
        return 50; // any dummy value
    }

    command result_t StdControl.init(){
        call List.init(&m_list);
        m_be_state = SEND_IDLE;
        m_sneak_state = SNEAK_IDLE;
        m_retry_atask = NULL;
        return SUCCESS;
    }

    command result_t StdControl.start(){return SUCCESS;}
    command result_t StdControl.stop(){return SUCCESS;}

    list_action_t senddone_task(void *item, void *meta){
        sendTest_item_t *c = (sendTest_item_t *)item;
        uint16_t *pTid = (uint16_t *)meta;
        if (c->tid == *pTid) {
            m_be_state = SEND_IDLE;
            if ((c->a->data == NULL) || (!call List.push(&m_list, c->a))) {
                c->a->t->sendbusy = FALSE;
                call Schedule.next(c->a);
            }
            call Memory.free(c);    /* free list item */
            return LIST_REMOVE;
        }
        return LIST_CONT;
    }

    void sendDone(uint16_t tid, void *data, result_t success) {
        if (m_sneak_state == SNEAK_SENDING) {
            m_sneak_state = SNEAK_IDLE;
            signal SneakSend.sendDone(tid, data, success);
        } else {
            call List.iterate(&m_sendinglist, senddone_task, &tid);
        }
        post pop_and_send();
    }

    event result_t SendMsg.sendDone(TOS_MsgPtr msg, result_t success) {
        link_hdr_t *l = (link_hdr_t *)msg->data;
        sendDone(l->tid, l->data, success);
        return SUCCESS;
    }
}


