/*
* "Copyright (c) 2006 University of Southern California.
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
 * Onset detector tasklet used for event detection in structural 
 * vibration sensing. 
 *
 * Designed specifically for Wisden with MDA400 vibration board.
 * Does not support multiple tasks.
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 2/5/2007
 **/

#include "tenet_task.h"

module OnsetDetector {
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

    typedef struct onsetDetector_element_s {
        element_t e;
        
        tag_t type_in;
        tag_t type_out;
        tag_t type_info;

        int32_t alpha; //the filter coeficient for mean estimoator
        int32_t beta;  //the filter coeficient or the std estimator

        int32_t noiseMean;  //current noise mean
        int32_t noiseStd;   //current noise std deviation
        int32_t noiseMeanOffset;
        
        int32_t signalEnvMin; //upper bound of the signal
        int32_t signalEnvMax; //lower bounnd of the signal
        
        int8_t noiseThresh; //the noise threshold before onset is delcared in terms
        //of standard deviations from mean once its below this its quiescient period
        int8_t signalThresh;  //the signal threshold also in terms of 
        //standard deviations from mean once this is reached onset is signalled

        uint16_t sampleCntr;    // number of samples before initialization
        uint16_t startDelay;    // number of samples for initialization

        uint32_t current_offset;

        uint8_t od_state;
        uint8_t isQuiescientPending;
        uint8_t adaptiveMean;

    } __attribute__((packed)) onsetDetector_element_t;

    sched_action_t onsetDetector_run(active_task_t *active_task, element_t *e);
    void onsetDetector_suicide(task_t *t, element_t *e) {}

    void register_sample(onsetDetector_element_t *e, uint16_t ui_sample);

    enum {
        ACCURACY = 7,
        Q_PENDING_WAIT_THRESH = 2,
        ALPHA = 98,
        BETA = 96,
        NOISE_THRESH = 4,
        SIGNAL_THRESH = 10
    };

    enum {
        NOT_READY = 1,
        IN_QUIESCENT = 2,
        MOVE_TO_ONSET = 3,
        IN_ONSET = 4,
        MOVE_TO_QUIESCENT = 5
    };

    command element_t *Element.construct(task_t *t, void *data, uint16_t length) {
        onsetDetector_element_t *e;
        onsetDetector_params_t *p;
        if (data == NULL || length < sizeof(onsetDetector_params_t)) {
            return NULL;
        }
        if ((e = (onsetDetector_element_t *)call Memory.malloc(sizeof(onsetDetector_element_t))) == NULL) {
            return NULL;
        }
        p = (onsetDetector_params_t *)data;
        call TenetTask.element_construct(t, (element_t *)e,
                ELEMENT_ONSETDETECTOR,
                onsetDetector_run,
                onsetDetector_suicide);
    
        e->signalEnvMin = 0;
        e->signalEnvMax = 0;
        e->noiseMean = 0;
        e->noiseStd = 0;
        e->sampleCntr = 0; // this must be initted to zero (indication of firstSample)
        e->current_offset = 0;
        e->od_state = NOT_READY;

        e->isQuiescientPending = Q_PENDING_WAIT_THRESH;
        e->alpha = ALPHA;   // e->alpha = p->alpha;     //int32_alpha
        e->beta = BETA;     // e->beta = p->beta;       //int32_t

        if (p->noiseThresh > 0) e->noiseThresh = p->noiseThresh;   //int8_t
        else e->noiseThresh = NOISE_THRESH;  //two std deviations from mean
        if (p->signalThresh > 0) e->signalThresh = p->signalThresh; //int8_t
        else e->signalThresh = SIGNAL_THRESH; //five thresholds from mean

        e->startDelay = p->startDelay;     //uint16_t
        e->type_in = p->type_in;
        e->type_out = p->type_out;
        e->type_info = p->type_info;
        e->adaptiveMean = p->adaptiveMean;
        e->noiseMeanOffset = (0x00000001<<15);
        return (element_t *)e;
    }

