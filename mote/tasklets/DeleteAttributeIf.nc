/* $Id: DeleteAttributeIf.nc,v 1.6 2007-12-20 07:59:55 jpaek Exp $ */
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
 * deleteattributeif(arg, argtype, attr2) 
 *
 * This tasklet deletes attr2 from the bag of attributes if
 * one of these two conditions is true:
 * argtype is 1 and value of attribute identified by arg is non-zero
 * OR
 * argtype is not 1 and arg is non-zero.
 *
 * @author Omprakash gnawali
 * @version modified 2/27/2007
 **/

#include "tenet_task.h"

module DeleteAttributeIf {
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

    typedef struct deleteAttributeIf_element_s {
        element_t e;
        tag_t arg;
        tag_t tag;
        uint8_t argtype;
        uint8_t deleteAll;
    } deleteAttributeIf_element_t;

    sched_action_t deleteAttributeIf_run(active_task_t *active_task, element_t *e);
    void deleteAttributeIf_suicide(task_t *t, element_t *e) {} // nothing to do

    command element_t *Element.construct(task_t *t, void *data, uint16_t length) {
        deleteAttributeIf_element_t *e;
        deleteAttributeIf_params_t *p;

        if (data == NULL || length < sizeof(deleteAttributeIf_params_t)) {
            return NULL;
        }

        if ((e = (deleteAttributeIf_element_t *)call Memory.malloc(sizeof(deleteAttributeIf_element_t))) == NULL) {
            return NULL;
        }

        p = (deleteAttributeIf_params_t *)data;
        call TenetTask.element_construct(t, (element_t *)e,
                ELEMENT_DELETEATTRIBUTEIF,
                deleteAttributeIf_run,
                deleteAttributeIf_suicide);
        e->arg = p->arg;
        e->tag = p->tag;
        e->argtype = p->argtype;
        e->deleteAll = p->deleteAll;

        return (element_t *)e;
    }


    sched_action_t deleteAttributeIf_run(active_task_t *active_task, element_t *e) {
        deleteAttributeIf_element_t *de = (deleteAttributeIf_element_t *)e;
        data_t *d = NULL;
        uint16_t *arg = NULL;

        if (de->argtype == ARGTYPE_ATTRIBUTE) {
            if ((d = call TenetTask.data_get_by_type(active_task, de->arg)) != NULL) {
                arg = (uint16_t *)d->attr.value;
            }
        } else {
            arg = &de->arg;
        }

        if (!arg) {
            call TaskError.kill(active_task->t, ERR_INVALID_ATTRIBUTE, 
                                ELEMENT_DELETEATTRIBUTEIF, de->arg);
            return SCHED_TERMINATE;
        }

        if (*arg != FALSE) {
            if (de->deleteAll) {
                while ((d = call TenetTask.data_pop(active_task)) != NULL)
                    call TenetTask.data_delete(d);
            } else {
                d = call TenetTask.data_get_by_type(active_task, de->tag);
                call TenetTask.data_remove(active_task, d);
            }
        }

        return SCHED_NEXT;
    }
}

