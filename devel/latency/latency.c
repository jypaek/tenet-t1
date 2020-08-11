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
 * A Tenet application that measures the task dissemination latency.
 *
 * First, ask for the current time-synchronized mote-world global time,
 * and set this as the 'task sent time'.
 * Then send out a task to all motes that asks for the global_time.
 * Each mote will get the global_time as soon as the task is installed,
 * and wait for a second (to avoid congestion with the dissemination packets),
 * and send the result back to this application.
 * Latency is calculated as 'received mote global time' - 'task sent time'.
 * This application will wait for 'interval_ms' time to receive reponses,
 * and print out the results on the screen.
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 2/5/2007
 **/

#include <stdio.h>
#include <stdlib.h>
#include <signal.h>
#include "tenet.h"
#include "serviceAPI.h"
#include "LinkedList.h"

/**
 * The task that this application will send out.
 **/
char *task_string = "globaltime(0xab)->wait(1000,0)->send(1)";

int tid = 0;
uint32_t senttime = 0;
uint32_t clockfreq;
struct LinkedList* mylist;
struct LinkedList* idlist;

void print_latency_all() {
    // print task dissemination latencies
    struct Node* item;
    int num_nodes = 0;
    uint16_t addr;
    long int latency_tick;
    double latency_ms;
    double sum = 0.0, min = 1000.0, max = 0.0;

    printf("\n\n < Printing the tasking latency >\n\n");

    while ((item = Pop(mylist)) != NULL) {
        addr = (uint16_t)item->nID;
        latency_tick = item->nValue;
        latency_ms = (double)latency_tick*1000.0/(double)clockfreq;
        printf(" Node %3d : latency %5.3lf ms (%6ld ticks)\n", addr, latency_ms, latency_tick);
        num_nodes++;
        if (latency_ms > max)
            max = latency_ms;
        if ((latency_ms < min) && (latency_ms > 0.0))
            min = latency_ms;
        sum += latency_ms;
    }
    printf("\n # num_nodes  : %d\n", num_nodes);
    printf(" #    max     : %5.3f ms\n", max);
    printf(" #    min     : %5.3f ms\n", min);
    printf(" #  average   : %5.3f ms\n\n", (sum/(double)num_nodes));
    DeleteLinkedList(mylist);
}


/**
 * Print out the sorted list of all the node-id's that this application 
 * has received response from.
 * This can help figuring out which nodes did/didn't send responses.
 **/
void print_node_id_list() {
    struct Node* item;
    
    printf("\n\n < Printing the sorted id list >  (num_nodes %d)\n\n", idlist->nCount);
    printf ( ">> ");
    while ((item = Pop(idlist)) != NULL) {
        printf( "%d ", item->nID );
    }
    printf ( "\n\n");
    DeleteLinkedList(idlist);
}


/**
 * Terminate the application, due to either timeout of 'interval_ms'
 * or 'Ctrl-C' (SIGINT) by user.
 **/
void TimerFired() {
    if (tid) delete_task(tid);
    print_latency_all();
    print_node_id_list();
    exit(1);
}

void sig_int_handler(int signo) {
    TimerFired();
}

/**
 * Received 'mote-time-request' response from the BaseStation.
 * Record this time value as the task 'senttime'.
 **/
void motetime_result_event(uint16_t tid, uint32_t motetime, 
                           uint32_t freq, uint16_t root, float skew, double rtt_ms) {
    senttime = motetime;
    //clockfreq = freq;
    clockfreq = 32768;

    printf("\n sent time : %u, clock freq %d\n\n", motetime, freq);
}

                           
int main(int argc, char **argv)
{
    uint16_t r_tid, r_addr;
    int interval_ms = 5000; // wait for this time to receive responses from motes.
    int verbosemode = 0;

    if(signal(SIGINT, sig_int_handler) == SIG_ERR)
        fprintf(stderr, "Warning: failed to set SINGINT handler");

    if (argc == 3) {
        config_transport(argv[1], atoi(argv[2]));
    } else if (argc != 1)  {
        fprintf(stderr, " Usage: %s [host] [port]\n", argv[0]);
        exit(1);
    }
    register_motetime_service_handler(&motetime_result_event);

    /**
     * send mote-time request to the BaseStation mote through transport-service.
     */
    send_motetime_query(0);

    tid = send_task(task_string); // send the task
    if (tid > 0) {                  
        printf("\ntask has been sent with tid %d!!\n", tid);
        printf("\n");
    } else {
        exit(1);
    }

    mylist = NewLinkedList(); /* create a list of latencies */
    idlist = NewLinkedList(); /* create a list of node-id's */

    /* receive response packets */
    struct response *list;
    struct attr_node* valueNode;
    uint32_t timestamp = 0;
    long int latency;
    double latency_d;

    while (1) {
        list = read_response(interval_ms); /* read task response with timeout */
        if (list == NULL) {//did not get any attribute.
            TimerFired();
        }
        
        /* extract data from the response packets */
        r_addr = response_mote_addr(list);
        r_tid = response_tid(list);
        valueNode = response_find(list, 0xab);
        timestamp = (uint32_t)valueNode->value[1];
        timestamp = (timestamp<<16) + (uint32_t)valueNode->value[0];

        if (timestamp < senttime) {
            latency = 0;
        } else {
            /* calculate task dissemination latency in units of 'mote ticks' */
            latency = (long int)(timestamp - senttime);
        }
        /* convert mote-ticks unit to millisecond unit */
        latency_d = (double)latency*1000.0/(double)clockfreq;

        InsertNode(mylist, r_addr, latency);
        InsertNode(idlist, r_addr, r_addr); // for debugging

        if (verbosemode) {
            printf("(%d) [tid %d] node %d >> timestamp %u ", idlist->nCount, r_tid, r_addr, timestamp);
            printf(" latency_est %1.3lf ms (%ld ticks)\n", latency_d, latency);
        } else {
            printf(".");
        }
        fflush(stdout);

        /* delete the received task response data structure */
        response_delete(list);
    }
    return 0;
}

