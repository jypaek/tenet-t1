/*
 * Translate a tasklet string into tasklet packet format (like binary format) 
 * for motes to understand it and be able to get the tasklet parameters.
 * Every created tasklet should have its construct. 
 *
 */
#include "element_construct.h"
#include "element_map.h"
#include <string.h>
#include <stdlib.h>
#include <stdio.h>

#ifdef DEBUG_ELEMENT
#define DEBUG_ELEMENT_CONSTRUCT 1
#endif


/* first function called by tp.c while constructing a task packet */
int construct_init(unsigned char* buf){
    int len;
    task_msg_t *taskMsg;

#if defined(BUILDING_PC_SIDE) && defined(DEBUG_ELEMENT_CONSTRUCT)
    fprintf(stderr,"creating INSTALL task\n");
#endif
    taskMsg = (task_msg_t *)(buf);
    taskMsg->type = TASK_INSTALL;

    len = sizeof(task_msg_t);

#if defined(BUILDING_PC_SIDE) && defined(DEBUG_ELEMENT_CONSTRUCT)
    fprintf(stderr, " task_msg_t length %d\n", len);
#endif
    return len;
}


/* This function set's the "num_element' field in the 
   INSTALL tasking packet after all elements are constructed */
int construct_finalize(unsigned char* buf, int num_elements){
    task_msg_t *taskMsg;

    taskMsg = (task_msg_t *)(buf);
    taskMsg->numElements = num_elements;

    return 0;
}


/* This function constructs a complete DELETE task packet */
int construct_delete(unsigned char* buf) {
    int len = sizeof(task_msg_t);
    task_msg_t *taskMsg;

#if defined(BUILDING_PC_SIDE) && defined(DEBUG_ELEMENT_CONSTRUCT)
    fprintf(stderr,"creating DELETE task\n");
#endif
    taskMsg = (task_msg_t *)(buf);
    taskMsg->type = TASK_DELETE;
    taskMsg->numElements = 0;

#if defined(BUILDING_PC_SIDE) && defined(DEBUG_ELEMENT_CONSTRUCT)
    fprintf(stderr, "task_msg_t length %d\n", len);
#endif
    return len;
}


/******** Below are constructors for default tasklets ********/

int construct_issue(unsigned char* buf, int len, int *num_elements,
		    uint32_t starttime, uint32_t period ,uint8_t abst) {
    attr_t *attr;
    issue_params_t *issue;

    attr = (attr_t *)(buf + len);
    attr->type = ELEMENT_ISSUE;
    attr->length = sizeof(issue_params_t);
    issue = (issue_params_t *)(attr->value);
    issue->starttime = starttime;
    issue->period = period;
    issue->abs = abst;

    len = sizeof(attr_t) + sizeof(issue_params_t); 
    (*num_elements)++;

#if defined(BUILDING_PC_SIDE) && defined(DEBUG_ELEMENT_CONSTRUCT)
    fprintf(stderr, "  attr %u + issue %u = length %d\n",
            sizeof(attr_t), sizeof(issue_params_t), len);
#endif
    return len;
}

int construct_count(unsigned char* buf, int len, int *num_elements, 
                    uint16_t tag, int16_t count, int16_t rate) {
    attr_t *attr;
    count_params_t *cnt;

    attr = (attr_t *)(buf + len);
    attr->type = ELEMENT_COUNT;
    attr->length = sizeof(count_params_t);
    cnt = (count_params_t *)(attr->value);
    cnt->type = tag;
    cnt->count = (uint16_t)count;
    cnt->rate = rate;

    len = sizeof(attr_t) + sizeof(count_params_t);
    (*num_elements)++;

#if defined(BUILDING_PC_SIDE) && defined(DEBUG_ELEMENT_CONSTRUCT)
    fprintf(stderr, "  attr %u + count %u = length %d\n",
            sizeof(attr_t), sizeof(count_params_t), len);
#endif
    return len;
}

int construct_get(unsigned char* buf, int len, int *num_elements, 
                  uint16_t tag, uint16_t value) {
    attr_t *attr;
    get_params_t *n;

    attr = (attr_t *)(buf + len);
    attr->type = ELEMENT_GET;
    attr->length = sizeof(get_params_t);
    n = (get_params_t *)(attr->value);
    n->type = tag;
    n->value = value;

    len = sizeof(attr_t) + sizeof(get_params_t);
    (*num_elements)++;

#if defined(BUILDING_PC_SIDE) && defined(DEBUG_ELEMENT_CONSTRUCT)
    fprintf(stderr, "  attr %u + get %u = length %d\n",
            sizeof(attr_t), sizeof(get_params_t), len);
#endif
    return len;
}

int construct_actuate(unsigned char* buf, int len,int *num_elements,
                      uint8_t chan, uint8_t argtype, uint16_t arg1) {
  attr_t *attr;
  actuate_params_t *actuate;

  attr=(attr_t*)(buf+len);
  attr->type=ELEMENT_ACTUATE;
  attr->length = sizeof(actuate_params_t);
  actuate=(actuate_params_t *)(attr->value);
  actuate->chan=chan;
  actuate->argtype=argtype;
  actuate->arg1=arg1;

  len=sizeof(attr_t)+sizeof(actuate_params_t);
  (*num_elements)++;

  #if defined(BUILDING_PC_SIDE) && defined(DEBUG_ELEMENT_CONSTRUCT)
    fprintf(stderr, "  attr %u + actuate %u = length %d\n",
            sizeof(attr_t), sizeof(actuate_params_t), len);
  #endif

  return len;
}

