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
 * Header file for tenet transport API
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified May/22/2008
 **/

#ifndef _TRANSPORT_API_H_
#define _TRANSPORT_API_H_

#include <sys/types.h>
#include <unistd.h>
#include <stddef.h>
#include "common.h"


#define DEFAULT_TRANSPORT_HOST    "127.0.0.1"
#define DEFAULT_TRANSPORT_PORT    9998

#define NO_ERROR 1
#define TIMEOUT 0
#define OPEN_TRANSPORT_FAIL_ERROR -2
#define TASK_DESCRIPTION_ERROR -3
#define TASK_SEND_ERROR -4
#define FAILED_TO_SEND_ERROR -5
#define SELECT_ERROR -6
#define TRANSPORT_LAYER_DISCONNECTED_ERROR -7
#define MALLOC_FAILURE_ERROR -8
#define MOTE_ERROR -9
#define CHECK_STDIN -10


/* get error code */
int getTenetErrorCode();
/* print internal messages*/
void setTenetVerboseMode(void);

/* Set parameters to connect to transport*/
void config_transport(char *host, int port);
int open_transport();

/* Send/Disseminate already constructed tasking packet (internal use) */
int send_task_packet(int len, unsigned char *packet);

/* Receive task response packet */
unsigned char *receive_packet_with_timeout(uint16_t *tid, uint16_t *addr, int *len, int millitimeout);
/* this is blocking: will not return until a packet is received */
unsigned char *receive_packet(uint16_t *tid, uint16_t *addr, int *len);

/* Send/Disseminate delete task */
void send_delete_task(uint16_t tid);

/* definition of close done hander function pointer, and it's register function */
typedef void (*close_done_handler_t)(uint16_t, uint16_t);
void signal_close_done(uint16_t tid, uint16_t addr);

/* receive_packet returns on stdin interrupt*/
void setInteractive(void);

#endif

