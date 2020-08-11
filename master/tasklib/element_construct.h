/*
 * Header File
 * Translate a tasklet string into tasklet packet format (like binary format) for motes to understand it and be able to get the tasklet parameters.
 * Every created tasklet should have its construct.
 *
 */
#ifndef ELEMENT_CONSTRUCT_H
#define ELEMENT_CONSTRUCT_H

#include "nx.h"
#ifdef BUILDING_PC_SIDE
#include "common.h"
#endif
#include "tenet_task.h"

/**
 * initialize and finalize a task packet
 **/
int construct_init(unsigned char* buf);
int construct_finalize(unsigned char* buf, int num_elements);


/**
 * construct a delete-task packet
 **/
int construct_delete(unsigned char* buf);



/**
 * construct each tasklet within a task
 **/

/*** default Tenet tasklets ***/
int construct_sendpkt(unsigned char* buf, int len, int *num_elements, uint8_t e2e_ack);
int construct_sendstr(unsigned char* buf, int len, int *num_elements);
int construct_sendrcrt(unsigned char* buf, int len, int *num_elements, uint16_t irate);
int construct_send(   unsigned char* buf, int len, int *num_elements, uint16_t sendtype);
int construct_get(    unsigned char* buf, int len, int *num_elements, 
                      uint16_t tag, uint16_t value);
int construct_issue(  unsigned char* buf, int len, int *num_elements, 
                      uint32_t starttime, uint32_t period, uint8_t abst);
int construct_count(  unsigned char* buf, int len, int *num_elements, 
                      uint16_t tag, int16_t count, int16_t rate);
int construct_logical(unsigned char* buf, int len, int *num_elements,
                      uint16_t result, uint16_t tag, uint8_t optype, 
                      uint8_t argtype, uint16_t arg1);
int construct_bit(    unsigned char* buf, int len, int *num_elements,
                      uint16_t result, uint16_t tag, uint8_t optype, 
                      uint8_t argtype, uint16_t arg1);
int construct_arith(  unsigned char* buf, int len, int *num_elements,
                      uint16_t result, uint16_t nAttr, uint8_t optype, 
                      uint8_t argtype, uint16_t arg);
int construct_comparison(unsigned char* buf, int len, int *num_elements,
                      uint16_t result, uint16_t nAttr, uint8_t optype, 
                      uint8_t argtype, uint16_t arg);
int construct_stats(  unsigned char* buf, int len, int *num_elements,
                      uint16_t result, uint16_t nAttr, uint16_t optype);
int construct_pack(   unsigned char* buf, int len, int *num_elements,
                      uint16_t attr, uint16_t size, uint8_t block);
int construct_attribute(unsigned char* buf, int len, int *num_elements,
                      uint16_t result, uint16_t attr, uint8_t optype);
int construct_actuate(unsigned char* buf, int len, int *num_elements,
                      uint8_t chan, uint8_t argtype, uint16_t arg1);
int construct_reboot( unsigned char* buf, int len, int *num_elements);
int construct_storage(unsigned char* buf, int len, int *num_elements, 
                      uint16_t tagIn, uint16_t tagOut, uint8_t store);
int construct_deleteAttributeIf(unsigned char *buf, int len, int *num_elements,
                                uint16_t arg, uint8_t argtype, uint16_t tag, uint8_t deleteAll);
int construct_deleteActiveTaskIf(unsigned char *buf, int len, int *num_elements,
                                uint16_t arg, uint8_t argtype);
int construct_deleteTaskIf(     unsigned char *buf, int len, int *num_elements,
                                uint16_t arg, uint8_t argtype);
int construct_voltage(unsigned char* buf, int len, int *num_elements, uint16_t out0);


/*** sensing(sampling) related tasklets ***/
int construct_sample(unsigned char* buf, int len, int *num_elements, 
                     uint32_t interval, uint16_t count, uint8_t repeat, uint8_t ch0, uint16_t out0);
int construct_fastsample(unsigned char* buf, int len, int *num_elements, 
                     int rate, int count, int numChannels, int ch0, int out0,
                     int ch1, int out1, int ch2, int out2);


