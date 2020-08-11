/*
* "Copyright (c) 2006~2008 University of Southern California.
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
 *
 * Embedded Networks Laboratory, University of Southern California
 *
 * @modified Mar/8/2008
 *
 * @author Jeongyeup Paek (jpaek@enl.usc.edu)
 **/

#include "tenet_task.h"

module FirLpFilter {
    provides {
        interface Element;
    }
    uses {
        interface Schedule;
        interface TenetTask;
        interface Memory;
    }
}
implementation {

    enum {
        SCALED = 65536,      // 2^16 = 63356, already applied in the coeff's
    };

 /** FIR filter coefficient **/
 #include "FirLpFilter.h"

    typedef struct firLpFilter_element_s {
        element_t e;

        tag_t type_in;
        tag_t type_out;

        const int32_t *coeff;
        int8_t lastidx;            // assuming FIR_SIZE < 127
        uint8_t buflen;
        uint16_t samplebuf[FIR_SIZE];
    } __attribute__((packed)) firLpFilter_element_t;

    sched_action_t firLpFilter_run(active_task_t *active_task, element_t *e);
    void firLpFilter_suicide(task_t *t, element_t *e) {}

    command element_t *Element.construct(task_t *t, void *data, uint16_t length) {
        firLpFilter_element_t *e;
        firLpFilter_params_t *p = (firLpFilter_params_t *)data;

        if ((e = (firLpFilter_element_t *)call Memory.malloc(sizeof(firLpFilter_element_t))) == NULL)
            return NULL;

        call TenetTask.element_construct(t, (element_t *)e,
                ELEMENT_FIRLPFILTER,
                firLpFilter_run,
                firLpFilter_suicide);
    
        e->type_in = p->type_in;
        e->type_out = p->type_out;
        e->lastidx = -1;
        e->buflen = 0;
        e->coeff = filter_coeff_5;
        return (element_t *)e;
    }

    void filter_data(firLpFilter_element_t *e, int datalen, uint16_t *inbuf, uint16_t *outbuf) {
        int i, j, k;
        int32_t sum;

        for (i = 0; i < datalen; i++) {

            e->lastidx = (e->lastidx + 1) % FIR_SIZE;
            e->samplebuf[e->lastidx] = inbuf[i];

            if (e->buflen < FIR_SIZE)
                e->buflen += 1;
            if (e->buflen < FIR_SIZE) { // we don't have enough samples to start
                outbuf[i] = inbuf[i];   // out == in
                continue;
            }

            sum = 0;
            for (j = 0; j < FIR_SIZE; j++) {
                k = (e->lastidx + FIR_SIZE - j) % FIR_SIZE;
                sum += e->coeff[j] * e->samplebuf[k];
            }
            outbuf[i] = (uint16_t)((sum + 32768L) / SCALED);    // +32768 is for correct rounding
        }
    }


    sched_action_t firLpFilter_run(active_task_t *active_task, element_t *e) {
        firLpFilter_element_t *fe = (firLpFilter_element_t *)e;
        data_t *d = NULL, *d2;
        uint16_t *inbuf, *outbuf;
        int datalen;

        /* if we have the data with 'type_in' */
        if ((d = call TenetTask.data_get_by_type(active_task, fe->type_in)) != NULL) {

            inbuf = (uint16_t *)d->attr.value;
            datalen = d->attr.length/2;

            /* if the attribute has data */
            if (datalen > 0) {

                /* if we can allocate output buffer */
                if ((outbuf = (uint16_t *)call Memory.malloc(datalen*sizeof(uint16_t))) != NULL) {

                    filter_data(fe, datalen, inbuf, outbuf);

                    d2 = call TenetTask.data_new(fe->type_out, datalen*sizeof(uint16_t), (void *)outbuf);
                    call TenetTask.data_push(active_task, d2);
                }
            }
        }
        return SCHED_NEXT;
    }

}


