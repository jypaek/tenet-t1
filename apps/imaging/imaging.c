/*
* "Copyright (c) 2006~2007 University of Southern California.
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
 * A Tenet application that fetches images from cyclops nodes
 *
 *
 * @modified Feb/27/2008
 *
 * @author Jeongyeup Paek (jpaek@enl.usc.edu)
 *
 * Embedded Networks Laboratory, University of Southern California
 **/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>
#include <sys/time.h>
#include "tenet.h"
#include "cyapp_util.h"
#include "cyclops_query.h"


#define ATTR_ID1 9               // attribute tag for image data

/* Global variables */
query_state_t m_qstate;         /* query state/parameters */
result_item_t *outlist = NULL;  /* list of result items (each from different nodes) */
int m_reliable = 0;             /* use reliable transport? */
int m_num_times = 1;            /* how many times to run the given task */
int m_repeat_interval = 120;    /* repeat every this seconds */
char m_task_string[300] = {};
int verbosemode = 0;            /* verbose mode. OFF as default for now. */
struct timeval tv_start;        /* query sent time */
struct timeval tv_stop;         /* reception time for the last pkt */
int close_wait = 0;             /* wait for close done */
int m_timeout = 5000;           /* set default timeout to 5 sec if we are not repeating */

/*************************************************************************/

/**
 * Terminate the application at 'Ctrl-C' (SIGINT) by user.
 **/
void terminate_application(void) {
    struct result_item *r;
    
    for (r = outlist; r; r = r->next) {
        if (r->incomplete_image)
            output_result_to_file(&m_qstate, r);

        printf(" - mote %d: num_pkts %d ", r->addr, r->num_pkts);
        if ((m_qstate.numExpectedPkts > 0) && (r->image_cnt > 0))
            printf("(%.1lf%%) ", 100.0*r->num_pkts/(r->image_cnt*m_qstate.numExpectedPkts));
        if (r->image_cnt)
            printf("num_images %d ", r->image_cnt);
        printf("received\n");
    }
    
    printf("\n(%lu seconds)\n", tv_stop.tv_sec - tv_start.tv_sec);

    remove_outlist(&outlist);
    exit(1);
}

/* Ctrl-C handler */
void sig_int_handler(int signo) {
    if (!close_wait) {
        close_wait = 1;
        if (m_qstate.tid) delete_task(m_qstate.tid);
        printf("Waiting for connections to be closed... (tid %d)\n", m_qstate.tid);
    } else {
        terminate_application();
    }
}

void close_done(uint16_t tid, uint16_t addr) {
    terminate_application();
}

void print_usage(char* argv0) {
    printf("\n### '%s' send query and get response from nodes with cyclops \n\n", argv0);
    printf("Usage: %s [-v] [-npt <arg>] [OPTIONS]\n\n", argv0);
    printf("  -n <host>    : host on which transport is running. (default: 127.0.0.1)\n");
    printf("  -p <port>    : port on which transport is listening for connection. (default: 9998)\n");
    printf("  -t <timeout> : time (in milli-sec) to timeout after receiving last packet. (default: inf)\n");
    printf("  -v           : verbose mode. (1=on(default), 0=off)\n\n");
    printf("Usage: %s [-ha]\n\n", argv0);
    printf("  -h           : display this help message.\n");
    printf("  -a           : display detailed help message for [OPTIONS].\n\n");
    printf("Examples:\n\n");
    printf("    ex>  %s  REPORTRATE 50  SIZE 64 64  IMAGETYPE COLOR\n", argv0);
    printf("             : send 64x64 color image, at 20pkts/sec\n");
    printf("    ex>  %s  REPORTRATE 50  REPEAT 5 60  SIZE 128 128  IMAGETYPE BW\n", argv0);
    printf("             : send black&white 128x128 image, every 60sec for 5 times, at 20pkts/sec\n");
    printf("    ex>  %s  MODULE GET_RLE REPORTRATE 100 THRESH 10\n", argv0);
    printf("             : send default image, using run-length encoding w/threshold=10, at 10pkts/sec\n");
    printf("    ex>  %s  MODULE GET_PACKBITS RELIABLE 2 FRAGMENTSIZE 50 REPORTRATE 20 THRESH 0\n", argv0);
    printf("             : send default image, using lossless PackBits encoding, at 50pkts/sec\n");
    printf("               with reliable stream transport. (PackBits must use reliable 2)\n");
    printf("\n");
    exit(1);
}

