/*
 * "Copyright (c) 2006~2009 University of Southern California.
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
 * Tenet Application for threaded-Tenet (Tenet on TOSThreads)
 * - test packet delivery
 *
 * @author Jeongyeup Paek (jpaek@usc.edu)
 * @modified Feb/16/2009
 **/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>
#include <unistd.h>
#include <sys/time.h>
#include <sys/types.h>
#include <stddef.h>
#ifdef __CYGWIN__
#include <windows.h>
#include <io.h>
#else
#include <stdint.h>
#endif
#include "response.h"
#include "tenet.h"
#include "timeval.h"

#define PARENT_LIST_LEN 10

/* Response/result data structure per node */
typedef struct result_item {
    struct result_item *next;
    int addr;
    int num_pkts;
    int last_seqno;
    int nexthop[PARENT_LIST_LEN];
    int nextfreq[PARENT_LIST_LEN];
    int nextrssi[PARENT_LIST_LEN];
    int hopcount[PARENT_LIST_LEN];
    int hopfreq[PARENT_LIST_LEN];
    unsigned long int f_time;
    unsigned long int l_time;
    long int interval;
    unsigned long int meandev;
} result_item_t;

/* Global variables */
result_item_t *outlist = NULL;  /* list of result items (each from different nodes) */
int m_tid = 0;                  /* TID used for the task */
int c_reliable = 0;             /* use reliable transport? 0=best-effort, 1=ptr, 2=str */
int c_interval = 500;           /* inter-packet interval, in ms */
int c_num_pkts = 300;           /* number of packets to send per mote */
int c_num_node = 0;             /* expected number of nodes to receive response from */
int c_initwait = 5000;
unsigned long int m_first_time = 0;
unsigned long int m_last_time = 0;
int m_curr_node_cnt = 0;
int verbosemode = 0;
int close_wait = 0;             /* wait for close done event from transport layer */
int m_tot_pkts_read = 0;
int m_timeout = 5000;
int m_last_progress = 0;
int m_est_tot_num_pkts = 1;
int showdetails = 1;


struct result_item *add_outitem(result_item_t **outlist_ptr, unsigned int addr);
struct result_item *find_outitem(result_item_t *outlist, unsigned int addr);
void remove_outlist(result_item_t **outlist_ptr);
void print_progress();

/*************************************************************************/

/**
 * Terminate the application at 'Ctrl-C' (SIGINT) by user.
 **/
void terminate_application(void) {
    struct result_item *r;
    double goodput, duration, prr;
    double interval, meandev;
    int i;

    print_progress();
    printf("\n"); 
    duration = (double)(m_last_time - m_first_time)/1000.0;
    printf("# received total of %d pkts during %.1f seconds\n", m_tot_pkts_read, duration);
    goodput = ((double)m_tot_pkts_read/duration);
    printf("# tot. goodput %.2f pkts/sec\n", goodput);
    goodput = goodput/(double)m_curr_node_cnt;
    printf("# avg. goodput %.2f pkts/sec\n", goodput);
    prr = ((double)m_tot_pkts_read * 100.0)/(double)m_est_tot_num_pkts;
    printf("# avg. PRR     %.2f %%\n", prr);
    printf("\n"); 

    for (r = outlist; r; r = r->next) {
        duration = (double)(r->l_time - r->f_time)/1000.0;
        goodput = r->num_pkts/duration;
        interval = ((double)r->interval/(double)(c_num_pkts - 1));
        meandev = ((double)r->meandev/(double)(c_num_pkts - 1));
        printf("# mote %3d: num_pkts %3d (%3.1lf%%) received during %.1f sec (goodput %.2f pkts/sec)\n", 
                r->addr, r->num_pkts, 100.0*r->num_pkts/c_num_pkts, duration, goodput);
        printf("#          - inter-packet interval : avg %.1f, meandev %.1f\n",
                interval, meandev);

        if (showdetails) {
            printf("#          - nexthop : ");
            for (i = 0; i < PARENT_LIST_LEN; i++) {
                if (r->nexthop[i] != 0) {
                    printf("%5d (%3.0f%%)", r->nexthop[i], r->nextfreq[i]*100.0/(double)r->num_pkts);
                    printf("(%3.1f dbm) ", (double)r->nextrssi[i]/(double)r->num_pkts);
                }
            }
            printf("\n");
            printf("#          - hopcount: ");
            for (i = 0; i < PARENT_LIST_LEN; i++) {
                if (r->hopcount[i] != 0)
                    printf("%5d (%3.0f%%) ", r->hopcount[i], r->hopfreq[i]*100.0/(double)r->num_pkts);
            }
            printf("\n");
        }
    }
    printf("\n");

    remove_outlist(&outlist);
    exit(1);
}

