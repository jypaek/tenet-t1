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
 * Header file for tid (transaction id) list related functions.
 *
 * When an application sends a task, assign an unique tid and disseminate 
 * the task with that tid.
 * Maintains the list of tid's used for tasks.
 * When an application disconnects, automatically send out DELETE task
 * for the tid's that belong to that application.
 * When this transport itself terminates, automatically send out DELETE task
 * for all the tid's in the list.
 * When a DELETE task is sent from the application, delete the corresponding
 * tid from the list.
 * When a packet is received at the transport layer, and if the transport 
 * layer decides that the packet should be forwarded to an application,
 * it looks up the tid-client binding list, and forward it to the appropirate
 * client application through the socket file descripter in the list.
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 2/5/2007
 **/


#ifndef _TID_LIST_H_
#define _TID_LIST_H_

#include <sys/types.h>
#include "timeval.h"
#include "transport.h"

#define ALL_TID 0xffff
#define MAX_TID 0xc350  // 50000
#define MIN_TID 1

#define TID_LOGFILE  ".tenettid"


/*************************************************
   assign tid function
*************************************************/
uint16_t tidlist_init();
void tidlist_terminate();
uint16_t assign_new_tid(uint16_t tid);


/*************************************************
   Interfaces to use tid list
*************************************************/
struct tid_list *tidlist_add_tid(uint16_t tid, uint16_t addr, int type, int fd);
struct tid_list *tidlist_find_tid(uint16_t tid);
void tidlist_remove_tid(uint16_t tid);
int send_to_tid(const void *packet, int len, uint16_t tid, uint16_t addr);
void close_all_tid_for_a_client(int client_fd);
int tidlist_num_tids();


/*************************************************
   Data structure
*************************************************/
struct tid_list {
    struct tid_list *next;  // linked list pointer
    uint16_t tid;              // tid of this transactions
    uint16_t addr;          // destination address, usually the target mote
    int type;               // type of transaction: TRANS_TYPE
    int fd;                 // fd of the client that created this transaction
    struct timeval timestamp;
};


#endif