void process_arguments(int argc, char *argv[], query_state_t *p) {
    int ind;
    char tr_host[30];
    int tr_port;

    /* set bunch of DEFAULT values */
    strcpy(tr_host, "127.0.0.1");
    tr_port = 9998;

    set_query_defaults(p);

    for (ind = 1; ind < argc; ind++) {
        /* take options, starting with '-' */
        if (argv[ind][0] == '-') {
            switch (argv[ind][1]) {
                case 'n':
                    strcpy(tr_host, argv[++ind]); break;   // set transport host
                case 'p':
                    tr_port = atoi(argv[++ind]); break;    // set transport port
                case 'f':
                    p->outputFormat = atoi(argv[++ind]); break;
                case 't':
                    m_timeout = atoi(argv[++ind]); break;
                case 'v':
                    verbosemode = 1; break;
                case 'a':
                    print_cyclops_option_usage();
                    printf(" (extra option)\n");
                    printf("    REPEAT <num> <sec>  : repeat task 'num' times, every 'sec'\n");
                    exit(1);
                default : 
                    print_usage(argv[0]); break;
            }
            continue;
        }
        if ((ind + 1) >= argc) {
            printf("Wrong formatting of arguments... %s\n", argv[ind]);
            exit(0);
        }
    /************ Repeat options ***********/
        else if (strncasecmp(argv[ind], "REPEAT", 7) == 0) {    // REPEAT
            m_num_times = atoi(argv[++ind]);
            m_repeat_interval = atoi(argv[++ind]);
        }
    /************ Generic options ***********/
        else if (strncasecmp(argv[ind], "RELIABLE", 3) == 0) {  // RELIABLE
            m_reliable = atoi(argv[++ind]);
        }
        else if ((ind = parse_single_argument(argv, ind, p)) < 0) {
            exit(0);
        }
    }

    /* check image parameters for erros. set total number of packets */
    check_img_size(p);  // do not remove this.... required.

    /* print out the selected options, including defaults */
    printf("RELIABLE     = %d\n", m_reliable);
    if (m_num_times == 0) 
        printf("REPEAT       = every %d sec\n", m_repeat_interval);
    else if (m_num_times > 1)
        printf("REPEAT       = every %d sec, for %d times.\n", m_repeat_interval, m_num_times);

    if (m_num_times != 1)               // if repeating,
        if ((m_timeout != -1) &&            // if timeout is not infinite &&
            (m_timeout <= m_repeat_interval))   // if timeout is less than interval
            m_timeout = m_repeat_interval + 3000;   // set timeout greater than interval.

    print_query_state(p);
    
    /* configure host name and port number for the transport layer */
    config_transport(tr_host, tr_port);
}


/* decode simple RLE directly (does not buffer) from *in to *out */
int decode_rle(char *in, int inlen, char *out) {
    unsigned char val, runlen;
    int codelen = 0;
    int rawlen = 0;
    while (codelen < inlen) {
        val = (unsigned char) in[codelen++];
        runlen = (unsigned char) in[codelen++];

        while (runlen > 0) {
            out[rawlen++] = val;
            if (rawlen > BUF_SIZE) break;   // error, abort
            runlen--;
        }
        if (rawlen > BUF_SIZE) {
            printf("invalid (decoded) data length during simple RLE decoding.\n");
            break;   // error, abort
        }
    }
    return rawlen;
}

