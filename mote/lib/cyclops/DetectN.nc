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
 *          David Zats dzats@ucla.edu
 *          Mohammad Rahimi mhr@cens.ucla.edu
 * History: created 08/29/05
 *
 * This module responsible for communicating over neuron and parsing queries 
 * used to perform object detection.
 */

/**
 * Modified:
 *
 * @author Jeongyeup Paek (jpaek@usc.edu)
 * @modified 8/1/2007
 **/
 
#include "segment.h"
#include "image.h"
#include "cyclops_query.h"

module DetectN
{
    uses {
        interface Leds;

        //Interfaces for using object detection library
        interface ObjectDetection;

        //Interface for communicating over neuron
        interface neuronC;

        //Active-Eye Snap(take image) interface (imager)
        interface imagerSnap;
        
        interface CameraState;
    }

    provides interface StdControl;
}

implementation
{ 
    //Variables to maintain state
    uint8_t m_state;                // Current state of snap module
    bool readRequested;             // Check to see if host has requested a read.

    //Parameters obtained from query
    CYCLOPS_Image img;              // Image struct that specifies the picture params.     
    bool m_use_segment;

    enum {
        RESPONSE_SIZE = offsetof(cyclops_response_t, data) + sizeof(result_response_t)
    };
    //Variables to send images
    uint8_t buf[RESPONSE_SIZE];     // buffer for response data
    cyclops_response_t *m_resp;     // pointer to segment of data to send back to mote
    result_response_t* m_dr;

    //States for m_state;
    enum { S_IDLE, S_BUSY, S_RESPOND };

    //***********************************************************************************

    command result_t StdControl.init() {
        m_state = S_IDLE;
        
        m_resp = (cyclops_response_t *)buf;
        m_resp->type = CYCLOPS_RESPONSE_RESULT;
        m_resp->more_left = 0;

        m_dr = (result_response_t*)m_resp->data;
        m_dr->result = 0;
        
        img.type = CYCLOPS_IMAGE_TYPE_Y;
        img.size.x = 128;
        img.size.y = 128;
        img.imageData = IMAGE_PTR_FIRST;    // 0x1100
        img.nFrames = 1;

        m_use_segment = FALSE;

        call ObjectDetection.init();
        return SUCCESS;
    }
    command result_t StdControl.start() { return SUCCESS; }
    command result_t StdControl.stop() { return SUCCESS; }

    //***********************************************************************************

    task void responseTask() {
        if (m_state == S_RESPOND)
            m_state = S_IDLE;
        call neuronC.neuronSignalRead(RESPONSE_SIZE, (char*)m_resp);
        call Leds.greenOff();
    }

    //This event is signaled whenever objectDetection has attempted to detect an object.
    void detect_object () {
        result_t success;

        if (m_use_segment) success = call ObjectDetection.detect(TRUE);
        else             success = call ObjectDetection.detect(FALSE);
        m_dr->result = success;
        //if (success) segSuccess = call ObjectDetection.getSegmentResult();

        m_state = S_RESPOND; // ready to respond
        
        //If a read was requested while we were attempting to detect an object,
        //then set the boolean to false and post a task to respond to the request.
        if (readRequested) {
            readRequested = FALSE;
            post responseTask();
        }
    }  

    //This event is signaled whenever a query needs to be responded to.
    event void neuronC.neuronSignalWrite(uint8_t len, char *data) {
        //Type-cast the query so that we can parse it
        detect_query_t* dq = (detect_query_t* ) data;

        // if we were in the middle of processing previous image, abort.
        if (m_state == S_RESPOND)
            m_state = S_IDLE;

        if (m_state != S_IDLE) {
            call Leds.redOn();
            return;
        }
        call Leds.amberOn(); //Turn on amber led
        
        if (dq->type == DETECT_RESET_BACKGROUND) {
            call ObjectDetection.resetBackground();
        }
        else if (dq->type == DETECT_SET_BACKGROUND) {
            call ObjectDetection.setBackground();
        }
        else if (dq->type == DETECT_SET_PARAM) {
        
            //We call object detection to set all of the parameters provided to us.
            img.size.x = dq->snapQ.size.x;
            img.size.y = dq->snapQ.size.y;
            call ObjectDetection.setImgRes(img.size.x, img.size.y, img.type);
            call ObjectDetection.setRACoeff(dq->detectParam.RACoeff);
            call ObjectDetection.setSkip(dq->detectParam.skip);
            call ObjectDetection.setIlluminationCoeff((double)dq->detectParam.illCoeff/100.0);
            call ObjectDetection.setRange(dq->detectParam.range);
            call ObjectDetection.setDetectThresh(dq->detectParam.detectThresh);

            // must reset background after setting param
            call ObjectDetection.resetBackground();
        }
        else if ((dq->type == DETECT_RUN_OLD) || (dq->type == DETECT_RUN_NEW_IMG)) {
            m_use_segment = dq->use_segment;
            
            img.size.x = dq->snapQ.size.x;
            img.size.y = dq->snapQ.size.y;
            call ObjectDetection.setImgRes(img.size.x, img.size.y, img.type);

            if (dq->type == DETECT_RUN_NEW_IMG) {
                // is camera ready?
                if (call CameraState.get() != CAMERA_IDLE) {
                    call Leds.redOn();
                    return;
                }
                
                m_state = S_BUSY;                //Set state to busy
                call CameraState.set(CAMERA_BUSY);  //Set camera state to busy
                call Leds.greenOn();

                call imagerSnap.snapImage(&img, dq->snapQ.enableFlash);
            }
            else {
                call Leds.greenOn();
                // run object detection algorithm
                detect_object();
            }
        }
        else {
            call Leds.amberOff();
            call Leds.redOn();
        }
    }

    //This event is signaled when a read is requested.
    event void neuronC.neuronSignalReadReady() {
        if (m_state == S_BUSY) { // we are in the middle of taking an image.
            readRequested = TRUE;
        } else if (m_state == S_RESPOND) {
            //If an image is available, then post a task to obtain a segment
            post responseTask();
        } else {                    //If an image is not available...
            post responseTask();
        }
    }

    //This event is called when the image has been obtained.
    event void imagerSnap.snapImageDone(CYCLOPS_ImagePtr myImg, result_t status) {
        //Check to see if image returned is ours. If not, return
        if (myImg != &img)
            return;

        //Since the imager is done, set the camera to idle
        call CameraState.set(CAMERA_IDLE);

        //If there is a problem: light the red led and return a fail
        if (status == FAIL) {
            m_state = S_IDLE;
            call Leds.redOn();
            return;
        }

        // run object detection algorithm
        detect_object();
    }

    //This event is signaled when we are done transmitting over neuron.
    event void neuronC.neuronSignalReadDone(result_t success) {
        m_dr->result = 0;
        call Leds.amberOff();
    }

}