int construct_reboot(unsigned char* buf, int len, int *num_elements) {
    attr_t *attr;

    attr = (attr_t *)(buf + len);
    attr->type = ELEMENT_REBOOT;
    attr->length = 0;

    len = sizeof(attr_t);
    (*num_elements)++;

#if defined(BUILDING_PC_SIDE) && defined(DEBUG_ELEMENT_CONSTRUCT)
    fprintf(stderr, "  attr %u + reboot %u = length %d\n",
            sizeof(attr_t), 0, len);
#endif
    return len;
}

int construct_logical(unsigned char* buf, int len,int *num_elements,
                      uint16_t result, uint16_t tag, uint8_t optype, 
                      uint8_t argtype, uint16_t arg1) {
    attr_t *attr;
    logical_params_t *n;

    attr = (attr_t *)(buf + len);
    attr->type = ELEMENT_LOGICAL;
    attr->length = sizeof(logical_params_t);
    n = (logical_params_t *)(attr->value);
    n->result = result;
    n->attr = tag;
    n->optype = optype;
    n->argtype = argtype;
    n->arg = arg1;          

    len = sizeof(attr_t) + sizeof(logical_params_t);
    (*num_elements)++;

#if defined(BUILDING_PC_SIDE) && defined(DEBUG_ELEMENT_CONSTRUCT)
    fprintf(stderr, "  attr %u + logical %u = length %d\n",
            sizeof(attr_t), sizeof(logical_params_t), len);
#endif
    return len;
}

int construct_bit(unsigned char* buf, int len, int *num_elements,
                  uint16_t result, uint16_t tag, uint8_t optype, 
                  uint8_t argtype, uint16_t arg1) {
    attr_t *attr;
    bit_params_t *n;

    attr = (attr_t *)(buf + len);
    attr->type = ELEMENT_BIT;
    attr->length = sizeof(bit_params_t);
    n = (bit_params_t *)(attr->value);
    n->result = result;
    n->attr = tag;
    n->optype = optype;
    n->argtype = argtype;
    n->arg = arg1;          

    len = sizeof(attr_t) + sizeof(bit_params_t);
    (*num_elements)++;

#if defined(BUILDING_PC_SIDE) && defined(DEBUG_ELEMENT_CONSTRUCT)
    fprintf(stderr, "  attr %u + bit %u = length %d\n",
            sizeof(attr_t), sizeof(bit_params_t), len);
#endif
    return len;
}

int construct_arith(unsigned char* buf, int len, int *num_elements,
                    uint16_t result, uint16_t nAttr, uint8_t optype, 
                    uint8_t argtype, uint16_t arg) {
    attr_t *attr;
    arith_params_t *n;

    attr = (attr_t *)(buf + len);
    attr->type = ELEMENT_ARITH;
    attr->length = sizeof(arith_params_t);
    n = (arith_params_t *)(attr->value);
    n->result = result;
    n->attr = nAttr;
    n->optype = optype;
    n->argtype = argtype;
    n->arg = arg;

    len = sizeof(attr_t) + sizeof(arith_params_t);
    (*num_elements)++;

#if defined(BUILDING_PC_SIDE) && defined(DEBUG_ELEMENT_CONSTRUCT)
    fprintf(stderr, "  attr %u + arith %u = length %d\n",
            sizeof(attr_t), sizeof(arith_params_t), len);
#endif
    return len;
}

int construct_comparison(unsigned char* buf, int len, int *num_elements,
                         uint16_t result, uint16_t nAttr, uint8_t optype, 
                         uint8_t argtype, uint16_t arg) {
    attr_t *attr;
    comparison_params_t *n;

    attr = (attr_t *)(buf + len);
    attr->type = ELEMENT_COMPARISON;
    attr->length = sizeof(comparison_params_t);
    n = (comparison_params_t *)(attr->value);
    n->result = result;
    n->attr = nAttr;
    n->optype = optype;
    n->argtype = argtype;
    n->arg = arg;

    len = sizeof(attr_t) + sizeof(comparison_params_t);
    (*num_elements)++;

#if defined(BUILDING_PC_SIDE) && defined(DEBUG_ELEMENT_CONSTRUCT)
    fprintf(stderr, "  attr %u + comparison %u = length %d\n",
            sizeof(attr_t), sizeof(comparison_params_t), len);
#endif
    return len;
}

int construct_stats(unsigned char* buf, int len, int *num_elements,
                    uint16_t result, uint16_t nAttr, uint16_t optype) {
    attr_t *attr;
    stats_params_t *n;

    attr = (attr_t *)(buf + len);
    attr->type = ELEMENT_STATS;
    attr->length = sizeof(stats_params_t);
    n = (stats_params_t *)(attr->value);
    n->result = result;
    n->attr = nAttr;
    n->optype = optype;

    len = sizeof(attr_t) + sizeof(stats_params_t);
    (*num_elements)++;

#if defined(BUILDING_PC_SIDE) && defined(DEBUG_ELEMENT_CONSTRUCT)
    fprintf(stderr, "  attr %u + stats %u = length %d\n",
            sizeof(attr_t), sizeof(stats_params_t), len);
#endif
    return len;
}

