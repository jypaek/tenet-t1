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
 * Comparison 
 *
 * - performs comparison operation
 * 
 * For the logical operators 11~16 (below), result can only be a scalar 
 * or vector of 0 (FALSE) or 1 (TRUE). For the couting logical operators 
 * 21~26 (below), result is a scalar, which is the count of the elements 
 * in the attr vector which results in TRUE. 
 *
 * Legal values of optype are: 
 *
 * 11: (LT) 
 * 12: (GT) 
 * 13: (EQ) 
 * 14: (LEQ) 
 * 15: (GEQ) 
 * 16: (NEQ) 
 * 21: (COUNT_LT) 
 * 22: (COUNT_GT) 
 * 23: (COUNT_EQ) 
 * 24: (COUNT_LEQ) 
 * 25: (COUNT_GEQ) 
 * 26: (COUNT_NEQ) 
 *
 * Legal values of argtype are: 
 *
 * 0: means arg is a literal constant. 
 * 1: means arg is the name of an attribute.
 *
 * @author Ki-Young Jang
 * @author Jeongyeup Paek
 **/

#include "tenet_task.h"

module Comparison {
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

    typedef struct comparison_element_s {
        element_t e;
        tag_t result;
        tag_t attr;
        uint8_t optype;
        uint8_t argtype;
        tag_t arg;
    } __attribute__((packed)) comparison_element_t;

    sched_action_t comparison_run(active_task_t *active_task, element_t *e);
    void comparison_suicide(task_t *t, element_t *e) { return; } // nothing to do


    command element_t *Element.construct(task_t *t, void *data, uint16_t length) {
        comparison_element_t *e;
        comparison_params_t *p;
        if (data == NULL || length < sizeof(comparison_params_t)) {
            return NULL;
        }
        if ((e = (comparison_element_t *)call Memory.malloc(sizeof(comparison_element_t))) == NULL) {
            return NULL;
        }
        p = (comparison_params_t *)data;
        call TenetTask.element_construct(t, (element_t *)e,
                ELEMENT_COMPARISON,
                comparison_run,
                comparison_suicide);
        e->result = p->result;
        e->attr = p->attr;
        e->optype = p->optype;
        e->argtype = p->argtype;
        e->arg = p->arg;
        return (element_t *)e;
    }

    sched_action_t comparison_run(active_task_t *active_task, element_t *e) {
        comparison_element_t* ce = (comparison_element_t *)e;

        uint16_t* pData = NULL;
        uint16_t* pArg = NULL;
        uint16_t* pResult;
        data_t* pArgAttr;
        data_t* pDataAttr;

        uint16_t i;
        uint16_t nLength = 0;
        uint16_t result_len;

        if (ce->argtype == ARGTYPE_ATTRIBUTE) {    // arg is the name of an attribute
            if ((pArgAttr = call TenetTask.data_get_by_type(active_task, ce->arg)) != NULL) {
                pArg  = (uint16_t*) pArgAttr->attr.value;
            }
        } else {
            pArg = &ce->arg;
        }

        if ((pDataAttr = call TenetTask.data_get_by_type(active_task, ce->attr)) != NULL) {
            pData = (uint16_t*) pDataAttr->attr.value;
            nLength = (pDataAttr->attr.length)/sizeof(uint16_t);
        }

        if (!pArg || !pData) {
            call TaskError.kill(active_task->t, ERR_INVALID_ATTRIBUTE, ELEMENT_COMPARISON, ce->attr);
            return SCHED_TERMINATE;
        }

        if (ce->optype < COUNT_LT)
            result_len = pDataAttr->attr.length;
        else
            result_len = sizeof(uint16_t);
        
        pResult = (uint16_t *)call Memory.malloc(result_len);

        if (NULL == pResult) {
            call TaskError.kill(active_task->t, ERR_MALLOC_FAILURE, ELEMENT_COMPARISON,
                                active_task->element_index);
            return SCHED_TERMINATE;
        }

        pResult[0] = 0;

        for (i = 0; i < nLength; i++)
        {
            if (ce->optype < COUNT_LT)
                pResult[i] = FALSE;
                
            switch ( ce->optype )
            {
                case LT:
                    if ( pData[i] < pArg[0] )
                        pResult[i] = TRUE;
                    break;
                case GT:
                    if ( pData[i] > pArg[0] )
                        pResult[i] = TRUE;
                    break;
                case EQ:
                    if ( pData[i] == pArg[0] )
                        pResult[i] = TRUE;
                    break;
                case LEQ:
                    if ( pData[i] <= pArg[0] )
                        pResult[i] = TRUE;
                    break;
                case GEQ:
                    if ( pData[i] >= pArg[0] )
                        pResult[i] = TRUE;
                    break;
                case NEQ:
                    if ( pData[i] != pArg[0] )
                        pResult[i] = TRUE;
                    break;
                case COUNT_LT:
                    if ( pData[i] < pArg[0] )
                        pResult[0]++;
                    break;
                case COUNT_GT:
                    if ( pData[i] > pArg[0] )
                        pResult[0]++;
                    break;
                case COUNT_EQ:
                    if ( pData[i] == pArg[0] )
                        pResult[0]++;
                    break;
                case COUNT_LEQ:
                    if ( pData[i] <= pArg[0] )
                        pResult[0]++;
                    break;
                case COUNT_GEQ:
                    if ( pData[i] >= pArg[0] )
                        pResult[0]++;
                    break;
                case COUNT_NEQ:
                    if ( pData[i] != pArg[0] )
                        pResult[0]++;
                    break;
                default:
                    call Memory.free(pResult);
                    call TaskError.kill(active_task->t, ERR_INVALID_OPERATION, ELEMENT_COMPARISON, 
                                        active_task->element_index);
                    return SCHED_TERMINATE;
            }
        }

        call TenetTask.data_push(active_task, call TenetTask.data_new(ce->result, result_len, pResult));
        return SCHED_NEXT;
    }

}


