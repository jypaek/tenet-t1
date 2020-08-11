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
 * This module provides the implementation for the activeEye control system on the cyclops. 
 * It allows the host to change the parameters of activeEye. This module communicates with
 * the host (mote) through Neuron.
 */

/**
 * @modified 6/27/2007
 * @author Jeongyeup Paek
 *
 * - Merge ActiveEyeN.nc and activeEyeM.nc
 *   (No need for seperate configuration file if interfaces are identical.)
 * - Remove 'control' (wire to Main in top-level configuration)
 **/
 
#include "camera_state.h"
#include "cyclops_query.h"

module ActiveEyeN
{
    provides interface StdControl;
    uses {
        interface Leds;

        //Interface for communicating over neuronC
        interface neuronC;

        //Active-Eye interfaces (imager)
        interface imagerConfig;
        interface StdControl as ImagerControl;

        interface CameraState;
    }
}
implementation
{
    enum {
        ExposureDiv  = 1000,
        RESPONSE_SIZE = offsetof(cyclops_response_t, data) + sizeof(capture_param_t)
    };
    
    CYCLOPS_Capture_Parameters m_capture;   // Structure used for setting params.

    cyclops_response_t *m_resp;     // pointer to segment of data to send back to mote
    uint8_t mbuf[RESPONSE_SIZE];    // buffer for response data

    bool replyReady = FALSE;
    bool replyRequested = FALSE;
    bool initialization = TRUE;

    //***********************************************************************************
    //****************************Initialization and Termination*************************
    //***********************************************************************************

    command result_t StdControl.init() {
        m_resp = (cyclops_response_t *)mbuf;
        m_resp->more_left = 0;
        m_resp->type = CYCLOPS_RESPONSE_CAPTURE_PARAM;

        //Set all of the default control parameters for the camera
        m_capture.offset.x           = DEFAULT_CAPTURE_OFFSET_X;
        m_capture.offset.y           = DEFAULT_CAPTURE_OFFSET_Y;
        m_capture.inputSize.x        = DEFAULT_CAPTURE_INPUT_SIZE_X;
        m_capture.inputSize.y        = DEFAULT_CAPTURE_INPUT_SIZE_Y;
        m_capture.testMode           = DEFAULT_CAPTURE_TEST_MODE;
        m_capture.exposurePeriod     = (float)DEFAULT_CAPTURE_EXPOSURE_PERIOD/(float)ExposureDiv;
        m_capture.analogGain.red     = DEFAULT_CAPTURE_ANALOG_GAIN_RED;
        m_capture.analogGain.green   = DEFAULT_CAPTURE_ANALOG_GAIN_GREEN;
        m_capture.analogGain.blue    = DEFAULT_CAPTURE_ANALOG_GAIN_BLUE;
        m_capture.digitalGain.red    = DEFAULT_CAPTURE_DIGITAL_GAIN_RED;
        m_capture.digitalGain.green  = DEFAULT_CAPTURE_DIGITAL_GAIN_GREEN;
        m_capture.digitalGain.blue   = DEFAULT_CAPTURE_DIGITAL_GAIN_BLUE;
        m_capture.runTime            = DEFAULT_CAPTURE_RUN_TIME;

        call ImagerControl.init();
        call CameraState.set(CAMERA_OFF);
        return SUCCESS;
    }

    //ActiveEye started and set to default parameters
    command result_t StdControl.start() {
        // Turn on the red led to show that initialization is in progress
        call Leds.redOn();
        call ImagerControl.start();
        call CameraState.set(CAMERA_STARTING);
        return SUCCESS;
    }

    command result_t StdControl.stop() {
        call ImagerControl.stop();
        call CameraState.set(CAMERA_OFF);
        return SUCCESS;
    }

    //**********************************************************************
    //*******************************Neuron*********************************
    //**********************************************************************

    task void responseTask() {
        call neuronC.neuronSignalRead(RESPONSE_SIZE, (char*)m_resp);
    }

    event void neuronC.neuronSignalWrite(uint8_t len, char *data) {
        activeEye_query_t *qActive = (activeEye_query_t*)data;
        capture_param_t *p = (capture_param_t *) &qActive->cp;
        capture_param_t *rp = (capture_param_t*) m_resp->data; 

        //If camera is not in idle mode, then turn on red led and return
        if (call CameraState.get() != CAMERA_IDLE) {
            call Leds.redOn();
            return;
        }

        switch (qActive->type) {
            case ACTIVE_EYE_SET_PARAMS:
                //Set state to setting
                call CameraState.set(CAMERA_SETTING);

                //Store new capture peters
                m_capture.offset.x           = p->offset.x;
                m_capture.offset.y           = p->offset.y;
                m_capture.inputSize.x        = p->inputSize.x;
                m_capture.inputSize.y        = p->inputSize.y;
                m_capture.testMode           = p->testMode;
                m_capture.exposurePeriod     = (float)p->exposurePeriod/(float)ExposureDiv;
                m_capture.analogGain.red     = p->analogGain.red;
                m_capture.analogGain.green   = p->analogGain.green;
                m_capture.analogGain.blue    = p->analogGain.blue;
                m_capture.digitalGain.red    = p->digitalGain.red;
                m_capture.digitalGain.green  = p->digitalGain.green;  
                m_capture.digitalGain.blue   = p->digitalGain.blue;  
                m_capture.runTime            = p->runTime;

                //Prepare empty packet to send back
                memcpy(m_resp->data, (uint8_t *)p, sizeof(capture_param_t));

                // Turn on the yellow led to show that we are busy doing CAMERA_SETTING
                call Leds.yellowOn();
                
                //Call to set the parameters
                call imagerConfig.setCaptureParameters(&m_capture);
                break;

            case ACTIVE_EYE_GET_PARAMS:
                //Set replyReady to true since we do not have to wait for an event
                replyReady = TRUE;

                //Get current capture parameters
                rp->offset.x = m_capture.offset.x;
                rp->offset.y = m_capture.offset.y;
                rp->inputSize.x = m_capture.inputSize.x;
                rp->inputSize.y = m_capture.inputSize.y;
                rp->testMode = m_capture.testMode;
                rp->exposurePeriod = (uint16_t)(m_capture.exposurePeriod*(float)ExposureDiv);
                rp->analogGain.red = m_capture.analogGain.red;
                rp->analogGain.green = m_capture.analogGain.green;
                rp->analogGain.blue = m_capture.analogGain.blue;
                rp->digitalGain.red = m_capture.digitalGain.red;
                rp->digitalGain.green = m_capture.digitalGain.green;
                rp->digitalGain.blue = m_capture.digitalGain.blue;
                rp->runTime = m_capture.runTime;
                break;

            default:
                break;
        }
    }

    event void neuronC.neuronSignalReadReady() {
        if (replyReady) {
            replyReady = FALSE;
            post responseTask();
        } else {
            replyRequested = TRUE;
        }
    }

    //This event fires upon a successful transmission. We do not need to do any
    //more processing here.
    event void neuronC.neuronSignalReadDone(result_t success) { }

    //**********************************************************************
    //*******************************Imager*********************************
    //**********************************************************************

    //This event is signalled when the imager has finished setting the parameters
    event result_t imagerConfig.setCaptureParametersDone(result_t status) {
        // set the camera status to idle
        call CameraState.set(CAMERA_IDLE);

        // Turn off the yellow led
        call Leds.yellowOff();

        if (initialization) {
            // Turn off the red led to show that initialization is done
            call Leds.redOff();
            initialization = FALSE;
        }
        else {
            if (replyRequested) {
                replyRequested = FALSE;
                post responseTask();
            } else {
                replyReady = TRUE;
            }
        }
        return SUCCESS;
    }

    //This event is called when the imager has finished initializing
    event result_t imagerConfig.imagerReady(result_t status) {
        call imagerConfig.run(5000);   // run the imager for 5 seconds (for AE convergence)
        return SUCCESS;
    }

    //Event that is called when AE convergence has finished. At this moment we load the
    //camera with the default parameters
    event result_t imagerConfig.runDone(result_t status) {
        //Set the camera status to setting
        call CameraState.set(CAMERA_SETTING);
        call imagerConfig.setCaptureParameters(&m_capture);
        return SUCCESS;
    }

    //Dummy event that should not be signaled in this program. This should be removed when
    //the imager interface is divided into two interfaces.
    event result_t imagerConfig.getPixelAveragesDone(color16_t statVals, result_t status) {	
        return SUCCESS;
    }

}

