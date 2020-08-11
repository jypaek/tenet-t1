
/**
 * @modified 7/2/2007
 * @author Jeongyeup Paek (jpaek@enl.usc.edu)
 **/

#ifndef CYAPP_UTIL_H
#define CYAPP_UTIL_H

#include "cyclops_query.h"

#define BUF_SIZE 65535  /* the size of the image buffer */

typedef struct query_state {
    int tid;

    // which module? (SNAP, ACTIVE_EYE, etc)
    int nSignal;

    // if nSignal == NEURON_GET_IMAGE
    getImage_query_t getImageQ;         /* GET_IMAGE query parameter*/

    // if nSignal == NEURON_SNAP_ONLY
    snap_query_t snapQ;                 /* SNAP query parameter*/

    // if nSignal == NEURON_ACTIVE_EYE
    activeEye_query_t activeQ;          /* ACTIVE-EYE query parameter*/

    // if nSignal == NEURON_DETECT_OBJECT
    detect_query_t detectQ;             /* DETECT query parameter*/
 
    // if nSignal == NEURON_GET_RLE_IMAGE
    getRle_query_t getRleQ;             /* GET_RLE_IMAGE query parameter*/

    // if nSignal == NEURON_GET_PACKBITS_IMAGE
    getPackBits_query_t getPackBitsQ;   /* GET_PACKBITS_IMAGE query parameter*/

    // if nSignal == NEURON_COPY_IMAGE
    copy_query_t copyQ;                 /* COPY_IMAGE query parameter*/

    int outputFormat;               /* used to determine if we save in dat/bmp format */ 
    int numExpectedPkts;            /* to calculate packet reception ratio */
} query_state_t;

enum {
    OUTPUT_FORMAT_DAT = 0,
    OUTPUT_FORMAT_BMP = 1,
};

/* Response/result data structure per node */
typedef struct result_item {
    struct result_item *next;
    int addr;
    char buffer[BUF_SIZE];      /* buffer pointer to the image data */
    int data_type;
    int num_pkts;
    int image_cnt;
    int incomplete_image;
    int recv_bytes;
    int lastpkt;    // used to track either last seq.# or last fragment.#
} result_item_t;


/********************************************
 * functions for saving data/image
 ********************************************/
void output_result_to_file(query_state_t *p, result_item_t *r);


/********************************************
 * helper functions for initializing query/task
 ********************************************/
void set_query_defaults(query_state_t *p);
int parse_single_argument(char *argv[], int ind, query_state_t *p);
void check_img_size(query_state_t *p);

void print_query_state(query_state_t *p);
void print_cyclops_option_usage();


/********************************************
 * functions for the list of received result
 ********************************************/
struct result_item *add_outitem(result_item_t **outlist_ptr, unsigned int addr);
struct result_item *find_outitem(result_item_t *outlist, unsigned int addr);
void remove_outlist(result_item_t **outlist_ptr);

#endif

