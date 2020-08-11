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

/*
 * Stats 
 * This tasklet performs the specified statistical operation optype 
 * on attr (which must be a vector), and stores the result in result. 
 *
 * Legal values of optype are: 
 * 1: (SUM) 
 * 2: (MIN) 
 * 3: (MAX) 
 * 4: (AVG) 
 * //5: (STD) 
 * 6: (CNT) 
 * 7: (MEANDEV) 
 *
 * @author Ki-Young Jang
 * @author Jeongyeup Paek
*/

#include "tenet_task.h"

module Stats {
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

    typedef struct stats_element_s {
        element_t e;
        tag_t result;
        tag_t attr;
        uint16_t optype;
    } __attribute__((packed)) stats_element_t;

    sched_action_t stats_run(active_task_t *active_task, element_t *e);
    void stats_suicide(task_t *t, element_t *e) {} // nothing to do

    command element_t *Element.construct(task_t *t, void *data, uint16_t length) {
        stats_element_t *e;
        stats_params_t *p;
        if (data == NULL || length < sizeof(stats_params_t)) {
            return NULL;
        }
        if ((e = (stats_element_t *)call Memory.malloc(sizeof(stats_element_t))) == NULL) {
            return NULL;
        }
        p = (stats_params_t *)data;
        call TenetTask.element_construct(t, (element_t *)e,
                ELEMENT_STATS,
                stats_run,
                stats_suicide);

        e->result = p->result;
        e->attr = p->attr;
        e->optype = p->optype;
        return (element_t *)e;
    }

    uint16_t absval(uint16_t a, uint16_t b) {
        return (a < b ? b-a : a-b);
    }

    sched_action_t stats_run(active_task_t *active_task, element_t *e) {
        stats_element_t* se = (stats_element_t *)e;
        uint16_t* pData;
        data_t* pDataAttr;
        uint16_t i;
        uint16_t nLength;
        uint32_t nResult = 0;

        pDataAttr = call TenetTask.data_get_by_type(active_task, se->attr);

        if (NULL == pDataAttr) {
            call TaskError.kill(active_task->t, ERR_INVALID_ATTRIBUTE, ELEMENT_STATS, se->attr);
            return SCHED_TERMINATE;
        }

        pData = ( uint16_t* ) pDataAttr->attr.value;
        nLength = (pDataAttr->attr.length)/sizeof(uint16_t);

        for (i = 0; i < nLength; i++)
        {
            switch (se->optype)
            {
                case MEANDEV:
                case SUMM:
                case AVG:
                    nResult += pData[i];
                    break;
                case MIN:
                    if ( 0 == i || pData[i] < nResult )
                        nResult = pData[i];
                    break;
                case MAX:
                    if ( 0 == i || pData[i] > nResult )
                        nResult = pData[i];
                    break;
                //case STD:
                    // will be implemented later
                //    break;
                case CNT:
                    nResult++;
                    break;
                default:
                    call TaskError.kill(active_task->t, ERR_INVALID_OPERATION, ELEMENT_STATS, 
                                        active_task->element_index);
                    return SCHED_TERMINATE;
            }
        }

        if (se->optype == AVG) {
            nResult /= nLength;
        } else if (se->optype == MEANDEV) {
            uint32_t mean = nResult / nLength;
            nResult = 0;
            for (i = 0; i < nLength; i++) {
                nResult += absval(pData[i], (uint16_t)mean);
            }
            nResult /= nLength;
        }


        nLength = (uint16_t)nResult; // hacky re-use of variable
        call TenetTask.data_push(active_task,
                call TenetTask.data_new_copy(se->result, sizeof(uint16_t), &nLength));
        return SCHED_NEXT;

    }

}

