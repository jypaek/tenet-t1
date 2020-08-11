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
 * XmastTree application makes all LEDS blink synchronously.
 *
 * This application first verify if all the nodes in the network are synchronized.
 * If there is at least one node that is not synchronized, it will wait for it to synchronized.
 *
 * When all nodes are synchronized, the application will task for nodes to blink in the same time.
 *
 * Blink should be similar to CntToLeds behavior in TinyOs. 
 * Blinks should a value that is incremented every time.
 * The difference is that here all nodes do this synchronosly!
 *
 * It is an application that is part of Tenet Distribution
 * ( http://tenet.usc.edu )
 *
 * Authors: Marcos Augusto Menezes Vieira
 * Embedded Networks Laboratory, University of Southern California
 **/

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include "tenet.h"

void print_usage() {
    printf("Blink all LEDS synchronously.\n\n");
    printf("Usage: xmasTree [-vh] [-n host] [-p port] [-t timeout]\n\n");
    printf("  h : display this help message\n");
    printf("  v : verbose mode. Display all traffic messages.\n");
    printf("  n : host on which transport is running.Default is localhost\n");
    printf("  p : port on which transport is listening for connection. Default is port 9998.\n");
    printf("  t : time (in ms) to wait before changing LEDs. Default is 1s.\n");
}

                
int main(int argc, char **argv)
{
    int tid = 0;
    char task_string1[200];     // for checking timesync
    char task_string2[200];     // for xmastree blinking
    unsigned int blink_interval_ms = 1000;  // blink interval

    int c;
    int verbose = 0;

    struct response *list;
    struct attr_node* valueNode;

    int tr_port = 9998;
    char host_name[200];
    strcpy(host_name, "127.0.0.1");

    while ((c = getopt(argc, argv, "vh:n:p:t:")) != -1)
      switch(c){
        case 'n':
          strcpy(host_name,optarg); break;
        case 'p':
          tr_port = atoi(optarg); break;
        case 't':
          blink_interval_ms = atoi(optarg); break;
        case 'v':
          setVerbose(); verbose = 1; break;
        case 'h': case '?': default:
          print_usage();
          exit(1);
    }
  
    config_transport(host_name, tr_port);

    /* task string that checks whether nodes are time-synchronized */
    strcpy(task_string1, "is_timesync(0x3)->globaltime(0x2)->localtime(0x4)->sendpkt(1)");

    /* run xmastree forever ! */
    while (1) {
        int wait_interval_ms = 5000;
        int notSynchronized = 0;
        int npackets = 0;
        unsigned long int maxtime;      // largest time value we got
        unsigned long int starttime;    // the time that motes will start blinking

        /* verify if all nodes are synchronized */
        do {
            notSynchronized = 0;

            tid = send_task(task_string1);
            if (tid < 0) {
                printf("couldn't send task 1...\n");
                exit(1);
            }
            printf("Verifying if all nodes are time-synchronized...\n");

            maxtime = 0;  // assuming that it is very unlikely to actually get 'time==0'
            npackets = 0;

            /* receive response packets */
            do {
                /* wait for all responses */
                list = read_response(wait_interval_ms);

                if (list == NULL) {
                    // did not get a response till timeout, or got a response with no attribute
                    if (get_error_code() == MOTE_ERROR) continue;   // ignore error?
                    // if not error, then it was timeout. assume we got all packets
                    break;  // BREAK;
                } 
                else if (tid != list->tid) { // if the tid is not what I've sent out
                    response_delete(list);   // don't process packet
                } else {
                    int isSynchronized = 0;
                    unsigned long int currGlobaltime, localtime;

                    npackets++;

                    valueNode = response_find(list, 0x2);    /* extract data: globaltime */
                    currGlobaltime = (valueNode->value[1]<<16) + valueNode->value[0];
                    valueNode = response_find(list, 0x3);    /* extract data: is_timesync */
                    isSynchronized = valueNode->value[0];
                    valueNode = response_find(list, 0x4);    /* extract data: localtimetime */
                    localtime = (valueNode->value[1]<<16) + valueNode->value[0];
                    
                    if (isSynchronized == 0) { //some node is not synchronized yet
                        notSynchronized++; 
                    }
                    if ((isSynchronized) && (currGlobaltime > maxtime)) { // find max. global time value.
                        maxtime = currGlobaltime;
                    }
                    if (verbose) {
                        int nodeid = response_mote_addr(list);
                        printf("Node %d: GlobalTime %lu, isSynchronized %d, LocalTime %lu, max.GlobalTime so far %lu\n", 
                                nodeid, currGlobaltime, isSynchronized, localtime, maxtime);
                    }
                    response_delete(list);
                }
            } while(1); // until break;

            if (verbose)
                printf("Received %d packets;\n", npackets);

            if (npackets == 0) {
                printf("Please check network and try again since there were 0 packets received.\n");
                exit(1);
            }
            if (notSynchronized > 0) {
                printf("There are %d nodes not yet synchronized. waiting 30sec...\n", notSynchronized);
                wait_interval_ms += 2000;
                sleep(30);
            }

            if (tid) delete_task(tid); //close previous task

        } while ((notSynchronized != 0) || (maxtime == 0));

        /* let's start blinking after 10 seconds from now */
        starttime = maxtime + (32768*10); // delta, 10s (32768 = 1s)
        if (verbose)
            printf("Got Global Time %lu, will start xmasTree at %lu\n", maxtime, starttime);

        sleep(3);

        /* task to count and blink */
        sprintf(task_string2, "issue(%lu,%d,1)->count(0xED,0,1)->set_leds(0xED)", starttime, blink_interval_ms);
        if (verbose)
            printf("%s\n",task_string2);

        tid = send_task(task_string2);
        if (tid < 0) {
            printf("couldn't send task 2...\n");
            exit(1);
        }

        printf("LEDs should be blinking synchronously soon...\n");
        printf("\n\nPress Cntrl-C to STOP!\n");
        
        /* LEDs keep blinking and counting... */
        while (1) {                     // infinite
            list = read_response(-1);   // blocking wait
            if ((list == NULL) && (get_error_code() == MOTE_ERROR)) {
                // restart everything !!!
                printf("timesync out of sync... restarting xmastree after 30sec\n");
                sleep(30);
                break;
            }
            if (list) response_delete(list);
        }

        if (tid) delete_task(tid); //close previous blinking task
    }
    return 0;
}


