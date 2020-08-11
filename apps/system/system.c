/*
* "Copyright (c) 2006 University of Southern California.
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
 * System application displays the properties of each node in tabular form.
 *
 * @author Marcos Augusto Menezes Vieira
 * Embedded Networks Laboratory, University of Southern California
 * @modified 2/5/2007
 **/

#include <stdio.h>
#include <stdlib.h>
#include <signal.h>
#include <unistd.h>
#include "sortedlist.h"
#include "tenet.h"

/* global variables */
struct sortedlist *slist;
int m_tid = 0;
int verbosemode = 0;

/* When ctrl-C or retx timeout, display table information */
int terminate_application(void) {
    struct Node* pNode = NULL;
    int i;

    delete_task(m_tid);
    printf("\n");
    printf("\nNumber of nodes %d\n\n", sortedlist_length(slist));
    for (i = 0; i < 78; i++)  printf("=");
    printf("\n");
    printf("  ID   PLAT   NUM   ACTIVE LEDS RADIO RADIO TIME  NEXT  USED  MAX     TIME \n");
    printf("              TASKS  TASKS      POWER  CH   SYNCR HOP   RAM   RAM    \n");
    for (i = 0; i < 78; i++)  printf("=");
    printf("\n");
    printf("\n");

    for (pNode = slist->pListHead ; pNode ; pNode = pNode->pNextNode) {
        printf(" %3d ", pNode->attributes[0]);//first column is smaller
        if (pNode->attributes[1] == 1) //seconde column is platform
            printf(" telosb");
        else if (pNode->attributes[1] == 2)
            printf(" micaz ");
        else if (pNode->attributes[1] == 3)
            printf(" imote2" );
        else if (pNode->attributes[1] == 4)
            printf(" mica2 ");
        else if (pNode->attributes[1] == 5)
            printf("mica2dot");
        else printf("unknown ");

        for (i = 2; i < pNode->nAttributes; i++) {
            if ((i == 9 || i == 10 || i == 11) && (pNode->attributes[i] == 0))
                printf("  N/A ");
            else if (i == 11)
                printf("%10lu ", (unsigned long int)pNode->attributes[i]);
            else
                printf("%5u ", (unsigned int)pNode->attributes[i]);
        }
        printf("\n");
    }
    printf ("\n\n");
    sortedlist_delete(slist);
    exit(1);
}

/* Cntrl-C handler */
void sig_int_handler(int signo) {
    terminate_application();
}

void print_usage() {
    printf("system displays the properties of each node.\n\n");
    printf("Usage: system [-vhzs] [-n host] [-p port] [-t timeout] \n\n");
    printf("  -h            : display this help message.\n");
    printf("  -v            : verbose mode. display additional informative messages.\n");
    printf("  -n [host]     : host on which transport is running. (default: localhost)\n");
    printf("  -p [port]     : port on which transport is listening for connection. (default: 9998)\n");
    printf("  -t [millisec] : time to wait after receiving last packet. (default: 6000)\n");
    printf("  -c [num]      : number of responses after which the program will stop.\n");
    printf("  -z            : run without 'memory_stats' tasklet. (for micaz users) \n");
    printf("  -s            : run without 'global_time' tasklet. (if no timesync) \n");
    printf("\n");
}
                