int construct_storage(unsigned char* buf, int len, int *num_elements, 
                      uint16_t tagIn, uint16_t tagOut, uint8_t store) {
    attr_t *attr;
    storage_params_t *p;

    attr = (attr_t *)(buf + len);
    attr->type = ELEMENT_STORAGE;
    attr->length = sizeof(storage_params_t);
    p = (storage_params_t *)(attr->value);
    p->tagIn = tagIn;
    p->tagOut = tagOut;
    p->store = store;
    p->pad = 0;

    len = sizeof(attr_t) + sizeof(storage_params_t);
    (*num_elements)++;

#if defined(BUILDING_PC_SIDE) && defined(DEBUG_ELEMENT_CONSTRUCT)
    fprintf(stderr, "  attr %u + storage %u = length %d\n",
            sizeof(attr_t), sizeof(storage_params_t), len);
#endif
    return len;
}

int construct_pack(unsigned char* buf, int len, int *num_elements,
                   uint16_t nAttr, uint16_t size, uint8_t block) {
    attr_t *attr;
    pack_params_t *n;

    attr = (attr_t *)(buf + len);
    attr->type = ELEMENT_PACK;
    attr->length = sizeof(pack_params_t);
    n = (pack_params_t *)(attr->value);
    n->attr = nAttr;
    n->size = size;
    n->block = block;

    len = sizeof(attr_t) + sizeof(pack_params_t);
    (*num_elements)++;

#if defined(BUILDING_PC_SIDE) && defined(DEBUG_ELEMENT_CONSTRUCT)
    fprintf(stderr, "  attr %u + pack %u = length %d\n",
            sizeof(attr_t), sizeof(pack_params_t), len);
#endif
    return len;
}

int construct_attribute(unsigned char* buf, int len, int *num_elements,
                    uint16_t result, uint16_t nAttr, uint8_t optype) {
    attr_t *attr;
    attribute_params_t *n;

    attr = (attr_t *)(buf + len);
    attr->type = ELEMENT_ATTRIBUTE;
    attr->length = sizeof(attribute_params_t);
    n = (attribute_params_t *)(attr->value);
    n->result = result;
    n->attr = nAttr;
    n->optype = optype;

    len = sizeof(attr_t) + sizeof(attribute_params_t);
    (*num_elements)++;

#if defined(BUILDING_PC_SIDE) && defined(DEBUG_ELEMENT_CONSTRUCT)
    fprintf(stderr, "  attr %u + attribute %u = length %d\n",
            sizeof(attr_t), sizeof(attribute_params_t), len);
#endif
    return len;
}


/******** send related tasklet constructors ********/

int construct_sendpkt(unsigned char* buf, int len, int *num_elements, uint8_t e2e_ack) {
    attr_t *attr;
    sendPkt_params_t *sp;

    attr = (attr_t *)(buf + len);
    attr->type = ELEMENT_SENDPKT;
    attr->length = sizeof(sendPkt_params_t);
    sp = (sendPkt_params_t *)(attr->value);
    sp->e2e_ack = e2e_ack;
    sp->unused = 0;

    len = sizeof(attr_t) + sizeof(sendPkt_params_t); 
    (*num_elements)++;

#if defined(BUILDING_PC_SIDE) && defined(DEBUG_ELEMENT_CONSTRUCT)
    fprintf(stderr, "  attr %u + sendpkt %u = length %d\n",
            sizeof(attr_t), sizeof(sendPkt_params_t), len);
#endif
    return len;
}

int construct_sendstr(unsigned char* buf, int len, int *num_elements) {
    attr_t *attr;

    attr = (attr_t *)(buf + len);
    attr->type = ELEMENT_SENDSTR;
    attr->length = 0;

    len = sizeof(attr_t);
    (*num_elements)++;

#if defined(BUILDING_PC_SIDE) && defined(DEBUG_ELEMENT_CONSTRUCT)
    fprintf(stderr, "  attr %u + sendstr %u = length %d\n",
            sizeof(attr_t), 0, len);
#endif
    return len;
}

int construct_sendrcrt(unsigned char* buf, int len, int *num_elements, uint16_t irate) {
    attr_t *attr;
    sendRcrt_params_t *sp;

    attr = (attr_t *)(buf + len);
    attr->type = ELEMENT_SENDRCRT;
    attr->length = sizeof(sendRcrt_params_t);
    sp = (sendRcrt_params_t *)(attr->value);
    sp->irate = irate;

    len = sizeof(attr_t) + sizeof(sendRcrt_params_t); 
    (*num_elements)++;

#if defined(BUILDING_PC_SIDE) && defined(DEBUG_ELEMENT_CONSTRUCT)
    fprintf(stderr, "  attr %u + sendrcrt %u = length %d\n",
            sizeof(attr_t), sizeof(sendRcrt_params_t), len);
#endif
    return len;
}

int construct_send(unsigned char* buf, int len, int *num_elements, uint16_t sendtype) {
    if (sendtype == 2)
        return construct_sendstr(buf, len, num_elements);
    else if (sendtype == 1)
        return construct_sendpkt(buf, len, num_elements, 1);
    else if (sendtype == 3)
        return construct_sendrcrt(buf, len, num_elements, 0);
    else
        return construct_sendpkt(buf, len, num_elements, 0);
}