/* decode PackBits RLE from *in to *out */
int decode_packbits(char *in, int inlen, char *out) {
    char outbuf[BUF_SIZE];
    unsigned char val;      /* current character */
    int8_t lenbyte;         /* (signed) run/copy count */
    unsigned int runlen;    /* actual run length */
    unsigned int rawlen = 0;
    unsigned int codelen = 0;

    if (inlen > BUF_SIZE) {
        printf("Error! input length too long in PackBits\n");
        exit(0);
    }

    while (codelen+1 < inlen) {

        lenbyte = in[codelen++];

        if (lenbyte == -128)    // dummy value
            continue;

        if (lenbyte < 0) {
            runlen = 1 - (int)lenbyte;

            val = in[codelen++];

            while (runlen > 0) {
                outbuf[rawlen++] = val;
                if (rawlen >= BUF_SIZE) break;   // error, abort
                runlen--;
            }
        } else {
            runlen = 1 + (int)lenbyte;

            while (runlen > 0) {
                val = in[codelen++];

                outbuf[rawlen++] = val;
                if (rawlen >= BUF_SIZE) break;   // error, abort
                runlen--;
                if (codelen >= inlen) break;
            }
        }
        if (rawlen >= BUF_SIZE) break;   // error, abort
    }
    if (rawlen >= BUF_SIZE) {
        printf("Error! invalid (decoded) data length during PackBits RLE decoding.\n");
        exit(0);
    }

    memcpy(out, outbuf, rawlen);
    return rawlen;
}


