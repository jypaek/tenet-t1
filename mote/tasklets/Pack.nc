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
 * Pack
 *
 * - Pack scalars into a vector
 *   - At every run, a scalar attribute will come as input.
 *     This tasklet constructs a vector out of those inputs.
 *     When the vector is full, output will be generated.
 *
 * @author Jeongyeup Paek
 **/

#include "tenet_task.h"

module Pack {
    provides {
        interface Element;
    }
    uses {
        interface TenetTask;
        interface TaskError;
        interface Memory;
    }
}
implementation {

    typedef struct pack_element_s {
        element_t e;
        tag_t attr;
        uint16_t size;   // number of scalars to pack.
        uint16_t count;  // number of scalars packed till now.
        uint8_t block;   // whether to block-when-not-full or not.
        uint8_t pad;
        uint16_t *data;
    } __attribute__((packed)) pack_element_t;

    sched_action_t pack_run(active_task_t *active_task, element_t *e);
    void pack_suicide(task_t *t, element_t *e);

    command element_t *Element.construct(task_t *t, void *data, uint16_t length) {
        pack_element_t *e;
        pack_params_t *p;
        if (data == NULL || length < sizeof(pack_params_t)) {
            return NULL;
        }
        if ((e = (pack_element_t *)call Memory.malloc(sizeof(pack_element_t))) == NULL) {
            return NULL;
        }
        p = (pack_params_t *)data;
        e->attr = p->attr;
        e->size = p->size;
        e->block = p->block;
        e->count = 0;
        if ((e->data = (uint16_t *)call Memory.malloc(sizeof(uint16_t)*e->size)) == NULL) {
            call Memory.free(e);
            return NULL;
        }
        call TenetTask.element_construct(t, (element_t *)e,
                                         ELEMENT_PACK,
                                         pack_run, pack_suicide);
        return (element_t *)e;
    }

    sched_action_t pack_run(active_task_t *active_task, element_t *e) {
        pack_element_t* pe = (pack_element_t *)e;
        data_t* d;
        uint16_t* pData = NULL;

        if ((d = call TenetTask.data_get_by_type(active_task, pe->attr)) != NULL) {
            pData = (uint16_t*)d->attr.value;
        }
        if ((!pData) || (d->attr.length < 2)) {
            call TaskError.kill(active_task->t, ERR_INVALID_ATTRIBUTE, ELEMENT_PACK, pe->attr);
            return SCHED_TERMINATE;
        }

        /* read scalar and put it into vector */
        pe->data[pe->count++] = pData[0];

        /* delete scalar attribute from active task */
        call TenetTask.data_remove(active_task, d);

        /* if the vector is full, send it down */
        if (pe->count == pe->size) {
            call TenetTask.data_push(active_task,
                    call TenetTask.data_new_copy(pe->attr, sizeof(uint16_t)*pe->size, pe->data));
            pe->count = 0;
        }
        /* if the vector is not-full, but if 'block' is requested, delete active task */
        else if (pe->block == 1) {
            return SCHED_TERMINATE;
        }
        return SCHED_NEXT;
    }

    void pack_suicide(task_t *t, element_t *e) {
        pack_element_t* pe = (pack_element_t*)e;
        /* free the vector */
        call Memory.free(pe->data);
    }

}

