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
 * Module that contains functions related to Tenet Task Library.
 * Those functions include:
 * - task creation, deletion, manipulation, and lookup
 * - active_task creation, deletion, manipulation, and lookup
 * - data attribute creation, deletion, manipulation, and lookup
 * - list data structure creation, deletion, manipulation, and lookup
 * This module is state-less except for one variable: number of tasks.
 *
 * @author Ben Greenstein
 * @author Jeongyeup Paek
 * @modified 3/6/2007
 **/

#include "tenet_task.h"
 
module TaskLib {
    provides {
        interface List;
        interface TenetTask;
    }
    uses {
        interface Memory;
    }
}
implementation {
  #include "tenet_debug.h"

    void list_init(list_t *list);
    bool list_push(list_t *list, void *data);
    bool list_remove(list_t *list, void *data);
    void *list_pop(list_t *list);
    void list_iterate(list_t *list, operator_fn_t op_fn, void *meta);
    bool list_empty(list_t *list);

    uint32_t task_id(active_task_t *atask);
    uint16_t get_tid(task_t *t);
    uint16_t get_src(task_t *t);
    void element_construct(task_t *t, element_t *e,
            uint16_t id,
            run_t run,
            suicide_t suicide);
    element_t *element_this(active_task_t *atask);
    void element_delete(task_t *t, element_t *e);

    active_task_t *active_task_clone(active_task_t *atask);
    void active_task_delete(active_task_t *active_task);
    active_task_t *active_task_new(task_t *t);

    data_t *data_new(uint16_t type, uint16_t length, void *data);
    data_t *data_new_copy(uint16_t type, uint16_t length, void * value);
    void data_delete(data_t *data);
    data_t *data_get_by_type(active_task_t *active_task, uint16_t type);
    data_t *data_copy(data_t *data);
    void data_push(active_task_t *at, data_t *d);
    data_t *data_pop(active_task_t *at);
    bool data_to_send(active_task_t *at);
    //  uint8_t data_list_size(active_task_t *at);
    bool data_remove(active_task_t *active_task, data_t *d);
    uint16_t data_serialize(active_task_t *at, uint8_t *dst, uint16_t dst_len);

    task_t *task_new(uint8_t num_elements, uint32_t id);
    void task_delete(task_t *t);

    uint32_t time_diff(uint32_t time1, uint32_t time2);
  
  //--------------------------------------------------------------------------------

  /* Although it is nice to keep this 'TaskLib.nc' stateless,
     there is no better place to keep the count of tasks and active tasks.
     I did try, but it is easiest (and cheapest in terms of code size) 
     to keep it here */
    uint16_t task_count = 0;
    uint16_t active_task_count = 0;
  
  //--------------------------------------------------------------------------------

    command void List.init(list_t *list) {
        list_init(list);
    }
    command bool List.push(list_t *list, void *data) {
        return list_push(list, data);
    }
    command bool List.remove(list_t *list, void *data) {
        return list_remove(list, data);
    }
    command void *List.pop(list_t *list) {
        return list_pop(list);
    }
    command void List.iterate(list_t *list, operator_fn_t op_fn, void *meta) {
        list_iterate(list, op_fn, meta);
    }
    command bool List.empty(list_t *list) {
        return list_empty(list);
    }
  
  //--------------------------------------------------------------------------------
  
    command uint32_t TenetTask.task_id(active_task_t *atask) {
        return task_id(atask);
    }
    command uint16_t TenetTask.get_tid(task_t *t) {
        return get_tid(t);
    }
    command uint16_t TenetTask.get_src(task_t *t) {
        return get_src(t);
    }
    command void TenetTask.element_construct(task_t *t, element_t *e,
            uint16_t id, run_t run, suicide_t suicide) {
        element_construct(t, e, id, run, suicide);
    }
    command element_t *TenetTask.element_this(active_task_t *atask) {
        return element_this(atask);
    }
    command active_task_t *TenetTask.active_task_new(task_t *t) {
        /* TaskInstallerM.nc is the only place where this command is called */
        return active_task_new(t);
    }
    command active_task_t *TenetTask.active_task_clone(active_task_t *atask) {
        return active_task_clone(atask);
    }
    command void TenetTask.active_task_delete(active_task_t *active_task) {
        active_task_delete(active_task);
    }
    command data_t *TenetTask.data_new(tag_t type, uint16_t length, void *data) {
        return data_new(type, length, data);
    }
    command data_t *TenetTask.data_new_copy(tag_t type, uint16_t length, void * value) {
        return data_new_copy(type, length, value);
    }
    command void TenetTask.data_delete(data_t *data) {
        data_delete(data);
    }
    command data_t *TenetTask.data_get_by_type(active_task_t *active_task, uint16_t type) {
        return data_get_by_type(active_task, type);
    }
    command data_t *TenetTask.data_copy(data_t *data) {
        return data_copy(data);
    }
    command void TenetTask.data_push(active_task_t *at, data_t *d) {
        data_push(at, d);
    }
    command data_t *TenetTask.data_pop(active_task_t *at) {
        return data_pop(at);
    }
    command bool TenetTask.data_remove(active_task_t *active_task, data_t *d) {
        return data_remove(active_task, d);
    }
    command uint16_t TenetTask.data_serialize(active_task_t *at, uint8_t *dst, uint16_t dst_len) {
        return data_serialize(at, dst, dst_len);
    }
    command task_t *TenetTask.task_new(uint8_t num_elements, uint32_t id) {
        /* TaskInstallerM.nc is the only place where this command is called */
        return task_new(num_elements, id);
    }
    command void TenetTask.task_delete(task_t *t) {
        task_delete(t);
    }

    command uint32_t TenetTask.time_diff(uint32_t time1, uint32_t time2) {
        return time_diff(time1, time2);
    }

    command uint16_t TenetTask.get_task_count() {
        return task_count;
    }

    command uint16_t TenetTask.get_active_task_count() {
        return active_task_count;
    }

  //--------------------------------------------------------------------------------
  
    void list_init(list_t *list) {
        if (list == NULL) {
            tlog(LOG_ERR,"null list\n");
            return;
        }
        list->head = NULL;
        list->tail = NULL;
    }
    bool list_push(list_t *list, void *data) {
        list_item_t *item;
        tlog(LOG_DEBUG, "entered\n");
        if (list == NULL || data == NULL) {
            tlog(LOG_ERR,"item alloc failed\n");
            return FALSE;
        }
        item = (list_item_t *)call Memory.malloc(sizeof(list_item_t));
        if (item == NULL) {
            tlog(LOG_ERR,"item alloc failed\n");
            return FALSE;
        }
        item->data = data;
        item->next = NULL;

        if (list->head == NULL) {
            list->head = item;
        }
        else {
            list->tail->next = item;
        }
        list->tail = item;
        return TRUE;
    }
    bool list_remove(list_t *list, void *data) {
        list_item_t *current, *previous = NULL;
        if (list == NULL || data == NULL) {
            tlog(LOG_ERR,"list %x or data %x is null\n",list,data);
            return FALSE;
        }
        current = list->head;
        while (current != NULL && current->data != data) {
            previous = current;
            current = current->next;
        }
        if (current != NULL) {
            if (current == list->head) list->head = current->next;
            if (current == list->tail) list->tail = previous;
            if (previous != NULL) previous->next = current->next;
            else list->head = current->next;
            if (current->next == NULL) list->tail = previous;
            tlog(LOG_DEBUG, "freeing list item\n");
            current->next = NULL;
            current->data = NULL;
            call Memory.free(current);
            return TRUE;
        }
        return FALSE;
    }

    void *list_pop(list_t *list) {
        void *data;
        if (list && list->head) {
            data = list->head->data;
            list_remove(list,data);
            return data;
        }
        return NULL;
    }

    void list_iterate(list_t *list, operator_fn_t op_fn, void *meta) {
        list_item_t *tmp, *current, *previous = NULL;
        list_action_t action;
        tlog(LOG_DEBUG,"entered\n");
        current = list->head;
        while (current != NULL) {
            tlog(LOG_DEBUG,"there are more items on the list\n");
            action = op_fn(current->data, meta);
            switch (action) {
                case LIST_REMOVE:
                    if (current == list->head) list->head = current->next;
                    if (current == list->tail) list->tail = previous;
                    if (previous != NULL) previous->next = current->next;
                    tmp = current;
                    current = current->next;
                    tmp->next = NULL;
                    call Memory.free(tmp);
                    break;
                case LIST_BREAK:
                    current = NULL;
                    break;
                case LIST_CONT:
                default:
                    previous = current;
                    current = current->next;
            }
        }
        tlog(LOG_DEBUG, "there are NO more items on the list\n");
    }

    bool list_empty(list_t *list) {
        if (list == NULL) {
            tlog(LOG_ERR,"null list\n");
            return TRUE;
        }
        if (list->head == NULL && list->tail == NULL) {
            return TRUE;
        }
        else {
            return FALSE;
        }
    }
  
  //------------------------------------------------------------------------------
  
    uint32_t task_id(active_task_t *atask) {
        if (!atask || !(atask->t)) {
            tlog(LOG_ERR,"malformed active task\n");
            return 0;
        }
        return (atask->t->id);
    }
    uint16_t get_tid(task_t *t) {
        uint16_t tid;
        if (!t) {
            tlog(LOG_ERR,"malformed task\n");
            return 0;
        }
        tid = (uint16_t)(t->id & 0x0000ffff);
        return tid;
    }
    uint16_t get_src(task_t *t) {
        uint16_t src;
        if (!t) {
            tlog(LOG_ERR,"malformed task\n");
            return 0;
        }
        src = (uint16_t)((t->id >> 16) & 0x0000ffff);
        return src;
    }
  //------------------------------------------------------------------------------
  
    void element_construct(task_t *t, element_t *e,
                           uint16_t id,
                           run_t run,
                           suicide_t suicide) {
        e->id = id;
        e->run = run;
        e->suicide = suicide;
    }
  
    element_t *element_this(active_task_t *atask) {
        if (!atask || !(atask->t) || !(atask->t->elements) ||
                atask->element_index >= atask->t->num_elements) {
            tlog(LOG_ERR,"malformed active task\n");
            return NULL;
        }
        return (atask->t->elements[atask->element_index]);
    }

    void element_delete(task_t *t, element_t *e) {
        if (e) {
            e->suicide(t, e);
            /* This frees the actual element instances which were malloced
               within each element's construct function */
            e->id = 0;
            e->run = NULL;
            e->suicide = NULL;
            call Memory.free(e);
        }
    }

    //------------------------------------------------------------------------------

    /* TaskInstallerM.nc is the only place where active_task_new is called */
    active_task_t *active_task_new(task_t *t) {
        active_task_t *atask;
        if ((atask = (active_task_t *)call Memory.malloc(sizeof(active_task_t))) == NULL) {
            tlog(LOG_ERR,"can't allocate active task\n");
            return NULL;
        }
        atask->element_index = 0;
        atask->data = NULL;
        atask->t = t;
        active_task_count++;
        t->num_atasks++;
        return atask;
    }

    /* cloning an active task will practically result in a loop of task-chain
       starting at the cloning point */
    active_task_t *active_task_clone(active_task_t *atask) {
        active_task_t *c;
        data_t *tmp;
        if (atask == NULL) {
            tlog(LOG_ERR,"null active task\n");
            return NULL;
        }
        if ((c = (active_task_t *)call Memory.malloc(sizeof(active_task_t))) == NULL) {
            tlog(LOG_ERR,"can't allocated cloned active task\n");
            return NULL;
        }
        memcpy(c, atask, sizeof(active_task_t));

        // copy all the "data" in the atask to the cloned task.
        c->data = NULL;
        tmp = atask->data;
        while (tmp != NULL) {
            data_push(c, data_copy(tmp));
            tmp = tmp->next;
        }
        active_task_count++;
        atask->t->num_atasks++;
        return c;
    }

    /* When deleting an active task, it is important to know who is 
       holding the active task: the scheduler? or an element?
       - Scheduler owns an active task when the active task is in
         the schdule-list of the scheduler.
       - Element owns an active task when the active task is STOPPED
         at the scheduler and held/blocked by the element
         waiting for some kind of resource or queued execution 
         within that element. (eg. timer event, in send queue, etc).
       - If the scheduler has it, then scheduler must delete.
       - If the element has it, then the element must delete. */
    void active_task_delete(active_task_t *active_task) {
        data_t *tmp;
        if (active_task == NULL)
            return;
        while ((tmp = active_task->data) != NULL) {
            active_task->data = active_task->data->next;
            data_delete(tmp);
        }
        if (active_task->t)
            active_task->t->num_atasks--;
        call Memory.free(active_task);
        active_task_count--;
    }
  
  //------------------------------------------------------------------------------
  
    /* caller should allocate the actual memory for the 'value' */
    data_t *data_new(tag_t type, uint16_t length, void *value) {
        data_t *d = (data_t *)call Memory.malloc(sizeof(data_t));
        if (d) {
            d->attr.type = type;
            d->attr.length = length;
            d->attr.value = value;
            d->next = NULL;
        }
        else {
            tlog(LOG_ERR,"failed\n");
        }
        return d;
    }
 
    /* memory for the new data is allocated here. caller need not do so */
    data_t *data_new_copy(tag_t type, uint16_t length, void *value) {
        data_t *d = data_new(type, length, NULL);
        if (d) {
            if (length > 0 && value) {
                if ((d->attr.value = (uint8_t *)call Memory.malloc(length)) == NULL) {
                    call Memory.free(d);
                    return NULL;
                }
                memcpy(d->attr.value, value, length);
            }
        }
        return d;
    }
  
  // data->attr.value must not be a complex structure. i.e., if it contains
  // pointers to other data, that other data will not be deleted
  
    void data_delete(data_t *data) {
        if (data) {
            if (data->attr.value) {
                call Memory.free(data->attr.value);
                data->attr.value = NULL;
            }
            data->next = NULL;
            call Memory.free(data);
        }
    }
  
    data_t *data_get_by_type(active_task_t *active_task, tag_t type) {
        data_t *tmp;
        if (!active_task || !(active_task->data)) return NULL;
        tmp = active_task->data;
        while (tmp) {
            if (tmp->attr.type == type) {
                return tmp;
            }
            tmp = tmp->next;
        }
        return NULL;
    }
  
    data_t *data_copy(data_t *data) {
        data_t *copy;
        void *copy_payload;
        if ((copy = (data_t *)call Memory.malloc(sizeof(data_t))) == NULL) {
            tlog(LOG_ERR,"can't allocate data copy\n");
            return NULL;
        }
        // TODO: any chance that attr.length==0 ?
        if ((copy_payload = call Memory.malloc(data->attr.length)) == NULL) {
            tlog(LOG_ERR,"can't allocate data copy payload\n");
            call Memory.free(copy);
            return NULL;
        }
        memcpy(copy,data,sizeof(data_t));
        memcpy(copy_payload,data->attr.value,data->attr.length);
        copy->attr.value = copy_payload;
        copy->next = NULL;
        return copy;
    }
  
    void data_push(active_task_t *at, data_t *d) {
        data_t *last;
        if (at && d) {
            last = data_get_by_type(at, d->attr.type); /* duplicate check */
            if (last != NULL)
                data_remove(at, last);  /* remove attr with duplicate tag */

            last = at->data;
            d->next = NULL;
            if (last == NULL) at->data = d;
            else {
                while (last->next != NULL) last = last->next;
                last->next = d;
            }
        }
        else {
            tlog(LOG_ERR,"active task %x or data %x is null\n",at,d);
        }
    }
  
    data_t *data_pop(active_task_t *at) {
        data_t *pop;
        if (at) {
            if (at->data) {
                pop = at->data;
                at->data = pop->next;
                pop->next = NULL;
                return pop;
            }
            else {
                tlog(LOG_NOTICE,"empty data list\n");
            }
        }
        else {
            tlog(LOG_ERR,"null task\n");
        }
        return NULL;
    }

    bool data_remove(active_task_t *active_task, data_t *d) {
        data_t *current, *previous = NULL;
        if (!active_task || !(active_task->data) || !d) {
            tlog(LOG_ERR,"active_task %x or its data bag %x or the data to remove %x is null\n",
                    active_task,active_task?active_task->data:NULL,d);
            return FALSE;
        }
        current = active_task->data;
        while (current != NULL) {
            if (current == d) {
                if (previous == NULL) active_task->data = current->next;
                else previous->next = current->next;
                data_delete(current);
                return TRUE;
            }
            else {
                previous = current;
                current = current->next;
            }
        }
        return FALSE;
    }
 
    uint16_t data_serialize(active_task_t *at, uint8_t *dst, uint16_t dst_len) {
        data_t *d;
        uint16_t offset = 0;
        while ((offset < dst_len) && (at->data != NULL) &&
                (offsetof(attr_t,value) + at->data->attr.length + offset <= dst_len)) {
            tlog(LOG_DEBUG, "at %p d %p\n",at, d);
            d = data_pop(at);
            if (d->attr.length > 0) { // let's not send zero length data
                memcpy(&dst[offset],&(d->attr.type), offsetof(attr_t, value));
                offset += sizeof(d->attr.type) + sizeof(d->attr.length);
                tlog(LOG_DEBUG,"added type & length %d offset now %d\n", 
                                offsetof(attr_t, value), offset);
                memcpy(&dst[offset],d->attr.value, d->attr.length);
                offset += d->attr.length;
                tlog(LOG_DEBUG,"added value offset now %d\n", offset);
            }
            data_delete(d);
        }
        if (at->data != NULL) {
            tlog(LOG_ERR,"too much data for one packet. invent fragmentation.\n");
        }
        return offset;
    }

  //------------------------------------------------------------------------------
  
    /* TaskInstallerM.nc is the only place where task_new is called */
    task_t *task_new(uint8_t num_elements, uint32_t id) {
        task_t *t;
        uint8_t i;
        if ((t = (task_t *)call Memory.malloc(sizeof(task_t))) == NULL) {
            tlog(LOG_ERR,"can't allocate new task\n");
            return NULL;
        }
        if ((t->elements = (element_t **)call Memory.malloc(num_elements * sizeof(element_t *))) == NULL) {
            /* This only creates the pointer list to the elements in this task chain.
               The actual elements are allocated withing each element, and this 
               process is called within TaskInstallerM.nc */
            tlog(LOG_ERR,"can't allocate element pointers\n");
            call Memory.free(t);
            return NULL;
        }
	t->num_elements = num_elements;

        for (i = 0; i < t->num_elements; i++)
            t->elements[i] = NULL;
        t->id = id;
        
        t->num_atasks = 0;
        t->block_cloning = 0;
        t->sendbusy = 0;
        task_count++;
        return t;
    }

    /* TaskInstallerM.nc is the only place where task_delete is called */
    void task_delete(task_t *t) {
        uint8_t i;
        if (t) {
            /* Before freeing the task itself, elements must be freed.
               Before elements are freed, all elements must have suicided */
            for (i = 0; i < t->num_elements; i++) {
                element_delete(t, t->elements[i]);  /* removing the element instances */
                t->elements[i] = NULL;
            } 
            if (t->elements) 
                call Memory.free(t->elements);      /* removing the element pointers */
            else 
                tlog(LOG_ERR,"can't delete elements. there aren't any!\n");
            t->elements = NULL;
            call Memory.free(t);
            task_count--;
        }
        else {
            tlog(LOG_ERR,"can't delete null task\n");
        }
    }

    uint32_t time_diff(uint32_t time1, uint32_t time2) {
        uint32_t offset = 0;
        if (time2 < time1) {// we've overflowed
            offset = 0xffffffff - time1 + time2;
        }
        else {
            offset = time2 - time1;
        }
        return offset;
    }
}



