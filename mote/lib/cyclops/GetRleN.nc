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
 * @modified Feb/24/2008
 * @author Jeongyeup Paek (jpaek@usc.edu)
 *
 * - A neuron module that implements simple 'Run-Length Encoding' (RLE)
 *   to compress and send images.
 *   - An image is encoded (compressed) using basic "[len][char]"
 *     run-length-encoding before being sent to the master.
 * - This module implements 'lossless' AND 'lossy' RLE;
 *   - 'lossy RLE' defines a 'run' when consecutive values are within
 *     +/-'threshold' of the last non-run value.
 *   - 'lossless RLE' is 'lossy RLE' with threshold equal to zero.
 **/

#include "cyclops_query.h"

module GetRleN
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
    rle_image_response_t *m_rleresp;

    uint32_t m_totNumBytes;         // Total number of bytes per image
    uint8_t *m_ptrSeg;              // Pointer to current segment to send

    /* for Run-length encoding */
    uint8_t m_runVal;
    uint8_t m_runlen;
    uint32_t m_dataIdx;
    uint32_t m_sum;
    uint8_t m_thresh;

    //States for m_state;
    enum { S_IDLE, S_BUSY, S_RESPOND };

    //***********************************************************************************

    command result_t StdControl.init() {
        call Leds.init();

        m_state = S_IDLE;
        readRequested = FALSE;
        
        m_resp = (cyclops_response_t *)m_buf;
        m_resp->type = CYCLOPS_RESPONSE_RLE_IMAGE;
        m_rleresp = (rle_image_response_t *)m_resp->data;
        m_rleresp->rleType = CYCLOPS_RESPONSE_RLE_IMAGE;
        m_thresh = 0;

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

    uint8_t max8(uint8_t a, uint8_t b) { if (a > b) return a; return b; }
    uint8_t min8(uint8_t a, uint8_t b) { if (a > b) return b; return a; }

    //This task sends a segment of the appropriate length to the host.
    task void getSeg() {
        uint8_t length;
        uint8_t curVal;

        if (m_state == S_IDLE)
            return;

        //Toggle the green led to specify that a packet is being sent
        call Leds.greenOn();

        length = 0;
        m_rleresp->seqNum = m_dataIdx - m_runlen;   // addr of first byte

        while (m_dataIdx < m_totNumBytes) {

            curVal = m_ptrSeg[m_dataIdx++];

            if (m_dataIdx == 1) {
                m_runlen = 1;
                m_runVal = curVal;
                m_sum = (uint32_t) curVal;
            //} else if (curVal == m_runVal) {
            } else if ((curVal <= max8(m_runVal, m_runVal + m_thresh)) && 
                        (curVal >= min8(m_runVal, m_runVal - m_thresh))) {
                if (m_runlen == 254) {    // length too long... flush
                    m_runVal = (uint8_t)(m_sum/(uint32_t)m_runlen);
                    m_rleresp->data[length++] = m_runVal;
                    m_rleresp->data[length++] = m_runlen;
                    m_runlen = 1;
                    m_runVal = curVal;
                    m_sum = (uint32_t)curVal;
                } else {
                    m_runlen++;
                    m_sum += (uint32_t)curVal;
                }
            } else { /* no run */
                m_runVal = (uint8_t)(m_sum/(uint32_t)m_runlen);
                m_rleresp->data[length++] = m_runVal;
                m_rleresp->data[length++] = m_runlen;
                m_runlen = 1;
                m_runVal = curVal;
                m_sum = (uint32_t)curVal;
            }
            if (length + 2 > m_fragmentSize)
                break;
        }

        if ((m_dataIdx == m_totNumBytes) && (length + 2 <= m_fragmentSize)) {
            m_runVal = (uint8_t)(m_sum/(uint32_t)m_runlen);
            m_rleresp->data[length++] = m_runVal;
            m_rleresp->data[length++] = m_runlen;
            m_runlen = 0;
            m_resp->more_left = 0;
            stop_sending(); 
        } else {
            m_resp->more_left = 1;
        }
        m_rleresp->dataLength = length;

        //length of the packet that will be sent to the host via neuron.
        length = offsetof(cyclops_response_t, data) + offsetof(rle_image_response_t, data) + m_rleresp->dataLength;
        
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

        m_rleresp->seqNum = 0;
        m_dataIdx = 0;
        m_runlen = 0;

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
        //Type-cast the data as a getRle_query_t in order to properly parse it
        getRle_query_t *q = (getRle_query_t *)data;

        if (len == 0) {
            stop_sending(); 
            return;
        }
        
        // if we were in the middle of sendinging previous image, abort.
        if (m_state == S_RESPOND)
            stop_sending(); 
            
        if (m_state != S_IDLE) {
            call Leds.redOn();
            return;
        }
        // is camera ready?
        if (call CameraState.get() != CAMERA_IDLE) {
            call Leds.redOn();
            return;
        }
        
        m_state = S_BUSY;                //Set GetRleN state to busy
        call CameraState.set(CAMERA_BUSY);  //Set camera state to busy
        call Leds.amberOn(); //Turn on amber led

        //Copy get-image parameters into global variables    
        m_imageAddr    = q->imageAddr;
        m_fragmentSize = q->fragmentSize;  // data size of each fragment.
        m_reportRate   = q->reportRate;      // inter-fragment interval in millisec
        m_thresh       = q->threshold;

        //Copy snap-image parameters into global variables    
        m_useFlash  = q->snapQ.enableFlash;
        img.type    = q->snapQ.type;
        img.size.x  = q->snapQ.size.x;
        img.size.y  = q->snapQ.size.y;
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