/*** Delete (task/active_task/attribute) tasklet constructors ***/

int construct_deleteAttributeIf(unsigned char *buf, int len, int *num_elements,
                                uint16_t arg, uint8_t argtype, uint16_t tag, uint8_t deleteAll) {
    attr_t *attr;
    deleteAttributeIf_params_t *n;

    attr = (attr_t *)(buf + len);
    attr->type = ELEMENT_DELETEATTRIBUTEIF;
    attr->length = sizeof(deleteAttributeIf_params_t);
    n = (deleteAttributeIf_params_t *)(attr->value);
    n->arg = arg;
    n->tag = tag;
    n->argtype = argtype;
    n->deleteAll = deleteAll;
    len = sizeof(attr_t) + sizeof(deleteAttributeIf_params_t); 
    (*num_elements)++;

#if defined(BUILDING_PC_SIDE) && defined(DEBUG_ELEMENT_CONSTRUCT)
    fprintf(stderr, "  attr %u + deleteAttributeIf %u = length %d\n",
            sizeof(attr_t), sizeof(deleteAttributeIf_params_t), len);
#endif
    return len;
}


int construct_deleteActiveTaskIf(unsigned char *buf, int len, int *num_elements,
                                 uint16_t arg, uint8_t argtype) {
    attr_t *attr;
    deleteActiveTaskIf_params_t *n;

    attr = (attr_t *)(buf + len);
    attr->type = ELEMENT_DELETEACTIVETASKIF;
    attr->length = sizeof(deleteActiveTaskIf_params_t);
    n = (deleteActiveTaskIf_params_t *)(attr->value);
    n->arg = arg;
    n->argtype = argtype;
    n->pad = 0;
    len = sizeof(attr_t) + sizeof(deleteActiveTaskIf_params_t); 
    (*num_elements)++;

#if defined(BUILDING_PC_SIDE) && defined(DEBUG_ELEMENT_CONSTRUCT)
    fprintf(stderr, "  attr %u + deleteActiveTaskIf %u = length %d\n",
            sizeof(attr_t), sizeof(deleteActiveTaskIf_params_t), len);
#endif
    return len;
}

int construct_deleteTaskIf(unsigned char *buf, int len, int *num_elements,
                           uint16_t arg, uint8_t argtype) {
    attr_t *attr;
    deleteTaskIf_params_t *n;

    attr = (attr_t *)(buf + len);
    attr->type = ELEMENT_DELETETASKIF;
    attr->length = sizeof(deleteTaskIf_params_t);
    n = (deleteTaskIf_params_t *)(attr->value);
    n->arg = arg;
    n->argtype = argtype;
    n->pad = 0;
    len = sizeof(attr_t) + sizeof(deleteTaskIf_params_t); 
    (*num_elements)++;

#if defined(BUILDING_PC_SIDE) && defined(DEBUG_ELEMENT_CONSTRUCT)
    fprintf(stderr, "  attr %u + deleteTaskIf %u = length %d\n",
            sizeof(attr_t), sizeof(deleteTaskIf_params_t), len);
#endif
    return len;
}

int construct_voltage(unsigned char* buf, int len, int *num_elements, uint16_t out0) {
    attr_t *attr;
    voltage_params_t *s;

    attr = (attr_t *)(buf + len);
    attr->type = ELEMENT_VOLTAGE;
    attr->length = sizeof(voltage_params_t);
    s = (voltage_params_t *)(attr->value);
    s->outputName = out0;       // tag

    len = sizeof(attr_t) + sizeof(voltage_params_t);
    (*num_elements)++;

#if defined(BUILDING_PC_SIDE) && defined(DEBUG_ELEMENT_CONSTRUCT)
    fprintf(stderr, "  attr %u + voltage %u  = length %d\n",
            sizeof(attr_t),  sizeof(voltage_params_t), len);
#endif
    return len;
}


/******** sampling related tasklet constructors ********/

int construct_sample(unsigned char* buf, int len, int *num_elements, 
                     uint32_t interval, uint16_t count, uint8_t repeat, 
                     uint8_t ch0, uint16_t out0) {
    attr_t *attr;
    sample_params_t *s;

    attr = (attr_t *)(buf + len);
    attr->type = ELEMENT_SAMPLE;
    attr->length = sizeof(sample_params_t);
    s = (sample_params_t *)(attr->value);
    s->interval = interval;     // ms, between samples
    s->count = count;           // # sample in an attr
    s->channel = ch0;           // ADC channel
    s->outputName = out0;       // tag
    s->repeat = repeat;         // repeat

    len = sizeof(attr_t) + sizeof(sample_params_t);
    (*num_elements)++;

#if defined(BUILDING_PC_SIDE) && defined(DEBUG_ELEMENT_CONSTRUCT)
    fprintf(stderr, "  attr %u + sample %u  = length %d\n",
            sizeof(attr_t),  sizeof(sample_params_t), len);
#endif
    return len;
}

/******** constructors for telosb-dependant tasklets ********/

