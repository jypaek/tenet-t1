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
 * "PackBits" Run Length Encoding
 * - with run-value re->thresholding.
 *
 * This tasklet performs the 'PackBits' run length encoding
 * on attr (which must be a vector), and stores the result in result. 
 *
 * @author Jeongyeup Paek (jpaek@usc.edu)
 **/


/***********************************************************************
*                          Packbits Encoding
*
*     This packbits variant begins each block of
*     data with the a byte header that is decoded as follows.
*
*     Byte (n)   | Meaning
*     -----------+-------------------------------------
*     0 ~ 127    | Copy the next n + 1 bytes
*     -127 ~ -1  | Make 1 - n copies of the next byte
*     -128       | Do nothing
***********************************************************************/


#include "tenet_task.h"

module PackBitsRle {
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

    typedef struct packbits_element_s {
        element_t e;
        tag_t result;
        tag_t attr;
        uint16_t thresh;
    } __attribute__((packed)) packbits_element_t;

    void packbits_suicide(task_t *t, element_t *e) {} // nothing to do

    uint16_t maxval(uint16_t a, uint16_t b) { if (a > b) return a; return b; }
    uint16_t minval(uint16_t a, uint16_t b) { if (a > b) return b; return a; }

    #define MIN_RUN     2               /* minimum run length */
    #define MAX_RUN     128             /* maximum run length */
    #define MAX_READ    MAX_RUN+1       /* maximum characters to buffer */

    sched_action_t packbits_run(active_task_t *active_task, element_t *e) {
        packbits_element_t* re = (packbits_element_t *)e;
        nx_uint16_t* pData;
        data_t* pDataAttr;
        uint16_t i = 0, j = 0;
        uint16_t nLength;
        nx_uint16_t* pResult;
        uint16_t val = 0, runlen = 0, codelen = 0;
        uint32_t sum = 0;
        uint16_t prevBuf[MAX_READ];

        pDataAttr = call TenetTask.data_get_by_type(active_task, re->attr);

        if (NULL == pDataAttr) {
            call TaskError.kill(active_task->t, ERR_INVALID_ATTRIBUTE, ELEMENT_PACKBITS, re->attr);
            return SCHED_TERMINATE;
        }

        pData = (nx_uint16_t*) pDataAttr->attr.value;
        nLength = (pDataAttr->attr.length)/sizeof(uint16_t);

        if ((pResult = (nx_uint16_t *)call Memory.malloc(sizeof(uint16_t)*nLength)) == NULL) {
            call TaskError.kill(active_task->t, ERR_MALLOC_FAILURE, ELEMENT_PACKBITS, re->attr);
            return SCHED_TERMINATE;
        }

        while (i < nLength)
        {
            /* code longer than data... bad */
            if (codelen >= nLength) {
                call TaskError.kill(active_task->t, ERR_QUEUE_OVERFLOW, ELEMENT_PACKBITS, re->attr);
                return SCHED_TERMINATE;
            }

            val = pData[i++];

            prevBuf[runlen] = val;
            runlen++;

            if (runlen >= MIN_RUN) {

                if ((val <= maxval(prevBuf[runlen - MIN_RUN], prevBuf[runlen - MIN_RUN] + re->thresh)) &&
                        (val >= minval(prevBuf[runlen - MIN_RUN], prevBuf[runlen - MIN_RUN] - re->thresh))) { /* run */
                    uint16_t next = 0;

                    if (runlen > MIN_RUN) {
                        pResult[codelen++] = runlen - MIN_RUN - 1;
                        for (j = 0; j < runlen - MIN_RUN; j++) {
                            pResult[codelen++] = prevBuf[j];
                        }
                    }

                    sum = prevBuf[runlen - MIN_RUN];
                    sum += val;
                    val = prevBuf[runlen - MIN_RUN];
                    runlen = MIN_RUN;

                    while (i < nLength) {
                        next = pData[i++];

                        if ((next > maxval(val, val + re->thresh)) ||
                                (next < minval(val, val - re->thresh))) break;  // no more run
                        runlen++;                       // run continues
                        sum += next;
                        if (MAX_RUN == runlen) break;   // run is at max length
                    }

                    val = (sum / runlen);

                    /* write out encoded run length and run symbol */
                    pResult[codelen++] = (1 - runlen);
                    pResult[codelen++] = val;

                    if ((i != nLength) && (runlen != MAX_RUN)) {
                        /* make run breaker start of next buffer */
                        runlen = 1;
                        prevBuf[0] = next;
                    }
                    else { /* file or max run ends in a run */
                        runlen = 0;
                    }
                } else if (runlen == MAX_RUN + 1) {
                    pResult[codelen++] = MAX_RUN - 1;
                    for (j = 0; j < MAX_RUN; j++) {
                        pResult[codelen++] = prevBuf[j];
                    }

                    runlen = 1;                     /* start a new buffer */
                    prevBuf[0] = prevBuf[MAX_RUN];  /* copy excess to front of buffer */
                }
            }

        }
        /* write the left-overs */
        if (0 != runlen) {
            if (runlen <= MAX_RUN) { /* write out entire copy buffer */
                    pResult[codelen++] = (runlen - 1);
                for (j = 0; j < runlen; j++) {
                    pResult[codelen++] = prevBuf[j];
                }
            } else {
                /* we read more than the maximum for a single copy buffer */
                pResult[codelen++] = (MAX_RUN - 1);
                for (j = 0; j < MAX_RUN; j++) {
                    pResult[codelen++] = prevBuf[j];
                }
                codelen += (1 + MAX_RUN);

                /* write out remainder */
                pResult[codelen++] = (runlen - MAX_RUN - 1);
                for (j = MAX_RUN; j < runlen; j++) {
                    pResult[codelen++] = prevBuf[j];
                }
            }
        }

        call TenetTask.data_push(active_task,
                call TenetTask.data_new(re->result, sizeof(uint16_t)*codelen, pResult));
        return SCHED_NEXT;
    }

    command element_t *Element.construct(task_t *t, void *data, uint16_t length) {
        packbits_element_t *e;
        rle_params_t *p;
        if (data == NULL || length < sizeof(rle_params_t)) {
            return NULL;
        }
        if ((e = (packbits_element_t *)call Memory.malloc(sizeof(packbits_element_t))) == NULL) {
            return NULL;
        }
        p = (rle_params_t *)data;
        call TenetTask.element_construct(t, (element_t *)e,
                ELEMENT_PACKBITS,
                packbits_run,
                packbits_suicide);

        e->result = p->result;
        e->attr = p->attr;
        e->thresh = p->thresh;
        return (element_t *)e;
    }

}

