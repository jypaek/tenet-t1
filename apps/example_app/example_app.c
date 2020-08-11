/*
* "Copyright (c) 2006~2008 University of Southern California.
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
 * This application is part of Tenet Distribution
 * (http://tenet.usc.edu)
 *
 * This application is a simple example on how to write Tenet application.
 * It gets:
 * - voltage level,
 * - global timestamp (time-synchronized time) and
 * - next hop (routing tree information)
 * every 5 seconds.
 *
 * @author Jeongyeup Paek
 * @author Marcos Vieira
 *
 * Embedded Networks Laboratory, University of Southern California
 * @modified Jan/12/2008
 **/


#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include "tenet.h"

int m_tid = 0;  /* 'tid' (task_id) that is used to send my task */


void print_usage() {
    printf("Example application that get's 'global timestamp' and 'next hop' information from the network. \n");
    printf("Usage: example_app [-h] [-n host] [-p port]\n\n");
    printf("  h : display this help message.\n");
    printf("  n : host on which transport is running. Default is localhost\n");
    printf("  p : port on which transport is listening for connection.Default is port 9998.\n");
}

/* Ctrl-C interrupt handler */
void sig_int_handler(int signo) {
    /* It is good habit to delete the task that you have sent,
       although Tenet transport layer should take care of it in usual cases */
    if (m_tid) delete_task(m_tid);
    exit(0);
}


int main(int argc, char **argv){
    char host_name[200];
    int tr_port;
    int c;
    int interval_ms;


    /* Write your own task using the tasklets in our tasking language !!!! */    
    char *my_task_string = "repeat(5000)->nexthop(101)->globaltime(102)->voltage(103)->send()";
    /* repeat(1000)    : this tasklet means that we repeat the task every '1000ms'
       nexthp(101)     : this tasklet means that we want to get the next-routing-hop information
                         and call this data 'type 101'
       globaltime(102) : this tasklet means that we want to get the global-time information
                         (time-synchronized time) and call this data 'type 102'
       voltage(103)    : this tasklet means that we want to get the mote voltage level
                         and call this data 'type 103'
       send()          : this taskelt means we want the data to be sent back to this application
    */


    /* register a Ctrl-C interrupt handler so that we can cleanly kill the task */
    if(signal(SIGINT, sig_int_handler) == SIG_ERR)
        fprintf(stderr, "Warning: failed to set SINGINT handler");
        

    /* default values */
    strcpy(host_name, "127.0.0.1"); /* the host where the Tenet master stack is running */
    tr_port = 9998;                 /* the port number where the Tenet master stack is running */
    
    interval_ms = 10000;            /* default timeout value that we wait for a response
                                       before the 'read_response' function returns NULL */

    /* parse option line */
    while ((c = getopt(argc, argv, "t:n:p:vh")) != -1) {
        switch(c){
            case 'n':
                strcpy(host_name, optarg); break;
            case 'p':
                tr_port = atoi(optarg); break;
            case 'h':
            case '?':
            default:
                print_usage();
                exit(1);
        }
    }

    /* configure the host:port setting for connecting to the Tenet master stack */
    config_transport(host_name, tr_port);
    

    /* send my task */
    m_tid = send_task(my_task_string);
    
    if (m_tid < 0) exit(1); /* if tid < 0, that means task dissemination failed */
    

    /* receive response packets */
    struct response *list; 
    struct attr_node* data_attr = NULL;
    
    /* example data in our example task */
    int mote_address;
    int nexthop;
    int voltage;
    unsigned int globaltime, globaltime_high, globaltime_low;
    
    while (1) {
        list = read_response(interval_ms);
        
        if (list == NULL) { /* timeout!!. Did not get any response for the last 'interval_ms' */
        
            if (get_error_code() < 0) { /* check if there is an error on below layers */
                printf("exiting error code %d\n", get_error_code());
                /* error codes are defined in 'tenet.h' */
                delete_task(m_tid);
                exit(1);
            }

            /* if there is no error, and just timed out, you can either
                continue;   // wait more, or
                exit(1);    // exit. */
            exit(1);
        }
        
        /* extract data from the response packet */

        /* get node id */
        mote_address = response_mote_addr(list);
        printf("Node=%d ",mote_address);

        /* get next hop */
        data_attr = response_find(list, 101);   /* recall from our task that we said 'type 101' is the nexthop */
        nexthop = data_attr->value[0];
        printf("nexthop=%d ",nexthop);

        /* get global time */
        data_attr = response_find(list, 102);   /* recall from our task that we said 'type 102' is the globaltime */
        globaltime_low = data_attr->value[0];   /* global time is 32-bit value which is represented as an array of */
        globaltime_high = data_attr->value[1];  /* two 16-bit integers in the response->value structure */
        globaltime = (globaltime_high<<16) + globaltime_low;
        printf("globaltime=%u ",globaltime);

        /* get voltage */
        data_attr = response_find(list, 103);   /* recall from our task that we said 'type 103' is the voltage */
        voltage = data_attr->value[0];
        printf("voltage=%d ",voltage);

        printf("\n");

        /* uncomment below line if you want to print all data in the response data structure */
        //response_print(list);        

        /* delete the response structure */
        response_delete(list);
    }
    return 0;
}


