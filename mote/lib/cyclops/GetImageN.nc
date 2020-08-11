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
 * @modified 6/27/2007
 * @author Jeongyeup Paek
 *
 * - Merge snapN.nc and snapN.nc
 *   (No need for seperate configuration file if interfaces are identical.)
 * - Remove all pointer arithmatic.
 *   Replace it with integer calculation of number of bytes.
 **/

#include "cyclops_query.h"

module GetImageN
{
    provides interface StdControl;
    uses {
        interface neuronC;      // Interface for communicating over neuron
        interface imagerSnap;   // Active-Eye interface (imager)
        interface CameraState;
        interface Timer;
        interface Leds;
    }
}
implementation
{
#include "cyclops_query.c"

    //Variables to maintain state
    uint8_t m_state;                // Current state of snap module
    bool readRequested;             // Check to see if host has requested a read.

    //Parameters obtained from query
    CYCLOPS_Image img;              // Image struct that specifies the picture params.     
    uint8_t m_imageAddr;
    bool m_useFlash;                // Use a flash (turn on IR LEDS) or not
    uint8_t m_fragmentSize;         // Number of data bytes per packet
    uint16_t m_reportRate;

    //Variables to send images
    uint8_t m_buf[TOSH_DATA_LENGTH];  // buffer for response data
    cyclops_response_t *m_resp;
    image_response_t *m_imgresp;
    // remember that the total length of a reponse packet that is passed via
    // I2C cannot exceed I2C_MAX_PACKETSIZE, which is limited to 128 bytes.

    uint32_t m_totNumBytes;         // Total number of bytes per image
    uint32_t m_sentNumBytes;        // Total number of bytes sent...
    uint8_t *m_ptrSeg;              // Pointer to current segment to send
    
    //States for m_state;
    enum { S_IDLE, S_BUSY, S_RESPOND };

    //***********************************************************************************

    command result_t StdControl.init() {
        call Leds.init();

        m_state = S_IDLE;
        readRequested = FALSE;
        
        m_resp = (cyclops_response_t *)m_buf;
        m_resp->type = CYCLOPS_RESPONSE_IMAGE;
        m_imgresp = (image_response_t *)m_resp->data;

        img.nFrames = 1;    // we don't use this.
        return SUCCESS;
    }

    command result_t StdControl.start() {return SUCCESS;}
    command result_t StdControl.stop() {return SUCCESS;}

    //**********************************************************************

    void stop_sending() {
        m_state = S_IDLE;
        call Leds.greenOff();
        call Leds.amberOff();
    }

    //This task sends a segment of the appropriate length to the host.
    task void getSeg() {
        uint8_t length;

        if (m_state == S_IDLE)
            return;

        //Toggle the green led to specify that a packet is being sent
        call Leds.greenOn();

        //Increment the fragment count
        m_imgresp->fragNum++;

        //If the last packet, then find out how much data is left to send,
        if (m_imgresp->fragNum == m_imgresp->fragTotal) {
            m_resp->more_left = 0;
            m_imgresp->dataLength = m_totNumBytes - m_sentNumBytes;
            stop_sending(); 
        }
        //If there are more full-size segments, then the if-statement is calculated by 
        //using pointer arithmetic.  
        else {
            //Check to see that we are sending the correct data
            if ((m_sentNumBytes + m_fragmentSize) < m_totNumBytes) {
                m_resp->more_left = 1;
                m_imgresp->dataLength = m_fragmentSize;
            }
            //If we are not, then turn on the red led and return;
            else {
                call Leds.redOn();
                return;
            }
        }

        //Image is available so send the appropriate segment                
        memcpy(m_imgresp->data, m_ptrSeg, m_imgresp->dataLength);

        //Update pointer to the next segment
        m_ptrSeg = (uint8_t *)((uint16_t)m_ptrSeg + (uint16_t)m_imgresp->dataLength);

        //Update total number of bytes  sent
        m_sentNumBytes += m_imgresp->dataLength;

        //length of the packet that will be sent to the host via neuron.
        length = offsetof(cyclops_response_t, data) + offsetof(image_response_t, data) + m_imgresp->dataLength;
        
        //We are sending a 'cyclops_response_t' structure to the host.
        call neuronC.neuronSignalRead(length, (char*)m_resp);
    }

    task void getImage() {    

        //img.imageData = (uint8_t *)0x1100;  
        if (m_imageAddr == IMAGE_ADDR_THIRD)
            img.imageData = IMAGE_PTR_THIRD;
        else if (m_imageAddr == IMAGE_ADDR_SECOND)
            img.imageData = IMAGE_PTR_SECOND;
        else
            img.imageData = IMAGE_PTR_FIRST;    // 0x1100

        m_ptrSeg = (uint8_t *)img.imageData;

        //Calculate number of bytes
        m_totNumBytes = get_image_size(img.size.x, img.size.y, img.type);
        m_sentNumBytes = 0;
        
        //Calculate number of fragments
        m_imgresp->fragTotal = (uint16_t)(m_totNumBytes / (uint32_t)m_fragmentSize);
        m_imgresp->fragNum = 0; //Initially set the fragCount to 0

        //We add another fragment to the total if
        //there is data left to send that only fills part of a packet.
        if (((uint32_t)m_imgresp->fragTotal * (uint32_t)m_fragmentSize) < m_totNumBytes)
            m_imgresp->fragTotal++;

        if (m_imageAddr == IMAGE_ADDR_TAKE_NEW) {
            call imagerSnap.snapImage(&img, m_useFlash);
        }
        else { // not taking new image...
            call CameraState.set(CAMERA_IDLE);
            m_state = S_RESPOND;

            if (readRequested) {
                post getSeg();
                readRequested = FALSE;
            }
        }
    }

    /*When a query arrives, we check to see if the camera is busy. If so, we copy the 
      parts of it that we are processing into global variables. Otherwise, we drop the
      query.*/
    event void neuronC.neuronSignalWrite(uint8_t len, char *data) {
        //Type-cast the data as a getImage_query_t in order to properly parse it
        getImage_query_t *sf = (getImage_query_t *)data;

        if (len == 0) {
            stop_sending(); 
            return;
        }
        
        // if we were in the middle of sendinging previous image, abort.
        if (m_state == S_RESPOND)
            stop_sending(); 
            
        if ((m_state != S_IDLE) || (call CameraState.get() != CAMERA_IDLE)) {
            call Leds.redOn();
            return;
        }
        call Leds.redOff();
        
        m_state = S_BUSY;                //Set GetImageN state to busy
        call CameraState.set(CAMERA_BUSY);  //Set camera state to busy
        call Leds.amberOn(); //Turn on amber led

        //Copy get-image parameters into global variables    
        m_imageAddr = sf->imageAddr;
        m_fragmentSize = sf->fragmentSize;  // data size of each fragment.
        m_reportRate = sf->reportRate;      // inter-fragment interval in millisec

        //Copy snap-image parameters into global variables    
        m_useFlash  = sf->snapQ.enableFlash;
        img.type    = sf->snapQ.type;
        img.size.x  = sf->snapQ.size.x;
        img.size.y  = sf->snapQ.size.y;
        if (img.size.x == 0) img.size.x = 128;
        if (img.size.y == 0) img.size.y = 128;

        //Post task to start obtaining the image
        post getImage();
    }

    task void sendFailResult() {
        uint8_t length;
        m_resp->type = CYCLOPS_RESPONSE_FAIL;
        length = offsetof(cyclops_response_t, data);
        call neuronC.neuronSignalRead(length, (char*)m_resp);
    }

    //This event handles read requests. Its actions depend on the status of the camera.
    event void neuronC.neuronSignalReadReady() {

        if (m_state == S_BUSY) { // we are in the middle of taking an image.
            //If the camera is busy obtaining an image, then set the readRequested
            //flag to true so that we know to obtain a segment, when the camera finishes
            //taking an image.
            readRequested = TRUE;
        } else if (m_state == S_RESPOND) {
            //If an image is available, then post a task to obtain a segment
            if (m_reportRate > 0)
                call Timer.start(TIMER_ONE_SHOT, m_reportRate);
            else
                post getSeg();
        } else {                    //If an image is not available...
            //If no image available and camera is idle, then there is a problem.
            //Turn on the red led because we should never encounter this.
            call Leds.redOn();
            post sendFailResult();
        }
    }

    //This event is called when the image has been obtained.
    event void imagerSnap.snapImageDone(CYCLOPS_ImagePtr myImg, result_t status) {
        //Check to see if image returned is ours. If not, return
        if (myImg != &img)
            return;

        //Since the imager is done, set the camera to idle
        call CameraState.set(CAMERA_IDLE);

        if (status == FAIL) {
            call Leds.redOn();
            stop_sending(); 
            return;
        }

        if (m_state == S_IDLE)
            return;
        m_state = S_RESPOND;

        if (readRequested) {
            post getSeg();
            readRequested = FALSE;
        }
    }

    //At this point we are assuming that the neuron transaction completed successfully
    //and are not doing any more processing.
    event void neuronC.neuronSignalReadDone(result_t success) {
        call Leds.greenOff();
    }

    event result_t Timer.fired() { 
        post getSeg();
        return SUCCESS;
    }
}