/* Received a response attribute from a cyclops */
void process_cyclops_response_attr(query_state_t *p, result_item_t *r, struct attr_node *ret_attr) {
    unsigned char raw_packet[128];  /* buffer for content of received packet */
    cyclops_response_t *cResp = (cyclops_response_t *)raw_packet;
    int i;

    if ((ret_attr->length * 2) < offsetof(cyclops_response_t, data)) {
        if (verbosemode) {
            print_neuron_module_name(p->nSignal);
            printf("response = %d\n", ret_attr->value[0]);
        } else {
            printf("0");
        }
        return;
    } else if (ret_attr->length > 64) {
        printf("Error: ret_attr->length %d >> 64\n", r->recv_bytes);
        exit(1);
    } else if (r->recv_bytes >= BUF_SIZE) {
        printf("Error: recv_bytes %d is already >= BUF_SIZE %d\n", r->recv_bytes, BUF_SIZE);
        exit(1);
    }
    
    /* 'read_response' API of tenet transport layer assumes that
       all data within attributes are 16-bit integers.
       Hence, each value in 'attr_node->value[]' are 16-bit integers.
       We need to re-construct the imageData[] by copying each
       16-bit integers into a chunk of char *data structure */
    for (i = 0; i < ret_attr->length; i++) {
        int tmp = ret_attr->value[i];
        uint16_t tmp2 = (uint16_t) tmp;
        memcpy(&raw_packet[2*i], &tmp2, 2);
    }
    
    /* if the response data is a fragment of an image... */
    if (cResp->type == CYCLOPS_RESPONSE_IMAGE) {
        char *currentbufPtr;
        image_response_t *ir = (image_response_t *) cResp->data;

        if (ir->fragNum < r->lastpkt) {
            output_result_to_file(p, r);
            r->recv_bytes = 0;
        }

        //Set pointer to correct buffer location based on fragment number.
        currentbufPtr = &r->buffer[(ir->fragNum - 1) * p->getImageQ.fragmentSize];
        memcpy(currentbufPtr, ir->data, ir->dataLength); //Copy the data

        r->recv_bytes += ir->dataLength;
        r->data_type = CYCLOPS_RESPONSE_IMAGE;
        if (verbosemode)
            printf("Image: Fragment [%d/%d] RecvBytes [%d]\n", ir->fragNum, ir->fragTotal, r->recv_bytes);
        
        if (ir->fragNum == ir->fragTotal ) {        // when we receive LAST packet
            r->incomplete_image = 0;
            if (!verbosemode) printf("\n");
            output_result_to_file(p, r);            // output result to a file
            r->lastpkt = 0;
            r->recv_bytes = 0;
        } else { //if (ir->fragNum < ir->fragTotal) // for any packets >1 && <Total
            r->incomplete_image = 1;
            r->lastpkt = ir->fragNum;
        }
    } 
    else if (cResp->type == CYCLOPS_RESPONSE_CAPTURE_PARAM) {
        capture_param_t *cp = (capture_param_t *)cResp->data;
        printf("\nCyclops capture parameters response received.\n");
        print_neuron_module_name(p->nSignal);
        print_capture_parameters(cp); printf("\n");
    }
    else if (cResp->type == CYCLOPS_RESPONSE_RESULT) {
        result_response_t *dr = (result_response_t *) cResp->data;
        print_neuron_module_name(p->nSignal);
        printf("\nCyclops query result = %d\n", dr->result);
    } 
    else if (cResp->type == CYCLOPS_RESPONSE_FAIL) {
        print_neuron_module_name(p->nSignal);
        printf("\nCyclops query execution FAIL.\n");
    } 
    else if (cResp->type == CYCLOPS_RESPONSE_SUCCESS) {
        print_neuron_module_name(p->nSignal);
        printf("\nCyclops query execution SUCCESS.\n");
    } 
    else if (cResp->type == CYCLOPS_RESPONSE_RLE_IMAGE) {
        char *currentbufPtr;
        rle_image_response_t *ir = (rle_image_response_t *) cResp->data;

        r->recv_bytes += ir->dataLength;
        if (verbosemode)
            printf("RLE Image: StartByte [%d] RecvBytes [%d]\n", ir->seqNum, r->recv_bytes);
        
        currentbufPtr = &r->buffer[ir->seqNum];  // assume reliable delivery
        decode_rle((char *)ir->data, ir->dataLength, currentbufPtr);

        if (cResp->more_left == 0) {
            r->incomplete_image = 0;
            r->data_type = CYCLOPS_RESPONSE_IMAGE;
            if (!verbosemode) printf("\n");
            output_result_to_file(p, r);
            r->lastpkt = 0;
            r->recv_bytes = 0;
        } else { // more_left == 1
            r->incomplete_image = 1;
        }
    } 
    else if (cResp->type == CYCLOPS_RESPONSE_PACKBITS_IMAGE) {
        char *currentbufPtr;
        rle_image_response_t *ir = (rle_image_response_t *) cResp->data;

        currentbufPtr = &r->buffer[r->recv_bytes];  // assume reliable delivery
        memcpy(currentbufPtr, ir->data, ir->dataLength); //Copy the data

        r->recv_bytes += ir->dataLength;
        if (verbosemode)
            printf("PackBits Image: SeqNum [%d] RecvBytes [%d]\n", ir->seqNum, r->recv_bytes);

        if ((ir->seqNum != (r->lastpkt+1)) && (ir->seqNum != r->lastpkt)) {
            printf("Error: SeqNum %d >> LastPkt %d\n", ir->seqNum, r->lastpkt);
            printf("PackBits RLE will work only with 100%% reliable data delivery!!\n");
            exit(1);
        }

        if (cResp->more_left == 0) {
            decode_packbits(r->buffer, r->recv_bytes, r->buffer);
            r->data_type = CYCLOPS_RESPONSE_IMAGE;      // after decoding
            r->incomplete_image = 0;
            if (!verbosemode) printf("\n");
            output_result_to_file(p, r);
            r->lastpkt = 0;
            r->recv_bytes = 0;
        } else { // more_left == 1
            r->data_type = CYCLOPS_RESPONSE_PACKBITS_IMAGE;  // before decoding
            r->incomplete_image = 1;
            r->lastpkt = ir->seqNum;
        }
    }
    else {
        printf("Unknown cyclops response type\n");
    }
}