int construct_fastsample(unsigned char* buf, int len, int *num_elements, int rate, int count, int numChannels,
        int ch0, int out0,
        int ch1, int out1,
        int ch2, int out2){
    attr_t *attr;
    fastSample_params_t *sample;

    attr = (attr_t *)(buf + len);
    attr->type = ELEMENT_FASTSAMPLE;
    attr->length = sizeof(fastSample_params_t);
    sample = (fastSample_params_t *)(attr->value);
    sample->rate =(sample_rate_t) rate;
    sample->count = count;
    sample->numChannels = numChannels;
    sample->channel[0] = ch0;
    sample->outputName[0]  = out0;
    sample->channel[1] = ch1;
    sample->outputName[1]  = out1;
    sample->channel[2] = ch2;
    sample->outputName[2]  = out2;

    len = sizeof(attr_t) + sizeof(fastSample_params_t); 
    (*num_elements)++;

#if defined(BUILDING_PC_SIDE) && defined(DEBUG_ELEMENT_CONSTRUCT)
    fprintf(stderr, "  attr %u + fastSample %u = length %d\n",
            sizeof(attr_t), sizeof(fastSample_params_t), len);
#endif
    return len;
}

int construct_user_button(unsigned char* buf, int len, int *num_elements, int repeat) {
    attr_t *attr;
    userButton_params_t *userButton;

    attr = (attr_t *)(buf + len);
    attr->type = ELEMENT_USERBUTTON;
    attr->length = sizeof(userButton_params_t);
    userButton = (userButton_params_t *)(attr->value);
    userButton->repeat = (uint8_t)repeat;
    userButton->pad = 0x00;

    len = sizeof(attr_t) + sizeof(userButton_params_t);
    (*num_elements)++;

#if defined(BUILDING_PC_SIDE) && defined(DEBUG_ELEMENT_CONSTRUCT)
    fprintf(stderr, "  attr %u + userButton %u = length %d\n",
            sizeof(attr_t), sizeof(userButton_params_t), len);
#endif
    return len;
}


/******** Below are constructors for tasklets under devel. ********/

int construct_memoryop(unsigned char* buf, int len, int *num_elements, int addr, int value, int op, int type) {
    attr_t *attr;
    memoryop_params_t *mem;

    attr = (attr_t *)(buf + len);
    attr->type = ELEMENT_MEMORYOP;
    attr->length = sizeof(memoryop_params_t);
    mem = (memoryop_params_t *)(attr->value);
    mem->addr = addr;
    mem->value = value;
    mem->op = op;
    mem->type = type;

    len = sizeof(attr_t) + sizeof(memoryop_params_t);
    (*num_elements)++;

#if defined(BUILDING_PC_SIDE) && defined(DEBUG_ELEMENT_CONSTRUCT)
    fprintf(stderr, "  attr %u + mem %u = length %d\n",
            sizeof(attr_t), sizeof(memoryop_params_t), len);
#endif
    return len;
}

int construct_mda400(unsigned char* buf, int len, int *num_elements, 
                     uint16_t us_sample_interval, uint16_t num_kilo_samples,
                     uint16_t tag_x, uint16_t tag_y, uint16_t tag_z, uint16_t tag_time,
                     uint8_t channel_select, uint8_t samples_per_buffer) {
    attr_t *attr;
    sampleMda400_params_t *mda;

    attr = (attr_t *)(buf + len);
    attr->type = ELEMENT_SAMPLEMDA400;
    attr->length = sizeof(sampleMda400_params_t);
    mda = (sampleMda400_params_t *)(attr->value);
    mda->interval = us_sample_interval;     //ex> 20000UL, // sample interval in usec
    mda->numKiloSamples = num_kilo_samples; //ex> 0,       // num kilo samples (0 = continuous)
    mda->typeOut[0] = tag_x;                //ex> 0x101
    mda->typeOut[1] = tag_y;                //ex> 0x202
    mda->typeOut[2] = tag_z;                //ex> 0x303
    mda->time_tag = tag_time;               //ex> 0x404,   // tag for sample index (time)
    mda->channelSelect = channel_select;    //ex> 4,       // channel select in bitmap (LSB) (4 is Z-axis)
    mda->samplesPerBuffer = samples_per_buffer; //ex> 25   // num samples per packet

    len = sizeof(attr_t) + sizeof(sampleMda400_params_t); 
    (*num_elements)++;

#if defined(BUILDING_PC_SIDE) && defined(DEBUG_ELEMENT_CONSTRUCT)
    fprintf(stderr, "  attr %u + sampleMda400 %u = length %d\n",
            sizeof(attr_t), sizeof(sampleMda400_params_t), len);
#endif
    return len;
}

int construct_mda300(unsigned char* buf, int len, int *num_elements, 
                     uint8_t channel, uint8_t channelType,
                     tag_t outName, uint8_t param) {
    attr_t *attr;
    sampleMda300_params_t *mda;

    attr = (attr_t *)(buf + len);
    attr->type = ELEMENT_SAMPLEMDA300;
    attr->length = sizeof(sampleMda300_params_t);
    mda = (sampleMda300_params_t *)(attr->value);
    //mda->interval = sample_interval;
    //mda->count = count;
    mda->channel = channel;
    mda->channelType = channelType;
    mda->outputName = outName;
    //mda->repeat = repeat;
    mda->param = param;

    len = sizeof(attr_t) + sizeof(sampleMda300_params_t); 
    (*num_elements)++;

#if defined(BUILDING_PC_SIDE) && defined(DEBUG_ELEMENT_CONSTRUCT)
    fprintf(stderr, "  attr %u + sampleMda300 %u = length %d\n",
            sizeof(attr_t), sizeof(sampleMda300_params_t), len);
#endif
    return len;
}

