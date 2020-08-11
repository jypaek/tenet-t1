/*
* "Copyright (c) 2006~2008 University of Southern California.
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
*/

/**
 * Tenet Tasklet data structures
 *
 * Each tasklet has a structure that defines the list of
 * parameters required to instantiate and run that tasklet. This
 * file also includes other constants and definitions used by
 * various tasklets.
 * 
 * @author Ben Greenstein
 * @author Jeongyeup Paek
 **/


#ifndef _TENET_TASK_H_
#define _TENET_TASK_H_

#if defined(BUILDING_PC_SIDE)
#include "nx.h"
#ifndef __cplusplus
#ifndef bool
typedef unsigned char bool;
#endif
#endif
#endif

enum {
    UNKNOWN_TYPE = 0,
    NULL_TYPE = 0, // TODO: make this a reserved type other than 0
    UNKNOWN_ID = 0,
    INSTALL_TASK = 1,
    TYPE_LEN_SZ = 4,
};
//#define TYPE_LEN_SZ (offsetof(attr_t,value))

typedef enum {
    LIST_REMOVE,
    LIST_BREAK,
    LIST_CONT
} list_action_t;

typedef enum {
    SCHED_STOP,
    SCHED_NEXT,
    SCHED_TERMINATE, /* terminate that active task */
    SCHED_TKILL,     /* terminate/kill the task from which that active task belong to */
} sched_action_t;

typedef list_action_t (*operator_fn_t)(void *item, void *meta);

/* all tag_t's should be unique */
typedef uint16_t tag_t;
typedef nx_uint16_t nxtag_t;

typedef struct {
    tag_t type;
    uint16_t length;
    uint8_t value[0];
} __attribute__((packed)) attr_t;

typedef struct element_s element_t;

typedef struct task_s {
    uint32_t id;
    uint8_t num_elements;
    uint8_t num_atasks;
    uint8_t block_cloning;
    uint8_t sendbusy;
    element_t **elements;
} task_t;

/* data_attr_t is an element in the 'data_t', linked-list of attributes */
typedef struct {
    tag_t type;
    uint16_t length;
    void *value;
} data_attr_t;

/* 'data_t' is a linked-list of attributes associated with an active task */
typedef struct data_s {
    data_attr_t attr;
    uint16_t flags;
    struct data_s *next;
} data_t;

typedef struct active_task_s {
    uint8_t element_index;
    uint8_t pad;
    data_t *data;
    task_t *t;
} active_task_t;

typedef sched_action_t (*run_t)(active_task_t *active_task, element_t *e);
typedef void (*suicide_t)(task_t *t, element_t *e);

struct element_s {
    uint16_t id;
    run_t run;
    suicide_t suicide;
};


typedef struct list_item_s {
    void *data;
    struct list_item_s *next;
} list_item_t;

typedef struct list_s {
    struct list_item_s *head;
    struct list_item_s *tail;
} list_t;


typedef struct link_hdr_s {
    uint16_t tid;
    uint16_t src;
    uint8_t data[0];
} __attribute__((packed)) link_hdr_t;

typedef enum {
    UNKNOWN = 0,
    TASK_INSTALL = 1,
    //MODIFY = 2,
    TASK_DELETE = 3,
    //RERUN = 4,
    DATA = 5  //originated from mote
} tenet_msg_type_t;

typedef struct task_msg_s {
    uint8_t type; // tenet_msg_type_t
    uint8_t numElements;
    uint8_t data[0];
} __attribute__((packed)) task_msg_t;


typedef enum {
    ERROR_ATTRIBUTE = 0x01
} reserved_attr_type_t;


typedef enum {
    ARGTYPE_CONSTANT = 0,
    ARGTYPE_ATTRIBUTE = 1
} argtype_t;

typedef enum {
    GET_ROUTING_PARENT = 1,
    GET_GLOBAL_TIME = 2,
    GET_LOCAL_TIME = 3,
    GET_MEMORY_STATS = 4, 
    GET_NUM_TASKS = 5,
    GET_NUM_ACTIVE_TASKS = 6,
    GET_ROUTING_CHILDREN = 7,
    GET_NEIGHBORS = 8,
    GET_LEDS = 9,
    GET_RF_POWER = 10,
    GET_RF_CHANNEL = 11,
    GET_IS_TIMESYNC = 12,
    GET_TOS_LOCAL_ADDRESS = 13,
    GET_GLOBAL_TIME_MS = 14,
    GET_LOCAL_TIME_MS = 15,
    GET_ROUTING_PARENT_LINKQUALITY = 16,
    GET_PLATFORM = 17,
    GET_CLOCK_FREQ = 18,
    GET_ROUTING_MASTER = 19,
    GET_ROUTING_HOPCOUNT = 20,
    GET_ROUTING_PARENT_RSSI = 21,
} get_value_t;