/* Received a response packet from the cyclops node */
void process_response(query_state_t *p, struct response *rlist) {
    uint16_t r_tid = response_tid(rlist);           // get TID
    uint16_t r_addr = response_mote_addr(rlist);    // get mote ADDR
    struct attr_node *ret_attr;
    result_item_t *r;

    if (verbosemode) {
        printf("received response from node %d  TID %d : ", r_addr, r_tid);
    } else {
        printf(".");
    }

    /* find the appropriate result_item structure for this node */
    r = find_outitem(outlist, r_addr);  // find the result item for this node
    if (r == NULL)
        r = add_outitem(&outlist, r_addr);
    r->num_pkts++;      // number of packets received from this node

    ret_attr = response_find(rlist, ATTR_ID1); // get cyclops response attribute that we asked for
    if (ret_attr != NULL)
        process_cyclops_response_attr(p, r, ret_attr);
        
    /* write down the reception time of the last pkt received */
    gettimeofday(&tv_stop, NULL);
}


/* construct the task string to send, based on the processed arguments/options */
void construct_app_task_string(query_state_t *p) {
    char main_task[100] = {}, task_header[150] = {};
    
    /* - check for repeat options... construct task header */
    if (m_num_times == 0)       // INFINITE repeat
        sprintf(task_header, "wait_n_repeat(5000,%d)->", m_repeat_interval*1000);
    else if (m_num_times > 1)   // finite numTimes
        sprintf(task_header, "wait_n_repeat(5000,%d)->count(2,0,1)->gt(3,2,'%d')->deletetaskif(3)->deleteattribute(2)->deleteattribute(3)->",
                                m_repeat_interval*1000, m_num_times);
    //else if (m_num_times == 1)           // Once. no need for repeat

/************************ ****************** *************************/
    /* - GET_IMAGE: take a picture and get it */
    if (p->nSignal == NEURON_GET_IMAGE) {
        sprintf(main_task, "image_get(%d,%d,%d,%d,%d,%d,%d,%d)->send(%d)",
                p->getImageQ.imageAddr,
                p->getImageQ.fragmentSize, 
                p->getImageQ.reportRate, 
                p->getImageQ.snapQ.enableFlash, p->getImageQ.snapQ.type,
                p->getImageQ.snapQ.size.x, p->getImageQ.snapQ.size.y,
                ATTR_ID1, m_reliable);
        sprintf(m_task_string, "%s%s", task_header, main_task);
    }
    /* - DETECT: take a picture, compare it with previous, and detect difference */
    else if (p->nSignal == NEURON_DETECT_OBJECT) {
        if (p->detectQ.type == DETECT_SET_PARAM) {
            sprintf(main_task, "image_detect_param(%d,%d,%d,%d,%d,%d)", // don't need reply
                p->detectQ.snapQ.size.x,
                p->detectQ.detectParam.RACoeff,
                p->detectQ.detectParam.skip,
                p->detectQ.detectParam.illCoeff,
                p->detectQ.detectParam.range,
                p->detectQ.detectParam.detectThresh);
        } else if (p->detectQ.type == DETECT_RESET_BACKGROUND) {   // no reply
            sprintf(main_task, "image_detect_reset()");
        } else if (p->detectQ.type == DETECT_SET_BACKGROUND) {     // no reply
            sprintf(main_task, "image_detect_set()");
        } else {    // RUN_NEW or RUN_OLD
            sprintf(main_task, "image_detect(%d,%d,%d,%d,%d)->send(1)",
                    p->detectQ.type, p->detectQ.use_segment,
                    p->detectQ.snapQ.enableFlash, p->detectQ.snapQ.size.x,
                    ATTR_ID1); // attribute tag for detect output
        }
        sprintf(m_task_string, "%s%s", task_header, main_task);
    }
    /* - ACTIVE_EYE: set/get camera parameters */
    else if (p->nSignal == NEURON_ACTIVE_EYE) {
        if (p->activeQ.type == ACTIVE_EYE_SET_PARAMS) {
            sprintf(m_task_string, "image_set_capture_params(%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d)->send(1)",
                    p->activeQ.cp.offset.x, p->activeQ.cp.offset.y,
                    p->activeQ.cp.inputSize.x, p->activeQ.cp.inputSize.y,
                    p->activeQ.cp.testMode, p->activeQ.cp.exposurePeriod,
                    p->activeQ.cp.analogGain.red, p->activeQ.cp.analogGain.green,
                    p->activeQ.cp.analogGain.blue, p->activeQ.cp.digitalGain.red,
                    p->activeQ.cp.digitalGain.green, p->activeQ.cp.digitalGain.blue,
                    p->activeQ.cp.runTime, ATTR_ID1);
        } else if (p->activeQ.type == ACTIVE_EYE_GET_PARAMS) {
            sprintf(m_task_string, "image_get_capture_params(%d)->send(1)", ATTR_ID1);
        } else {
            printf("ERROR...\n"); exit(0);
        }
    } else if (p->nSignal == NEURON_GET_RLE_IMAGE) {
        sprintf(main_task, "image_getRle(%d,%d,%d,%d,%d,%d,%d,%d,%d)->send(%d)",
                p->getRleQ.imageAddr,
                p->getRleQ.fragmentSize, 
                p->getRleQ.reportRate, 
                p->getRleQ.snapQ.enableFlash, p->getRleQ.snapQ.type,
                p->getRleQ.snapQ.size.x, p->getRleQ.snapQ.size.y,
                p->getRleQ.threshold,
                ATTR_ID1, m_reliable);
        sprintf(m_task_string, "%s%s", task_header, main_task);
    } else if (p->nSignal == NEURON_GET_PACKBITS_IMAGE) {
        sprintf(main_task, "image_getPackBits(%d,%d,%d,%d,%d,%d,%d,%d,%d)->send(%d)",
                p->getPackBitsQ.imageAddr,
                p->getPackBitsQ.fragmentSize, 
                p->getPackBitsQ.reportRate, 
                p->getPackBitsQ.snapQ.enableFlash, p->getPackBitsQ.snapQ.type,
                p->getPackBitsQ.snapQ.size.x, p->getPackBitsQ.snapQ.size.y,
                p->getPackBitsQ.threshold,
                ATTR_ID1, m_reliable);
        sprintf(m_task_string, "%s%s", task_header, main_task);
    } else if (p->nSignal == NEURON_COPY_IMAGE) {
        sprintf(main_task, "image_copy(%d,%d,%d,%d,%d,%d)",
                p->copyQ.fromImageAddr,
                p->copyQ.toImageAddr,
                p->copyQ.snapQ.enableFlash, p->copyQ.snapQ.type,
                p->copyQ.snapQ.size.x, p->copyQ.snapQ.size.y);
        sprintf(m_task_string, "%s%s", task_header, main_task);
    } else {
        printf("ERROR...\n"); exit(0);
    }
}


