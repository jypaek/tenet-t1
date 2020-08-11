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
 * History: created 08/10/05
 *
 * This configuration provides the wiring necessary to put combine multiple
 * modules on the cyclops side. This allows neuron (the software bus) to work
 * properly.
 */

/**
 * @modified Feb/24/2008
 * @author Jeongyeup Paek (jpaek@enl.usc.edu)
 *
 * - Add new neuron modules (e.g. GetRleN, GetPackBitsN)
 * - Image-fragment read-timer is within each Get* module
 * - Minor code clean-up
 *   - rename neuron modules
 *   - merge *N.nc and *M.nc files into one *N.nc file (e.g. SnapN.nc)
 *   - do all wirings here
 *   - hash include header files
 **/

#include "cyclops_query.h"

configuration CyclopsDevice {}
implementation {

    components Main
            , cyclopsNeuron
            , activeEye as realImager
            , imagerM
            , TimerC
            , LedsC
            ;

    Main.StdControl -> cyclopsNeuron.neuronControl;
    Main.StdControl -> TimerC;
    
    imagerM.imager -> realImager;
    imagerM.ImagerControl -> realImager;


/*********** Nueron Module Wirings *************/

    components ConfigurationN;
    Main.StdControl -> ConfigurationN;
    ConfigurationN.neuronC -> cyclopsNeuron.neuronC[NEURON_CONFIGURATION];
    ConfigurationN.Leds -> LedsC;

    components ActiveEyeN;
    Main.StdControl -> ActiveEyeN;
    ActiveEyeN.ImagerControl -> imagerM;
    ActiveEyeN.imagerConfig -> imagerM;
    ActiveEyeN.neuronC -> cyclopsNeuron.neuronC[NEURON_ACTIVE_EYE];
    ActiveEyeN.CameraState -> imagerM.CameraState[NEURON_ACTIVE_EYE];
    ActiveEyeN.Leds -> LedsC;

    components SnapN;
    Main.StdControl -> SnapN;
    SnapN.imagerSnap -> imagerM;
    SnapN.neuronC -> cyclopsNeuron.neuronC[NEURON_SNAP_ONLY];
    SnapN.CameraState -> imagerM.CameraState[NEURON_SNAP_ONLY];
    SnapN.Leds -> LedsC;

    components GetImageN;
    Main.StdControl -> GetImageN;
    GetImageN.imagerSnap -> imagerM;
    GetImageN.neuronC -> cyclopsNeuron.neuronC[NEURON_GET_IMAGE];
    GetImageN.CameraState -> imagerM.CameraState[NEURON_GET_IMAGE];
    GetImageN.Timer -> TimerC.Timer[unique("Timer")];
    GetImageN.Leds -> LedsC;
    
    components DetectN, ObjectDetectionC;
    Main.StdControl -> DetectN;
    DetectN.imagerSnap -> imagerM;
    DetectN.neuronC -> cyclopsNeuron.neuronC[NEURON_DETECT_OBJECT];
    DetectN.CameraState -> imagerM.CameraState[NEURON_DETECT_OBJECT];
    DetectN.Leds -> LedsC;
    DetectN.ObjectDetection -> ObjectDetectionC;

    components GetRleN;
    Main.StdControl -> GetRleN;
    GetRleN.imagerSnap -> imagerM;
    GetRleN.neuronC -> cyclopsNeuron.neuronC[NEURON_GET_RLE_IMAGE];
    GetRleN.CameraState -> imagerM.CameraState[NEURON_GET_RLE_IMAGE];
    GetRleN.Timer -> TimerC.Timer[unique("Timer")];
    GetRleN.Leds -> LedsC;

    components GetPackBitsN;
    Main.StdControl -> GetPackBitsN;
    GetPackBitsN.imagerSnap -> imagerM;
    GetPackBitsN.neuronC -> cyclopsNeuron.neuronC[NEURON_GET_PACKBITS_IMAGE];
    GetPackBitsN.CameraState -> imagerM.CameraState[NEURON_GET_PACKBITS_IMAGE];
    GetPackBitsN.Timer -> TimerC.Timer[unique("Timer")];
    GetPackBitsN.Leds -> LedsC;
}