    uint8_t filter_data(onsetDetector_element_t *e, uint8_t numSamples, 
                        uint16_t *buffer, uint16_t *obuffer, uint32_t *timestamp) {
        uint16_t sample;
        uint32_t obufferTs = 0;
        uint8_t obufferIndex = 0;
        int i;

        for (i = 0; i < numSamples; i++) {

            //sample = ((uint16_t)buffer[2*i] << 8) & 0xff00;
            //sample += ((uint16_t)buffer[2*i + 1]) & 0x00ff;
            sample = buffer[i];

            register_sample(e, sample);

            switch (e->od_state) {
                case MOVE_TO_ONSET:
                    if (obufferIndex == 0) {
                        obufferTs = e->current_offset + i;
                    //} else { // Internal error
                    }
                    //obuffer[obufferIndex++] = (uint8_t)((sample >> 8) & 0x00ff);
                    //obuffer[obufferIndex++] = (uint8_t)(sample & 0x00ff);
                    obuffer[obufferIndex++] = sample;
                    break;
                case IN_ONSET:
                    if (obufferIndex == 0) {
                        obufferTs = e->current_offset + i;
                    }
                    //obuffer[obufferIndex++] = (uint8_t)((sample >> 8) & 0x00ff);
                    //obuffer[obufferIndex++] = (uint8_t)(sample & 0x00ff);
                    obuffer[obufferIndex++] = sample;
                    break;
                case MOVE_TO_QUIESCENT:
                    if (obufferIndex == 0)
                        continue;
                    else {
                        *timestamp = obufferTs;
                        return obufferIndex;
                    }
                case NOT_READY:
                case IN_QUIESCENT:
                default:
                    break;
            }
        }
        if (e->od_state != NOT_READY)
            e->current_offset += numSamples;

        *timestamp = obufferTs;
        return obufferIndex;
    }


    sched_action_t onsetDetector_run(active_task_t *active_task, element_t *e) {
        onsetDetector_element_t *oe = (onsetDetector_element_t *)e;
        data_t *d = NULL;
        uint16_t *data, *outbuf;
        uint8_t inlen, outlen;      // in number of samples
        data_t *d2, *d3;
        uint32_t ts2;

        if ((d = call TenetTask.data_get_by_type(active_task, oe->type_in)) == NULL) {
            return SCHED_NEXT;
            //TODO: what happens when there are is no data of this type?
        }
        data = (uint16_t *)d->attr.value;
        inlen = d->attr.length/2;
        if ((outbuf = (uint16_t *)call Memory.malloc(inlen*sizeof(uint16_t))) == NULL) {
            return SCHED_NEXT;
        }
        outlen = filter_data(oe, inlen, data, outbuf, &ts2);

        if (outlen > 0) {
            onsetDetector_info_t *info;
            info = (onsetDetector_info_t *)call Memory.malloc(sizeof(onsetDetector_info_t));
            
            // push 'filtered data' into bag of attribute
            d2 = call TenetTask.data_new(oe->type_out, outlen*sizeof(uint16_t), (void *)outbuf);
            call TenetTask.data_push(active_task, d2);
            // note that if type_in == type_out, then raw samples will be deleted

            info->offset = ts2;
            info->mean = (uint16_t)((uint32_t)((oe->noiseMean>>ACCURACY) + oe->noiseMeanOffset));
            d3 = call TenetTask.data_new(oe->type_info, sizeof(onsetDetector_info_t), info);
            call TenetTask.data_push(active_task, d3);
        } 
        else {
            call Memory.free(outbuf);
        }
        return SCHED_NEXT;
    }


    //calculation of the signal envelope
    void updateSignalEnvelope(onsetDetector_element_t *e, int32_t sample) {
        int32_t sMax, sMin, dev;
        if (e->sampleCntr == 0) {
            e->signalEnvMax = sample;
            e->signalEnvMin = sample;
        } else {
            sMax = e->signalEnvMax;
            sMin = e->signalEnvMin;
            dev = ((sMax - sMin)*e->alpha)/100;
            e->signalEnvMax = (sample > sMin + dev ? sample : sMin + dev);
            e->signalEnvMin = (sample < sMax - dev ? sample : sMax - dev);
        }
    }

