
/**
 * Helper functions related to 'cyclops_query.h'
 *
 * @modified 7/2/2007
 * @author Jeongyeup Paek (jpaek@enl.usc.edu)
 **/

#ifndef _CYCLOPS_QUERY_C_
#define _CYCLOPS_QUERY_C_

#ifdef BUILDING_PC_SIDE
#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <stddef.h>
#ifdef __CYGWIN__
#include <windows.h>
#include <io.h>
#else
#include <stdint.h>
#endif
#include <unistd.h>
#endif

#include "cyclops_query.h"

/*******************************************************************/

uint8_t is_neuron_valid(uint8_t nSignal) {
    switch (nSignal) {
        case NEURON_GET_IMAGE:
        case NEURON_SNAP_ONLY:
        case NEURON_DETECT_OBJECT:
        case NEURON_CONFIGURATION:
        case NEURON_ACTIVE_EYE:
        case NEURON_GET_RLE_IMAGE:
        case NEURON_GET_PACKBITS_IMAGE:
            return 1;
        default:
            break;
    }
    return 0;
}

int8_t get_bytes_per_pixel(uint8_t img_type) {
    int8_t bytesPerPixel;
    //Calculate the bytes per pixel based upon image type 
    switch (img_type) {
        case CYCLOPS_IMAGE_TYPE_RGB:    //Color image (3 bytes)
            bytesPerPixel = 3;
            break;
        case CYCLOPS_IMAGE_TYPE_YCbCr:  //Color image (2 bytes)
            bytesPerPixel = 2;
            break;
        case CYCLOPS_IMAGE_TYPE_Y:      //Black and white image
        case CYCLOPS_IMAGE_TYPE_RAW:    //Raw format, one byte per pixel
            bytesPerPixel = 1;
            break;
        default:                        //Error
            bytesPerPixel = -1;
    }
    return bytesPerPixel;
}

uint32_t get_image_size(uint16_t width, uint16_t height, uint8_t type) {
    int8_t bytesPerPixel = get_bytes_per_pixel(type);
    if (bytesPerPixel < 0)
        return 0;
    return ((uint32_t)(width * height) * bytesPerPixel);
}

/*******************************************************************/

void set_snap_query_defaults(snap_query_t *q) {
    q->type           = DEFAULT_IMAGE_TYPE;         // 16, Black & White
    q->size.x         = DEFAULT_IMAGE_SIZE_X;       // 128
    q->size.y         = DEFAULT_IMAGE_SIZE_Y;       // 128
    q->enableFlash    = DEFAULT_SNAP_ENABLE_FLASH;  // 1
}

void set_getImage_query_defaults(getImage_query_t *q) {
    q->imageAddr       = IMAGE_ADDR_TAKE_NEW;
    q->fragmentSize    = DEFAULT_FRAGMENT_SIZE;// 40 (limited...)
    q->reportRate      = 20;  // at least 20ms between fragments
    set_snap_query_defaults(&q->snapQ);
}

void set_capture_param_defaults(capture_param_t *cp) {
    cp->offset.x           = DEFAULT_CAPTURE_OFFSET_X;
    cp->offset.y           = DEFAULT_CAPTURE_OFFSET_Y;
    cp->inputSize.x        = DEFAULT_CAPTURE_INPUT_SIZE_X;
    cp->inputSize.y        = DEFAULT_CAPTURE_INPUT_SIZE_Y;
    cp->testMode           = DEFAULT_CAPTURE_TEST_MODE;
    cp->exposurePeriod     = DEFAULT_CAPTURE_EXPOSURE_PERIOD;
    cp->analogGain.red     = DEFAULT_CAPTURE_ANALOG_GAIN_RED;
    cp->analogGain.green   = DEFAULT_CAPTURE_ANALOG_GAIN_GREEN;
    cp->analogGain.blue    = DEFAULT_CAPTURE_ANALOG_GAIN_BLUE;
    cp->digitalGain.red    = DEFAULT_CAPTURE_DIGITAL_GAIN_RED;
    cp->digitalGain.green  = DEFAULT_CAPTURE_DIGITAL_GAIN_GREEN;
    cp->digitalGain.blue   = DEFAULT_CAPTURE_DIGITAL_GAIN_BLUE;
    cp->runTime            = DEFAULT_CAPTURE_RUN_TIME;
}

void set_activeEye_query_defaults(activeEye_query_t *q) {
    q->type                = ACTIVE_EYE_GET_PARAMS;
    set_capture_param_defaults(&q->cp);
}