/*** platform dependant tasklets ***/
int construct_sample_rssi(unsigned char* buf, int len, int *num_elements, uint16_t tag);
int construct_user_button(unsigned char* buf, int len, int *num_elements, int repeat);


/*** image/cyclops tasklets ***/
int construct_image_snap(  unsigned char* buf, int len, int *num_elements, 
                           uint8_t flash, uint8_t imgtype, 
                           uint8_t xsize, uint8_t ysize, uint16_t out0);
int construct_image_get (  unsigned char* buf, int len, int *num_elements, 
                           uint8_t imageAddr, uint8_t fragsize, uint16_t reportRate,
                           uint8_t flash, uint8_t imgtype, 
                           uint8_t xsize, uint8_t ysize, uint16_t out0);
int construct_image_detect(unsigned char* buf, int len, int *num_elements, 
                           uint8_t type, uint8_t use_segment,
                           uint8_t enableFlash, uint8_t ImgRes, uint16_t out0);
int construct_image_detect_params(unsigned char* buf, int len, int *num_elements, 
                           uint8_t ImgRes, uint8_t RACoeff, uint8_t skip,
                           uint8_t illCoeff, uint8_t range, uint8_t detectThresh);
int construct_image_capture_params(unsigned char* buf, int len, int *num_elements, 
                           int type,
                           int16_t offsetx, int16_t offsety, 
                           uint16_t inputx, uint16_t inputy,
                           uint8_t testmode, uint16_t exposure,
                           uint8_t a_red, uint8_t a_green, uint8_t a_blue,
                           uint16_t d_red, uint16_t d_green, uint16_t d_blue,
                           uint16_t runtime, uint16_t out0);
int construct_image_reboot(unsigned char* buf, int len, int *num_elements);
int construct_image_getRle(unsigned char* buf, int len, int *num_elements, 
                           uint8_t imageAddr, uint8_t fragsize, uint16_t reportRate,
                           uint8_t flash, uint8_t imgtype, 
                           uint8_t xsize, uint8_t ysize,
                           uint8_t threshold, uint16_t out0);
int construct_image_getPackBits(unsigned char* buf, int len, int *num_elements, 
                           uint8_t imageAddr, uint8_t fragsize, uint16_t reportRate,
                           uint8_t flash, uint8_t imgtype, 
                           uint8_t xsize, uint8_t ysize, 
                           uint8_t threshold, uint16_t out0);
int construct_image_copy(  unsigned char* buf, int len, int *num_elements,
                           uint8_t fromImageAddr, uint8_t toImageAddr,
                           uint8_t flash, uint8_t imgtype, 
                           uint8_t xsize, uint8_t ysize);


/*** tasklets under devel ***/
int construct_memoryop(unsigned char* buf, int len, int *num_elements, 
                      int addr, int value, int op, int type);
int construct_mda400( unsigned char* buf, int len, int *num_elements, 
                      uint16_t us_sample_interval, uint16_t num_kilo_samples,
                      uint16_t tag_x, uint16_t tag_y, uint16_t tag_z, uint16_t tag_time,
                      uint8_t channel_select, uint8_t samples_per_buffer);
int construct_onset_detector(unsigned char* buf, int len, int *num_elements, 
                      int8_t noiseThresh, int8_t signalThresh, uint16_t startDelay, 
                      uint16_t tag_in, uint16_t tag_out, uint16_t tag_info,
                      uint8_t adaptiveMean);
int construct_firlpfilter(unsigned char* buf, int len, int *num_elements, 
                      uint16_t tag_in, uint16_t tag_out);
int construct_mda300(unsigned char* buf, int len, int *num_elements,
                     uint8_t channel, uint8_t channelType,
                     tag_t outName, uint8_t param);


int construct_rle(unsigned char* buf, int len, int *num_elements,
                    uint16_t result, uint16_t arg, uint16_t thresh);
int construct_packbits(unsigned char* buf, int len, int *num_elements,
                    uint16_t result, uint16_t arg, uint16_t thresh);
int construct_vector(unsigned char* buf, int len, int *num_elements,
                    uint16_t result, uint16_t length, uint16_t pattern);
#endif

