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
 * Tenet transport API that the application can used to 
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
#include "trsource.h"
#include "tosmsg.h"
#include "timeval.h"
#include "tr_if.h"
#include "serviceAPI.h"
#include "transportAPI.h"


int   tr_fd;                // socket file descriptor for the transport layer
int   tr_opened = 0;        // is the connection to the transport layer opened?
char *tr_host = NULL;       // host name of the transport layer
int   tr_port = 0;          // port number of the transport layer
char  tr_host_buf[40];      // host name buffer

int   tenetVerboseMode = 0; // verbose mode, print messages on stdout.
int   tenetErrorCode = 0;   // Tenet error code.

close_done_handler_t close_done_handler = NULL;


int getTenetErrorCode() {
    return tenetErrorCode;
}

void setTenetVerboseMode(void) {
    tenetVerboseMode = 1;
}


/**
 * Configure the host name and the port number of the transport layer.
 * Application will connect to the transport layer using the 
 * configured host name and the port number.
 * Connection is established when the application sends a task for the
 * first time.
 **/
void config_transport(char *host, int port) {
    if (host != NULL) {
        strcpy(tr_host_buf, host);
        tr_host = tr_host_buf;
    }
    if (port != 0)
        tr_port = port;
}

/**
 * Open a socket connection to the master transport layer
 **/
int open_transport() {
    char *tmp;
    if (tr_opened) // if already opened,
        return 1;    //    no need to open again.
        
    if (tr_host == NULL) {
        tmp = getenv("TENET_TRANSPORT_HOST");
        if (tmp) tr_host = tmp;
        else tr_host = DEFAULT_TRANSPORT_HOST;
    }
    if (tr_port == 0) {
        tmp = getenv("TENET_TRANSPORT_PORT");
        if (tmp) tr_port = atoi(tmp);
        else tr_port = DEFAULT_TRANSPORT_PORT;
    }
    tr_fd = open_tr_source(tr_host, tr_port);
    if (tr_fd < 0) {
        fprintf(stderr, "Couldn't open transport layer at %s:%d\n", tr_host, tr_port);
        fprintf(stderr, "TENET_TRANSPORT_HOST = %s\n", getenv("TENET_TRANSPORT_HOST"));
        fprintf(stderr, "TENET_TRANSPORT_PORT = %s\n", getenv("TENET_TRANSPORT_PORT"));
        fprintf(stderr, "DEFAULT_TRANSPORT_HOST = %s\n", DEFAULT_TRANSPORT_HOST);
        fprintf(stderr, "DEFAULT_TRANSPORT_PORT = %d\n", DEFAULT_TRANSPORT_PORT);
        return tr_fd;//exit(1);
    }
    tr_opened = 1; // socket to transport layer is opened.
    return tr_fd;
}

void close_transport_socket() {
    if (tr_opened)
        close(tr_fd);
}

/////////////////////////

int send_task_packet(int len, unsigned char *packet) {
    int s_tid;

    tenetErrorCode = NO_ERROR;
    
    if ((!tr_opened) && (open_transport() < 0)) {
        tenetErrorCode = OPEN_TRANSPORT_FAIL_ERROR;  //failed to open_transport
        return -1;
    }
    
    s_tid = tr_send_task(tr_fd, len, packet);
    if (s_tid < -1) {       // -2
        tenetErrorCode = TASK_SEND_ERROR;        // app couldn't send to transport
    } else if (s_tid < 0) { // -1
        tenetErrorCode = FAILED_TO_SEND_ERROR;   // transport couldn't disseminate
    }
       
    if (tenetVerboseMode) {
        if (s_tid > 0) {
            printf("Tasking success ... : tid %d\n", s_tid);
            printf("Tasking packet .... : "); fdump_packet(stdout, packet,len);
        } else {
            printf("Tasking failed .... : tid %d\n", s_tid); 
            fdump_packet(stdout, packet,len);
        }
    }

    return s_tid;
}