typedef enum {
    TELOSB   = 1,
    MICAZ    = 2,
    IMOTE2   = 3,
    MICA2    = 4,
    MICA2DOT = 5,
} platform_value_t;

typedef enum {
/* Arith Operators */ 
    A_ADD  = 1,
    A_SUB  = 2,
    A_MULT = 3,
    A_DIV  = 4,
    A_DIFF = 5,
    A_MOD  = 6,
    A_POW  = 7,
/* Comparison Operators */ 
    LT  = 11,
    GT  = 12,
    EQ  = 13,
    LEQ = 14,
    GEQ = 15,
    NEQ = 16,
/* Counting Comparison Operators */ 
//All COUNT_* need to have bigger number than others due to Comparison element implementation
    COUNT_LT  = 21,
    COUNT_GT  = 22,
    COUNT_EQ  = 23,
    COUNT_LEQ = 24,
    COUNT_GEQ = 25,
    COUNT_NEQ = 26,
} arith_comparison_op_t;
 
typedef enum {
    AND  = 1,
    OR   = 2,
    NOT  = 3,
    XOR  = 4,
    NAND = 5,
    NOR  = 6,
    SHL  = 7, //shift left <<
    SHR  = 8, //shift right >>
} bit_op_t;

typedef enum {
    LAND = AND,
    LOR  = OR,
    LNOT = NOT,
} logical_op_t;

typedef enum {
    SUMM = 1,   // name conflict... change later
    MIN = 2,
    MAX = 3,
    AVG = 4,
    STD = 5,
    CNT = 6,
    MEANDEV = 7,
} stat_op_t;

typedef enum {
    EXIST     = 1,
    NOT_EXIST = 2,
    LENGTH    = 3,
} attribute_op_t;

typedef enum {
    ERR_INSTALL_FAILURE = 1,
    ERR_CONSTRUCT_FAILURE,
    ERR_INVALID_TASK_DESCRIPTION,
    ERR_INVALID_TASK_PARAMETER,
    ERR_MALLOC_FAILURE,
    ERR_INVALID_ATTRIBUTE,
    ERR_INVALID_OPERATION,
    ERR_NULL_TASK,
    ERR_NULL_ACTIVE_TASK,
    ERR_RESOURCE_BUSY,
    ERR_RUNTIME_FAILURE,
    ERR_NOT_SUPPORTED,
    ERR_MALFORMED_ACTIVE_TASK,
    ERR_DATA_REMOVE,
    ERR_NO_ROUTE,
    ERR_QUEUE_OVERFLOW,
    ERR_SENSOR_ERROR,
    ERR_TIMESYNC_FAILURE,
} error_code_t;

typedef enum {
    ACTUATE_LEDS = 0,
    ACTUATE_RADIO = 1,
    ACTUATE_SOUNDER = 2,
    ACTUATE_LEDS_TOGGLE = 3,
    ACTUATE_ROUTE_RESET = 11,
    ACTUATE_ROUTE_HOLD = 12,
} actuate_channel_t;

typedef struct {
    uint16_t err_code;   /* error code.     (eg. malloc fail, description error) */
    uint16_t err_loc;    /* error location. (eg. element_id) */
    uint16_t err_loc2;   /* error location-2. (eg. element index) */
} error_report_t;


//----------------- UserButton ----------------------

typedef struct userButton_params_s {
    uint8_t repeat;
    uint8_t pad;
} __attribute__((packed)) userButton_params_t;

//----------------- SendPkt --------------------------

typedef struct sendPkt_params_s {
    // possible params could be...
    //  - number of e2e retx, or timeout, etc
    uint8_t e2e_ack;
    uint8_t unused;
} __attribute__((packed)) sendPkt_params_t;

//----------------- SendSTR --------------------------
// no params

//----------------- SendRcrt --------------------------

typedef struct sendRcrt_params_s {
    uint16_t irate;     // inverse of desired pkt rate (interval in millisec)
} __attribute__((packed)) sendRcrt_params_t;

//----------------- Issue -------------------------

/**
 * time units for starttime is in mote-ticks, period is in ms. 
 * if period == 0, execute just one (similar to one shot timer) 
 * othewise, execute every period (periodic timer).
 * if abs == 1, starttime is global time.
 * otherwise, starttime is relative time interval.
 **/
