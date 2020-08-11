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
 * A simplest Tenet application: 'Blink/CntToLeds'
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

int m_tid = 0;  /* 'tid' (task_id) that is used to send my task */
int verbose = 0;

void print_usage() {
    printf("\n\"Blink/CntToLeds Application\" \n\n");
    printf(" Usage: blink [-h] [-n host] [-p port] [-t time] [-b bits]\n\n");
    printf("   h : display this help message.\n");
    printf("   n : host on which transport is running. (default is 'localhost')\n");
    printf("   p : port on which transport is listening for connection. (default port is 9998)\n");
    printf("   t : blinking interval in millisec. (default is 500ms)\n");
    printf("   b : run in 'blink' mode instead of 'cnttoleds'. (default is 'cnttoleds')\n");
    printf("       'bitmap' represent which leds to 'blink'. (-b 1 will only blink red leds)\n");
}

void sig_int_handler(int signo) {
    if (m_tid) delete_task(m_tid);
    exit(0);
}


int main(int argc, char **argv){
    char my_task_string[200];
    unsigned int interval = 500;
    int blinkmode = 0;
    struct response *list; 
    int c;
    int tr_port = 9998;                 /* the port number where the Tenet master stack is running */
    char host_name[200];
    strcpy(host_name, "127.0.0.1");     /* the host where the Tenet master stack is running */


    /* register a Ctrl-C interrupt handler so that we can cleanly kill the task */
    if(signal(SIGINT, sig_int_handler) == SIG_ERR)
        fprintf(stderr, "Warning: failed to set SINGINT handler");

    /* parse option line */
    while ((c = getopt(argc, argv, "t:n:p:vh")) != -1) {
        switch(c) {
            case 'n':
                strcpy(host_name, optarg); break;
            case 'p':
                tr_port = atoi(optarg); break;
            case 't':
                interval = atoi(optarg); break;
            case 'b':
                blinkmode = atoi(optarg); break;
            case 'v':
                verbose = 1; break;
            case 'h':
            case '?':
            default:
                print_usage();
                exit(1);
        }
    }

    /* configure the host:port setting for connecting to the Tenet master stack */
    config_transport(host_name, tr_port);

    /* construct my task (either blink or cnttoleds) */
    if (blinkmode > 0)  // blink mode
        sprintf(my_task_string, "repeat(%u)->count(2,%d,4)->set_leds(2)", interval, blinkmode);
    else                // cnttoleds mode
        sprintf(my_task_string, "repeat(%u)->count(2,0,1)->set_leds(2)", interval);

    if (verbose)
        printf("TASK: %s\n", my_task_string);

    /* send my task */
    m_tid = send_task(my_task_string);
    if (m_tid < 0) exit(1); /* if tid < 0, that means task dissemination failed */
    
    printf("LEDs should be blinking...\n");
    printf("\n\nPress Cntrl-C to STOP!\n");

    while (1) {
        // We are not really waiting for any response since 
        // 'blink' application does not have any responses. 
        // But we do want to get error messages, if any.
        list = read_response(-1);   // blocking wait for any reponse
        if (get_error_code() < 0)   // check if there is an error on below layers
            printf("Error! error code = %d\n", get_error_code());
        response_delete(list);
    }
    return 0;
}