/* Ctrl-C handler */
void sig_int_handler(int signo) {
    if (!close_wait) {
        close_wait = 1;
        if (m_tid) delete_task(m_tid);
        printf("\nWaiting for connections to be closed... (tid %d)\n", m_tid);
    } else {
        terminate_application();
    }
}

void close_done(uint16_t tid, uint16_t addr) {
    terminate_application();
}

void print_usage(char* argv0) {
    printf("\n## '%s' tests packet delivery from every mote \n\n", argv0);
    printf("Usage: %s [-vdh] [-n host] [-p port] [-t timeout] [-i/r/c/e ARG]\n\n", argv0);
    printf("  -n <host>     : host on which transport is running. (default: 127.0.0.1)\n");
    printf("  -p <port>     : port on which transport is listening for connection. (default: 9998)\n");
    printf("  -t <millisec> : time (in milli-sec) to wait after receiving last packet. (default 10s)\n");
    printf("  -r <type>     : set transport protocol (0=best-effort(default), 1=ptr, 2=str)\n");
    printf("  -i <interval> : set inter-packet interval in ms (1/rate) (default=500)\n");
    printf("  -c <num>      : set number of packets to send (default=200)\n");
    printf("  -e <num>      : set expected number of nodes to respond (default=1)\n");
    printf("  -v            : verbose mode\n");
    printf("  -d            : do not show details about routing information (parent, etc)\n");
    printf("  -h            : display this help message.\n");
    printf("\nExample: When you have 5 motes, try 10pkts/sec, best-effort transport\n");
    printf("    > %s -e 5 -i 100 -r 0\n\n", argv0);
    exit(1);
}