    //update the noise mean and noise std
    void updateMeanAndStd(onsetDetector_element_t *e, int32_t sample) {
        int32_t nstd;

        if (e->sampleCntr == 0) {
            e->noiseMean = sample;
            e->noiseStd = 0;
        } else {
            e->noiseMean = ((sample*(100-e->beta))/100) + ((e->noiseMean*e->beta)/100);
            nstd = (sample - e->noiseMean > 0 ? sample - e->noiseMean : e->noiseMean - sample);
            nstd = (nstd*(100-e->beta))/100;
            e->noiseStd = nstd + (e->noiseStd*e->beta)/100;
        }
    }

    //check if onset has occured
    bool onsetDetected(onsetDetector_element_t *e) {
        //the 5/4 is conversion factor from l1 norm to l2 norm
        //the actual value is somehwere around 0.7985 
        int32_t dev = (e->signalThresh*e->noiseStd*5)/4;
        if ((e->signalEnvMax > e->noiseMean + dev) ||
            (e->signalEnvMin < e->noiseMean - dev)) {
            return TRUE;
        }
        return FALSE;
    }

    bool quiescientDetected(onsetDetector_element_t *e) {
        //the 5/4 is conversion factor from l1 norm to l2 norm
        //the actual value is somehwere around 0.7985 
        int32_t dev = (e->noiseThresh*e->noiseStd*5)/4;
        if ((e->signalEnvMax < e->noiseMean + dev) &&
            (e->signalEnvMin > e->noiseMean - dev)) {
            if (e->isQuiescientPending <= 0) {
                e->isQuiescientPending = 1;
                return TRUE;
            } else {
                e->isQuiescientPending--;
            }
        }
        return FALSE;
    }

    //register is implemented as task so it does not keep the interrupts
    //off too long
    void register_sample(onsetDetector_element_t *e, uint16_t ui_sample) {
        int32_t sample;
        if (e == NULL)
            return;

        sample = ((uint32_t)ui_sample) & 0x0000ffff; 
        //sample = sample - (0x00000001<<15); //subtract 2^15
        sample = sample - e->noiseMeanOffset;
        sample = sample << ACCURACY; //convert to fixed floating point

        updateSignalEnvelope(e, sample); //update signal envelope;
    
        if (e->od_state == NOT_READY) {//if the detector is not yet ready{
            updateMeanAndStd(e, sample);   //update the noise mean and std
            if (e->sampleCntr++ >= e->startDelay) { //did we have enough samples?
                e->isQuiescientPending = Q_PENDING_WAIT_THRESH;
                e->od_state = IN_QUIESCENT;
                e->noiseMeanOffset = e->noiseMean;
            }
        } else {
            if ((e->od_state == IN_QUIESCENT) || (e->od_state == MOVE_TO_QUIESCENT)) {
                // is in quescient period
                if (onsetDetected(e)) {  //is it onset?
                    e->od_state = MOVE_TO_ONSET;
                    e->isQuiescientPending = Q_PENDING_WAIT_THRESH;
                } else {
                    e->od_state = IN_QUIESCENT;
                }
            } else {
                if (quiescientDetected(e)) { //has queiscient period arrived
                    e->od_state = MOVE_TO_QUIESCENT;
                } else {
                    e->od_state = IN_ONSET;
                }
            }
            if ((e->od_state == IN_QUIESCENT) || (e->od_state == MOVE_TO_QUIESCENT) ||
                (e->adaptiveMean)) {
                 updateMeanAndStd(e, sample); 
                //keep updating mean and std during quiescient period
            }
        }
    }

    //getting internal state variable values
    /*
    uint32_t get_noise_mean() {
        return (uint32_t)((e->noiseMean>>ACCURACY) + (0x00000001<<15));
    }
    uint32_t get_noise_std() {
        return (uint32_t)(e->noiseStd>>ACCURACY);
    }
    uint32_t get_signal_envelope() {
        return (uint32_t)((e->signalEnvMax>>ACCURACY) + (0x00000001<<15));
    }
    */
}