void set_detect_query_defaults(detect_query_t *q) {
    q->type                = DETECT_RUN_NEW_IMG;    // 1
    q->use_segment         = 0;
    set_snap_query_defaults(&q->snapQ);
    
    q->detectParam.RACoeff      = DEFAULT_DETECT_RACOEFF;
    q->detectParam.skip         = DEFAULT_DETECT_SKIP;
    q->detectParam.illCoeff     = DEFAULT_DETECT_ILLCOEFF;
    q->detectParam.range        = DEFAULT_DETECT_RANGE;
    q->detectParam.detectThresh = DEFAULT_DETECT_THRESH;
    q->detectParam.pad          = 0;
}

void set_getRle_query_defaults(getRle_query_t *q) {
    q->imageAddr       = IMAGE_ADDR_TAKE_NEW;
    q->fragmentSize    = DEFAULT_FRAGMENT_SIZE;// 40 (limited...)
    q->reportRate      = 20;  // at least 20ms between fragments
    q->threshold       = DEFAULT_RLE_THRESH;
    set_snap_query_defaults(&q->snapQ);
}

void set_getPackBits_query_defaults(getPackBits_query_t *q) {
    q->imageAddr       = IMAGE_ADDR_TAKE_NEW;
    q->fragmentSize    = DEFAULT_FRAGMENT_SIZE;// 40 (limited...)
    q->reportRate      = 20;  // at least 20ms between fragments
    q->threshold       = DEFAULT_RLE_THRESH;
    set_snap_query_defaults(&q->snapQ);
}

void set_copy_query_defaults(copy_query_t *q) {
    q->fromImageAddr   = IMAGE_ADDR_TAKE_NEW;
    q->toImageAddr     = IMAGE_ADDR_SECOND;
    set_snap_query_defaults(&q->snapQ);
}

/*******************************************************************/

#ifdef BUILDING_PC_SIDE

void print_neuron_module_name(uint8_t nSignal) {
    if (nSignal == NEURON_GET_IMAGE)
        printf("MODULE       = (%d) GET_IMAGE\n", nSignal);
    else if (nSignal == NEURON_SNAP_ONLY)
        printf("MODULE       = (%d) SNAP_ONLY\n", nSignal);
    else if (nSignal == NEURON_ACTIVE_EYE)
        printf("MODULE       = (%d) ACTIVE_EYE\n", nSignal);
    else if (nSignal == NEURON_DETECT_OBJECT)
        printf("MODULE       = (%d) DETECT_OBJECT\n", nSignal);
    else if (nSignal == NEURON_GET_RLE_IMAGE)
        printf("MODULE       = (%d) GET_RLE_IMAGE\n", nSignal);
    else if (nSignal == NEURON_GET_PACKBITS_IMAGE)
        printf("MODULE       = (%d) GET_PACKBITS_IMAGE\n", nSignal);
    else
        printf("MODULE       = ? (%d)\n", nSignal);
}

void print_snap_query(snap_query_t *q) {
    printf("IMAGETYPE    = %d\n", q->type);
    printf("XSIZE        = %d\n", q->size.x);
    printf("YSIZE        = %d\n", q->size.y);
    printf("FLASH        = %d\n", q->enableFlash);
}

void print_getImage_query(getImage_query_t *q) {
    if (q->imageAddr == IMAGE_ADDR_TAKE_NEW)
        printf("IMAGE_ADDR   = TAKE_NEW_IMAGE\n");
    else
        printf("IMAGE_ADDR   = %d (abstract addr)\n", q->imageAddr);
    printf("REPORTRATE   = %d (%.1f pkts/sec)\n", q->reportRate, 1000.0/(double)q->reportRate);
    printf("FRAGMENTSIZE = %d bytes\n", q->fragmentSize);
    print_snap_query(&q->snapQ);
}

void print_capture_parameters(capture_param_t *cp) {
    printf("OFFSET.X          = %d\n", cp->offset.x);
    printf("OFFSET.Y          = %d\n", cp->offset.y);
    printf("INPUTSIZE.X       = %d\n", cp->inputSize.x);
    printf("INPUTSIZE.Y       = %d\n", cp->inputSize.y);
    printf("TESTMODE          = %d\n", cp->testMode);
    printf("EXPOSUREPERIOD    = %d\n", cp->exposurePeriod);
    printf("ANALOGGAIN.RED    = %d\n", cp->analogGain.red);
    printf("ANALOGGAIN.GREEN  = %d\n", cp->analogGain.green);
    printf("ANALOGGAIN.BLUE   = %d\n", cp->analogGain.blue);
    printf("DIGITALGAIN.RED   = %d\n", cp->digitalGain.red);
    printf("DIGITALGAIN.GREEN = %d\n", cp->digitalGain.green);
    printf("DIGITALGAIN.BLUE  = %d\n", cp->digitalGain.blue);
    printf("RUNTIME           = %d\n", cp->runTime);
}

