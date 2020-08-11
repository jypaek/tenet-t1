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
 * Application programming interface of Tenet Library for the Master Side.
 * Applications should use this functions.
 *
 * @author Jeongyeup Paek
 * @author Marcos Vieira
 * Embedded Networks Laboratory, University of Southern California
 * @modified 10/18/2006
 **/

#ifndef _TENET_API_H_
#define _TENET_API_H_

#include "response.h"
#include "transportAPI.h"

/* Send/Disseminate task */
int send_task(char *task_string);

/* Delete/Close a task with tid=tid */
void delete_task(int tid);

/* Receive task response packet
    - '-1' will make it blocking */
response* read_response(int militimeout);

/* Set parameters to connect to transport*/
extern void config_transport(char *host, int port);
extern int open_transport();

/* print internal messages*/
void setVerbose(void);

/* get_error_code */
int get_error_code();

void register_close_done_handler(close_done_handler_t handler);

#endif

