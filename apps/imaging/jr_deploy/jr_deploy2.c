
/**
 * A Tenet application for James Reserve pitfall trap array deployment
 *
 * - This is a very simple secondary application that fetches
 *   new image every T seconds without object detection.
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

/* Global variables */
query_state_t m_qstate;         /* query state/parameters */
result_item_t *outlist = NULL;  /* list of result items (each from different nodes) */
int m_outlist_len = 0;          /* length of result item list */
int m_tid = 0;                  /* TID used for the task */
int m_reliable = 0;             /* use reliable transport? */
int m_repeat_interval = 0;
char m_task_string[300];
struct timeval tv_start;        /* query sent time */
struct timeval tv_stop;         /* reception time for the last pkt */
int close_wait = 0;             /* wait for close done */
int m_total_num_images = 0;     /* total number of images received */
int m_expected_num_images = -1;
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
            if (r->data_type == CYCLOPS_RESPONSE_IMAGE) {
                output_result_to_file(&m_qstate, r);
                m_total_num_images++;
            } else
                printf("un-decodable incomplete data reception\n");
        }

        printf(" - Mote %d: num_pkts %d ", r->addr, r->num_pkts);
        if (m_qstate.numExpectedPkts > 0)
            printf("(%.1lf%%) ", 100.0*r->num_pkts/(r->image_cnt*m_qstate.numExpectedPkts));
        if (r->image_cnt)
            printf("num_images %d ", r->image_cnt);
        printf("received\n");
    }
    
    printf("Total: %d images (%lu seconds)\n", m_total_num_images, tv_stop.tv_sec - tv_start.tv_sec);

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
    printf("  -s        : single image - do not repeat\n");
    printf("  -t <sec>  : repeat interval (in sec) between images\n");
    printf("  -r <rate> : fragment report interval (in millisec)\n");
    printf("  -e <num>  : set expected number of images so that program safely terminate\n");
    printf("  -h        : display this help message.\n");
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
    m_reliable = 2;                 // reliable stream transport
    p->getImageQ.reportRate = 142;  // 7pkts/sec
    m_repeat_interval = 1800;       // every 30 minute

    for (ind = 1; ind < argc; ind++) {
        /* take options, starting with '-' */
        if (argv[ind][0] == '-') {
            switch (argv[ind][1]) {
                case 'n':
                    strcpy(tr_host, argv[++ind]); break;   // set transport host
                case 'p':
                    tr_port = atoi(argv[++ind]); break;    // set transport port
                case 's':
                    m_repeat_interval = 0; break;           // only once
                case 't':
                    m_repeat_interval = atoi(argv[++ind]); break;   // repeat interval in sec
                case 'r':
                    p->getImageQ.reportRate = atoi(argv[++ind]); break;
                case 'e':
                    m_expected_num_images = atoi(argv[++ind]); break;
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

    check_img_size(p);

    /* configure host name and port number for the transport layer */
    config_transport(tr_host, tr_port);
}

/* Received a response attribute from a cyclops */
void process_cyclops_response_attr(query_state_t *p, result_item_t *r, struct attr_node *ret_attr) {
    unsigned char *raw_packet;
    cyclops_response_t *cResp;
    int i;

    if ((ret_attr->length * 2) < offsetof(cyclops_response_t, data)) {
        printf("Unexpected reponse from Mote %3d\n", r->addr);
        return;
    }
    
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
            m_time = time(NULL);
            printf("%s", asctime(localtime(&m_time)));
            output_result_to_file(p, r);
            m_total_num_images++;
        }

        currentbufPtr = &r->buffer[(ir->fragNum - 1) * p->getImageQ.fragmentSize];
        memcpy(currentbufPtr, ir->data, ir->dataLength); //Copy the data

        r->recv_bytes += ir->dataLength;
        r->data_type = CYCLOPS_RESPONSE_IMAGE;
        
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
    
    free(raw_packet);
}


/* Received a response packet from the cyclops node */
void process_response(query_state_t *p, struct response *rlist) {
    uint16_t r_addr = response_mote_addr(rlist);    // get mote ADDR
    struct attr_node *ret_attr;
    result_item_t *r;

    printf(".");

    /* find the appropriate result_item structure for this node */
    r = find_outitem(outlist, r_addr);  // find the result item for this node
    if (r == NULL) {
        r = add_outitem(&outlist, r_addr);
        m_outlist_len++;
        if ((m_expected_num_images > 0) && (m_outlist_len > m_expected_num_images))
            m_expected_num_images = m_outlist_len;
    }
    r->num_pkts++;      // number of packets received from this node

    ret_attr = response_find(rlist, ATTR_ID1); // get cyclops response attribute that we asked for
    if (ret_attr != NULL)
        process_cyclops_response_attr(p, r, ret_attr);
        
    /* write down the reception time of the last pkt received */
    gettimeofday(&tv_stop, NULL);
}


/* construct the task string to send, based on the processed arguments/options */
void construct_app_task_string(query_state_t *p) {
    if (m_repeat_interval > 0) {
        /* repeated image taking. fetch images continuously every T sec */
        sprintf(m_task_string, "wait_n_repeat(5000,%d)->image(%d,%d,%d,%d,%d,%d,%d)->send(%d)",
                m_repeat_interval*1000,
                p->getImageQ.fragmentSize, 
                p->getImageQ.reportRate, 
                p->getImageQ.snapQ.enableFlash, p->getImageQ.snapQ.type,
                p->getImageQ.snapQ.size.x, p->getImageQ.snapQ.size.y,
                ATTR_ID1, 
                m_reliable);
    }
    else {
        /* one-shot image taking. fetches one image after 5sec */
        sprintf(m_task_string, "wait(5000)->image(%d,%d,%d,%d,%d,%d,%d)->send(%d)",
                p->getImageQ.fragmentSize,
                p->getImageQ.reportRate,
                p->getImageQ.snapQ.enableFlash, p->getImageQ.snapQ.type,
                p->getImageQ.snapQ.size.x, p->getImageQ.snapQ.size.y,
                ATTR_ID1, 
                m_reliable);
    }
}


int main(int argc, char **argv)
{
    struct response *resplist;

    printf("\n");
    printf("#################################################################\n");
    printf("## jr_deploy2: Task Tenet-Cyclops nodes and get images ##########\n");
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

        /* terminate program if we have received expected number of images */
        if ((m_expected_num_images > 0) && (m_expected_num_images == m_total_num_images))
            terminate_application();

        fflush(stdout);
        response_delete(resplist);
    }
    return 0;
}