int construct_onset_detector(unsigned char* buf, int len, int *num_elements, 
                             int8_t noiseThresh, int8_t signalThresh, uint16_t startDelay, 
                             uint16_t tag_in, uint16_t tag_out, uint16_t tag_info,
                             uint8_t adaptiveMean) {
    attr_t *attr;
    onsetDetector_params_t *onset;

    attr = (attr_t *)(buf + len);
    attr->type = ELEMENT_ONSETDETECTOR;
    attr->length = sizeof(onsetDetector_params_t);
    onset = (onsetDetector_params_t *)(attr->value);
    onset->noiseThresh = noiseThresh;   //ex> 2, // noise thresh
    onset->signalThresh = signalThresh; //ex> 7, // signal thresh
    onset->startDelay = startDelay;     //ex> 5000,  // init delay
    onset->type_in = tag_in;            //ex> 0x303, // tag in
    onset->type_out = tag_out;          //ex> 0x313, // tag out
    onset->type_info = tag_info;        //ex> 0x414, // tag offset
    onset->adaptiveMean = adaptiveMean;

    len = sizeof(attr_t) + sizeof(onsetDetector_params_t); 
    (*num_elements)++;

#if defined(BUILDING_PC_SIDE) && defined(DEBUG_ELEMENT_CONSTRUCT)
    fprintf(stderr, "  attr %u + onsetDetector %u = length %d\n",
            sizeof(attr_t), sizeof(onsetDetector_params_t), len);
#endif
    return len;
}

int construct_sample_rssi(unsigned char* buf, int len, int *num_elements, uint16_t tag) {
    attr_t *attr;
    sampleRssi_params_t *n;

    attr = (attr_t *)(buf + len);
    attr->type = ELEMENT_SAMPLERSSI;
    attr->length = sizeof(sampleRssi_params_t);
    n = (sampleRssi_params_t *)(attr->value);
    n->type = tag;

    len = sizeof(attr_t) + sizeof(sampleRssi_params_t); 
    (*num_elements)++;

#if defined(BUILDING_PC_SIDE) && defined(DEBUG_ELEMENT_CONSTRUCT)
    fprintf(stderr, "  attr %u + sampleRssi %u = length %d\n",
            sizeof(attr_t), sizeof(sampleRssi_params_t), len);
#endif
    return len;
}

int construct_firlpfilter(unsigned char* buf, int len, int *num_elements, 
                          uint16_t tag_in, uint16_t tag_out) {
    attr_t *attr;
    firLpFilter_params_t *p;

    attr = (attr_t *)(buf + len);
    attr->type = ELEMENT_FIRLPFILTER;
    attr->length = sizeof(firLpFilter_params_t);
    p = (firLpFilter_params_t *)(attr->value);
    p->type_in = tag_in;
    p->type_out = tag_out;

    len = sizeof(attr_t) + sizeof(firLpFilter_params_t); 
    (*num_elements)++;

#if defined(BUILDING_PC_SIDE) && defined(DEBUG_ELEMENT_CONSTRUCT)
    fprintf(stderr, "  attr %u + firLpFilter %u = length %d\n",
            sizeof(attr_t), sizeof(firLpFilter_params_t), len);
#endif
    return len;
}


#ifdef INCLUDE_CYCLOPS
/******** Image (cyclops) related tasklet constructors ********/

int construct_cyclops(unsigned char* buf, int len, int *num_elements, 
                      uint8_t nModule, uint8_t datalen, uint8_t *slaveQuery, 
                      uint16_t out0) {
    attr_t *attr;
    image_params_t *img;

    attr = (attr_t *)(buf + len);
    attr->type = ELEMENT_IMAGE;
    attr->length = offsetof(image_params_t, slaveQuery) + datalen;  // NOTE
    img = (image_params_t *)(attr->value);
    img->outputName = out0;
    img->nModule = nModule;  //Neuron module (snapN, activeN, etc)
    img->length = datalen;
    memcpy(img->slaveQuery, slaveQuery, datalen);
    free(slaveQuery);

    len = sizeof(attr_t) + attr->length;
    (*num_elements)++;

#if defined(BUILDING_PC_SIDE) && defined(DEBUG_ELEMENT_CONSTRUCT)
    fprintf(stderr, "  attr %u + image %u  = length %d\n",
            sizeof(attr_t), attr->length, len);
#endif
    return len;
}

#include "cyclops_query.h"

int construct_image_snap(unsigned char* buf, int len, int *num_elements, 
                         uint8_t flash, uint8_t imgtype, 
                         uint8_t xsize, uint8_t ysize, uint16_t out0) {
    snap_query_t *q;
    q = (snap_query_t *) malloc(sizeof(snap_query_t));
    q->enableFlash = flash;
    q->type = imgtype;
    q->size.x = xsize;
    q->size.y = ysize;
    return construct_cyclops(buf, len, num_elements, NEURON_SNAP_ONLY, 
                             sizeof(snap_query_t), (uint8_t *)q, out0);
}

