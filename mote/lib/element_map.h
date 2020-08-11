
#ifndef ELEMENT_MAP_H
#define ELEMENT_MAP_H

/**
 * Tenet Tasklet IDs
 *
 * - Each tasklet must have a unique ID.
 * - Tasklet is short for 'task elements'
 *
 **/

/* Tasklet IDs */

typedef enum {
    /* this does not exist */
    ELEMENT_INSTALL        = 1,

    /* List of current default tasklets */
    ELEMENT_REBOOT             = 2,
    ELEMENT_COUNT              = 3,
    ELEMENT_SENDPKT            = 4,
    ELEMENT_ISSUE              = 5,
    ELEMENT_GET                = 6,
    ELEMENT_ACTUATE            = 7,
    ELEMENT_STORAGE            = 8,
    ELEMENT_COMPARISON         = 9,
    ELEMENT_STATS              = 10,
    ELEMENT_ARITH              = 11,
    ELEMENT_LOGICAL            = 12,
    ELEMENT_BIT                = 13,
    ELEMENT_DELETEATTRIBUTEIF  = 14,
    ELEMENT_DELETEACTIVETASKIF = 15,
    ELEMENT_DELETETASKIF       = 16,
    ELEMENT_PACK               = 17,
    ELEMENT_ATTRIBUTE          = 18,

    ELEMENT_SAMPLE             = 21,
    ELEMENT_VOLTAGE            = 22,

    /* Non-default tasklets (under devel?) */
    ELEMENT_SENDSTR            = 31,    // reliable stream transport
    ELEMENT_IMAGE              = 32,    // CYCLOPS
    ELEMENT_USERBUTTON         = 33,    // telosb only
    ELEMENT_SAMPLERSSI         = 34,    // PEG
    ELEMENT_MEMORYOP           = 35,

    ELEMENT_SAMPLEMDA400       = 37,    // MDA400, micaz only
    ELEMENT_ONSETDETECTOR      = 38,    // filter for MDA400
    ELEMENT_FASTSAMPLE         = 39,    // Telosb only, DMA accessed ADC

    ELEMENT_SENDRCRT           = 40,    // RCRT
    ELEMENT_FIRLPFILTER        = 41,    // FIR low pass filter
    ELEMENT_SAMPLEMDA300       = 42,    // MDA300, mica2/micaz
    ELEMENT_RLE                = 43,    // Run Length Encoding
    ELEMENT_PACKBITS           = 44,    // PackBits Run Length Encoding
    ELEMENT_VECTOR             = 45,    // Dummy vector
} element_types_t;

#endif