void process_arguments(int argc, char *argv[]) {
    int ind;
    char tr_host[30];
    int tr_port;

    /* set bunch of DEFAULT values */
    strcpy(tr_host, "127.0.0.1");
    tr_port = 9998;

    for (ind = 1; ind < argc; ind++) {
        /* take options, starting with '-' */
        if (argv[ind][0] == '-') {
            switch (argv[ind][1]) {
                case 'n':
                    strcpy(tr_host, argv[++ind]); break;   // set transport host
                case 'p':
                    tr_port = atoi(argv[++ind]); break;    // set transport port
                case 'v':
                    verbosemode = 1; break;
                case 't':
                    m_timeout = atoi(argv[++ind]); break;
                case 'r':
                    c_reliable = atoi(argv[++ind]); break;
                case 'i':
                    c_interval = atoi(argv[++ind]); break;
                case 'c':
                    c_num_pkts = atoi(argv[++ind]); break;
                case 'e':
                    c_num_node = atoi(argv[++ind]); break;
                case 'd':
                    showdetails = 0; break;
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

    // if RCRT is used, achieved rate can be low -> let timeout be large!
    if (c_reliable == 3) if (m_timeout != -1) m_timeout = 65535;
    // timeout should be larger than the inter-packet interval
    if (m_timeout < 2*c_interval + c_initwait + 5000) 
        m_timeout = 2*c_interval + c_initwait + 5000;
    
    /* configure host name and port number for the transport layer */
    config_transport(tr_host, tr_port);
}

void print_progress() {
    int est_tot_num_pkts, num_nodes, progress;
    int total_sent = 0;
    unsigned long int cur_time = gettimeofday_ms();
    result_item_t *r;
    
    for (r = outlist; r; r = r->next)
        total_sent += r->last_seqno;

    if (m_curr_node_cnt > c_num_node) num_nodes = m_curr_node_cnt;
    else num_nodes = c_num_node;

    est_tot_num_pkts = num_nodes * c_num_pkts;
    progress = (total_sent*1000/est_tot_num_pkts);  // 10*%
    
    if (progress > m_last_progress) {
        if ((progress%100) == 0) {
            printf("\nprogress...%2d %% (%.1f sec passed)", progress/10,
                    ((double)(cur_time - m_first_time)/1000.0));
        } else if ((progress%10) == 0) {
            printf(".");
        }
    }

    if (progress > m_last_progress)
        m_last_progress = progress;
    if (est_tot_num_pkts > m_est_tot_num_pkts)
        m_est_tot_num_pkts = est_tot_num_pkts;
}

/* Received a response packet from the cyclops node */
void process_response(struct response *rlist) {
    //uint16_t r_tid = response_tid(rlist);           // get TID
    uint16_t nodeid = response_mote_addr(rlist);    // get mote ADDR
    struct attr_node *ret_attr;
    result_item_t *r;
    int seqno = 0, nexthop = 0, hopcount = 0, rssi = 0;  // data to read from response
    int found1 = 0, found2 = 0;
    int i;
    unsigned long int currtime = gettimeofday_ms();

    ret_attr = response_find(rlist, 2); // seqno (from 'count' tasklet)
    if (ret_attr != NULL) seqno = ret_attr->value[0];
    ret_attr = response_find(rlist, 5); // nexthop (parent)
    if (ret_attr != NULL) nexthop = ret_attr->value[0];
    ret_attr = response_find(rlist, 6); // hopcount
    if (ret_attr != NULL) hopcount = ret_attr->value[0];
    ret_attr = response_find(rlist, 8); // nexthop rssi
    if (ret_attr != NULL) rssi = (int16_t)ret_attr->value[0];

    //if ((seqno == 0) || (nexthop == 0) || (hopcount == 0))
    //    return;
    
    /* find the appropriate result_item structure for this node */
    r = find_outitem(outlist, nodeid);  // find the result item for this node
    if (r == NULL) {
        r = add_outitem(&outlist, nodeid);
        m_curr_node_cnt++;
        printf("%d (%d)\n", nodeid, m_curr_node_cnt);
    }

    /* suppress duplicate packets */
    if (seqno <= r->last_seqno) // duplicate packet
        return;

    r->last_seqno = seqno;
    currtime = gettimeofday_ms();  // last packet time
    if (r->num_pkts == 0) {
        r->f_time = gettimeofday_ms();
    } else {
        r->interval += (currtime - r->l_time);
        r->meandev += abs((currtime - r->l_time) - c_interval);
    }
    r->l_time = currtime;
    r->num_pkts++;      // number of packets received from this node

    /* write down the reception time of the last pkt received */
    if (m_tot_pkts_read == 0)
        m_first_time = gettimeofday_ms();
    m_last_time = gettimeofday_ms();
    m_tot_pkts_read++;
/*
    for (i = 0; i < PARENT_LIST_LEN; i++) {
        if (nexthop == r->nexthop[i]) {
            r->nextfreq[i]++;
            r->nextrssi[i] += rssi;
            found1 = 1;
        }
        if (hopcount == r->hopcount[i]) {
            r->hopfreq[i]++;
            found2 = 1;
        }
        if (found1 && found2) break;
    }
    for (i = 0; i < PARENT_LIST_LEN; i++) {
        if ((found1 == 0) && (r->nexthop[i] == 0)) {
            r->nexthop[i] = nexthop;
            r->nextfreq[i] = 1;
            r->nextrssi[i] = rssi;
            found1 = 1;
        }
        if ((found2 == 0) && (r->hopcount[i] == 0)) {
            r->hopcount[i] = hopcount;
            r->hopfreq[i] = 1;
            found2 = 1;
        }
        if (found1 && found2) break;
    }
*/
    print_progress();
    if ((c_num_node) && (m_last_progress == 1000))
        sig_int_handler(0);
        
    fflush(stdout);
}


int main(int argc, char **argv)
{
    char task_string[200];
    struct response *resplist;

    printf("\n<< test packet delivery >>\n\n");
    
    /* set Ctrl-C handler */
    if (signal(SIGINT, sig_int_handler) == SIG_ERR)
        fprintf(stderr, "Warning: failed to set SINGINT handler");
    register_close_done_handler(&close_done);

    /* parse command line arguements */
    process_arguments(argc, argv);
    /* config_transport is done within process_arguments */


    /* construct the task string to send, based on the processed arguments/options */
    //sprintf(task_string, "wait(%d)->repeat(%d)->count(2,0,1)->gt(3,2,'%d')->deletetaskif(3)->deleteattribute(3)->nexthop(5)->hopcount(6)->rssi(8)->send(%d)", 
    sprintf(task_string, "wait(%d)->repeat(%d)->count(2,0,1)->gt(3,2,'%d')->deletetaskif(3)->deleteattribute(3)->nexthop(5)->send(%d)", 
                         c_initwait, c_interval, c_num_pkts, c_reliable);

    /* do you want to have a look at the task string? */
    if (verbosemode) {
        printf("TASK STRING: %s\n", task_string); fflush(stdout);
    }

    /* send out the task through the transport layer */
    m_tid = send_task(task_string);
    if (m_tid <= 0) {
        printf(" tasking failed.... \n"); exit(1); // fail.
    } 

    printf(" You have issued a 'test packet delivery' task (tid %d)\n", m_tid);
    printf("  - interval        = %u ms\n", c_interval);
    printf("  - transport_type  = %d\n", c_reliable);
    printf("  - num_packets     = %u\n", c_num_pkts);
    if (c_num_node)
    printf("  - num nodes       = %d\n", c_num_node);
    printf(" Expected test time = %d sec\n", (c_interval*c_num_pkts + m_timeout)/1000 + 2);
    fflush(stdout);

    /* receive response packets */
    while (1) {
        resplist = read_response(m_timeout);
        if (resplist == NULL) {        // did not get any attribute.
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
        process_response(resplist);
        
        fflush(stdout);
        response_delete(resplist);
    }
    return 0;
}


/********************************************
 * functions for the list of received result
 ********************************************/
struct result_item *add_outitem(result_item_t **outlist_ptr, unsigned int addr) {
    struct result_item *c = malloc(sizeof(struct result_item));
    int i;
    if (c == NULL) {
        fprintf(stderr, "FatalError: Not enough memory, failed to malloc!\n");
        exit(1);
    }
    if ((*outlist_ptr) == NULL) {
        c->next = *outlist_ptr;
        *outlist_ptr = c;
    } else if (addr < (*outlist_ptr)->addr) {
        c->next = *outlist_ptr;
        *outlist_ptr = c;
    } else {
        struct result_item *p, *n;
        for (p = (*outlist_ptr); p; p = p->next) {
            n = p->next;
            if ((n == NULL) || (addr < n->addr)) {
                p->next = c;
                c->next = n;
                break;
            }
        }

    }
    c->addr = addr;
    c->num_pkts = 0;
    c->last_seqno = 0;
    c->interval = 0;
    c->meandev = 0;
    for (i = 0; i < PARENT_LIST_LEN; i++) {
        c->nexthop[i] = 0;
        c->nextfreq[i] = 0;
        c->nextrssi[i] = 0;
        c->hopcount[i] = 0;
        c->hopfreq[i] = 0;
    }
    return c;
}

struct result_item *find_outitem(result_item_t *outlist, unsigned int addr) {
    struct result_item *c;
    for (c = outlist; c; c = c->next) {
        if (c->addr == addr)
            return c;
    }
    return NULL;
}

void remove_outlist(result_item_t **outlist_ptr) {
    struct result_item **c;
    for (c = outlist_ptr; *c; ) {
        struct result_item *dead = *c;
        *c = dead->next;
        free(dead);
    }
}