int construct_image_get(unsigned char* buf, int len, int *num_elements, 
                        uint8_t imageAddr, uint8_t fragsize, uint16_t reportRate,
                        uint8_t flash, uint8_t imgtype, 
                        uint8_t xsize, uint8_t ysize, uint16_t out0) {
    getImage_query_t *q;
    q = (getImage_query_t *) malloc(sizeof(getImage_query_t));
    q->imageAddr = imageAddr;
    q->fragmentSize = fragsize;
    q->reportRate = reportRate;
    q->snapQ.enableFlash = flash;
    q->snapQ.type = imgtype;
    q->snapQ.size.x = xsize;
    q->snapQ.size.y = ysize;
    return construct_cyclops(buf, len, num_elements, NEURON_GET_IMAGE, 
                             sizeof(getImage_query_t), (uint8_t *)q, out0);
}

int construct_image_detect(unsigned char* buf, int len, int *num_elements, 
                           uint8_t type, uint8_t use_segment,
                           uint8_t enableFlash, uint8_t ImgRes, 
                           uint16_t out0) {
    detect_query_t *q;
    q = (detect_query_t *) malloc(sizeof(detect_query_t));
    q->type = type;
    q->use_segment = use_segment;
    q->snapQ.enableFlash = enableFlash;
    q->snapQ.type = CYCLOPS_IMAGE_TYPE_Y;
    q->snapQ.size.x = ImgRes;
    q->snapQ.size.y = ImgRes;
    return construct_cyclops(buf, len, num_elements, NEURON_DETECT_OBJECT, 
                             sizeof(detect_query_t), (uint8_t *)q, out0);
}

int construct_image_detect_params(unsigned char* buf, int len, int *num_elements, 
                                  uint8_t ImgRes, uint8_t RACoeff, uint8_t skip,
                                  uint8_t illCoeff, uint8_t range, uint8_t detectThresh) {
    detect_query_t *q;
    q = (detect_query_t *) malloc(sizeof(detect_query_t));
    q->type = DETECT_SET_PARAM;
    q->use_segment = 0;
    q->snapQ.enableFlash = 0;
    q->snapQ.type = CYCLOPS_IMAGE_TYPE_Y;
    q->snapQ.size.x = ImgRes;
    q->snapQ.size.y = ImgRes;
    q->detectParam.RACoeff = RACoeff;
    q->detectParam.skip = skip;
    q->detectParam.illCoeff = illCoeff;
    q->detectParam.range = range;
    q->detectParam.detectThresh = detectThresh;
    q->detectParam.pad = 0;
    return construct_cyclops(buf, len, num_elements, NEURON_DETECT_OBJECT, 
                             sizeof(detect_query_t), (uint8_t *)q, 0);
}

int construct_image_capture_params(unsigned char* buf, int len, int *num_elements, 
                                   int type,
                                   int16_t offsetx, int16_t offsety, 
                                   uint16_t inputx, uint16_t inputy,
                                   uint8_t testmode, uint16_t exposure,
                                   uint8_t a_red, uint8_t a_green, uint8_t a_blue,
                                   uint16_t d_red, uint16_t d_green, uint16_t d_blue,
                                   uint16_t runtime, uint16_t out0) {
    activeEye_query_t *activeQ;
    capture_param_t * captureQ;
    int length;
   
    if (type == ACTIVE_EYE_SET_PARAMS)
        length = sizeof(activeEye_query_t);
    else
        length = offsetof(activeEye_query_t, cp);

    activeQ = (activeEye_query_t *)malloc(length);
    activeQ->pad  = 0;          // byte-alignment

    if (type == ACTIVE_EYE_SET_PARAMS) {
        activeQ->type = ACTIVE_EYE_SET_PARAMS;
        captureQ = &activeQ->cp;
        captureQ->offset.x          = offsetx;
        captureQ->offset.y          = offsety;
        captureQ->inputSize.x       = inputx;
        captureQ->inputSize.y       = inputy;
        captureQ->testMode          = testmode;
        captureQ->exposurePeriod    = exposure;
        captureQ->analogGain.red    = a_red;
        captureQ->analogGain.green  = a_green;
        captureQ->analogGain.blue   = a_blue;
        captureQ->digitalGain.red   = d_red;
        captureQ->digitalGain.green = d_green;
        captureQ->digitalGain.blue  = d_blue;
        captureQ->runTime           = runtime;
    }
    else {
        activeQ->type = ACTIVE_EYE_GET_PARAMS;
    }

    return construct_cyclops(buf, len, num_elements, NEURON_ACTIVE_EYE, 
                             length, (uint8_t *)activeQ, out0);
}

int construct_image_reboot(unsigned char* buf, int len, int *num_elements) {
    config_query_t *cq;
    int length;
   
    length = sizeof(config_query_t);
    cq = (config_query_t *) malloc(length);
    cq->type = CONFIG_REBOOT;

    return construct_cyclops(buf, len, num_elements, NEURON_CONFIGURATION, 
                             length, (uint8_t *)cq, 0);
}

