
/**
 * A Tenet application for James Reserve pitfall trap array deployment
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
#include <time.h>
#include "tenet.h"
#include "cyapp_util.h"
#include "cyclops_query.h"


#define ATTR_ID1 9               // attribute tag for image data
#define ATTR_ID2 8               // attribute tag for detection result

/* Global variables */
query_state_t m_qstate;         /* query state/parameters */
result_item_t *outlist = NULL;  /* list of result items (each from different nodes) */
int m_tid = 0;                  /* TID used for the task */
int m_reliable = 0;             /* use reliable transport? */
int m_repeat_interval = 0;
char m_task_string[300];
struct timeval tv_start;        /* query sent time */
struct timeval tv_stop;         /* reception time for the last pkt */
int close_wait = 0;             /* wait for close done */
int m_total_num_images = 0;        /* total number of images received */
time_t m_time;

/*************************************************************************/

/**
 * Terminate the application at 'Ctrl-C' (SIGINT) by user.
 **/
void terminate_application(void) {
    struct result_item *r;
    
    /* if it is first time entering this function, try to cleanly close the task */
    if (!close_wait) {
        close_wait = 1;
        if (m_tid) delete_task(m_tid);
        printf("Waiting for connections to be closed... (tid %d)\n", m_tid);
        return;
    }

    printf("\nProgram terminating.........\n");
    m_time = time(NULL);
    printf("%s", asctime(localtime(&m_time)));

    for (r = outlist; r; r = r->next) {
        if (r->incomplete_image) {
            output_result_to_file(&m_qstate, r);
            m_total_num_images++;
        }

        printf(" - Mote %d: num_pkts %d ", r->addr, r->num_pkts);
        if (m_qstate.numExpectedPkts > 0)
            printf("(%.1lf%%) ", 100.0*r->num_pkts/(r->image_cnt*m_qstate.numExpectedPkts));
        if (r->image_cnt)
            printf("num_images %d ", r->image_cnt);
        printf("received\n");
    }
    printf("\nTotal: %d images (%lu seconds)\n", m_total_num_images, tv_stop.tv_sec - tv_start.tv_sec);

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
    printf("  n : host on which transport is running. (default: 127.0.0.1)\n");
    printf("  p : port on which transport is listening for connection. (default: 9998)\n");
    printf("  h : display this help message.\n");
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

    /* override some defaults */
    m_reliable = 2;                     // reliable stream transport
    p->getImageQ.reportRate = 142;      // 7pkts/sec
    m_repeat_interval = 120;            // every 2 min

    for (ind = 1; ind < argc; ind++) {
        /* take options, starting with '-' */
        if (argv[ind][0] == '-') {
            switch (argv[ind][1]) {
                case 'n':
                    strcpy(tr_host, argv[++ind]); break;   // set transport host
                case 'p':
                    tr_port = atoi(argv[++ind]); break;    // set transport port
                default : 
                    print_usage(argv[0]); break;
            }
            continue;
        }
        if ((ind + 1) >= argc) {
            printf("Wrong formatting of arguments... %s\n", argv[ind]);
            exit(0);
        }
    /************ Generic options ***********/
        else if (strncasecmp(argv[ind], "RELIABLE", 3) == 0) {  // RELIABLE
            m_reliable = atoi(argv[++ind]);
        }
        else if ((ind = parse_single_argument(argv, ind, p)) < 0) {
            exit(0);
        }
    }

    /* set/check total number of bytes and packets */
    check_img_size(p);

    /* print out the selected options, including defaults */
    //printf("RELIABLE     = %d\n", m_reliable);
    //print_cyclops_query_options(p);
    
    /* configure host name and port number for the transport layer */
    config_transport(tr_host, tr_port);
}


/* Received a response attribute from a cyclops */
void process_cyclops_response_attr(query_state_t *p, result_item_t *r, struct attr_node *ret_attr) {
    unsigned char *raw_packet;
    cyclops_response_t *cResp;
    int i;

    if ((ret_attr->length * 2) < offsetof(cyclops_response_t, data)) {
        m_time = time(NULL);
        printf("Mote %3d (Nothing detected %d) - ", r->addr, ret_attr->value[0]);
        printf("%s", asctime(localtime(&m_time)));
        return;
    }
    
    raw_packet = (unsigned char *)malloc(ret_attr->length * 2);
    for (i = 0; i < ret_attr->length; i++) {
        int tmp = ret_attr->value[i];
        uint16_t tmp2 = (uint16_t) tmp;
        memcpy(&raw_packet[2*i], &tmp2, 2);
    }
    cResp = (cyclops_response_t *) raw_packet;
    
    /* if the response data is a fragment of an image... */
    if (cResp->type == CYCLOPS_RESPONSE_IMAGE) {
        char *currentbufPtr;
        image_response_t *ir = (image_response_t *) cResp->data;

        if (ir->fragNum < r->lastpkt) {
            printf("Mote %3d : Unexpected frag num, clean up image %3d\n", r->addr, r->image_cnt+1);
            m_time = time(NULL);
            printf("%s", asctime(localtime(&m_time)));
            output_result_to_file(p, r);
            m_total_num_images++;
        }

        //Set pointer to correct buffer location based on fragment number.
        currentbufPtr = &r->buffer[(ir->fragNum - 1) * p->getImageQ.fragmentSize];
        memcpy(currentbufPtr, ir->data, ir->dataLength); //Copy the data

        r->recv_bytes += ir->dataLength;
        r->data_type = CYCLOPS_RESPONSE_IMAGE;
        printf("Fragment [%d/%d] RecvBytes [%d]\n", ir->fragNum, ir->fragTotal, r->recv_bytes);
        
        if (ir->fragNum == ir->fragTotal ) {        // when we receive LAST packet
            m_time = time(NULL);
            printf("\n");
            printf("%s", asctime(localtime(&m_time)));
            r->incomplete_image = 0;
            output_result_to_file(p, r);            // output result to a file
            m_total_num_images++;
            r->lastpkt = 0;
        } else { //if (ir->fragNum < ir->fragTotal) // for any packets >1 && <Total
            r->incomplete_image = 1;
            r->lastpkt = ir->fragNum;
        }
    } 
    else {
        printf("Unknown cyclops response type\n");
    }
    
    free(raw_packet);
}