unsigned char *receive_transport_packet(uint16_t *r_tid, uint16_t *r_addr, int *r_len) {
    int paylen = 0;
    uint16_t addr, tid;
    uint8_t tr_type;
    void *payload = NULL;
    unsigned char *packet;
    unsigned char *return_buf = NULL;
    
    packet = (unsigned char*) read_transport_msg(tr_fd, &paylen, &tr_type, &tid, &addr, &payload);

    if (!packet) {
        *r_len = -1;
        return NULL; // exit(0);
    } else {
        *r_len = 0;
    }

    switch (tr_type) {
        case TRANS_TYPE_RESPONSE:
            *r_tid = tid;
            *r_addr = addr;
            *r_len = paylen;
            return_buf = (unsigned char *)malloc(paylen);
            memcpy(return_buf, payload, paylen);
            break;
        case TRANS_TYPE_PING: // ping result came back
            signal_ping_result(tid, addr, paylen, (unsigned char*)payload);
            break;
        case TRANS_TYPE_TRACERT: // trace route result came back
            signal_tracert_result(tid, addr, paylen, (unsigned char*)payload);
            break;
        case TRANS_TYPE_SERVICE: // service result (timesync, power, etc) came back
            signal_service_result(tid, paylen, (unsigned char*)payload);
            break;
        case TRANS_TYPE_CLOSE_ACK: // acknowledgement for 'close_task' came back
            signal_close_done(tid, addr);
            break;
        default:
            break;
    }
    free((void *)packet);
    return return_buf; // we don't free this here
}


unsigned char *receive_packet_with_timeout(uint16_t *tid, uint16_t *addr, int *len, int millitimeout) {
    fd_set rfds;
    int maxfd = -1;
    int ret;
    unsigned char *packet = NULL;
    struct timeval tv, *tvp = &tv;
    
    tenetErrorCode = NO_ERROR;

    while(1) {

        FD_ZERO(&rfds);
        FD_SET(tr_fd, &rfds);
        maxfd = tr_fd;

        if (millitimeout < 0)
            tvp = NULL;
        else
            ms2tv(&tv, millitimeout);
    
        ret = select(maxfd + 1, &rfds, NULL, NULL, tvp);

        /* check for error condition */
        if (ret == -1) {
            /* continue if interrupted */
            if (errno == EINTR) {
                if (tenetVerboseMode) fprintf(stderr, "INTERRUPTED\n");
                return NULL;
                //continue;
            }
            /* we have a serious error */
            fprintf(stderr, "Error: transport layer select() failed with errno = %d\n", errno);
            tenetErrorCode = SELECT_ERROR;
            return NULL;
        } 
        else if (ret) {
            if (FD_ISSET(tr_fd, &rfds)) {
                packet = receive_transport_packet(tid, addr, len);

                if (len < 0) {
                    fprintf(stderr, "NULL packet. transport layer might be disconnected.\n");
                    tenetErrorCode = TRANSPORT_LAYER_DISCONNECTED_ERROR;
                }
                if (tenetErrorCode < 0) return NULL;
                if (packet != NULL) return packet;
            }
        }
        else {
            /* timeout */
            tenetErrorCode = TIMEOUT;
            if (tenetVerboseMode) printf("receive timeout\n");
            return NULL;
        }
    }
    return NULL;
}


unsigned char *receive_packet(uint16_t *tid, uint16_t *addr, int *len) {
    return receive_packet_with_timeout(tid, addr, len, -1);
}


/**
 * Delete a task
 * - send a DELETE task that deletes the previously installed task.
 * @param tid : tid of the task that you want to delete.
 **/
void send_delete_task(uint16_t tid) {
    tr_close_task(tr_fd, tid);
    return;
}

///////////////////

void signal_close_done(uint16_t tid, uint16_t addr) {
    if (close_done_handler != NULL)
        (*close_done_handler)(tid, addr);
    return;
}

