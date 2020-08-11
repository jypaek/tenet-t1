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
 * A Tenet application that tests the task concurrency:
 * - "how many tasks can a mote run concurrently?"
 *
 * - Given a task, this application sends that same task repeatedly.
 *   It sends the next task only if it has received (a) response(s) for
 *   the previous task.
 * - You can specify the task that this application will send.
 *   Otherwise, it will use the default task provided by this application.
 * - Note that the task you provide
 *   - must have a response, and
 *   - should not make the network be the bottle-neck for receiving response.
 *     (memory constraint on the mote will be the bottle-neck for concurrency)
 * - Also note that when a mote hits it's memory limit, it will hang.
 *   You will need to hard reset the mote.
 *
 * @author Jeongyeup Paek
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

#define MAX_TASK_STRING_LEN 1000


int m_tid = 0;  /* last 'tid' (task_id) that was used to send my task */


void print_usage() {
    printf("\nApplication to test the task concurrency; \"how many tasks a mote can run concurrently?\"\n");
    printf("Usage: concurrencytest [options] \"task string\"\n\n");
    printf("  -h      : display this help message.\n");
    printf("  -n host : host on which transport is running. (Default = localhost)\n");
    printf("  -p port : port on which transport is listening for connection. (Default = 9998)\n");
    printf("  -t sec  : time (in sec) to way after receiving last packet to exit. (Default = 10s)\n");
    printf("  -v      : verbose mode. Display all traffic messages.\n");
    printf("  -r num  : min. number of responses to receive before sending the next task. (Default = 1)\n");
    exit(1);
}


/* Ctrl-C interrupt handler */
void sig_int_handler(int signo) {
    /* It is good habit to delete the task that you have sent,
       although Tenet transport layer should take care of it in usual cases */
    if (m_tid) delete_task(m_tid);
    exit(0);
}


int main(int argc, char **argv) {

    char task_string[MAX_TASK_STRING_LEN];
    int task_count = 0;

    int min_response = 1;

    char host_name[200];
    int c;
    int tr_port = 9998;             /* the port number where the Tenet master stack is running */
    int interval_ms = 10000;        /* default timeout value that we wait for a response
                                       before the 'read_response' function returns NULL */
    strcpy(host_name, "127.0.0.1"); /* the host where the Tenet master stack is running */


    /* register a Ctrl-C interrupt handler so that we can cleanly kill the task */
    if(signal(SIGINT, sig_int_handler) == SIG_ERR)
        fprintf(stderr, "Warning: failed to set SINGINT handler");

    /* parse option line */
    while ((c = getopt(argc, argv, "t:n:p:r:vh")) != -1) {
        switch(c){
            case 'n':
                strcpy(host_name, optarg); break;
            case 'p':
                tr_port = atoi(optarg); break;
            case 'v':
                setVerbose(); break;
            case 't':
                interval_ms = 1000* atoi(optarg); break;
            case 'r':
                min_response = atoi(optarg); break;
            case 'h':
            case '?':
            default:
                print_usage();
        }
    }

    /* configure the host:port setting for connecting to the Tenet master stack */
    config_transport(host_name, tr_port);

    printf("\n=== Running Tenet Concurrency Test Application ===\n");

    /* get string input */
    if (optind < argc) {
        strcpy(task_string, argv[optind]);
        printf("\nUsing task: \"%s\"\n\n", task_string);
    } else {
        char *default_task = "issue(2000,60000,0)->voltage(0x2)->send()";
        strcpy(task_string, default_task);
        printf("\nYou did not enter a task string...using default: \"%s\"\n\n", default_task);
        //print_usage();
    }
    

    /* let's see how many tasks a mote can run */
    while (1) {
        struct response *list; 
        int mote_address, responded_tid;
        int response_cnt = 0;
        int timeout_cnt = 0;


        /* send my task */
        m_tid = send_task(task_string);
        if (m_tid < 0) {
            printf("tasking failed for task [ %2d ]\n", task_count+1);
            exit(1); /* if tid < 0, that means task dissemination failed */
        }
        printf("Sent task [ %2d ] with tid %d...\n", task_count+1, m_tid);
        fflush(stdout); 

        while (1) {
            list = read_response(interval_ms);
            
            if (list == NULL) {
                switch (get_error_code()) { /* check if there is an error on below layers */
                    case TIMEOUT: // ignore timeout error, keep receiving other messages 
                        printf("TIMEOUT\n");
                        if (timeout_cnt++ > 10) {
                            printf("... Probably, the mote cannot run any more tasks. Terminating...\n");
                            printf("\nFinal number of tasks that ran successfully = %d\n", task_count);
                            exit(1);
                        }
                        continue;
                    case MOTE_ERROR:    // you'll see the error message on the screen
                        printf("MOTE_ERROR\n");
                        printf("... Probably, the mote cannot run any more tasks. Terminating...\n");
                        printf("\nFinal number of tasks that ran successfully = %d\n", task_count);
                        exit(1);
                        break;
                    default:            // transport is probably broken
                        printf("exiting error code %d\n", get_error_code());
                        break;
                }
                continue;
            }
            
            responded_tid = response_tid(list);

            if (responded_tid == m_tid) {   // is this the one that I've sent out last?

                response_cnt++;                             /* got a reponse */
                mote_address = response_mote_addr(list);    /* get node id */

                printf(" - TID %d (response# %d) ", responded_tid, response_cnt);
                response_print(list);        
            }

            /* delete the response structure */
            response_delete(list);

            if (response_cnt >= min_response) {
                printf("Received %d responses for TID %d. Moving on to next task...\n\n", response_cnt, responded_tid);
                task_count++;
                sleep(2);
                break;
            }
        }
    }
    return 0;
}

