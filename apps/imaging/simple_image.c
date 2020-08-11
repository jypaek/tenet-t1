
/**
 * A simple Tenet image application.
 *
 * - This application takes and transfers a single image from every mote.
 * - The Tenet mote should have Cyclops camera attached to it, AND
 *   have 'Image' tasklet included in it's binary.
 *
 * @modified June/1/2008
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
#include <time.h>
#include "tenet.h"
#include "cyapp_util.h"
#include "cyclops_query.h"


/* Global variables */
#define ATTR_TAG 9
query_state_t m_qstate;         /* query state/parameters */
result_item_t *outlist = NULL;  /* list of result items (each from different nodes) */
int m_tid = 0;                  /* TID used for the task */
char m_task_string[300];
int close_wait = 0;             /* wait for close done */


/*************************************************************************/

void terminate_application(void) {
    struct result_item *r;
   
    /* if it is first time entering this function, try to cleanly close the task */
    if (!close_wait) {
        close_wait = 1;
        if (m_tid) delete_task(m_tid);
        printf("Waiting for connections to be closed... (tid %d)\n", m_tid);
        return;
    }

    for (r = outlist; r; r = r->next) {
        if (r->incomplete_image) {
            if (r->data_type == CYCLOPS_RESPONSE_IMAGE)
                output_result_to_file(&m_qstate, r);
        }

        printf(" - Mote %d: num_pkts %d ", r->addr, r->num_pkts);
        if (m_qstate.numExpectedPkts > 0)
            printf("(%.1lf%%) ", 100.0*r->num_pkts/(r->image_cnt*m_qstate.numExpectedPkts));
        if (r->image_cnt)
            printf("num_images %d ", r->image_cnt);
        printf("received\n");
    }
    
    remove_outlist(&outlist);
    exit(1);
}

/* Ctrl-C handler */
void sig_int_handler(int signo) {
    terminate_application();
}

/* Task delete/close done handler */
void close_done(uint16_t tid, uint16_t addr) {
    terminate_application();
}

void print_usage(char* argv0) {
    printf("\n## '%s' captures image using cyclops  \n\n", argv0);
    printf("Usage: %s [-n host] [-p port]\n\n", argv0);
    printf("  -n <host> : host on which transport is running. (default: 127.0.0.1)\n");
    printf("  -p <port> : port on which transport is listening for connection. (default: 9998)\n");
    printf("  -r <rate> : fragment report interval (in millisec)\n");
    printf("  -h        : display this help message.\n");
    exit(1);
}


/* Received a response packet from the cyclops node */
void process_response(query_state_t *p, struct response *rlist) {
    uint16_t r_addr = response_mote_addr(rlist);    // get mote ADDR
    struct attr_node *ret_attr;
    result_item_t *r;

    printf("."); fflush(stdout);

    /* find the appropriate result_item structure for this node */
    r = find_outitem(outlist, r_addr);  // find the result item for this node
    if (r == NULL)
        r = add_outitem(&outlist, r_addr);
    r->num_pkts++;      // number of packets received from this node

    ret_attr = response_find(rlist, ATTR_TAG); // get cyclops response attribute that we asked for
    if (ret_attr != NULL) {
        unsigned char *raw_packet;
        cyclops_response_t *cResp;
        int i;

        if ((ret_attr->length * 2) < offsetof(cyclops_response_t, data)) // wrong pkt
            return;

        raw_packet = (unsigned char *)malloc(ret_attr->length * 2);
        for (i = 0; i < ret_attr->length; i++) {
            int tmp = ret_attr->value[i];
            uint16_t tmp2 = (uint16_t) tmp;
            memcpy(&raw_packet[2*i], &tmp2, 2);
        }
        cResp = (cyclops_response_t *) raw_packet;

        if (cResp->type == CYCLOPS_RESPONSE_IMAGE) {
            char *currentbufPtr;
            image_response_t *ir = (image_response_t *) cResp->data;

            if (ir->fragNum < r->lastpkt) {
                printf("Mote %3d : Unexpected frag num, clean up image %3d\n", r->addr, r->image_cnt+1);
                output_result_to_file(p, r);
            }

            currentbufPtr = &r->buffer[(ir->fragNum - 1) * p->getImageQ.fragmentSize];
            memcpy(currentbufPtr, ir->data, ir->dataLength); //Copy the data

            r->recv_bytes += ir->dataLength;
            r->data_type = CYCLOPS_RESPONSE_IMAGE;

            if (ir->fragNum == ir->fragTotal ) {        // when we receive LAST packet
                printf("\n");
                r->incomplete_image = 0;
                output_result_to_file(p, r);            // output result to a file
                r->lastpkt = 0;
            } else { //if (ir->fragNum < ir->fragTotal) // for any packets >1 && <Total
                r->incomplete_image = 1;
                r->lastpkt = ir->fragNum;
            }
        } 
        free(raw_packet);
    }
}


int main(int argc, char **argv)
{
    int ind;
    char tr_host[30];
    int tr_port;
    struct response *resplist;

    printf("\n## %s: get an 128x128 BW image from every mote\n\n", argv[0]);
    
    /* set Ctrl-C handler */
    if (signal(SIGINT, sig_int_handler) == SIG_ERR)
        fprintf(stderr, "Warning: failed to set SINGINT handler");
    register_close_done_handler(&close_done);

    /* clean up our state variable */
    memset(&m_qstate, 0, sizeof(query_state_t));

    /* set bunch of DEFAULT values */
    strcpy(tr_host, "127.0.0.1");
    tr_port = 9998;
    set_query_defaults(&m_qstate);

    /* override some defaults */
    m_qstate.getImageQ.reportRate = 50;  // 20pkts/sec

    for (ind = 1; ind < argc; ind++) {
        /* take options, starting with '-' */
        if (argv[ind][0] == '-') {
            switch (argv[ind][1]) {
                case 'n':
                    strcpy(tr_host, argv[++ind]); break;   // set transport host
                case 'p':
                    tr_port = atoi(argv[++ind]); break;    // set transport port
                case 'r':
                    m_qstate.getImageQ.reportRate = atoi(argv[++ind]); break;
                default : 
                    print_usage(argv[0]); break;
            }
            continue;
        }
        if ((ind + 1) >= argc) {
            printf("Wrong formatting of arguments... %s\n", argv[ind]);
            exit(0);
        }
    }

    /* configure host name and port number for the transport layer */
    config_transport(tr_host, tr_port);

    /* construct the task string to send, based on the processed arguments/options */
    sprintf(m_task_string, "wait(3000)->image(40,%d,1,16,128,128,%d)->send(0)",
            m_qstate.getImageQ.reportRate, ATTR_TAG);   
            // 40byte fragment, no flash, BW 128x128 image.


    /* send out the task through the transport layer */
    m_tid = send_task(m_task_string);
    if (m_tid < 0) {
        printf("tasking failed! \n");
        exit(2); // fail.
    }

    /* receive response packets */
    while (1) {
        resplist = read_response(10000);
        if (resplist == NULL)
            continue;
            
        /* process task response */
        process_response(&m_qstate, resplist);

        response_delete(resplist);
    }
    return 0;
}


