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
 * Tenet API that the application can used to 
 * - configure and connect to the master transport layer,
 * - disseminate tasks,
 * - receive responses, and
 * - check errors.
 *
 * @author Jeongyeup Paek
 * @author Marcos Vieira
 * Embedded Networks Laboratory, University of Southern California
 * @modified May/22/2008
 **/

#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <unistd.h>
#include <string.h>
#include <stddef.h>
#include <errno.h>
#include "sfsource.h"
#include "tosmsg.h"
#include "tr_if.h"
#include "serviceAPI.h"
#include "transportAPI.h"
#include "tenet.h"
#include "task_construct.h"
#include "task_error.h"
#include "tenet_task.h"


/* Below 'extern' variables are declared in transportAPI.c */
extern int   tr_fd;            // socket file descriptor for the transport layer
extern int   tr_opened;        // is the connection to the transport layer opened?
extern char *tr_host;          // host name of the transport layer
extern int   tr_port;          // port number of the transport layer
extern char  tr_host_buf[40];  // host name buffer

extern int tenetVerboseMode;   // verbose mode, print messages on stdout.
extern int tenetErrorCode;     // Tenet error code.

extern close_done_handler_t close_done_handler;


/**
 * Returns the current error code.
 * Application can call this to see what type of error happened when 
 * 'read_response' function returns NULL.
 **/
int get_error_code() {
    return tenetErrorCode;
}

void setVerbose(void) {
    tenetVerboseMode = 1;
}


/**
 * Send a task to the transport layer, 
 * which will be disseminated through the whole network.
 *
 * @param task_string is a task description string which will be
 *                    converted into a tasking packet.
 **/
int send_task(char *task_string) {
    unsigned char packet[300];
    int len;
    int s_tid;
    /* DeleteALL is a special case (delete all tasks, not install) */
    if (!strcasecmp(task_string, "DeleteALL")) {
        delete_task(65535);
        return 65535;
    }

    len = construct_task(packet, task_string);  // construct a task packet
    if (len < 0) {
        fprintf(stderr,"task description error!! \n");
        tenetErrorCode = TASK_DESCRIPTION_ERROR;
        return -1;
    }
    if (tenetVerboseMode) {
        printf("Task string ....... : %s\n", task_string);
        printf("Task packet length  : %d\n", len);
    }

    s_tid = send_task_packet(len, packet);
    return s_tid;
}


/**
 * Read a task response packet from the trasnport layer 
 * and return a list of attributes that were in the received response.
 *
 * @param militimeout : timeout in miliseconds.
 * @return list : a 'response *' data structure that contains a list of attributes.
 **/
response* read_response(int millitimeout) {
    uint16_t r_tid, r_addr;
    int l = 0;
    response *list = NULL;

    unsigned char *packet = receive_packet_with_timeout(&r_tid, &r_addr, &l, millitimeout);
    if (tenetErrorCode < 0) return NULL;

    if (packet) {
        unsigned char *nextptr = packet;
        int offset = 0;

        if (check_error_response((unsigned char*)packet)) {
            print_error_response(stderr, (unsigned char*)packet, r_addr);
            tenetErrorCode = MOTE_ERROR;
            free((void *)packet);
            return NULL;
        }

        list = response_create((int)r_tid,(int)r_addr);
        if (!list) {
            tenetErrorCode = MALLOC_FAILURE_ERROR;
            free((void *)packet);
            return NULL;
        }

        if (tenetVerboseMode) { 
            printf("\nincome packet:");
            fdump_packet(stdout, packet,l);
        }

        while (offset < l) {
            int i, nelements = 0;
            attr_t *attr = (attr_t *)nextptr;
            int* datavector;
            int data;
            int length = (attr->length/2) + (attr->length%2);   // one more if odd number of bytes

            datavector = (int*)malloc(sizeof(int)*length);

            /*break 2 char* into integer and construct a vector*/
            for (i = 0; i < attr->length; i += 2) {
                if (i == (attr->length - 1))
                    data = (uint16_t) *((uint8_t*)&attr->value[i]); // take care of odd number bytes
                else
                    data = (uint16_t) *((uint16_t*)&attr->value[i]);
                datavector[nelements] = data;
                nelements++;
            }

            response_insert(list, attr->type, datavector, nelements);
            free(datavector);

            offset += offsetof(attr_t, value) + attr->length;
            nextptr = packet + offset;
        }
        free((void *)packet);
    }
    return list;
}


/**
 * Delete a task
 * - send a DELETE task that deletes the previously installed task.
 *
 * @param tid : tid of the task that you want to delete.
 **/
void delete_task(int tid) {
    uint16_t s_tid = (uint16_t)tid;
    tr_close_task(tr_fd, s_tid);
    return;
}


///// UNDER TESTING /////

void register_close_done_handler(close_done_handler_t handler) {
    close_done_handler = handler;
}

