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
 * This application changes the CC2420 RF power of all motes.
 * - You can change RF power of all Tenet nodes using task.
 * - But you also need to change that of the BaseStation mote.
 * - This app does that for you.
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 2/5/2007
 **/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include "tenet.h"
#include "serviceAPI.h"

int m_tid = 0;  /* 'tid' (task_id) that is used to send my task */
int m_rfpower = 31;
int m_bs_last = 1;
int m_bs_only = 0;
int m_reset_parent = 0;

void print_usage() {
  printf("Example application that get's 'global timestamp' and 'next hop' information from the network. \n");
  printf("Usage: example_app [-h] [-n host] [-p port]\n\n");
  printf("  h : display this help message.\n");
  printf("  s : the value of CC2420 RF power (3~31) that you want to set\n");
  printf("  r : reset routing parent (you'll need to wait for 30sec or so after doing this)\n");
  printf("      - this might be required if the power change can drastically change routing tree\n");
  printf("  b : change the rf power of basestation 'before' sending task (default is 'after')\n");
  printf("  o : only change the rf power of basestation (do not send task)\n");
  printf("  n : host on which transport is running.Default is localhost\n");
  printf("  p : port on which transport is listening for connection.Default is port 9998.\n");
}

/* Ctrl-C interrupt handler */
void sig_int_handler(int signo) {
    if (m_bs_last) {
        struct response *list; 
        /*send 'set rfpower' request to the BaseStation mote through transport-service. */
        send_set_rfpower(m_rfpower);
        // wait till I get response from base station
        list = read_response(500);
        if (list != NULL) response_delete(list);
    }
    printf("\n");
    
    /* It is good habit to delete the task that you have sent,
       although Tenet transport layer should take care of it in usual cases */
    if (m_tid) delete_task(m_tid);
    exit(0);
}

/**
 * Received 'mote-time-request' response from the BaseStation.
 * Record this time value as the task 'senttime'.
 **/
void rfpower_result_event(uint16_t tid, uint16_t rfpower) {
    printf("RF power of BaseStation has been changed to %d\n", rfpower);
    fflush(stdout);
}

int main(int argc, char **argv){
    char host_name[200];
    int tr_port;
    int c;
    int interval_ms;

    char my_task_string[200];

    /* register a Ctrl-C interrupt handler so that we can cleanly kill the task */
    if(signal(SIGINT, sig_int_handler) == SIG_ERR)
        fprintf(stderr, "Warning: failed to set SINGINT handler");

    /* default values */
    strcpy(host_name, "127.0.0.1"); /* the host where the Tenet master stack is running */
    tr_port = 9998;                 /* the port number where the Tenet master stack is running */
    interval_ms = 3000;             /* default timeout value that we wait for a response
                                       before the 'read_response' function returns NULL */
                                       
    /* register a function that will be called when we get response from basestation */
    register_rfpower_service_handler(&rfpower_result_event);

    /*parse option line*/
    while ((c = getopt(argc, argv, "s:n:p:borvh")) != -1) {
        switch(c){
            case 's':
                m_rfpower = atoi(optarg);
                break;
            case 'n':
                strcpy(host_name, optarg);
                break;
            case 'p':
                tr_port = atoi(optarg);
                break;
            case 'b':
                m_bs_last = 0;
                break;
            case 'o':
                m_bs_only = 1;
                break;
            case 'r':
                m_reset_parent = 1;
                break;
            case 'h':
            case '?':
            default:
                print_usage();
                exit(1);
        }
    }

    /* configure the host:port setting for connecting to the Tenet master stack */
    config_transport(host_name, tr_port);

    if (m_bs_only) {
    /*send 'set rfpower' request to the BaseStation mote through transport-service. */
        send_set_rfpower(m_rfpower);
        exit(1);
    }

    sprintf(my_task_string, "wait(1000,0)->set_rfpower('%d')->rfpower(101)->send()", m_rfpower);
    /* wait(1000,0)     : this tasklet means that we wait for '1000ms' (without repeat)
       set_rfpower(%d)  : this tasklet means that we want to set the rfpower to 'm_rfpower'
       rfpower(101)     : this tasklet means that we want to get the rfpower information
                          and call this data 'type 101'
       send(1)          : this taskelt means we want the data to be sent back to this application
    */
    if (m_reset_parent) {
        sprintf(my_task_string, "wait(1000,0)->set_rfpower('%d')->rfpower(101)->send()->reset_parent()", m_rfpower);
    }

    /* send my task */
    m_tid = send_task(my_task_string);
    
    if (m_tid < 0) exit(1); /* if tid < 0, that means task dissemination failed */
   
    printf("\n");

    if (!m_bs_last)
    /*send 'set rfpower' request to the BaseStation mote through transport-service. */
        send_set_rfpower(m_rfpower);

    /* receive response packets */
    struct response *list; 
    struct attr_node* data_attr = NULL;
    
    /* example data in our example task */
    int mote_address;
    int rfpower;
    
    while (1) {
        list = read_response(interval_ms);
        
        if (list == NULL) { /* timeout!!. Did not get any response for the last 'interval_ms' */
            if (get_error_code() < 0) { /* check if there is an error on below layers */
                printf("exiting error code %d\n",get_error_code());
                /* error codes are defined in 'tenet.h' */
            }
            /* if there is no error, and just timed out, you can either
                continue;   // wait more, or
                exit(1);    // exit. */
            sig_int_handler(0);
        }
        
        /* extract data */
        mote_address = response_mote_addr(list);
        printf("Node %3d ", mote_address);
        data_attr = response_find(list, 101);
        rfpower = data_attr->value[0];
        printf("rfpower %2d\n", rfpower);

        /* delete the response structure */
        response_delete(list);
    }
    return 0;
}


