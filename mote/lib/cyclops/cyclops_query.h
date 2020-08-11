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
 * This file includes the queries that are to be resolved by modules in the cyclops, 
 * such as Active Eye, Snap, etc.
 */

/**
 * Modified a lot
 *
 * @author Jeongyeup Paek (jpaek@enl.usc.edu)
 * @modified Feb/17/2008
 **/
 
#ifndef CYCLOPS_QUERY_H
#define CYCLOPS_QUERY_H

#include <image.h>


/*****************************************************************************/

//Enumeration of modules used with neuron.    
enum {
    NEURON_GET_IMAGE          = 1,
    NEURON_SNAP_ONLY          = 2,
    NEURON_DETECT_OBJECT      = 3,
    
    NEURON_CONFIGURATION      = 4,
    NEURON_ACTIVE_EYE         = 5,

    NEURON_GET_RLE_IMAGE      = 6,
    NEURON_GET_PACKBITS_IMAGE = 7,
    
    NEURON_COPY_IMAGE         = 8,
}; // neuron module type (nSignal, nModule)



/*****************************************************************************/
/****************** Query Msg ********************
 * This message comes from the master(PC,stargate) 
 * to the host mote (connected to cyclops).
 * Host mote reads it, and passes it to cyclops
 *************************************************/
typedef struct cyclops_query {
    uint8_t nSignal;        // specification of the neuronSignal to use (snap, activeEye, ...)
    uint8_t length;         // The length of the data in the message
    uint8_t data[0];        // Pointer to the query message for each neuron module (snap_query_t, etc)
} __attribute__((packed)) cyclops_query_t;



/*****************************************************************************/
/****************** Slave Query ********************
 * - is something that is passed directly to the cyclops without the host node 
 *   opening it nor even know what it contains.
 * - is embedded inside 'cyclops_query->data'.
 * - is a query given to a particular neuron module.
 ***************************************************/

/* enumaration of values used in slave queries */
enum {
    ACTIVE_EYE_GET_PARAMS     = 0,
    ACTIVE_EYE_SET_PARAMS     = 1, 

    DEFAULT_SNAP_ENABLE_FLASH = 1,
    DEFAULT_FRAGMENT_SIZE     = 40,
    DEFAULT_RLE_THRESH        = 20,

    CONFIG_REBOOT = 1,

    IMAGE_ADDR_TAKE_NEW = 0,
    IMAGE_ADDR_FIRST    = 1,
    IMAGE_ADDR_SECOND   = 2,
    IMAGE_ADDR_THIRD    = 3,
};


/**
 * Below are values for "struct CYCLOPS_Capture_Parameters",
 *   - except that 'exposurePeriod' field is in uint16_t type instead of float.
 **/
typedef struct capture_param {
    wpos_t    offset;             // Offset from center (nominally [0,0])
    wsize_t   inputSize;          // Input window (<= [352,288])
    uint16_t  exposurePeriod;     // used by AE procedure, (0 = auto -or- exposure in milliseconds)
                                  // -> this gets divided by 1000.0 within cyclops to become (float)seconds.
    uint8_t   testMode;           // normal or test mode capture
    color8_t  analogGain;         // used by AE procedure, (0 = auto -or- analog gain: (1 + b[6]) * (1 + 0.15 * b[5:0]/(1 + 2 * b[7])) )
    color16_t digitalGain;        // used by AWB procedure,(0 = auto -or- digital gain * 128)
    uint16_t  runTime;            // equilibration time before capture
} __attribute__((packed)) capture_param_t;

//****** ActiveEye Query *******//
typedef struct activeEye_query {
    uint8_t   type;               // type of query (SET, GET)
    uint8_t   pad;                // not used (for 16-bit byte-alignment)
    capture_param_t cp;
} __attribute__((packed)) activeEye_query_t;



typedef struct qsize {
    uint8_t x;
    uint8_t y;
} __attribute__((packed)) qsize_t;

//********** SNAP Query ***********//
typedef struct snap_query_t {
    uint8_t enableFlash;            // boolean whether to use flash or not (FLASH = IR LEDS)
    uint8_t type;                   // monochrome, RGB...
    qsize_t size;                   // image width in pixels
} __attribute__((packed)) snap_query_t;



//********** Configuration Query ***********//
typedef struct config_query_t {
    uint8_t type;
    uint8_t pad;
} __attribute__((packed)) config_query_t;



//********** GET_IMAGE Query ***********//
typedef struct getImage_query_t {
    uint8_t imageAddr;
    uint8_t fragmentSize;           // set the data size of a frament for response data.
    uint16_t reportRate;
    snap_query_t snapQ;
} __attribute__((packed)) getImage_query_t;


//********** GET_RLE Query ***********//
typedef struct getRle_query_t {
    uint8_t imageAddr;
    uint8_t fragmentSize;           // set the data size of a frament for response data.
    uint16_t reportRate;
    uint8_t threshold;
    uint8_t pad;
    snap_query_t snapQ;
} __attribute__((packed)) getRle_query_t;


//********** GET_PACKBITS Query ***********//
typedef getRle_query_t getPackBits_query_t;



//********** DETECT Query ***********//
enum {
    DETECT_RUN_NEW_IMG = 1,     // take new image, and run od
    DETECT_RUN_OLD = 2,         // run detection on cached image
    DETECT_RESET_BACKGROUND = 3,
    DETECT_SET_BACKGROUND = 4,
    DETECT_SET_PARAM = 5,

