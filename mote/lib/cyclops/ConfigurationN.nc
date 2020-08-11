/*
 * Copyright (c) 2005 The Regents of the University of California.  All 
 * rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 *
 * - Neither the name of the University nor the names of its
 *   contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS''
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
 * PARTICULAR  PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE REGENTS OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 *
 * Authors: Shaun Ahmadian
 *          Alan Jern
 *          David Zats dzats@ucla.edu 
 *          Mohammad Rahimi mhr@cens.ucla.edu
 * History: created 08/02/05
 *
 */

/**
 * @author Jeongyeup Paek (jpaek@enl.usc.edu)
 * @modified 7/4/2007
 **/

#include "cyclops_query.h"

module ConfigurationN
{
    provides interface StdControl;
    uses {
        //Interface for communicating over neuronC
        interface neuronC;
        command result_t Enable();
        interface Leds;
    }
}
implementation
{

    cyclops_response_t *m_resp;       // pointer to segment of data to send back to mote
    uint8_t buf[TOSH_DATA_LENGTH];  // buffer for response data
    int pending_reboot;
    

    /* let's do Deluge-like bootup led flashing !! (function from deluge) */
    void startupLeds() {
        uint8_t a = 0x7;
        int i, j, k;
        for (i = 3; i; i--, a >>= 1 ) {
            for (j = 1536; j > 0; j -= 4) {
                call Leds.set(a);
                for (k = j; k > 0; k--);
                call Leds.set(a >> 1);
                for (k = 1536-j; k > 0; k--);
            }
        }
    }

    command result_t StdControl.init() {
        call Leds.init();
        pending_reboot = 0;
        m_resp = (cyclops_response_t *)buf;
        m_resp->type = CYCLOPS_RESPONSE_SUCCESS;
        m_resp->more_left = 0;
        startupLeds();
        return SUCCESS;
    }
    command result_t StdControl.start() {return SUCCESS;}
    command result_t StdControl.stop() {return SUCCESS;}

    //**********************************************************************
    //*******************************Neuron*********************************
    //**********************************************************************

    task void reboot() {
        if (pending_reboot++ < 32) {
            post reboot();
            return;
        }
        cli(); 
        wdt_enable(0);
        while(1) {
            __asm__ __volatile__("nop" "\n\t" ::);
        }
    }

    task void send_response() {
        call neuronC.neuronSignalRead(offsetof(cyclops_response_t, data), (char*)m_resp);
    }

    event void neuronC.neuronSignalWrite(uint8_t len, char *data) { 
        config_query_t *cq = (config_query_t *)data;
        if (cq->type == CONFIG_REBOOT)
            pending_reboot = 1;
    }
    event void neuronC.neuronSignalReadReady() { 
        post send_response();
    }

    //This event fires upon a successful transmission. We do not need to do any
    //more processing here.
    event void neuronC.neuronSignalReadDone(result_t success) { 
        if (pending_reboot)
            post reboot();
    }

}