int main(int argc, char **argv)
{
    char task_string[200];
    int c;
    unsigned long int timeout = 6000;
    int numExpectedNodes = 0;
    int no_memstats = 0;
    int no_timesync = 0;
    struct response *list;
    int tr_port = 9998;
    char tr_host[40];
    strcpy(tr_host, "127.0.0.1");

    /* parse this application options */
    while ((c = getopt(argc, argv, "vhzsn:p:t:c:")) != -1)
        switch (c){
            case 'n':
                strcpy(tr_host,optarg); break;
            case 'p':
                tr_port = atoi(optarg); break;
            case 't':
                timeout = atoi(optarg); break;
            case 'c':
                numExpectedNodes = atoi(optarg); break;
            case 'v':
                setVerbose(); verbosemode = 1; break;
            case 'z':
                no_memstats = 1; break;
            case 's':
                no_timesync = 1; break;
            case 'h':
            case '?':
            default:
                print_usage();
                exit(1);
        }

    if (signal(SIGINT, sig_int_handler) == SIG_ERR)
        fprintf(stderr, "Warning: failed to set SINGINT handler");

    config_transport(tr_host, tr_port);

    /* task string to collect information about nodes */
    strcpy(task_string, "wait(1000)->platform(2)->num_tasks(3)->num_active_tasks(4)->leds(5)->rfpower(6)->rfchannel(7)->is_timesync(8)->nexthop(9)");
    if (!no_memstats)
        strcat(task_string, "->memory_stats(10)");
    if (!no_timesync)
        strcat(task_string, "->globaltime(11)");
    strcat(task_string, "->send(1)");

    /* send task into network */
    m_tid = send_task(task_string);
    if (m_tid < 0) exit(1); // tasking failed
    
    slist = sortedlist_create();

    /* receive response packets */
    while (1) {
        int i;
        unsigned int attr_vec[MAX_ATTRIBUTES];
        int nodeid;
        struct attr_node* value_node = NULL;
        
        list = read_response(timeout);

        if (list == NULL) { // did not get any attribute,then we already got last packet.
            if (get_error_code() == MOTE_ERROR) continue; // keep receiving more packets
            terminate_application();//timeout
        }
        if (list->tid != m_tid) {
            response_delete(list);
            continue;   // got response with wrong tid
        }

        /* iterate through response list */
        nodeid = response_mote_addr(list);

        /* check whether we already have data structure ready for this node */
        if (sortedlist_find(slist, nodeid) != NULL) {
            response_delete(list);
            continue;   // already received response from this node
        }

        /* initialize mem space for recved data */
        for (i = 0; i < MAX_ATTRIBUTES; i++) attr_vec[i] = -1;
        attr_vec[0] = nodeid;

        for (i = 2; i < 10; i++) {
            value_node = response_find(list, i);
            if (value_node != NULL)
                attr_vec[i-1] = value_node->value[0];
        }
    
        /* memory stats (RAM, RAMptr, max-RAM, max-RAMptr) only interested in RAM and max RAM */
        value_node = response_find(list, 10);
        if (value_node != NULL) {
            attr_vec[9] = value_node->value[0];         // RAM allocated
            attr_vec[9] += (2*value_node->value[1]);    // a pointer used for allocation consume 2bytes each
            attr_vec[10] = value_node->value[2];        // max RAM
            attr_vec[10] += (2*value_node->value[3]);   // a pointer used for allocation consume 2bytes each
        } else {
            attr_vec[9] = 0;
            attr_vec[10] = 0;
        }

        /* global time */
        value_node = response_find(list, 11);
        if (value_node != NULL) {
            /* global time is 32-bit integer while our attribute values are in 16-bits */
            attr_vec[11] = (unsigned int)value_node->value[0] + 
                            ((unsigned int)value_node->value[1]<<16);
        } else {
            attr_vec[11] = 0;
        }

        /* insert attributes into table (sortlist) */
        if (sortedlist_insert(slist, 
                              nodeid,           // identifier
                              nodeid,           // value (to sort with)
                              attr_vec,         // *data 
                              12                // *data len
                              ) > 0) {
            int l = sortedlist_length(slist);
            
            if (verbosemode) {
                printf("system info ( ");
                for (i = 0; i < 12; i++) 
                    printf("%u ", attr_vec[i]);
                printf(")\n");
            } //end verbose
            else
                printf(".");
            fflush(stdout);

            if (numExpectedNodes && (l == numExpectedNodes)) 
                terminate_application();
        }
        response_delete(list);
    } //end while
    return 0;
}

