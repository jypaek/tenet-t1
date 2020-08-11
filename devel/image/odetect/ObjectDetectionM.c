
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
 * Authors:  
 *          Obi Iroezi: obimdina@seas.ucla.edu
 *          Juan Carlos Garcia: yahualic@ucla.edu
 *          Mohammad Rahimi: mhr@cens.ucla.edu
 *
 * Modified By:                 
 *          Shaun Ahmadian
 *          David Zats dzats@ucla.edu
 *          Mohammad Rahimi mhr@cens.ucla.edu
 *
 * History: modified 08/29/05
 *
 * This module provides the algorithm for performing object detection. It
 * informs the upper layer whether or not an object was detected with every
 * image that is taken.
 */

#include "ObjectDetectionM.h"
#include "segmentM.h"
#include "matrix.h"
#include "image.h"
#include <stdlib.h>
#include <string.h>


    //ALGORITHM PARAMETERS AND DEFAULT VALUES
    uint8_t m_RAcoeff = 3;
    double  m_illCoeff = 0.45;  //unkown for now
    uint8_t m_skip = 4;       //how many pixels and rows we will be skipping
    uint8_t m_range = 5;      //riange to look for values over the threshold
    uint8_t m_detectCntThresh = 40;
    uint8_t m_blobsize = 20;

    //Boolean that states whether or not segmentation was performed successfully
    int segSuccess = 0;

    //Matrix components
    CYCLOPS_Matrix m_newMat;    //Matrix for image that was just grabbed
    CYCLOPS_Matrix m_bgMat;     //Matrix for storing the background
    CYCLOPS_Matrix m_fgMat;     //Matrix that stores the foreground

    //Linked list components for analyzing image
    linkedListSets linkedListSet[MAXIMUM_NUMBER_LISTS+1];
    llnode* mI;

    //int m_first = 1;  //intean variable to see if it was the first image captured

    //***********************************************************************************

    void ObjectDetection_init(uint8_t *newMat, uint8_t *bg, uint8_t *fg, uint8_t *ll) {
        /* memeory location must be fixed.
           - we assume that new image will be at 0x1100
           - image size is limited to 0x4000
           - we only support b/w image */
        //m_newMat.data.ptr8 = (uint8_t *)0x1100;
        //m_bgMat.data.ptr8 = (uint8_t *)0x5100;
        //m_fgMat.data.ptr8 = (uint8_t *)0x9100;
        //mI = (llnode *)0xD100; //array of nodes for linked list
        m_newMat.data.ptr8 = (uint8_t *)newMat;
        m_bgMat.data.ptr8 = (uint8_t *)bg;
        m_fgMat.data.ptr8 = (uint8_t *)fg;
        mI = (llnode *)ll; //array of nodes for linked list

        m_newMat.depth = m_bgMat.depth = m_fgMat.depth = CYCLOPS_1BYTE;
        m_newMat.rows = m_bgMat.rows = m_fgMat.rows = 128;
        m_newMat.cols = m_bgMat.cols = m_fgMat.cols = 128;
        
        //m_first = 1;  //intean variable to see if it was the first image captured
    }

    //***********************************************************************************

    void matrix_abssub(const CYCLOPS_Matrix* A, const CYCLOPS_Matrix* B, CYCLOPS_Matrix* C) {
        uint16_t i; //used uint16_t, so max matrix size is 2^16
        // assume that all matrixes are the same size.
        for (i = 0; i < (A->rows*A->cols); i++) {
            if (A->data.ptr8[i] < B->data.ptr8[i])
                C->data.ptr8[i] = B->data.ptr8[i] - A->data.ptr8[i];
            else
                C->data.ptr8[i] = A->data.ptr8[i] - B->data.ptr8[i];
        }
        C->depth = A->depth;
        C->rows = A->rows;
        C->cols = A->cols;
    }

    uint8_t _obj_locate_max_point(CYCLOPS_Matrix* A, uint8_t* row, uint8_t* col) {
        uint8_t possibleMax = 0;
        uint8_t i, j;
        for (i = 0; i < A->rows; i++) {
            for (j = 0; j < A->cols; j++) {
                if (A->data.ptr8[(i*A->cols) + j] > possibleMax) {
                    possibleMax = A->data.ptr8[(i*A->cols) + j];
                    (*row) = i;
                    (*col) = j;
                }
            }
        }
        return possibleMax;
    }

    double _obj_estimateBackgroundAverage(CYCLOPS_Matrix* A) {
        uint8_t i, j;    //row and col counter
        uint16_t samples = 0;  //how many samples we collected
        uint32_t total = 0;
        
        // estimateAvgBackground
        for (i = 0; i < A->rows; i += m_skip) {
            for (j = 0; j < A->cols; j += m_skip) {
                total += A->data.ptr8[(i * A->cols) + j];
                samples++;
            }
        }
        return ((double)total)/samples;
    }

    uint8_t _obj_cntOverThresh(const CYCLOPS_Matrix* A, uint8_t row, uint8_t col, uint8_t thresh) {
        uint8_t startCol = col - m_range;
        uint8_t endCol = col + m_range;
        uint8_t startRow = row - m_range;
        uint8_t endRow = row + m_range;
        uint8_t i, j, counter = 0; //counters

        //Boundary checks
        if (row + m_range > A->rows) endRow = A->rows;
        if (row < m_range) startRow = 0;
        if (col + m_range > A->cols) endCol = A->cols;
        if (col < m_range) startCol = 0;
        
        for (i = startRow; i <= endRow; i++) {
            for (j = startCol; j <= endCol; j++) {
                if (A->data.ptr8[(i*A->cols) + j] > thresh)
                    counter++;
            }
        }
        return counter;
    }

    //This event is called when ActiveEye has finished obtaining an image. We
    //check to see if object was detected and inform the upper layer of our result.
    int ObjectDetection_detect(int performseg) {
        uint8_t thresh, overTheThresh;
        uint8_t maxrow = 0, maxcol = 0;
        int objectDetected = 0;
        double bckAvg;  //background average

        //If first image collected, m_bgMat should equal image
        /*
        if (m_first) {
            memcpy(m_bgMat.data.ptr8, m_newMat.data.ptr8, m_newMat.rows*m_newMat.cols);
            m_first = 0;
            return 0;
        } */

        //We first check to see whether or not an object has been detected
        //before updating the background. We will only update the background
        //if an object has not been detected

        matrix_abssub(&m_newMat, &m_bgMat, &m_fgMat); //foreground                           
        
        bckAvg = _obj_estimateBackgroundAverage(&m_bgMat);
        thresh = (uint8_t)(bckAvg * m_illCoeff);

        if (performseg) {
            uint16_t objCount;
            segSuccess = segment_segment(&m_fgMat, linkedListSet, mI, m_blobsize, thresh);
            for (objCount = 0; objCount<MAXIMUM_NUMBER_LISTS; objCount++) {
                if (linkedListSet[objCount].memberNumber) {
                    objectDetected = 1;
                    break;
                }
            }
        } else {
            _obj_locate_max_point(&m_fgMat, &maxrow, &maxcol);  //locate max
            overTheThresh = _obj_cntOverThresh(&m_fgMat, maxrow, maxcol, thresh);
            if (overTheThresh > m_detectCntThresh)
                objectDetected = 1;
        }

        if (objectDetected) {
            return 1;
        } else { 
            //If object was not detected,
            uint16_t i = 0;
            // update background 
            for (i = 0; i < m_newMat.rows*m_newMat.cols; i++) {
                m_bgMat.data.ptr8[i] = (m_newMat.data.ptr8[i] >> m_RAcoeff) + 
                                        ((1 << m_RAcoeff) - 1)*(m_bgMat.data.ptr8[i] >> m_RAcoeff);
            }
            return 0;
        }
    }

    //This is called to reset the background.
    void ObjectDetection_resetBackground() {
        //In order to reset the background, all we have to do is to set first to true.  
        //This means that the background calculation will start from scratch and the history of 
        //the background will be erased. 
        //m_first = 1;
    }

    void ObjectDetection_setBackground() {
        memcpy(m_bgMat.data.ptr8, m_newMat.data.ptr8, m_newMat.rows*m_newMat.cols);
        //m_first = 0;
    }

    //This is called to set the image resolution
    //This must be called before calling 'detect'
    int ObjectDetection_setImgRes(uint8_t sizex, uint8_t sizey, uint8_t imgtype) {

        /* ObjectDetection only support black&white image for now */
        if (imgtype != CYCLOPS_IMAGE_TYPE_Y)
            return 0;

        /* maximum image size supported is 16kB */
        if ((sizex * sizey) > 0x4000)
            return 0;

        //change the matrix sizes
        m_newMat.depth = m_bgMat.depth = m_fgMat.depth = CYCLOPS_1BYTE;
        m_newMat.rows = m_bgMat.rows = m_fgMat.rows = sizex;
        m_newMat.cols = m_bgMat.cols = m_fgMat.cols = sizey;
        return 1;
    }

    //This is called to change the Running Average Coefficient
    void ObjectDetection_setRACoeff(uint8_t newRAcoeff) {   
        m_RAcoeff = newRAcoeff;
    }

    //This is called to change the number of pixels to skip over
    //when determining if an object has been detected.
    void ObjectDetection_setSkip(uint8_t newSkip) {
        m_skip = newSkip;
    }

    //This is called to change the illumination coefficient.
    void ObjectDetection_setIlluminationCoeff(double newIllCoeff) {
        m_illCoeff = newIllCoeff;
    }

    //This is called to set the area of the pixels that we 
    //scan to see if we have enough pixels to overcome the threshold #.
    //If we overcome the threshold, we believe that we have detected an object.
    void ObjectDetection_setRange(uint8_t newRange) {
        m_range = newRange;
    }

    //This is called to set the threshold number of pixels. If we 
    //obtain more pixels than the threshold, we believe that an object
    //has been detected.
    void ObjectDetection_setDetectThresh(uint8_t newThresh) {
        m_detectCntThresh = newThresh;
    }

    //This is called to obtain the result of the segmentation.
    //It returns the intean
    int ObjectDetection_getSegmentResult() {
        return segSuccess;
    }