int main(int argc, char **argv)
{
    struct response *resplist;
    query_state_t *p = &m_qstate;

    /* set Ctrl-C handler */
    if (signal(SIGINT, sig_int_handler) == SIG_ERR)
        fprintf(stderr, "Warning: failed to set SINGINT handler");
    register_close_done_handler(&close_done);

    /* clean up our state variable */
    memset(&m_qstate, 0, sizeof(query_state_t));

    /* parse command line arguements */
    process_arguments(argc, argv, p);
    /* config_transport is done within process_arguments */


    /* construct the task string to send, based on the processed arguments/options */
    construct_app_task_string(p);  // into m_task_string

    /* do you want to have a look at the task string? */
    //if (verbosemode) {
        printf("TASK STRING  = %s\n", m_task_string); fflush(stdout);
    //}

    /* send out the task through the transport layer */
    p->tid = send_task(m_task_string);
    if (p->tid < 0) exit(1); // fail.

    /* check the time that the task was sent */
    gettimeofday(&tv_start, NULL);
    gettimeofday(&tv_stop, NULL);   // initialize end time with start time.
    
    /* receive response packets */
    while (1) {
        resplist = read_response(m_timeout);
        if (resplist == NULL) {          // did not get any attribute.
            switch(get_error_code()) {
                case TIMEOUT:
                    sig_int_handler(0);
                    continue;
                case MOTE_ERROR:    //ignore mote error
                    continue;
                default:
                    continue;
            }
        }
            
        /* process task response */
        process_response(&m_qstate, resplist);
        
        fflush(stdout);
        response_delete(resplist);
    }
    return 0;
}


