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
 * bit(result, attr, type, arg, argtype)
 *
 * - Perform the bit operation specified by optype, using a scalar arg. 
 * - Store the result in result, which must be an attribute. 
 * - If <attr> is a vector, perform the operation on all of its elements.
 *
 * Legal values of type are:
 * - 1: (AND)
 * - 2: (OR)
 * - 3: (NOT)
 * - 4: (XOR)
 * - 5: (NAND)
 * - 6: (NOR) 
 * - 7: (Shift Left) (4<<2) = 64
 * - 8: (Shift Right)
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

module Bit {
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

    typedef struct bit_element_s {
        element_t e;
        tag_t result;
        tag_t attr;
        uint8_t optype;
        uint8_t argtype;
        tag_t arg;
    }__attribute__((packed)) bit_element_t;

    sched_action_t bit_run(active_task_t *active_task, element_t *e);
    void bit_suicide(task_t *t, element_t *e) { return; } // nothing to do

    /* construct (at install) */
    command element_t *Element.construct(task_t *t, void *data, uint16_t length) {
        bit_element_t *e;
        bit_params_t *p;
        if (data == NULL || length < sizeof(bit_params_t)) {
            return NULL;
        }
        if ((e = (bit_element_t *)call Memory.malloc(sizeof(bit_element_t))) == NULL) {
            return NULL;
        }
        p = (bit_params_t *)data;
        call TenetTask.element_construct(t, (element_t *)e,
                    ELEMENT_BIT, bit_run, bit_suicide);
        e->result = p->result;
        e->attr = p->attr;
        e->optype = p->optype;
        e->argtype = p->argtype;
        e->arg = p->arg;

        return (element_t *)e;
    }

    sched_action_t bit_run(active_task_t *active_task, element_t *e) {
        bit_element_t *be = (bit_element_t *)e;
        uint16_t* pData = NULL;
        uint16_t* pArg = NULL;
        uint16_t* pResult;
        data_t* pArgAttr;
        data_t* pDataAttr;
        uint16_t i;
        uint16_t nLength = 0;
        uint16_t result_len = 0;

        if ((pDataAttr = call TenetTask.data_get_by_type(active_task, be->attr)) != NULL) {
            pData = (uint16_t*) pDataAttr->attr.value;
            nLength = (pDataAttr->attr.length)/sizeof(uint16_t);
            result_len = pDataAttr->attr.length;
        }

        if (be->optype != NOT) {//NOT is a unary operator, do not have pArg
            if (be->argtype == ARGTYPE_ATTRIBUTE) { // arg is the name of an attribute
                if ((pArgAttr = call TenetTask.data_get_by_type(active_task, be->arg)) != NULL) {
                    pArg  = (uint16_t*) pArgAttr->attr.value;
                }
            } else {
                pArg = &be->arg;
            }
        } else {
            pArg = pData;
        }

        if (!pData || !pArg) { //verify pArg exist
            call TaskError.kill(active_task->t, ERR_INVALID_ATTRIBUTE, ELEMENT_BIT, be->attr);
            return SCHED_TERMINATE;
        }

        pResult = (uint16_t *)call Memory.malloc(result_len);

        if (NULL == pResult) {
            call TaskError.kill(active_task->t, ERR_MALLOC_FAILURE, ELEMENT_BIT,
                                active_task->element_index);
            return SCHED_TERMINATE;
        }

        for (i = 0; i < nLength; i++) {
          
            pResult[i] = 0; 

            switch ( be->optype ) {
                // Bit operations
                case AND:
                        pResult[i] = pData[i] & pArg[0] ;
                    break;
                case OR:
                        pResult[i] = pData[i] | pArg[0];
                    break;
                case NOT:
                        pResult[i] = ~pData[i];//unary operation
                    break;
                case XOR:
                        pResult[i] = pData[i] ^ pArg[0];
                    break;
                case NAND:
                        pResult[i] = ~(pData[i] & pArg[0]);
                    break;
                case NOR:
                        pResult[i] = ~(pData[i] | pArg[0]);
                    break;
                 case SHL:
                        pResult[i] = (pData[i] << pArg[0]);
                    break;
                case SHR:
                        pResult[i] = (pData[i] >> pArg[0]);
                    break;
                default:
                    call Memory.free( pResult );
                    call TaskError.kill(active_task->t, ERR_INVALID_OPERATION, ELEMENT_BIT, 
                                        active_task->element_index);
                    return SCHED_TERMINATE;
            }
        }

        call TenetTask.data_push(active_task, call TenetTask.data_new(be->result, result_len, pResult));
        return SCHED_NEXT;
    }

}

