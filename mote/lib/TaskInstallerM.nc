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
 * Installs (or delete) the tasks upon reception of a tasking packet.
 *
 * @author Ben Greenstein
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 2/5/2007
 **/

module TaskInstallerM {
    provides {
        interface StdControl;
        interface TaskDelete;
    }
    uses {
        interface Element as Element_u[uint8_t id];
        interface Schedule;
        interface TenetTask;
        interface TaskError;
        interface List;
        interface TaskRecv;
    }
}
implementation {
#include "element_map.h"
#include "tenet_task.h"

    list_t m_taskList;

    command result_t StdControl.init(){
        call List.init(&m_taskList);
        return SUCCESS;
    }
    command result_t StdControl.start(){return SUCCESS;}
    command result_t StdControl.stop(){return SUCCESS;}


    attr_t *fetch_next_attr(void *buf, uint16_t buf_len) {
        attr_t *a = (attr_t *)buf;

        // TYPE_LEN_SZ == 4 (2 for len, 2 for type)
        if ((!buf) || (buf_len < TYPE_LEN_SZ))
            return NULL;

        if (a->length + TYPE_LEN_SZ > buf_len)
            return NULL;

        return a;
    }

    /**
     * Build (instantiate) the tasklets (elements) to install the task t.
     *
     **/
    result_t build_elements(task_t *t, void *buf, uint16_t buf_len){
        element_t *e;
        uint16_t offset = 0, element_index = 0;
        attr_t *a;

        if (!t || !buf)
            return FAIL;

        while (offset < buf_len) {

            /* get next attribute from the tasking packet */
            if ((a = fetch_next_attr(buf + offset, buf_len - offset)) == NULL)
                return FAIL;

            /* build each tasklet */
            if ((e = call Element_u.construct[a->type](t, a->value, a->length)) == NULL) {
                call TaskError.kill(t, ERR_CONSTRUCT_FAILURE, a->type, element_index);
                return FAIL;
            }

            t->elements[element_index++] = e;
            offset += (a->length + TYPE_LEN_SZ);
        }
        return SUCCESS;
    }

    list_action_t remove_task(void *item, void *meta){
        task_t *t = (task_t *)item;
        task_t *to_destroy = (task_t *)meta;
        if (t == to_destroy) {
            return LIST_REMOVE;
        }
        return LIST_CONT;
    }

    /**
     * Destroy a task: safely deletes all states related to that task.
     * 
     * Removes any schedule for the task, delete it from the tasklist,
     * and delete the task object itself.
     **/
    command void TaskDelete.destroy(task_t *t) { // completely destroy(delete) a task
        call Schedule.remove(t);
        call List.iterate(&m_taskList, remove_task, t);
        call TenetTask.task_delete(t); // this must come after removing schedule 
                                       // AND after removing from list
    }

    /**
     * Delete the task from the tasklist that has 32-bit tid == (*meta).
     **/
    list_action_t delete_task(void *item, void *meta){
        task_t *t = (task_t *)item;
        uint32_t *id = (uint32_t *)meta;
        uint32_t tmp = (uint32_t)call TenetTask.get_src(t);
        tmp = (tmp<<16) + 65535UL;
        if ((t->id == *id) || (tmp == *id)) {
            // should not call TaskDelete.destroy here since this is within the list
            // and TaskDelete.destroy also iterates through the list.
            call Schedule.remove(t);
            call TenetTask.task_delete(t);
            return LIST_REMOVE;
        }
        return LIST_CONT;
    }

    /**
     * Parse the tasking packet and either install or delete the task.
     *
     **/
    void parse_msg(void *data, uint16_t length, uint32_t tid) {
        task_t *newTask;
        active_task_t *new_atask;
        task_msg_t *taskMsg = (task_msg_t *)data;

        if (data == NULL)
            return; // barf

        switch (taskMsg->type) {

            /* we have received a new task. let's install it */
            case TASK_INSTALL:
                /* create a task data structure */
                if ((newTask = call TenetTask.task_new(taskMsg->numElements, tid)) != NULL) {

                    length -= offsetof(task_msg_t, data); /* exclude header */

                    /* build instances of the tasklets (elements of the task) */
                    if ((build_elements(newTask, taskMsg->data, length) != FAIL) &&
                            ((new_atask = call TenetTask.active_task_new(newTask)) != NULL)) {
                        call List.push(&m_taskList, newTask);
                        call Schedule.first(new_atask);
                    }
                    else {
                        call TaskError.kill(newTask, ERR_INSTALL_FAILURE, 1, 0);
                    }
                } else {
                    task_t tmp_task;
                    tmp_task.id = tid;
                    call TaskError.report(&tmp_task, ERR_INSTALL_FAILURE, 1, 0);
                }
                break;

            /* we have received a delete-task task */
            case TASK_DELETE:
                if (taskMsg->numElements == 0) {
                    call List.iterate(&m_taskList, delete_task, &(tid));
                }
                break;
            default:
                break;
        }
    }


    default command element_t *Element_u.construct[uint8_t id](task_t *t, void *data, uint16_t len){
        return NULL;
    }

    /**
     * Received the tasking packet and pass it to the task parser along with 
     * the 32-bit tid which is merge of 16-bit tid and the source address of
     * the task.
     *
     * @param data is the tasking packet.
     * @param length is the length of the data.
     * @param tid is the transaction id that identifies the task, per src.
     * @param src is the source address of the master that issued the task.
     **/
    event void TaskRecv.receive(void *data, uint16_t length, uint16_t tid, uint16_t src) {
        uint32_t bigTid = tid;
        uint32_t bigSrc = src;
        uint32_t moteTid = 0;
        bigSrc <<= 16;
        moteTid = bigSrc | bigTid;
        parse_msg(data, length, moteTid);
    }

}