/* Received a response packet from the cyclops node */
void process_response(query_state_t *p, struct response *rlist) {
    uint16_t r_addr = response_mote_addr(rlist);    // get mote ADDR
    struct attr_node *ret_attr;
    result_item_t *r;

    /* find the appropriate result_item structure for this node */
    r = find_outitem(outlist, r_addr);  // find the result item for this node
    if (r == NULL)
        r = add_outitem(&outlist, r_addr);
    r->num_pkts++;      // number of packets received from this node

    /* ATTR_ID1 contains the image fragment */
    ret_attr = response_find(rlist, ATTR_ID1); // get cyclops response attribute that we asked for
    if (ret_attr != NULL) {
        printf(".");
        process_cyclops_response_attr(p, r, ret_attr);
    }

    /* ATTR_ID2 contains object detection result */
    ret_attr = response_find(rlist, ATTR_ID2); // get cyclops response attribute that we asked for
    if (ret_attr != NULL) {
        r->num_pkts--;  // let's not count the object detection result into prr
        process_cyclops_response_attr(p, r, ret_attr);
    }

    /* write down the reception time of the last pkt received */
    gettimeofday(&tv_stop, NULL);
}


/* construct the task string to send, based on the processed arguments/options */
void construct_app_task_string(query_state_t *p) {

    /************************ pitfall trap deployment task  *************************/
    sprintf(m_task_string, "wait_n_repeat(5000,%d)->image_detect(%d,%d,%d,%d,%d)->count(2,0,1)->mod(2,2,'15')->eq(2,2,'0')->or(%d,%d,2)->store(%d,5)->deleteattributeif(%d,2)->deleteattributeif(%d,%d)->send(1)->retrieve(5)->not(5,5)->deleteactivetaskif(5)->deleteattribute(5)->image_detect_reset()->image_fetch(0,0,%d,16,%d,%d,%d,%d)->send(%d)", 
                m_repeat_interval*1000,
                p->detectQ.type, p->detectQ.use_segment,
                p->detectQ.snapQ.enableFlash, p->detectQ.snapQ.size.x,
                ATTR_ID2, ATTR_ID2, ATTR_ID2, ATTR_ID2, ATTR_ID2, ATTR_ID2, ATTR_ID2,
                p->getImageQ.fragmentSize, 
                p->getImageQ.snapQ.size.x, p->getImageQ.snapQ.size.y,
                ATTR_ID1, 
                p->getImageQ.reportRate, 
                m_reliable);
}


int main(int argc, char **argv)
{
    struct response *resplist;

    printf("\n");
    printf("#################################################################\n");
    printf("## jr_deploy: Task Tenet-Cyclops nodes to detect & send images ##\n");
    printf("#################################################################\n");
    printf("\n");
    
    /* set Ctrl-C handler */
    if (signal(SIGINT, sig_int_handler) == SIG_ERR)
        fprintf(stderr, "Warning: failed to set SINGINT handler");
    register_close_done_handler(&close_done);

    /* clean up our state variable */
    memset(&m_qstate, 0, sizeof(query_state_t));

    /* parse command line arguements */
    process_arguments(argc, argv, &m_qstate);
    /* config_transport is done within process_arguments */

    /* construct the task string to send, based on the processed arguments/options */
    construct_app_task_string(&m_qstate);  // into m_task_string

    /* do you want to have a look at the task string? */
    printf("TASK STRING: %s\n", m_task_string);
    fflush(stdout);

    /* send out the task through the transport layer */
    m_tid = send_task(m_task_string);
    if (m_tid < 0) {
        printf("tasking failed! \n");
        exit(2); // fail.
    } else {
        printf("TID        : %03d\n", m_tid);
    }
    m_qstate.tid = m_tid;

    /* check the time that the task was sent */
    gettimeofday(&tv_start, NULL);
    gettimeofday(&tv_stop, NULL);   // initialize end time with start time.
    m_time = time(NULL);
    printf("%s", asctime(localtime(&m_time)));
    
    /* receive response packets */
    while (1) {
        resplist = read_response(-1);
        if (resplist == NULL) {          // did not get any attribute.
            continue;
        }
            
        /* process task response */
        process_response(&m_qstate, resplist);
        
        fflush(stdout);
        response_delete(resplist);
    }
    return 0;
}


