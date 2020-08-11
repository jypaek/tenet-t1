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
 * Interface that is used between a object detection application
 * and an application that makes the use of it.
 */

#include "segment.h"

interface ObjectDetection {

    command void init();

    /*command to reset the background image for object detection
     *purposes. The first new image taken after the background is
     *reset will not be checked to see for object detection!
     *
     *return SUCCESS if it was succesfully changed, or FAIL otherwi
     */
    command void resetBackground();
    command void setBackground();

    /*commmand to check whether current image has object
     *
     *@segment states whether or not to perform the segmentation
     *
     *return FAIL if currently busy capturing an image or doing calculation.  
     *Returns SUCCESS if able to start obtaining the next image.
     */
    command result_t detect(bool performseg);

    /*command to change the image resolution.  
     *
     *@res can be 32,64, and 128 only
     *
     *return SUCCESS if it was succesfully changed, or FAIL otherwise
     */
    command result_t setImgRes(uint8_t sizex, uint8_t sizey, uint8_t imgtype);

    /*command to change the RACoeff.  The running average is calculated by 
     *calculated the weighted average of the image that was just captured and
     *the background stored in memory.  This value can change the weight of the
     *background and the image captured.  
     *
     *@RAcoeff new coefficient.  Can be 1,2,3, or 4.  The running average is
     *calculated using the following formula:
     *(I>>RAcoeff) + (1<<RACoeff -1) * (B>>RACoeff)
     *
     *@return SUCCESS if it was succesfully changed, or FAIL otherwise
     */
    command void setRACoeff(uint8_t RAcoeff);

    /*command to change the skip parameter.  This value is used when estimating
     *the illumination of the image.  The bigger that this value is, the less
     *accurate that the estimation will be, and the faster it will be.  
     *
     *@skip default is 4, which means we look at one pixel, and skip 4.
     *
     *return SUCCESS if it was succesfully changed, or FAIL otherwise
     */
    command void setSkip(uint8_t Skip);

    /*command to change the illumination coefficient.  This value is multiplied
     *by the illumination to determine the threshold value of the foreground.
     *
     *@illcoeff new value, default is .25
     *
     *return SUCCESS if it was succesfully changed, or FAIL otherwise
     */
    command void setIlluminationCoeff(double illCoeff);

    /*command to change the range parameter.  This value is used
     *to determine how big of a neighborhood to look at when locating an
     *object in the background.  default value is 5, so we look at an 
     *11x11 neighborhood, from the point 5 up, 5 down, and to each side.
     *
     *@range default is 5
     *
     *return SUCunix rename directoryCESS if it was succesfully changed, or FAIL otherwise
     */
    command void setRange(uint8_t range);

    /*command to change the detectThresh parameter.  This value is the number of
     *pixels that have to be above the threshold to consider an object.
     *
     *@detectThresh default value is 20
     *
     *return SUCCESS if it was succesfully changed, or FAIL otherwise
     */

    command void setDetectThresh(uint8_t detectThresh);

    command bool getSegmentResult();
}

