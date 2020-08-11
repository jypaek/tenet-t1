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
 * A Tenet application that plots the current routing forest (multi-tree).
 *
 * Sends out a task to all motes that asks for the current routing parent
 * of each mote. (and optionally the link quality metric for that parent).
 * Motes will send the task response to this application, and this application
 * will insert them into a tree data structure.
 * We can build a tree from the received 'parent-child' pairs.
 * This application will wait for 'interval_ms' time to receive reponses,
 * and print out the results on the screen.
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified May/25/2008
 **/


#include <stdio.h>
#include <stdlib.h>
#include <signal.h>
#include <unistd.h>
#include "ptree.h"
#include "sortedlist.h"
#include "tenet.h"


struct sortedlist *slist;       // list of nodes from which response was received
int with_link_quality = 0;      // print tree with link quality info.
int link_quality_is_rssi = 0;   // get RSSI as link quality.
int tid = 0;
char dotFilename[200];
int graphOutput = 0;            // whether to generate a dot file


/**
 * Terminate the application, due to either timeout of 'interval_ms'
 * or 'Ctrl-C' (SIGINT) by user.
 **/
void terminate_application(void) {
    FILE *in;

    if (tid) delete_task(tid);
    printf("\n");
    print_ptree(with_link_quality);
    if (graphOutput) {
        if ((in = fopen(dotFilename,"w")) == NULL) {
            printf("Not possible to open filename %s\n", dotFilename);
        } else {
            print_ptreeDotFormat(in, with_link_quality);
            fclose(in);
       }
    }

    delete_ptree();
    sortedlist_printValues(slist);
    //sortedlist_printMissing(slist);
    sortedlist_delete(slist);
    exit(1);
}

void sig_int_handler(int signo) {
    terminate_application();
}

void print_usage() {
    printf("pingtree draws the routing tree. \n");
    printf("Usage: pingtree [-qrvh] [-d filename] [-n host] [-p port] [-t timeout]\n\n");
    printf("  -h            : display this help message.\n");
    printf("  -v            : verbose mode. display additional informative messages.\n");
    printf("  -q            : print the tree with link quality (used by routing protocol).\n");
    printf("  -r            : print the tree with rssi as link quality.\n");
    printf("  -d [filename] : output DotFormat (text) to given filename.\n");
    printf("  -n [host]     : host on which transport is running. (default: localhost)\n");
    printf("  -p [port]     : port on which transport is listening for connection. (default: 9998)\n");
    printf("  -t [millisec] : time to wait after receiving last packet. (default: 5000)\n");
    printf("  -c [num]      : number of responses after which the program will stop.\n");
    exit(1);
}

int main(int argc, char **argv)
{
    char task_string[200];
    int c;
    int interval_ms = 10000;
    int verbosemode = 0;
    int numExpectedNodes = 0;
    struct response *list;      // response data structure (list of attribues)
    struct attr_node* valueNode;// attribute data structure
    int nexthop, linkq, nodeid;
    int tr_port = 9998;
    char tr_host[30];
    strcpy(tr_host, "127.0.0.1");

    while ((c = getopt(argc, argv, "n:p:t:d:rqvhc:")) != -1) {
        switch(c) {
            case 'r':
                link_quality_is_rssi = 1;          // get rssi as link quality 
            case 'q':
                with_link_quality = 1; break;      // get link quality 
            case 'n':
                strcpy(tr_host,optarg); break;     // set transport host
            case 'p':
                tr_port = atoi(optarg); break;     // set transport port
            case 't':
                interval_ms = atoi(optarg); break; // set timeout time
            case 'c':
                numExpectedNodes = atoi(optarg); break; // terminate after this many responses.
            case 'v':
                setVerbose(); verbosemode = 1; break;
            case 'd':
                strcpy(dotFilename, optarg); 
                graphOutput= 1; break;
            default:    // 'h','?'
                print_usage();
        }
    }

    /* set Ctrl-C handler */
    if (signal(SIGINT, sig_int_handler) == SIG_ERR)
        fprintf(stderr, "Warning: failed to set SINGINT handler");

    /* set the task string to send */
    if (link_quality_is_rssi == 1) {
        strcpy(task_string, "wait(2000)->nexthop(5)->rssi(6)->send(1)");
    } else if (with_link_quality == 1) {
        strcpy(task_string, "wait(2000)->nexthop(5)->linkquality(6)->send(1)");
    } else {
        strcpy(task_string, "wait(2000)->nexthop(5)->send(1)");
    }

    /* configure host name and port number for the transport layer */
    config_transport(tr_host, tr_port);

    /* send out the task through the transport layer */
    tid = send_task(task_string);
    if (tid < 0) exit(1); // fail.

    /* create a list for node-id's that we've received response from */
    slist = sortedlist_create();

    /* receive response packets */
    while (1) {

        /* read a response packet */
        list = read_response(interval_ms);
        if (list == NULL) {
            if (get_error_code() == TIMEOUT)
                terminate_application(); // no responses for 'interval_ms' time.
            else
                continue;                // ignore mote error
        }

        /* extract data from the task response */
        nodeid = response_mote_addr(list);      // 'node-id' == child
        valueNode = response_find(list, 5);     // 'nexthop(5)'
        nexthop = valueNode->value[0];          // 'next-hop' == parent
        add_ptree_edge(nexthop, nodeid);        // add to tree data structure.

        if (with_link_quality == 1) {
            valueNode = response_find(list, 6); // linkquality(6) or rssi(6)
            if (link_quality_is_rssi == 1) {
                linkq = (int16_t)valueNode->value[0];   // RSSI is signed (dbm)
            } else {
                linkq = (uint16_t)valueNode->value[0];  // unsigned metric
            }
            set_link_quality(nodeid, nexthop, linkq);
        }

        sortedlist_insert(slist, nodeid, nodeid); // insert node id into node-id list

        if (verbosemode) printf("nexthop info (%3d --> %3d)\n", nodeid, nexthop);
        else printf(".");
        fflush(stdout);

        response_delete(list);

        int l = sortedlist_length(slist); // check how many responses we've received.
        if (numExpectedNodes && (l == numExpectedNodes)) // if as expected,
            terminate_application();                     // done.
    }
    return 0;
}

