/* $Id: MemoryOp.nc,v 1.4 2007-12-10 05:16:06 jpaek Exp $ */
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
 * memoryop(addr, value, op)
 *
 * This task allows read and write from arbitrary memory address.
 * If op is 0, read the "value" number of bytes from addr and put it
 * in the bag of attributes.
 * If op is 1, write the value of "value" to the addr.
 * If op is 2, case the "value" into a two-byte value before
 * writing to addr
 * 
 * @author Omprakash Gnawali
 * @modified 2/27/2007
 **/

#include "tenet_task.h"

module MemoryOp {
    provides {
        interface Element;
    }
    uses {
        interface TenetTask;
        interface Memory;
    }
}
implementation {

    typedef struct memoryop_element_s {
        element_t e;
        uint16_t addr;
        uint8_t value;
        uint8_t op;
        tag_t type;
    } __attribute__((packed)) memoryop_element_t;

    sched_action_t memoryop_run(active_task_t *active_task, element_t *e);
    void memoryop_suicide(task_t *t, element_t *e) {}; // nothing to do

    command element_t *Element.construct(task_t *t, void *data, uint16_t length) {
        memoryop_element_t *e;
        memoryop_params_t *p;
        if (data == NULL || length < sizeof(memoryop_params_t)){
            return NULL;
        }
        if ((e = (memoryop_element_t *)call Memory.malloc(sizeof(memoryop_element_t))) == NULL) {
            return NULL;
        }
        p = (memoryop_params_t *)data;
        call TenetTask.element_construct(t, (element_t *)e,
                ELEMENT_MEMORYOP,
                memoryop_run,
                memoryop_suicide);
        e->addr = p->addr;
        e->value = p->value;
        e->op = p->op;
        e->type = p->type;
        return (element_t *)e;
    }

    sched_action_t memoryop_run(active_task_t *active_task) {
        memoryop_element_t *e;
        uint8_t *b1;
        uint16_t *b2;
        uint32_t *b4;

        if ((e = (memoryop_element_t *)call TenetTask.element_this(active_task)) == NULL) {
            return SCHED_NEXT;
        }

        if (e->op == 0) {
            // read
            if (e->value == 1) {
                b1 = e->addr;
                call TenetTask.data_push(active_task,
                        call TenetTask.data_new_copy(e->type,
                            sizeof(uint8_t), b1));
            }
            if (e->value == 2) {
                b2 = e->addr;
                call TenetTask.data_push(active_task,
                        call TenetTask.data_new_copy(e->type,
                            sizeof(uint16_t), b2));
            }
            if (e->value == 4) {
                b4 = e->addr;
                call TenetTask.data_push(active_task,
                        call TenetTask.data_new_copy(e->type,
                            sizeof(uint32_t), b4));
            }
        }
        if (e->op == 1) {
            // write 1 byte
            b1 = e->addr;
            *b1 = (uint8_t)e->value;
        }
        if (e->op == 2) {
            // write 2 bytes
            b2 = e->addr;
            *b2 = e->value;
        }
        return SCHED_NEXT;
    }

}

