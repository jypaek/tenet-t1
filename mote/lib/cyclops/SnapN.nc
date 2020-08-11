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
 * Authors: Shaun Ahmadian
 *          Alan Jern
 *          David Zats dzats@ucla.edu
 *          Mohammad Rahimi mhr@cens.ucla.edu
 * History: created 08/02/05
 *
 * This module provides the implementation for the snap system on the cyclops. It allows 
 * the host to resolve all queries related to snap. This module
 * communicates with the host (mote) through Neuron.
 */

/**
 * @modified Feb/27/2008
 * @author Jeongyeup Paek
 *
 * - Seperate 'take picture' functionality from 'transfer image' functionality.
 *   Now, 'snap' means 'take picture', without data transfer,
 *   and  'fetch' means 'transfer image'.
 * - Merge SnapN.nc and snapM.nc
 *   (No need for seperate configuration file if interfaces are identical.)
 * - Remove all pointer arithmatic.
 *   Replace it with integer calculation of number of bytes.
 **/

#include "camera_state.h"
#include "cyclops_query.h"

module SnapN
{
    provides interface StdControl;
    uses {
        interface Leds;

        //Interface for communicating over neuron
        interface neuronC;

        //Active-Eye interface (imager)
        interface imagerSnap;
        
        interface CameraState;
    }
}
implementation
{

    //Variables to maintain state
    uint8_t m_state;                // Current state of snap module
    bool readRequested;             // Check to see if host has requested a read.

    //Parameters obtained from query
    CYCLOPS_Image img;              // Image struct that specifies the picture params.     

    //Variables to send images
    cyclops_response_t *m_resp;       // pointer to segment of data to send back to mote
    uint8_t buf[offsetof(cyclops_response_t, data)];  // buffer for response data
    // remember that the total length of a reponse packet that is passed via
    // I2C cannot exceed I2C_MAX_PACKETSIZE, which is limited to 128 bytes.

    //States for m_state;
    enum { S_IDLE, S_BUSY, S_RESPOND };

    //***********************************************************************************

    command result_t StdControl.init() {
        readRequested = FALSE;  //Initialize readRequested;
        m_state = S_IDLE;  //Initialize m_state

        //Override location of storing imageData
        //img.imageData = (uint8_t *)0x1100;  
        img.imageData = 0x00001100;  
        img.nFrames = 1;    // we don't use this
        
        m_resp = (cyclops_response_t *)buf;
        m_resp->type = CYCLOPS_RESPONSE_FAIL;
        m_resp->more_left = 0;

        return SUCCESS;
    }

    command result_t StdControl.start() {return SUCCESS;}
    command result_t StdControl.stop() {return SUCCESS;}

    //**********************************************************************
    //*******************************Neuron*********************************
    //**********************************************************************

    //This task sends a segment of the appropriate length to the host.
    task void sendSnapResult() {
        uint8_t length;
        
        if (m_state == S_RESPOND)
            m_resp->type = CYCLOPS_RESPONSE_SUCCESS;
        else
            m_resp->type = CYCLOPS_RESPONSE_FAIL;
        
        //length of the packet that will be sent to the host via neuron.
        length = offsetof(cyclops_response_t, data);
        //We are sending a 'cyclops_response_t' structure to the host.
        call neuronC.neuronSignalRead(length, (char*)m_resp);
    }

    /*When a query arrives, we check to see if the camera is busy. If so, we copy the 
      parts of it that we are processing into global variables. Otherwise, we drop the
      query.*/
    event void neuronC.neuronSignalWrite(uint8_t len, char *data) {
        snap_query_t *sq = (snap_query_t *)data;

        if (m_state == S_IDLE) { // is camera ready?
            if (call CameraState.get() != CAMERA_IDLE) {
                call Leds.redOn();
                return;
            }
            
            m_state = S_BUSY;                //Set SnapN state to busy
            call CameraState.set(CAMERA_BUSY);  //Set camera state to busy

            //Copy snap/snap-image parameters into global variables
            img.type    = sq->type;
            img.size.x  = sq->size.x;
            img.size.y  = sq->size.y;

            call imagerSnap.snapImage(&img, sq->enableFlash);
        }
    }

    //This event handles read requests. Its actions depend on the status of the camera.
    event void neuronC.neuronSignalReadReady() {
        if (m_state == S_BUSY) { // we are in the middle of taking an image.
            readRequested = TRUE;
        } else {                    // we have already taken an image.
            post sendSnapResult();
        }
    }

    //This event is called when the image has been obtained.
    event void imagerSnap.snapImageDone(CYCLOPS_ImagePtr myImg, result_t status) {
        //Check to see if image returned is ours. If not, return
        if (myImg != &img)
            return;

        //Since the imager is done, set the camera to idle
        m_state = S_RESPOND;
        call CameraState.set(CAMERA_IDLE);

        if (status == FAIL) {
            m_state = S_IDLE;
            call Leds.redOn();
        }

        if (readRequested) {
            post sendSnapResult();
            readRequested = FALSE;
        }
    }

    //At this point we are assuming that the neuron transaction completed successfully
    //and are not doing any more processing.
    event void neuronC.neuronSignalReadDone(result_t success) {
        if (m_state == S_RESPOND)
            m_state = S_IDLE;
    }

}

