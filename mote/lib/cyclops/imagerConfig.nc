////////////////////////////////////////////////////////////////////////////
// 
// CENS 
// Agilent
//
// Copyright (c) 2003 The Regents of the University of California.  All 
// rights reserved.
//
// Copyright (c) 2003 Agilent Corporation 
// rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions
// are met:
//
// - Redistributions of source code must retain the above copyright
//   notice, this list of conditions and the following disclaimer.
//
// - Neither the name of the University nor Agilent Corporation nor 
//   the names of its contributors may be used to endorse or promote 
//   products derived from this software without specific prior written 
//   permission.
//
// THIS SOFTWARE IS PROVIDED BY THE REGENTS , AGILENT CORPORATION AND 
// CONTRIBUTORS ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, 
// BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS 
// FOR A PARTICULAR  PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE REGENTS OR
// AGILENT CORPORATION OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, 
// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT 
// NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, 
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
// OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// Contents:  The high level interface to an image sensor.  The frame buffers
//            must be allocated through this interface also.
//           
//          
//
////////////////////////////////////////////////////////////////////////////
//
// $Header
//
//
// Authors : Henry Uyeno 
//
////////////////////////////////////////////////////////////////////////////

/**
 * @modified 6/27/2007
 * @author Jeongyeup Paek
 *
 * - seperate 'imager.nc' interface into two interfaces:
 *   imagerSnap and imagerConfig
 **/

#include "image.h"

interface imagerConfig
{
    command result_t setCaptureParameters(CYCLOPS_CapturePtr myCap);
    command result_t getPixelAverages();
    command result_t run(uint16_t rTime);

    event result_t imagerReady(result_t status);   // init is complete
    event result_t setCaptureParametersDone(result_t status);
    event result_t getPixelAveragesDone(color16_t sumVals, result_t status);
    event result_t runDone(result_t status);
}

