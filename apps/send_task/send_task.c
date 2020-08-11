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
 * 'send_task' sends a task to the network.
 *
 * It is an application that is part of Tenet Distribution
 * ( http://tenet.usc.edu )
 *
 * This application is useful to play with and test constructing tasks.
 * Instructions for constructing a task (which is, writing a task description)
 * can be found at docs/Tasking_API.HOWT
 *
 *
 * @author Jeongyeup Paek
 * @author Marcos Vieira
 * Embedded Networks Laboratory, University of Southern California
 * @modified 2/5/2007
 **/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include "tenet.h"
#include "element_usage.h"

#define MAX_TASK_STRING_LEN 1000

int tid = 0;

void print_usage() {
    printf("Send a task command to the network. \n");
    printf("Usage: send_task [-vs] [-n host] [-p port] \"string to task\" \n");
    printf("       send_task [-ah] \n");
    printf("       send_task -u \"tasklet_name_to_see_usage\"\n\n");
    printf("  h : display this help message.\n");
    printf("  v : verbose mode. Display all traffic messages.\n");
    printf("  n : host on which transport is running.Default is localhost\n");
    printf("  p : port on which transport is listening for connection.Default is port 9998.\n");
    printf("  t : time (in ms) to way after receiving last packet to exit. Default is 20s.\n");
    printf("  a : print usage of all available tasklets/taskingAPI\n");
    printf("  s : print received response in simple space-separated format.\n");
}

void sig_int_handler(int signo) {
    if (tid) delete_task(tid);
    exit(0);
}

void print_response_simple(struct response *list) {
    attr_node* pattr_node = NULL;
    printf("%d %d ",list->mote_addr,list->length);
    for (pattr_node = list->head ; pattr_node ; pattr_node = pattr_node->next) {
        int i;
        printf("%d %d ",pattr_node->type, pattr_node->length);
        for (i = 0; i < pattr_node->length; i++)
            printf("%d ",pattr_node->value[i]);
    }
    printf("\n");
}

int main(int argc, char **argv){
    char task_string[MAX_TASK_STRING_LEN];
    char host_name[200];
    int c;
    int simple = 0;

    /* default values */
    int tr_port = 9998;
    int interval_ms = 30000;
    strcpy(host_name, "127.0.0.1");

    if(signal(SIGINT, sig_int_handler) == SIG_ERR)
        fprintf(stderr, "Warning: failed to set SINGINT handler");

    /* parse option line */
    while ((c = getopt(argc, argv, "t:n:p:u:vahs")) != -1) {
        switch (c) {
            case 'n':
                strcpy(host_name, optarg); break;
            case 'p':
                tr_port = atoi(optarg); break;
            case 'v':
                setVerbose(); break;
            case 't':
                interval_ms = atoi(optarg); break;
            case 'a':
                print_tasklet_usage_all(); /* tasklet/taskingAPI usage */
                exit(1);
            case 'u':
                strcpy(task_string, optarg);
                printf("\n");
                print_tasklet_usage_guess(task_string, strlen(task_string));
                exit(1);
            case 's':
                simple = 1; break;
            case 'h':
            default:
                print_usage();
                exit(1);
        }
    }

    /* get string input */
    if (optind < argc) {
        strcpy(task_string, argv[optind]);
    } else {
        print_usage();
        exit(1);
    }

    /* configure connection to master transport layer */
    config_transport(host_name, tr_port);

    /* send task */
    tid = send_task(task_string);
    if (tid < 0) exit(1);

    /* receive response packets */
    struct response *list; 
    while (1) {
        list = read_response(interval_ms);
        if (list == NULL) {             // did not get any response.
            switch (get_error_code()) {
                case TIMEOUT:           // timeout which means either
                    delete_task(tid);   // - we are done (received all messages), or
                    exit(1);            // - motes are not sending
                case MOTE_ERROR:        // mote error,
                    continue;           // - keep receiving other messages 
                default:                // transport is probably broken
                    fprintf(stderr,"error code %d\n",get_error_code());
                    break;
            }
        }
        if (simple)
            print_response_simple(list);
        else
            response_print(list);        
        response_delete(list);
        
        fflush(stdout);
    }
    return 0;
}

