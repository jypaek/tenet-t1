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
 * - This neuron module implements "PackBits" format (by Apple/Macintos)
 *   Run-Length Encoding(RLE) to compress and send images. (see below)
 *
 * - This module implements 'lossless' AND 'lossy' version of RLE;
 *   - 'lossy RLE' defines a 'run' when consecutive values are within
 *     +/-'threshold' of the last non-run value.
 *   - 'lossless RLE' is 'lossy RLE' with threshold equal to zero.
 **/

 /***************************************************************************
 *               Packbits Encoding and Decoding Library
 *
 *   Purpose : Use packbits run length coding to compress and
 *             decompress files.  This packbits variant begins each block of
 *             data with the a byte header that is decoded as follows.
 *
 *             Byte (n)   | Meaning
 *             -----------+-------------------------------------
 *             0 ~ 127    | Copy the next n + 1 bytes
 *             -127 ~ -1  | Make 1 - n copies of the next byte
 *             -128       | Do nothing
 ***************************************************************************/


#include "cyclops_query.h"

module GetPackBitsN
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

    //States for m_state;
    enum { S_IDLE, S_BUSY, S_RESPOND };


    /* for PackBits RLE */
    enum {
        MIN_RUN  = 2,                   /* minimum run length */
        MAX_RUN  = 128,                 /* maximum run length */
        MAX_READ = MAX_RUN+1,           /* maximum characters to buffer as a run */
        MAX_WRITE = MAX_READ+MAX_RUN    /* maximum characters to buffer before writing */
    };
    uint8_t m_runlen;
    uint32_t m_dataIdx;
    uint8_t m_prevVal[MAX_READ];
    uint32_t m_sum;
    uint8_t m_thresh;
    uint8_t m_writeBuf[MAX_WRITE];
    uint8_t m_wlen = 0;


    //***********************************************************************************

    command result_t StdControl.init() {
        call Leds.init();

        m_state = S_IDLE;
        readRequested = FALSE;
        
        m_resp = (cyclops_response_t *)m_buf;
        m_resp->type = CYCLOPS_RESPONSE_PACKBITS_IMAGE;
        m_rleresp = (rle_image_response_t *)m_resp->data;
        m_rleresp->rleType = CYCLOPS_RESPONSE_PACKBITS_IMAGE;
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
        uint8_t length = 0;
        uint8_t curVal;

        if (m_state == S_IDLE)
            return;

        //Toggle the green led to specify that a packet is being sent
        call Leds.greenOn();

        m_rleresp->seqNum++;

/***********/

        while (m_dataIdx < m_totNumBytes) {

            if (m_wlen >= m_fragmentSize)
                break;

            curVal = m_ptrSeg[m_dataIdx++];

            m_prevVal[m_runlen] = curVal;
            m_runlen++;

            if (m_runlen >= MIN_RUN) {

                if ((curVal <= max8(m_prevVal[m_runlen - MIN_RUN], m_prevVal[m_runlen - MIN_RUN] + m_thresh)) && 
                    (curVal >= min8(m_prevVal[m_runlen - MIN_RUN], m_prevVal[m_runlen - MIN_RUN] - m_thresh))) { /* run */
                    uint8_t next = 0;

                    /* everything before the run-run must be a non-run-run */
                    if (m_runlen > MIN_RUN) {
                        int j = 0;
                        m_writeBuf[m_wlen++] = (uint8_t)(m_runlen - MIN_RUN - 1);
                        for (j = 0; j < m_runlen - MIN_RUN; j++) {
                            m_writeBuf[m_wlen++] = m_prevVal[j];
                        }
                    }

                    m_sum = (uint32_t)m_prevVal[m_runlen - MIN_RUN];
                    m_sum += (uint32_t)curVal;
                    curVal = m_prevVal[m_runlen - MIN_RUN]; // reset curVal to first value of the run
                    m_runlen = MIN_RUN;

                    while ((m_dataIdx < m_totNumBytes) && (m_runlen != MAX_RUN)) {
                        /* while run is not at max length, (neither max run len nor max pkt len) */
                        next = m_ptrSeg[m_dataIdx++];

                        if ((next > max8(curVal, curVal + m_thresh)) ||
                            (next < min8(curVal, curVal - m_thresh))) break;  // no more run
                        m_runlen++;                       // run continues
                        m_sum += (uint32_t) next;
                    }
                    curVal = (uint8_t)(m_sum/(uint32_t)m_runlen);

                    /* write out encoded run length and run symbol */
                    m_writeBuf[m_wlen++] = (uint8_t)(1 - m_runlen);
                    m_writeBuf[m_wlen++] = curVal;

                    if ((m_dataIdx < m_totNumBytes) && (m_runlen != MAX_RUN)) {
                        /* make run breaker start of next buffer */
                        m_runlen = 1;
                        m_prevVal[0] = next;
                    }
                    else { /* file or max run ends in a run */
                        m_runlen = 0;
                    }
                } else if (m_runlen == MAX_RUN + 1) {
                    int j;
                    m_writeBuf[m_wlen++] = (uint8_t)(MAX_RUN - 1);
                    for (j = 0; j < MAX_RUN; j++) {
                        m_writeBuf[m_wlen++] = m_prevVal[j];
                    }

                    m_runlen = 1;                     /* start a new buffer */
                    m_prevVal[0] = m_prevVal[MAX_RUN];  /* copy excess to front of buffer */
                }
            }
        }

        if (m_wlen >= m_fragmentSize) {
            uint8_t j = 0;
            length = 0;
            for (j = 0; j < m_wlen; j++) {
                if (j < m_fragmentSize) {
                    m_rleresp->data[length++] = m_writeBuf[j];
                } else {
                    m_writeBuf[j - m_fragmentSize] = m_writeBuf[j];
                }
            }
            m_wlen -= length;
        }
        else {
            /* write out last buffer */
            if (0 != m_runlen) {
                uint8_t j = 0;
                if (m_runlen <= MAX_RUN) { /* write out entire copy buffer */
                    m_writeBuf[m_wlen++] = (uint8_t)(m_runlen - 1);
                    for (j = 0; j < m_runlen; j++) {
                        m_writeBuf[m_wlen++] = m_prevVal[j];
                    }
                } else {
                    /* we read more than the maximum for a single copy buffer */
                    m_writeBuf[m_wlen++] = (uint8_t)(MAX_RUN - 1);
                    for (j = 0; j < MAX_RUN; j++) {
                        m_writeBuf[m_wlen++] = m_prevVal[j];
                    }

                    /* write out remainder */
                    m_writeBuf[m_wlen++] = (uint8_t)(m_runlen - MAX_RUN - 1);
                    for (j = MAX_RUN; j < m_runlen; j++) {
                        m_writeBuf[m_wlen++] = m_prevVal[j];
                    }
                }
                m_runlen = 0;
            }
            if (m_wlen > 0) {
                uint8_t j = 0;
                length = 0;
                for (j = 0; j < m_wlen; j++) {
                    if (j < m_fragmentSize) {
                        m_rleresp->data[length++] = m_writeBuf[j];
                    } else {
                        m_writeBuf[j - m_fragmentSize] = m_writeBuf[j];
                    }
                }
                m_wlen -= length;
            }
        }

        if ((m_dataIdx == m_totNumBytes) && (m_wlen == 0)) {
            if ((length % 2) == 1) {
                m_rleresp->data[length++] = 0x80;   // null value for byte-align
            }
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
        m_sum = 0;
        m_wlen = 0;

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
        getPackBits_query_t *q = (getPackBits_query_t *)data;

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
        
        m_state = S_BUSY;                //Set GetPackBitsN state to busy
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