int construct_image_getRle(unsigned char* buf, int len, int *num_elements, 
                        uint8_t imageAddr, uint8_t fragsize, uint16_t reportRate,
                        uint8_t flash, uint8_t imgtype, 
                        uint8_t xsize, uint8_t ysize,
                        uint8_t threshold, uint16_t out0) {
    getPackBits_query_t *q;
    q = (getPackBits_query_t *) malloc(sizeof(getPackBits_query_t));
    q->imageAddr = imageAddr;
    q->fragmentSize = fragsize;
    q->reportRate = reportRate;
    q->threshold = threshold;
    q->snapQ.enableFlash = flash;
    q->snapQ.type = imgtype;
    q->snapQ.size.x = xsize;
    q->snapQ.size.y = ysize;
    return construct_cyclops(buf, len, num_elements, NEURON_GET_RLE_IMAGE, 
                             sizeof(getPackBits_query_t), (uint8_t *)q, out0);
}

int construct_image_getPackBits(unsigned char* buf, int len, int *num_elements, 
                        uint8_t imageAddr, uint8_t fragsize, uint16_t reportRate,
                        uint8_t flash, uint8_t imgtype, 
                        uint8_t xsize, uint8_t ysize,
                        uint8_t threshold, uint16_t out0) {
    getRle_query_t *q;
    q = (getRle_query_t *) malloc(sizeof(getRle_query_t));
    q->imageAddr = imageAddr;
    q->fragmentSize = fragsize;
    q->reportRate = reportRate;
    q->threshold = threshold;
    q->snapQ.enableFlash = flash;
    q->snapQ.type = imgtype;
    q->snapQ.size.x = xsize;
    q->snapQ.size.y = ysize;
    return construct_cyclops(buf, len, num_elements, NEURON_GET_PACKBITS_IMAGE, 
                             sizeof(getRle_query_t), (uint8_t *)q, out0);
}

int construct_image_copy(unsigned char* buf, int len, int *num_elements, 
                         uint8_t fromImageAddr, uint8_t toImageAddr,
                         uint8_t flash, uint8_t imgtype, 
                         uint8_t xsize, uint8_t ysize) {
    copy_query_t *q;
    q = (copy_query_t *) malloc(sizeof(copy_query_t));
    q->fromImageAddr = fromImageAddr;
    q->toImageAddr = toImageAddr;
    q->snapQ.enableFlash = flash;
    q->snapQ.type = imgtype;
    q->snapQ.size.x = xsize;
    q->snapQ.size.y = ysize;
    return construct_cyclops(buf, len, num_elements, NEURON_COPY_IMAGE, 
                             sizeof(copy_query_t), (uint8_t *)q, 0);
}
#endif

int construct_rle(unsigned char* buf, int len, int *num_elements,
                    uint16_t result, uint16_t arg, uint16_t thresh) {
    attr_t *attr;
    rle_params_t *n;

    attr = (attr_t *)(buf + len);
    attr->type = hxs(ELEMENT_RLE);
    attr->length = hxs(sizeof(rle_params_t));
    n = (rle_params_t *)(attr->value);
    n->result = hxs(result);
    n->attr = hxs(arg);
    n->thresh = hxs(thresh);

    len = sizeof(attr_t) + sizeof(rle_params_t);
    (*num_elements)++;

#if defined(BUILDING_PC_SIDE) && defined(DEBUG_ELEMENT_CONSTRUCT)
    fprintf(stderr, "  attr %u + rle %u = length %d\n",
            sizeof(attr_t), sizeof(rle_params_t), len);
#endif
    return len;
}

int construct_packbits(unsigned char* buf, int len, int *num_elements,
                    uint16_t result, uint16_t arg, uint16_t thresh) {
    attr_t *attr;
    rle_params_t *n;

    attr = (attr_t *)(buf + len);
    attr->type = hxs(ELEMENT_PACKBITS);
    attr->length = hxs(sizeof(rle_params_t));
    n = (rle_params_t *)(attr->value);
    n->result = hxs(result);
    n->attr = hxs(arg);
    n->thresh = hxs(thresh);

    len = sizeof(attr_t) + sizeof(rle_params_t);
    (*num_elements)++;

#if defined(BUILDING_PC_SIDE) && defined(DEBUG_ELEMENT_CONSTRUCT)
    fprintf(stderr, "  attr %u + packbits %u = length %d\n",
            sizeof(attr_t), sizeof(rle_params_t), len);
#endif
    return len;
}

int construct_vector(unsigned char* buf, int len, int *num_elements,
                    uint16_t result, uint16_t length, uint16_t pattern) {
    attr_t *attr;
    vector_params_t *n;

    attr = (attr_t *)(buf + len);
    attr->type = hxs(ELEMENT_VECTOR);
    attr->length = hxs(sizeof(vector_params_t));
    n = (vector_params_t *)(attr->value);
    n->attr = hxs(result);
    n->length = hxs(length);
    n->pattern = hxs(pattern);

    len = sizeof(attr_t) + sizeof(vector_params_t);
    (*num_elements)++;

#if defined(BUILDING_PC_SIDE) && defined(DEBUG_ELEMENT_CONSTRUCT)
    fprintf(stderr, "  attr %u + vector %u = length %d\n",
            sizeof(attr_t), sizeof(vector_params_t), len);
#endif
    return len;
}
