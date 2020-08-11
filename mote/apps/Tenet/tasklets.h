
/**
 * List of INCLUDE Tasklet definitions
 *
 * Uncommenting/commenting each 'define' line below 
 * includes/excludes each corresponding tasklet 
 **/
#define INCLUDE_COUNT
#define INCLUDE_REBOOT
#define INCLUDE_ISSUE
#define INCLUDE_ACTUATE
#define INCLUDE_GET
#define INCLUDE_COMPARISON
#define INCLUDE_LOGICAL
#define INCLUDE_ARITH
#define INCLUDE_STATS
#define INCLUDE_DELETEATTRIBUTEIF
#define INCLUDE_DELETEACTIVETASKIF
#define INCLUDE_DELETETASKIF
#define INCLUDE_PACK
#define INCLUDE_ATTRIBUTE

#define INCLUDE_SAMPLE
#define INCLUDE_VOLTAGE


/**
 * Below are either
 * - not included as default due to code size limit, or
 * - platform dependant tasklets
 **/

//#define INCLUDE_BIT
//#define INCLUDE_STORAGE
//#define INCLUDE_ONSETDETECTOR
//#define INCLUDE_MEMORYOP
//#define INCLUDE_FIRLPFILTER
//#define INCLUDE_SENDSTR
//#define INCLUDE_SENDRCRT

//#define INCLUDE_SAMPLERSSI

#ifdef PLATFORM_TELOSB
    //#define INCLUDE_USERBUTTON
    //#define INCLUDE_FASTSAMPLE
#endif

#if defined(PLATFORM_MICAZ) || defined(PLATFORM_MICA2)
    #define INCLUDE_SENDSTR
    #define INCLUDE_SENDRCRT
#endif

// For EmStar emulation
#if defined(EMSTAR_NO_KERNEL)
    #undef INCLUDE_SAMPLE
    #undef INCLUDE_VOLTAGE
#endif

// For CentRoute
#ifdef USE_CENTROUTE
    #undef INCLUDE_SAMPLE
    #undef INCLUDE_VOLTAGE
    #undef INCLUDE_STATS
    #undef INCLUDE_ATTRIBUTE
#endif

// For IMAGE tasklet, must add a line "CYCLOPS_HOST=1" in the Makefile
#ifdef CYCLOPS_HOST
    #if defined(PLATFORM_MICAZ) || defined(PLATFORM_MICA2)
        #define INCLUDE_IMAGE
        #undef INCLUDE_SENDSTR
        #undef INCLUDE_SAMPLE // Cannot use micasb with cyclops.
        #undef INCLUDE_BIT
        #undef INCLUDE_STATS
        #undef INCLUDE_PACK
        #undef INCLUDE_ATTRIBUTE
    #else
        #ERROR_CYCLOPS_ONLY_ON_MICA2_OR_MICAZ
    #endif
#endif
    
// For SampleMda400 tasklet, must add a line "MDA400_HOST=1" in the Makefile
#ifdef MDA400_HOST
    #if defined(PLATFORM_MICAZ) || defined(PLATFORM_MICA2)
        #define INCLUDE_SAMPLEMDA400
        #define INCLUDE_ONSETDETECTOR
        #undef INCLUDE_SAMPLE // Cannot use micasb with mda400
        #undef INCLUDE_BIT
        #undef INCLUDE_STATS
        #undef INCLUDE_PACK
        #undef INCLUDE_ATTRIBUTE
    #else
        #ERROR_MDA400_ONLY_ON_MICA2_OR_MICAZ
    #endif
#endif

#ifdef ONE_HOP_TASKING
    #undef INCLUDE_SENDSTR
    #undef INCLUDE_SENDRCRT
#endif