typedef struct issue_params_s {
    uint32_t starttime;
    uint32_t period;
    uint8_t abs;
    uint8_t pad;
} __attribute__((packed)) issue_params_t;

//---------------- Actuate ----------------------

typedef struct actuate_params_s {
    uint8_t chan;
    uint8_t argtype;
    uint16_t arg1;
}__attribute__((packed)) actuate_params_t;

//--------------- Logical ---------------------------

typedef struct logical_params_s {
    tag_t result;
    tag_t attr;
    uint8_t optype;
    uint8_t argtype;
    tag_t arg;
}__attribute__((packed)) logical_params_t;


//--------------- Bit ---------------------------

typedef struct bit_params_s {
    tag_t result;
    tag_t attr;
    uint8_t optype;
    uint8_t argtype;
    tag_t arg;
}__attribute__((packed)) bit_params_t;

//----------------- Arithmetic --------------------

typedef struct arith_params_s {
    tag_t result;
    tag_t attr;
    uint8_t optype;
    uint8_t argtype;
    tag_t arg;
} __attribute__((packed)) arith_params_t; 

//----------------- GlobalTimeWait ---------------

typedef struct globaltime_wait_params_s {
    uint32_t starttime;
    uint32_t period;
    uint8_t blink;
    uint8_t repeat;
} __attribute__((packed)) globaltime_wait_params_t;

//----------------- Memory ------------------------

typedef struct memoryop_params_s {
    uint16_t addr; // memory address
    uint8_t value; // length if op=read, data to write if op=write(1,2)
    uint8_t op; // 0=read/ 1=write 1-byte var, 2=write 2-byte var
    tag_t type; // tag for return data
} __attribute__((packed)) memoryop_params_t;


//----------------- Reboot -----------------------
// no params

//----------------- Count ------------------------

typedef struct count_params_s {
    uint16_t count;
    int16_t rate;
    tag_t type;
} __attribute__((packed)) count_params_t;

//----------------- Get --------------------

typedef struct get_params_s {
    tag_t type;
    uint16_t value;
} __attribute__((packed)) get_params_t;

//----------------- Comparison --------------------

typedef struct comparison_params_s {
    tag_t result;
    tag_t attr;
    uint8_t optype;
    uint8_t argtype;
    tag_t arg;
} __attribute__((packed)) comparison_params_t; 

//----------------- Stats --------------------

typedef struct stats_params_s {
    tag_t result;
    tag_t attr;
    uint16_t optype;
} __attribute__((packed)) stats_params_t;

//----------------- Pack --------------------

typedef struct pack_params_s {
    tag_t attr;
    uint16_t size;
    uint8_t block;
    uint8_t pad;
} __attribute__((packed)) pack_params_t;

//----------------- Attribute --------------------

typedef struct attribute_params_s {
    tag_t result;
    tag_t attr;
    uint8_t optype;
    uint8_t pad;
} __attribute__((packed)) attribute_params_t;

//---------------------- Sample -------------------------

typedef enum {
    // lets make this greater than 20.
    HUMIDITY = 20,
    TEMPERATURE = 21,
    TSRSENSOR = 22,
    PARSENSOR = 23,
    ITEMP = 24,
    VOLTAGE = 25,
    PHOTO = 26,
    ACCELX = 27,
    ACCELY = 28,
} sensors_t;

typedef struct sample_params_s {
    uint32_t interval;      // sampling interval in millisec
    uint16_t count;
    tag_t outputName;
    uint8_t channel;
    uint8_t repeat;
} __attribute__((packed)) sample_params_t;

//---------------------- Voltage -------------------------

typedef struct voltage_params_s {
    tag_t outputName;
} __attribute__((packed)) voltage_params_t;

//----------------- FastSample -------------------------

typedef enum {
    UNKNOWN_RATE = 0,
    RATE_100_HZ = 10486,
    RATE_200_HZ = 5243,
    RATE_300_HZ = 3495,
    RATE_400_HZ = 2621,
    RATE_500_HZ = 2097,
    RATE_600_HZ = 1748,
    RATE_700_HZ = 1498,
    RATE_800_HZ = 1311,
    RATE_900_HZ = 1165,
    RATE_1_000_HZ = 1049,
    RATE_1_500_HZ = 699,
    RATE_2_001_HZ = 524,
    RATE_2_503_HZ = 419,
    RATE_2_996_HZ = 350,
    RATE_3_495_HZ = 300,
    RATE_4_002_HZ = 262,
    RATE_4_500_HZ = 233,
    RATE_4_993_HZ = 210,
    RATE_5_992_HZ = 175,
    RATE_6_991_HZ = 150,
    RATE_8_004_HZ = 131,
    RATE_8_962_HZ = 117,
    RATE_9_986_HZ = 105,
    RATE_12_053_HZ = 87,
    RATE_13_981_HZ = 75,
    RATE_15_888_HZ = 66,
    RATE_23_831_HZ = 44,
} sample_rate_t;

