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
 * Attribute storage (Store/Restore) tasklet.
 *
 * Store an attribute into storage, and/or restore an attribute from storage.
 * - Storing an attr into storage does not remove that attr from current active task.
 * - Retrieving an attr from storage does not remove that attr from current storage.
 * - Storage is valid within a task, across repeated runs of active tasks.
 * - Storing overwrites the previously written attr with same type, within same task.
 * - Storage is cleared when the task is deleted. (not when active_task is deleted)
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 8/9/2007
 **/

#include "tenet_task.h"

module Storage {
    provides {
        interface StdControl;
        interface Element;
    }
    uses {
        interface TenetTask;
        interface List;
        interface Memory;
        interface TaskError;
    }
}
implementation {

    typedef struct storage_element_s {
        element_t e;
        tag_t tagIn;
        tag_t tagOut;
        uint8_t store;  /* 1: store, 0: restore */
    } storage_element_t;

    typedef struct {
        /* we store attributes as data linked to a dummy active task */
        active_task_t data_holder; 
    } storage_item_t;

    /**
     * List of all stored attributes
     **/
    list_t m_list;
    active_task_t *m_pending_active_task;

    sched_action_t storage_run(active_task_t *active_task, element_t *e);
    void storage_suicide(task_t *t, element_t *e);

    /**
     * Remove all storage_item and it's associated data 
     * in the list that belongs to task 'meta'.
     **/
    list_action_t remove_task(void *item, void *meta){
        storage_item_t *i = (storage_item_t *)item;
        active_task_t *at = &i->data_holder;
        task_t *t = (task_t *)meta;
        if (at->t == t) {
            data_t *tmp;
            while ((tmp = at->data) != NULL) {
                at->data = at->data->next;
                call TenetTask.data_delete(tmp);
            }
            call Memory.free(i);
            return LIST_REMOVE;
        }
        return LIST_CONT;
    }
    
    list_action_t store_data(void *item, void *meta){
        storage_item_t *i = (storage_item_t *)item;
        active_task_t *at = &i->data_holder;
        data_t *dOut = (data_t *)meta;
        if (m_pending_active_task->t == at->t) {
            call TenetTask.data_push(at, dOut);
            return LIST_BREAK;
        }
        return LIST_CONT;
    }

    list_action_t restore_data(void *item, void *meta){
        storage_item_t *i = (storage_item_t *)item;
        active_task_t *at = &i->data_holder;
        storage_element_t *e = (storage_element_t *)meta;
        data_t *d, *dOut;
        if (m_pending_active_task->t == at->t) {
            if ((d = call TenetTask.data_get_by_type(at, e->tagIn)) != NULL) {
                if ((dOut = call TenetTask.data_new_copy(e->tagOut, d->attr.length, d->attr.value)) != NULL) {
                    call TenetTask.data_push(m_pending_active_task, dOut);  /* put it in current active task */
                    //call TenetTask.data_remove(at, d);  /* delete from storage */
                } else {
                    call TaskError.kill(at->t, ERR_MALLOC_FAILURE, ELEMENT_STORAGE, at->element_index);
                }
            } else {
                call TaskError.kill(at->t, ERR_INVALID_ATTRIBUTE, ELEMENT_STORAGE, at->element_index);
            }
            return LIST_BREAK;
        }
        return LIST_CONT;
    }

    /* check whether data_holder for this task has already be allocated or not.
       we need this b/c a task may use multiple 'Storage' tasklets. */
    list_action_t check_storage(void *item, void *meta){
        storage_item_t *i = (storage_item_t *)item;
        active_task_t *at = &i->data_holder;
        task_t *t = (task_t *)meta;
        if (at->t == t) {
            m_pending_active_task = at;
            return LIST_BREAK;
        }
        return LIST_CONT;
    }
    
    command element_t *Element.construct(task_t *t, void *data, uint16_t length) {
        storage_element_t *e;
        storage_params_t *p;
        storage_item_t *tc;
        if (data == NULL || length < sizeof(storage_params_t)) {
            return NULL;
        }
        if ((e = (storage_element_t *)call Memory.malloc(sizeof(storage_element_t))) == NULL) {
            call TaskError.kill(t, ERR_MALLOC_FAILURE, ELEMENT_STORAGE, 0);
            return NULL;
        }
        p = (storage_params_t *)data;
        call TenetTask.element_construct(t, (element_t *)e,
                ELEMENT_STORAGE,
                storage_run,
                storage_suicide);
        e->tagIn = p->tagIn;
        e->tagOut = p->tagOut;
        e->store = p->store;

        /* check whether data_holder for this task has already be allocated or not */
        m_pending_active_task = NULL;
        call List.iterate(&m_list, check_storage, t);

        if (m_pending_active_task == NULL) {
            if ((tc = (storage_item_t *)call Memory.malloc(sizeof(storage_item_t))) == NULL) {
                call TaskError.kill(t, ERR_MALLOC_FAILURE, ELEMENT_STORAGE, 0);
                return NULL;
            }
            tc->data_holder.t = t;
            tc->data_holder.data = NULL;
            call List.push(&m_list, tc);
        }

        return (element_t *)e;
    }

    sched_action_t storage_run(active_task_t *active_task, element_t *e) {
        storage_element_t *se = (storage_element_t *)e;
        data_t *d, *dOut;

        if (se->store) {     /* store */
            if ((d = call TenetTask.data_get_by_type(active_task, se->tagIn)) != NULL) {
                if ((dOut = call TenetTask.data_new_copy(se->tagOut, d->attr.length, d->attr.value)) != NULL) {
                    m_pending_active_task = active_task;
                    call List.iterate(&m_list, store_data, dOut);     /* store into storage */
                    m_pending_active_task = NULL;
                    //call TenetTask.data_remove(active_task, d);     /* delete from active task */
                } else {
                    call TaskError.kill(active_task->t, ERR_MALLOC_FAILURE, 
                                        ELEMENT_STORAGE, active_task->element_index);
                    return SCHED_TERMINATE;
                }
            } else {
                call TaskError.kill(active_task->t, ERR_INVALID_ATTRIBUTE, 
                                    ELEMENT_STORAGE, active_task->element_index);
                return SCHED_TERMINATE;
            }
        } else {            /* restore */
            m_pending_active_task = active_task;
            call List.iterate(&m_list, restore_data, e);
            m_pending_active_task = NULL;
        }
        return SCHED_NEXT;
    }

    void storage_suicide(task_t *t, element_t *e) {
        call List.iterate(&m_list, remove_task, t);
    }

    command result_t StdControl.init(){
        call List.init(&m_list);
        m_pending_active_task = NULL;
        return SUCCESS;
    }
    command result_t StdControl.start(){return SUCCESS;}
    command result_t StdControl.stop(){return SUCCESS;}

}

