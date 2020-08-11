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
 * arith(result, attr, optype, argtype, arg) 
 *
 * - Perform the arithmetic operation specified by optype, using a scalar arg. 
 * - Store the result in result, which must be an attribute. 
 * - If <attr> is a vector, perform the operation on all of its elements.
 *
 * Legal values of optype are: 
 * - 1: (ADD) 
 * - 2: (SUB) 
 * - 3: (MULT) 
 * - 4: (DIV) 
 * - 5: (DIFF) 
 * - 6: (MOD) 
 * - //7: (POW) 
 *
 * Legal values of argtype are: 
 * - 0: means arg is a literal constant. 
 * - 1: means arg is the name of an attribute.
 *
 * @author Marcos Vieira
 * @author Jeongyeup Paek
 **/

#include "tenet_task.h"

module Arith {
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

    typedef struct arith_element_s {
        element_t e;
        tag_t result;
        tag_t attr;
        uint8_t optype;
        uint8_t argtype;
        tag_t arg;
    } __attribute__((packed)) arith_element_t;

    sched_action_t arith_run(active_task_t *active_task, element_t *e);
    void arith_suicide(task_t *t, element_t *e) { return; } // nothing to do

    command element_t *Element.construct(task_t *t, void *data, uint16_t length) {
        arith_element_t *e;
        arith_params_t *p;
        if (data == NULL || length < sizeof(arith_params_t)) {
            return NULL;
        }
        if ((e = (arith_element_t *)call Memory.malloc(sizeof(arith_element_t))) == NULL) {
            return NULL;
        }
        p = (arith_params_t *)data;
        call TenetTask.element_construct(t, (element_t *)e,
                                         ELEMENT_ARITH,
                                         arith_run,
                                         arith_suicide);
        e->result = p->result;
        e->attr = p->attr;
        e->optype = p->optype;
        e->argtype = p->argtype;
        e->arg = p->arg;
        return (element_t *)e;
    }

    sched_action_t arith_run(active_task_t *active_task, element_t *e) {
        arith_element_t* ae = (arith_element_t *)e;

        uint16_t* pData = NULL;
        uint16_t* pArg = NULL;
        uint16_t* pResult;
        data_t* pArgAttr;
        data_t* pDataAttr;

        uint16_t i;
        uint16_t nLength = 0;
        uint16_t result_len;
        uint8_t pow_i;

        if (ae->argtype == ARGTYPE_ATTRIBUTE) {  // arg is the name of an attribute
            if ((pArgAttr = call TenetTask.data_get_by_type( active_task, ae->arg )) != NULL) {
                pArg = (uint16_t *) pArgAttr->attr.value;
            }
        } else {
            pArg = &ae->arg;
        }

        if ((pDataAttr = call TenetTask.data_get_by_type(active_task, ae->attr)) != NULL)
        {
            pData = (uint16_t *) pDataAttr->attr.value;
            nLength = (pDataAttr->attr.length)/sizeof(uint16_t);
        }

        if (!pArg || !pData) {
            call TaskError.kill(active_task->t, ERR_INVALID_ATTRIBUTE, ELEMENT_ARITH, ae->attr);
            return SCHED_TERMINATE;
        }

        result_len = pDataAttr->attr.length;
        
        pResult = (uint16_t *)call Memory.malloc(result_len);

        if (NULL == pResult) {
            call TaskError.kill(active_task->t, ERR_MALLOC_FAILURE, ELEMENT_ARITH,
                                active_task->element_index);
            return SCHED_TERMINATE;
        }

        pResult[0] = 0;

        for (i = 0; i < nLength; i++) {
               
            switch (ae->optype) 
            {
                case A_ADD:
                    pResult[i] = pData[i] + pArg[0];
                    break;
                case A_SUB:
                    pResult[i] = pData[i] - pArg[0];
                    break;
                case A_MULT:
                    pResult[i] = pData[i] * pArg[0];
                    break;
                case A_DIV:
                    pResult[i] = pData[i] / pArg[0];
                    break;
                case A_DIFF:
                    if (pData[i] > pArg[0]) 
                        pResult[i] = pData[i] - pArg[0];
                    else
                        pResult[i] = pArg[0] - pData[i];
                    break;
                case A_MOD:
                    pResult[i] = pData[i] % pArg[0];
                    break;
                case A_POW:
                    pResult[i] =1;
                    for(pow_i = 1; pow_i <= pArg[0]; pow_i++) {
                        pResult[i] *= pData[i];
                    }
                    break;
               default:
                    call Memory.free( pResult );
                    call TaskError.kill(active_task->t, ERR_INVALID_OPERATION, ELEMENT_ARITH, 
                                        active_task->element_index);
                    return SCHED_TERMINATE;
            }
        }

        call TenetTask.data_push(active_task, call TenetTask.data_new(ae->result, result_len, pResult));
        return SCHED_NEXT;
    }

}