enum {
    FAST_CHANNELS = 3
};

typedef struct fastSample_params_s {
    sample_rate_t rate; // <= RATE_100_HZ
    uint16_t count;
    uint8_t repeat;
    uint8_t numChannels;
    uint8_t pad;
    uint8_t channel[FAST_CHANNELS];
    tag_t outputName[FAST_CHANNELS];
} __attribute__((packed)) fastSample_params_t;

//----------------- MemoryStats -------------------------

typedef struct {
    uint16_t bytesAllocated;
    uint16_t ptrsAllocated;
    uint16_t maxBytesAllocated;
    uint16_t maxPtrsAllocated;
} __attribute__((packed)) memory_stats_t;


//-------------- SampleMda400 -----------------------

enum { INFINITY_KILOSAMPLES = 0 };

typedef struct sampleMda400_params_s {
    uint16_t interval;
    uint16_t numKiloSamples;
    tag_t typeOut[3];
    tag_t time_tag;
    uint8_t channelSelect;
    uint8_t samplesPerBuffer;
} __attribute__((packed)) sampleMda400_params_t;

//-------------- SampleMda300 -----------------------
typedef struct sampleMda300_params_s {
    //uint16_t interval;
    //uint16_t count;
    uint8_t channel;
    uint8_t channelType;
    tag_t outputName;
    //uint8_t repeat;
    uint8_t param;
} __attribute__((packed)) sampleMda300_params_t;

//-------------- Onset Detector -----------------------

typedef struct onsetDetector_params_s {
    /*
       int8_t alpha;   // must be less than 100
       int8_t beta;    // must be less than 100
     */
    int8_t noiseThresh;
    int8_t signalThresh;
    uint16_t startDelay;
    tag_t type_in;
    tag_t type_out;
    tag_t type_info;
    uint8_t adaptiveMean;
    uint8_t pad;
} __attribute__((packed)) onsetDetector_params_t;

typedef struct onsetDetector_info_s {
    uint32_t offset;
    uint16_t mean;
} __attribute__((packed)) onsetDetector_info_t;

//----------------- SampleRssi --------------------

typedef struct sampleRssi_params_s {
    tag_t type;
} __attribute__((packed)) sampleRssi_params_t;

//------------- Storage (Store/Restore) --------------

typedef struct storage_params_s {
    tag_t tagIn;
    tag_t tagOut;
    uint8_t store; /* 1: store, 0: restore */
    uint8_t pad;
} __attribute__((packed)) storage_params_t;


//----------------- DeleteAttributeIf --------------------

typedef struct deleteAttributeIf_params_s {
    tag_t arg;
    tag_t tag;
    uint8_t argtype;
    uint8_t deleteAll;
} __attribute__((packed)) deleteAttributeIf_params_t;


//----------------- DeleteActiveTaskIf --------------------

typedef struct deleteActiveTaskIf_params_s {
    tag_t arg;
    uint8_t argtype;
    uint8_t pad;
} __attribute__((packed)) deleteActiveTaskIf_params_t;


//----------------- DeleteTaskIf --------------------

typedef struct deleteTaskIf_params_s {
    tag_t arg;
    uint8_t argtype;
    uint8_t pad;
} __attribute__((packed)) deleteTaskIf_params_t;


//----------------- Image (Cyclops) -------------------------

typedef struct image_params_s {
    tag_t outputName;
    uint8_t nModule;        // Neuron module (snapN, activeN, etc)
    uint8_t length;
    uint8_t slaveQuery[0];
} __attribute__((packed)) image_params_t;


//--------------------- FIR low pass filter -----------------------

typedef struct firLpFilter_params_s {
    tag_t type_in;
    tag_t type_out;
} __attribute__((packed)) firLpFilter_params_t;


//--------------------- Run Length Encoding -----------------------

typedef nx_struct rle_params_s {
    nxtag_t result;
    nxtag_t attr;
    nx_uint16_t thresh;
} __attribute__((packed)) rle_params_t;


//----------------- Vector ------------------------

typedef nx_struct vector_params_s {
    nx_uint16_t length;
    nx_uint16_t pattern;
    nxtag_t attr;
} __attribute__((packed)) vector_params_t;



#endif //_TENET_TASK_H_

