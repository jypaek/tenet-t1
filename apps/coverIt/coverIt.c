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
 * CoverIt application only works for Telos nodes.
 * It is an application that is part of Tenet Distribution
 * ( http://tenet.usc.edu )
 *
 * This application illustrates how easy is to implement a collaborative task in Tenet.
 * If at least one node is covered, all nodes should have blue LED on.
 * If no nodes are covered, all nodes should have red LED on.
 * It continously read light sensor from Telos nodes.
 *
 * Try blocking a node, two nodes and no nodes.
 *
 * @author Marcos Augusto Menezes Vieira
 * Embedded Networks Laboratory, University of Southern California
 * @date Jan/12/2008
 **/

#include <stdio.h>
#include <stdlib.h>
#include <signal.h>
#include <string.h>
#include <unistd.h>
#include "tenet.h"

int verbosemode = 0;
int sampletid = 0;

void print_usage() {
    printf("CoverIt. If you cover a node, blue LED will be on all nodes.\n");
    printf("If no node are covered, red LED will be on.\n\n");
    printf("Usage: coverIt [-vh] [-n host] [-p port] \n\n");
    printf("  h : display this help message\n");
    printf("  v : verbose mode. Display all traffic messages.\n");
    printf("  n : host on which transport is running. Default is localhost\n");
    printf("  p : port on which transport is listening for connection. Default is port 9998.\n");
}

void construct_string(char *a,int LEDstate){
    sprintf(a,"set_leds('%d')",LEDstate);
}

void sig_int_handler(int signo) {
    if (sampletid)
        delete_task(sampletid);
    exit(1);
}
                
int main(int argc, char **argv)
{
    char host_name[200];
    char task_string[3][200];
    int tr_port;
    int c;
    int interval_ms = 1000;
    int isblocked = 0;
    int oldtid = 0;

    if (signal(SIGINT, sig_int_handler) == SIG_ERR)
        fprintf(stderr, "Warning: failed to set SINGINT handler");

    strcpy(host_name, "127.0.0.1");
    tr_port = 9998;

    while ((c = getopt(argc, argv, "vh:n:p:")) != -1)
        switch(c) {
            case 'n':
                strcpy(host_name,optarg); break;
            case 'p':
                tr_port = atoi(optarg); break;
            case 'v':
                verbosemode = 1;
                setVerbose();
                break;
            case 'h':
            case '?':
            default:
                print_usage();
                exit(1);
        }

    config_transport(host_name, tr_port);

    strcpy(task_string[0], "repeat(500)->sample(22,0xAA)->comparison(0xBB,0xAA,>,'150')->deleteallattributeif(0xBB)->send()"); 

    construct_string(task_string[1],1);
    construct_string(task_string[2],4);

    // sensor will send message only if it is blocked
    // if light sensor higher than threshold, suppress message 
    sampletid = send_task(task_string[0]);
    if (sampletid < 0) exit(1);

    /* initial state */
    isblocked = 0;
    oldtid = send_task(task_string[1]);


    printf("\n\nPress Cntrl-C to STOP!\n");

    /* receive response packets */
    struct response *list = NULL;

    while(1) {
        list = read_response(interval_ms);
        //if (list->tid! = sampletid)continue;
        if (verbosemode)
            printf("response length %d block %d\n",(list)?response_length(list):0, isblocked);

        if (list == NULL) { //timeout, nobody is blocking
            if (get_error_code() < 0) {//check if there is an error on below layers
                printf("exiting error code %d\n", get_error_code());
                exit(1);
            }

            if (isblocked){//change state to not blocked
                if (oldtid)delete_task(oldtid);
                usleep(1000);
                oldtid = send_task(task_string[1]);
                isblocked = 0;
                printf("No nodes are blocked. Changing to Non-Blocking state.\n");
            }
        } else {
            // there is at least a node being covered
            if (!isblocked) {   // change state to blocked
                if (oldtid)
                    delete_task(oldtid);
                usleep(1000);
                oldtid = send_task(task_string[2]);
                isblocked = 1;
                printf("Node %d is blocked. Changing to Blocking state.\n",list->mote_addr);
            }
        }

        if (verbosemode) {
            if (list)
                response_print(list);
        }

        if (list) response_delete(list);
    }
    return 0;
}

