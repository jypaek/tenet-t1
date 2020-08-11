/**
 * "Copyright (c) 2006-2009 University of Southern California.
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
 * @modified Feb/27/2008
 * @author Jeongyeup Paek (jpaek@usc.edu)
 **/

#include "camera_state.h"
#include "cyclops_query.h"

module CopyImageN
{
    provides interface StdControl;
    uses {
        interface neuronC;
        interface imagerSnap;
        interface CameraState;
    }
}
implementation
{
    uint8_t m_state;                // Current state of snap module
    bool readRequested;             // Check to see if host has requested a read.

    CYCLOPS_Image img;              // Image struct that specifies the picture params.     

    cyclops_response_t *m_resp;       // pointer to segment of data to send back to mote
    uint8_t buf[offsetof(cyclops_response_t, data)];  // buffer for response data

    uint8_t m_fromImageAddr, m_toImageAddr;

    enum { S_IDLE, S_BUSY, S_RESPOND };

    //***********************************************************************************

    command result_t StdControl.init() {
        readRequested = FALSE;  //Initialize readRequested;
        m_state = S_IDLE;  //Initialize m_state

        img.imageData = (uint8_t *)0x1100;
        img.nFrames = 1;    // we don't use this
        
        m_resp = (cyclops_response_t *)buf;
        m_resp->type = CYCLOPS_RESPONSE_FAIL;
        m_resp->more_left = 0;
        return SUCCESS;
    }
    command result_t StdControl.start() {return SUCCESS;}
    command result_t StdControl.stop() {return SUCCESS;}

    //**********************************************************************

    task void sendCopyResult() {
        uint8_t length;
        
        if (m_state == S_RESPOND)
            m_resp->type = CYCLOPS_RESPONSE_SUCCESS;
        else
            m_resp->type = CYCLOPS_RESPONSE_FAIL;
        
        length = offsetof(cyclops_response_t, data);
        call neuronC.neuronSignalRead(length, (char*)m_resp);
    }

    uint8_t *logicalAddr_to_ImagePtr(uint8_t logical_addr) {
        if (logical_addr == IMAGE_ADDR_THIRD)
            return IMAGE_PTR_THIRD;     // 0x9100
        else if (logical_addr == IMAGE_ADDR_SECOND)
            return IMAGE_PTR_SECOND;    // 0x5100
        // else, FIRST or NEW
        return IMAGE_PTR_FIRST;         // 0x1100
    }

    task void copyImage() {
        uint8_t *fromImagePtr, *toImagePtr;
        uint32_t i, tot_size;

        fromImagePtr = logicalAddr_to_ImagePtr(m_fromImageAddr);
        toImagePtr = logicalAddr_to_ImagePtr(m_toImageAddr);

        tot_size = get_image_size(img.size.x, img.size.y, img.type);

        for (i = 0; i < tot_size; i++) {
            toImagePtr[i] = fromImagePtr[i];
        }

        m_state = S_RESPOND;

        if (readRequested) {
            post sendCopyResult();
            readRequested = FALSE;
        }
    }

    event void neuronC.neuronSignalWrite(uint8_t len, char *data) {
        copy_query_t *q = (copy_query_t *)data;

        if ((m_state == S_IDLE) && (call CameraState.get() == CAMERA_IDLE)) {
            call Leds.redOff();
            
            m_state = S_BUSY;                //Set CopyImageN state to busy
            call CameraState.set(CAMERA_BUSY);  //Set camera state to busy

            m_fromImageAddr = q->fromImageAddr;
            m_toImageAddr = q->toImageAddr;
            img.type    = q->snapQ.type;
            img.size.x  = q->snapQ.size.x;
            img.size.y  = q->snapQ.size.y;

            if (m_fromImageAddr == IMAGE_ADDR_TAKE_NEW)
                call imagerSnap.snapImage(&img, q->snapQ.enableFlash);
            else
                post copyImage();
        } 
        else {
            call Leds.redOn();
        }
    }


    event void neuronC.neuronSignalReadReady() {
        if (m_state == S_BUSY) { // we are in the middle of taking an image.
            readRequested = TRUE;
        } else {
            post sendCopyResult();
        }
    }

    event void imagerSnap.snapImageDone(CYCLOPS_ImagePtr myImg, result_t status) {
        if (myImg != &img)
            return;

        call CameraState.set(CAMERA_IDLE);

        if (status == FAIL) {
            m_state = S_IDLE;
            call Leds.redOn();
        }
        post copyImage();
    }

    event void neuronC.neuronSignalReadDone(result_t success) {
        if (m_state == S_RESPOND)
            m_state = S_IDLE;
    }

}

