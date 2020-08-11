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
 * Attribute
 * - check whether an attribute exists or not
 *
 * Legal values of type are:
 * - 1: (EXIST)
 * - 2: (NOT_EXIST)
 * - 3: (LENGTH)
 *
 * @author Jeongyeup Paek
 * @data Dec/10/2007
 **/

#include "tenet_task.h"

module Attribute {
    provides {
        interface Element;
    }
    uses {
        interface TenetTask;
        interface Memory;
        interface TaskError;
    }
}
implementation {

    typedef struct attribute_element_s {
        element_t e;
        tag_t result;
        tag_t attr;
        uint8_t optype;
        uint8_t pad;
    }__attribute__((packed)) attribute_element_t;

    sched_action_t attribute_run(active_task_t *active_task, element_t *e);
    void attribute_suicide(task_t *t, element_t *e) {} // nothing to do

    /* construct (at install) */
    command element_t *Element.construct(task_t *t, void *data, uint16_t length) {
        attribute_element_t *e;
        attribute_params_t *p;
        if (data == NULL || length < sizeof(attribute_params_t)) {
            return NULL;
        }
        if ((e = (attribute_element_t *)call Memory.malloc(sizeof(attribute_element_t))) == NULL) {
            return NULL;
        }
        p = (attribute_params_t *)data;
        call TenetTask.element_construct(t, (element_t *)e,
                    ELEMENT_ATTRIBUTE, attribute_run, attribute_suicide);
        e->result = p->result;
        e->attr = p->attr;
        e->optype = p->optype;

        return (element_t *)e;
    }

    sched_action_t attribute_run(active_task_t *active_task, element_t *e) {
        attribute_element_t *ae = (attribute_element_t *)e;
        data_t* pDataAttr = NULL;
        uint16_t answer;

        pDataAttr = call TenetTask.data_get_by_type(active_task, ae->attr);

        answer = 0;

        switch ( ae->optype ) {
            case EXIST:
                if (pDataAttr != NULL)
                    answer = 1;
                break;
            case NOT_EXIST:
                if (pDataAttr == NULL)
                    answer = 1;
                break;
            case LENGTH:
                if (pDataAttr != NULL)
                    answer = (pDataAttr->attr.length)/sizeof(uint16_t);
                break;
            default:
                call TaskError.kill(active_task->t, ERR_INVALID_OPERATION, ELEMENT_ATTRIBUTE, 
                                    active_task->element_index);
                return SCHED_TERMINATE;
        }
        call TenetTask.data_push(active_task, call TenetTask.data_new_copy(ae->result, sizeof(uint16_t), &answer));
        return SCHED_NEXT;
    }

}

