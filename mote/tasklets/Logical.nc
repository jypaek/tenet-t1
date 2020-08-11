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
 * logical(result, attr, type, arg, argtype)
 * - Perform the logical operation specified by optype, using a scalar arg. 
 * - Store the result in result, which must be an attribute. 
 * - If <attr> is a vector, perform the operation on all of its elements.
 *
 * Legal values of type are:
 * - 11: (LAND) Logical AND
 * - 12: (LOR) Logical OR
 * - 13: (LNOT) Logical NOT
 *
 * Legal values of argtype are:
 * - 0: means arg is a literal constant.
 * - 1: means arg is the name of an attribute. 
 *
 * @author Marcos Vieira
 * @author Ki-Young Jang
 * @author Jeongyeup Paek
 **/

#include "tenet_task.h"

module Logical {
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

    typedef struct logical_element_s {
        element_t e;
        tag_t result;
        tag_t attr;
        uint8_t optype;
        uint8_t argtype;
        tag_t arg;
    }__attribute__((packed)) logical_element_t;

    sched_action_t logical_run(active_task_t *active_task, element_t *e);
    void logical_suicide(task_t *t, element_t *e) {} // nothing to do

    /* construct (at install) */
    command element_t *Element.construct(task_t *t, void *data, uint16_t length) {
        logical_element_t *e;
        logical_params_t *p;
        if (data == NULL || length < sizeof(logical_params_t)) {
            return NULL;
        }
        if ((e = (logical_element_t *)call Memory.malloc(sizeof(logical_element_t))) == NULL) {
            return NULL;
        }
        p = (logical_params_t *)data;
        call TenetTask.element_construct(t, (element_t *)e,
                    ELEMENT_LOGICAL, logical_run, logical_suicide);
        e->result = p->result;
        e->attr = p->attr;
        e->optype = p->optype;
        e->argtype = p->argtype;
        e->arg = p->arg;

        return (element_t *)e;
    }

    sched_action_t logical_run(active_task_t *active_task, element_t *e) {
        logical_element_t *le = (logical_element_t *)e;
        uint16_t* pData = NULL;
        uint16_t* pArg = NULL;
        uint16_t* pResult;
        data_t* pArgAttr;
        data_t* pDataAttr;
        uint16_t i;
        uint16_t nLength = 0;
        uint16_t result_len = 0;

        if ((pDataAttr = call TenetTask.data_get_by_type(active_task, le->attr)) != NULL) {
            pData = (uint16_t*) pDataAttr->attr.value;   // assume that attr.value is in network byte order
            nLength = (pDataAttr->attr.length)/sizeof(uint16_t);
            result_len = pDataAttr->attr.length;
        }

        if (le->optype != NOT) { //NOT is a unary operator, do not have pArg
            if (le->argtype == ARGTYPE_ATTRIBUTE) { // arg is the name of an attribute
                if ((pArgAttr = call TenetTask.data_get_by_type(active_task, le->arg)) != NULL) {
                    pArg  = (uint16_t*) pArgAttr->attr.value;
                }
            } else {
                pArg = &le->arg;
            }
        } else {
            pArg = pData;
        }

        if (!pData || !pArg) { //verify pArg exist
            call TaskError.kill(active_task->t, ERR_INVALID_ATTRIBUTE, ELEMENT_LOGICAL,
                                le->attr);
            return SCHED_TERMINATE;
        }

        pResult = (uint16_t *)call Memory.malloc(result_len);

        if (NULL == pResult){
            call TaskError.kill(active_task->t, ERR_MALLOC_FAILURE, ELEMENT_LOGICAL,
                                active_task->element_index);
            return SCHED_TERMINATE;
        }

        for (i = 0; i < nLength; i++ ) {
          
            pResult[i] = 0; 

            switch ( le->optype ) {
                // Logical Operations
                case LAND:
                    if ( pData[i] > 0 && pArg[0] > 0 ) {
                        pResult[i] = 1;
                    }
                    break;
                case LOR:
                    if ( pData[i] > 0 || pArg[0] > 0 ) {
                        pResult[i] = 1;
                    }
                    break;
                case LNOT:
                    if ( pData[i] <= 0 ) {
                        pResult[i] = 1;
                    }
                    break;
                default:
                    call Memory.free(pResult);
                    call TaskError.kill(active_task->t, ERR_INVALID_OPERATION, ELEMENT_LOGICAL, 
                                        active_task->element_index);
                    return SCHED_TERMINATE;
            }
        }
        call TenetTask.data_push(active_task, call TenetTask.data_new(le->result, result_len, pResult));
        return SCHED_NEXT;
    }

}