void print_activeEye_query(activeEye_query_t* q) {
    printf("EYETYPE        = (%d) ", q->type);
    if (q->type == ACTIVE_EYE_SET_PARAMS) {
        printf("ACTIVE_EYE_SET_PARAMS\n");  // 0
        print_capture_parameters(&(q->cp));
    } else {
        printf("ACTIVE_EYE_GET_PARAMS\n");  // 1
    }
}

void print_detect_parameters(detect_param_t *dp) {
    printf("RA Coeff          = %d\n", dp->RACoeff);
    printf("SKIP              = %d\n", dp->skip);
    printf("ILL Coeff         = %d\n", dp->illCoeff);
    printf("RANGE             = %d\n", dp->range);
    printf("DETECT THRESH     = %d\n", dp->detectThresh);
}

void print_detect_query(detect_query_t *q) {
    printf("DETECTTYPE   = (%d) ", q->type);
    if (q->type == DETECT_RUN_NEW_IMG)
        printf("DETECT_RUN_NEW_IMG\n");
    else if (q->type == DETECT_RUN_OLD)
        printf("DETECT_RUN_OLD\n");
    else if (q->type == DETECT_RESET_BACKGROUND)
        printf("DETECT_RESET_BACKGROUND\n");
    else if (q->type == DETECT_SET_BACKGROUND)
        printf("DETECT_SET_BACKGROUND\n");
    else if (q->type == DETECT_SET_PARAM) {
        printf("DETECT_SET_PARAM\n");
        print_detect_parameters(&q->detectParam);
    }
    if ((q->type == DETECT_RUN_NEW_IMG) || 
        (q->type == DETECT_RUN_OLD) ||
        (q->type == DETECT_SET_PARAM)) {
        printf("USE_SEGMENT  = %d\n", q->use_segment);
        print_snap_query(&q->snapQ);
    }
}

void print_getRle_query(getRle_query_t *q) {
    if (q->imageAddr == IMAGE_ADDR_TAKE_NEW)
        printf("IMAGE_ADDR   = TAKE_NEW_IMAGE\n");
    else
        printf("IMAGE_ADDR   = %d\n", q->imageAddr);
    printf("REPORTRATE   = %d (%.1f pkts/sec)\n", q->reportRate, 1000.0/(double)q->reportRate);
    printf("FRAGMENTSIZE = %d bytes\n", q->fragmentSize);
    if (q->threshold == 0)
        printf("RLE THRESH   = LOSSLESS\n");
    else
        printf("RLE THRESH   = %d\n", q->threshold);
    print_snap_query(&q->snapQ);
}

void print_getPackBits_query(getPackBits_query_t *q) {
    if (q->imageAddr == IMAGE_ADDR_TAKE_NEW)
        printf("IMAGE_ADDR   = TAKE_NEW_IMAGE\n");
    else
        printf("IMAGE_ADDR   = %d\n", q->imageAddr);
    printf("REPORTRATE   = %d (%.1f pkts/sec)\n", q->reportRate, 1000.0/(double)q->reportRate);
    printf("FRAGMENTSIZE = %d bytes\n", q->fragmentSize);
    printf("RLE THRESH   = %d\n", q->threshold);
    print_snap_query(&q->snapQ);
}

void print_copy_query(copy_query_t *q) {
    if (q->fromImageAddr == IMAGE_ADDR_TAKE_NEW)
        printf("FROM: IMAGE_ADDR   = TAKE_NEW_IMAGE\n");
    else
        printf("FROM: IMAGE_ADDR   = %d\n", q->fromImageAddr);
    if (q->toImageAddr == IMAGE_ADDR_TAKE_NEW)
        printf(" TO : IMAGE_ADDR   = TAKE_NEW_IMAGE\n");
    else
        printf(" TO : IMAGE_ADDR   = %d\n", q->toImageAddr);
    print_snap_query(&q->snapQ);
}

#endif

#endif

