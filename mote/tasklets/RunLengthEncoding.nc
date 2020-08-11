/**
 * "Copyright (c) 2006~2009 University of Southern California.
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
 **/ 

/**
 * Run Length Encoding
 * - with run-value thresholding.
 *
 * This tasklet performs the simple run length encoding
 * on attr (which must be a vector), and stores the result in result. 
 *
 * @author Jeongyeup Paek (jpaek@usc.edu)
 **/

#include "tenet_task.h"

module RunLengthEncoding {
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

    typedef struct rle_element_s {
        element_t e;
        tag_t result;
        tag_t attr;
        uint16_t thresh;
    } __attribute__((packed)) rle_element_t;

    void rle_suicide(task_t *t, element_t *e) {} // nothing to do

    uint16_t maxval(uint16_t a, uint16_t b) { if (a > b) return a; return b; }
    uint16_t minval(uint16_t a, uint16_t b) { if (a > b) return b; return a; }

    sched_action_t rle_run(active_task_t *active_task, element_t *e) {
        rle_element_t* re = (rle_element_t *)e;
        nx_uint16_t* pData;
        data_t* pDataAttr;
        uint16_t i;
        uint16_t nLength;
        nx_uint16_t* pResult;
        uint16_t val = 0, prev = 0, runlen = 0, codelen = 0;
        uint32_t sum = 0;

        pDataAttr = call TenetTask.data_get_by_type(active_task, re->attr);

        if (NULL == pDataAttr) {
            call TaskError.kill(active_task->t, ERR_INVALID_ATTRIBUTE, ELEMENT_RLE, re->attr);
            return SCHED_TERMINATE;
        }

        pData = (nx_uint16_t*) pDataAttr->attr.value;
        nLength = (pDataAttr->attr.length)/sizeof(uint16_t);

        if ((pResult = (nx_uint16_t *)call Memory.malloc(sizeof(uint16_t)*nLength)) == NULL) {
            call TaskError.kill(active_task->t, ERR_MALLOC_FAILURE, ELEMENT_RLE, re->attr);
            return SCHED_TERMINATE;
        }

        for (i = 0; i < nLength; i++)
        {
            /* code longer than data... bad */
            if (codelen >= nLength) {
                call TaskError.kill(active_task->t, ERR_QUEUE_OVERFLOW, ELEMENT_RLE, re->attr);
                return SCHED_TERMINATE;
            }

            val = pData[i];
            if (i == 0) {
                runlen = 1;
                prev = val;
                sum = val;
            } else if ((val <= maxval(prev, prev + re->thresh)) && (val >= minval(prev, prev - re->thresh))) {
                // if we have run long than max len
                if (runlen == 254) {
                    prev = sum / runlen;
                    pResult[codelen++] = prev;
                    pResult[codelen++] = runlen;
                    runlen = 0;
                    prev = val;
                    sum = 0;
                }
                runlen++;
                sum += val;
            } else { /* no run */
                prev = sum / runlen;
                pResult[codelen++] = prev;
                pResult[codelen++] = runlen;
                runlen = 1;
                prev = val;
                sum = val;
            }
        }
        /* write the left-overs */
        prev = sum / runlen;
        pResult[codelen++] = prev;
        pResult[codelen++] = runlen;

        call TenetTask.data_push(active_task,
                call TenetTask.data_new(re->result, sizeof(uint16_t)*codelen, pResult));
        return SCHED_NEXT;
    }

    command element_t *Element.construct(task_t *t, void *data, uint16_t length) {
        rle_element_t *e;
        rle_params_t *p;
        if (data == NULL || length < sizeof(rle_params_t)) {
            return NULL;
        }
        if ((e = (rle_element_t *)call Memory.malloc(sizeof(rle_element_t))) == NULL) {
            return NULL;
        }
        p = (rle_params_t *)data;
        call TenetTask.element_construct(t, (element_t *)e,
                ELEMENT_RLE,
                rle_run,
                rle_suicide);

        e->result = p->result;
        e->attr = p->attr;
        e->thresh = p->thresh;
        return (element_t *)e;
    }

}

