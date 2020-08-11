
#ifndef IMAGE_H
#define IMAGE_H

#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <stddef.h>
#ifdef __CYGWIN__
#include <windows.h>
#include <io.h>
#else
#include <stdint.h>
#endif

/* The ADCM-1700 sensor array size is 352 x 288 pixels. The capture parameters
 * may be used select the entire array, or a sub-region. However there are
 * several restrictions:
 * 1) The sizer is deactivated in RAW mode. Consequently the output size
 *    will equal the input size.
 * 2) The minimum output size is 24 x 24 pixels.
 * 3) The granualarity of the input window specification is 4 pixels. 
 */

// 32 bit int representing byte offset into an abstracted 32 bit memory space
typedef uint32_t cyclopsMemPtr_t;

typedef struct wpos
{
    int16_t x;
    int16_t y;
} __attribute__((packed)) wpos_t;

typedef struct wsize
{
    uint16_t x;
    uint16_t y;
} __attribute__((packed)) wsize_t;

typedef struct color8
{
    uint8_t red;
    uint8_t green;
    uint8_t blue;
} color8_t;

typedef struct color16
{
    uint16_t red;
    uint16_t green;
    uint16_t blue;
} color16_t;

typedef struct CYCLOPS_Capture_Parameters
{
    wpos_t    offset;             // Offset from center (nominally [0,0])
    wsize_t   inputSize;          // Input window (<= [352,288])
    uint8_t   testMode;           // normal or test mode capture
    float     exposurePeriod;     // used by AE procedure, (0 = auto -or-  exposure in seconds)
    color8_t  analogGain;         // used by AE procedure, (0 = auto -or- analog gain: (1 + b[6]) * (1 + 0.15 * b[5:0]/(1 + 2 * b[7])) )
    color16_t digitalGain;        // used by AWB procedure,(0 = auto -or- digital gain * 128)
    uint16_t  runTime;            // equilibration time before capture
} CYCLOPS_Capture_Parameters;

typedef struct CYCLOPS_Capture_Parameters * CYCLOPS_CapturePtr;

typedef struct CYCLOPS_Image
{
    uint8_t  type;               // monochrome, RGB...
    wsize_t  size;               // image width in pixels
    uint8_t nFrames;             // number of sequential frames
    //uint8_t *imageData;          // pointer to image data , later will change to handlers that is pointer to pointer when direct mem access is complete
    //cyclopsMemPtr_t imageData;          // pointer to image data , later will change to handlers that is pointer to pointer when direct mem access is complete
    uint16_t imageData;          // pointer to image data , later will change to handlers that is pointer to pointer when direct mem access is complete
} CYCLOPS_Image;

typedef  CYCLOPS_Image * CYCLOPS_ImagePtr;

// *** image types: ***
enum {
    CYCLOPS_IMAGE_TYPE_UNSET  = 0,       // to force initialization ...
    CYCLOPS_IMAGE_TYPE_Y      = 0x10,     // Gray Scale Intensity Image (1 byte per pixel)
    CYCLOPS_IMAGE_TYPE_RGB    = 0x11,     // RGB in the eight bit format (3 bytes per pixel)
    CYCLOPS_IMAGE_TYPE_YCbCr  = 0x12,     // YCbCr fomat (2 bytes per pixel)
    // There be dragons!!! The ADCM-1700 image processing pipeline (including the sizer) is bypassed 
    // in RAW mode. The output size will equal
    // the input size, regardless of the window settings!!!
    CYCLOPS_IMAGE_TYPE_RAW    = 0x13      // RAW format (1 byte per pixel)
};

// *** capture test modes: ***
enum {
    CYCLOPS_TEST_MODE_UNSET,   // force initialization ...
    CYCLOPS_TEST_MODE_NONE,    // normal image capture
    CYCLOPS_TEST_MODE_SOC,     // sum of coordinates test mode
    CYCLOPS_TEST_MODE_8PB,     // 8-pixel wide border test mode
    CYCLOPS_TEST_MODE_CKB,     // checkerboard test mode
    CYCLOPS_TEST_MODE_BAR      // color bar test mode
};


// *** module control ***
enum {
    CYCLOPS_STOP,
    CYCLOPS_RUN
};

//enum
//    {
//        CYCLOPS_DEPTH_1U,
//        CYCLOPS_DEPTH_8U, 
//        CYCLOPS_DEPTH_8S//set_CPLD_run_mode(CPLD_OPCODE_RUN_CAMERA,0x11);
//    };
//

/* Default values for Snap_Parameters */
enum {
    DEFAULT_IMAGE_TYPE           = CYCLOPS_IMAGE_TYPE_Y,    // 16
    DEFAULT_IMAGE_SIZE_X         = 128,
    DEFAULT_IMAGE_SIZE_Y         = 128,
    DEFAULT_IMAGE_NFRAMES        = 1,
    
    // max. size limited by 64KB memory.
    // divide by 3 for color image
    MAX_IMAGE_SIZE_X             = 240,
    MAX_IMAGE_SIZE_Y             = 240,
};

/* Default values for Capture_Parameters */
enum {
    DEFAULT_CAPTURE_OFFSET_X            = 0,
    DEFAULT_CAPTURE_OFFSET_Y            = 0,
    DEFAULT_CAPTURE_INPUT_SIZE_X        = 0x120,
    DEFAULT_CAPTURE_INPUT_SIZE_Y        = 0x120,
    DEFAULT_CAPTURE_TEST_MODE           = CYCLOPS_TEST_MODE_NONE, // *** DEBUG ***
    DEFAULT_CAPTURE_EXPOSURE_PERIOD     = 0,
    DEFAULT_CAPTURE_ANALOG_GAIN_RED     = 0x00,
    DEFAULT_CAPTURE_ANALOG_GAIN_GREEN   = 0x00,
    DEFAULT_CAPTURE_ANALOG_GAIN_BLUE    = 0x00,
    DEFAULT_CAPTURE_DIGITAL_GAIN_RED    = 0x0000,   // awb
    DEFAULT_CAPTURE_DIGITAL_GAIN_GREEN  = 0x0000,  
    DEFAULT_CAPTURE_DIGITAL_GAIN_BLUE   = 0x0000,  
    DEFAULT_CAPTURE_RUN_TIME            = 500, // *** debug ***
};

enum {
    IMAGE_PTR_NEW    = 0x0000,
    IMAGE_PTR_FIRST  = 0x1100,
    IMAGE_PTR_SECOND = 0x5100,
    IMAGE_PTR_THIRD  = 0x9100,
};

#endif // IMAGE_H