    /* NOTE: currently, we only support black&white image for object detection.
             also, for now, we'll assume that x & y size is same. */
    DEFAULT_DETECT_IMGRES = 128,
    DEFAULT_DETECT_RACOEFF = 3,
    DEFAULT_DETECT_ILLCOEFF = 45,  // will be divided by 100 to make 0.45
    DEFAULT_DETECT_SKIP = 4,       //how many pixels and rows we will be skipping
    DEFAULT_DETECT_RANGE = 5,      //riange to look for values over the threshold
    DEFAULT_DETECT_THRESH = 40,
};

typedef struct detect_param_t {
    uint8_t RACoeff;             //Running Average Coefficient
    uint8_t skip;                //Number of pixels to skip when detecting object
    uint8_t illCoeff;            //Coefficient used when analyzing illumination
    uint8_t range;               //The range to look around the detected object
    uint8_t detectThresh;        //The threshold for forground-background for object to be detected.
    uint8_t pad;                // for byte-alignment
} __attribute__((packed)) detect_param_t;

//********** DETECT Query ***********//
typedef struct detect_query_t {
    uint8_t type;               // 
    uint8_t use_segment;        // Whether to use segmentation
    snap_query_t snapQ;         // parameters for taking an image
    detect_param_t detectParam; // parameters for detection algorithm
} __attribute__((packed)) detect_query_t;



//********** Copy Query ***********//
typedef struct copy_query_t {
    uint8_t fromImageAddr;      // 0, 1, 2, 3
    uint8_t toImageAddr;        // 1, 2, 3     && Not(fromImageAddr)
    snap_query_t snapQ;         // to know the size of the image
} __attribute__((packed)) copy_query_t;



/*****************************************************************************/
/***************** Response Msg *******************
 * This message comes from the cyclops to the host
 * mote (connected to cyclops). Host mote may read
 * and process it, or pass it directly to the master
 *************************************************/
typedef struct cyclops_response {
    uint8_t more_left;
    uint8_t type;
    int8_t data[0];
} __attribute__((packed)) cyclops_response_t;


/*****************************************************************************/
/************* Cyclops Response Type ***************/
enum {
    /**
     * - FAIL/SUCCESS tells whether the query has been successfully issued;
     *   it doesn't mean that the result of the processing is success or fail.
     * - FAIL means that the query cannot be executed due to some reason.
     *   (e.g. a query might fail to execute due to wrong parameters.)
     * - SUCCESS is for neuron modules that do not have return data.
     *   it does not imply anything about the result of that execution.
     **/
    CYCLOPS_RESPONSE_FAIL           = 0x00,
    CYCLOPS_RESPONSE_SUCCESS        = 0x01,

    /**
     * - this response type means that 'result_response_t' is the data
     *   in 'cyclops_response->data'.
     * - it's purpose is to serve as generic 16-bit TRUE/FALSE response
     **/
    CYCLOPS_RESPONSE_RESULT         = 0x02,

    CYCLOPS_RESPONSE_CAPTURE_PARAM  = 0x03,

    CYCLOPS_RESPONSE_IMAGE          = 0x07,
    CYCLOPS_RESPONSE_RLE_IMAGE      = 0x08,
    CYCLOPS_RESPONSE_PACKBITS_IMAGE = 0x09,
};


// Definition of message format for simple execution result
typedef struct result_response {
    uint16_t result;
} __attribute__((packed)) result_response_t;


// Definition of message format for raw image data
typedef struct image_response {
    uint16_t fragNum;            //The number of the current fragment
    uint16_t fragTotal;
    uint8_t pad;
    uint8_t dataLength;
    int8_t data[0];
} __attribute__((packed)) image_response_t;


// Definition of message format for run-length encoded image data
typedef struct rle_image_response {
    uint16_t seqNum;
    uint8_t rleType;
    uint8_t dataLength;
    int8_t data[0];
} __attribute__((packed)) rle_image_response_t;

typedef rle_image_response_t packbits_image_response_t;


/*****************************************************************************/

#ifdef BUILDING_PC_SIDE
uint8_t is_neuron_valid(uint8_t nSignal);
int8_t get_bytes_per_pixel(uint8_t img_type);
uint32_t get_image_size(uint16_t x, uint16_t y, uint8_t img_type);

void set_snap_query_defaults(snap_query_t *q);
void set_getImage_query_defaults(getImage_query_t *q);
void set_activeEye_query_defaults(activeEye_query_t *q);
void set_detect_query_defaults(detect_query_t *q);
void set_getRle_query_defaults(getRle_query_t *q);
void set_getPackBits_query_defaults(getPackBits_query_t *q);
void set_copy_query_defaults(copy_query_t *q);

void print_neuron_module_name(uint8_t nSignal);
void print_snap_query(snap_query_t *q);
void print_getImage_query(getImage_query_t *q);
void print_capture_parameters(capture_param_t *cp);
void print_activeEye_query(activeEye_query_t* q);
void print_detect_parameters(detect_param_t *dp);
void print_detect_query(detect_query_t *q);
void print_getRle_query(getRle_query_t *q);
void print_getPackBits_query(getPackBits_query_t *q);
void print_copy_query(copy_query_t *q);
#endif


#endif

