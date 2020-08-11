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
 * tid (transaction id) list related functions.
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

#include <sys/types.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <sys/time.h>

#include "transportmain.h"
#include "trsource.h"
#include "tosmsg.h"
#include "tr_if.h"
#include "tidlist.h"
#include "client.h"

//#define DEBUG_TIDLIST // print debugging messages


/*************************************************
   Global variable
*************************************************/
FILE *tid_fptr;
char *tid_filename;
char tid_filebuf[20];

uint16_t myTID;

struct tid_list *tids;
int num_tids;


/*************************************************
   Function declaration
*************************************************/
void rem_tid(struct tid_list **t);
struct tid_list **_find_tid(uint16_t tid);
void print_all_tids();


/////////////////////////////////////////////////


void store_tid() {
    tid_fptr = fopen(tid_filename, "w");
    if (tid_fptr != NULL) {
        fprintf(tid_fptr, "%hu \n", myTID);
        fflush(tid_fptr);
        fclose(tid_fptr);
    }
}

void tidlist_terminate() {
    store_tid();
}

uint16_t tidlist_init() {
    num_tids = 0;
    tid_fptr = fopen(tid_filename, "r");
    if (tid_fptr == NULL) {
        myTID = 1;
        store_tid();
    } else {
        fscanf(tid_fptr, " %hu", &myTID);
        fclose(tid_fptr);
    }
    return myTID;
}

uint16_t assign_new_tid(uint16_t tid) {
    // let tid=0 to automatically generate new tid
    while(1) {
        if ((tid != 0) &&
            (tid >= MIN_TID) && (tid <= MAX_TID) &&
            (tidlist_find_tid(tid) == NULL)) {
            break;
        } else {
            tid = myTID++;
            if (tid > MAX_TID) tid = MIN_TID;
        }
    }
    myTID = tid + 1; // the next tid to be used.
    if (myTID > MAX_TID) myTID = MIN_TID;

    store_tid(); // store myTID to a file.
    return tid;
}


/*************************************************
   Functions
*************************************************/

struct tid_list *tidlist_add_tid(uint16_t tid, uint16_t addr, int type, int fd) {
    struct tid_list *t;

    t = tidlist_find_tid(tid);
    if (t != NULL) {
        fprintf(stderr, "Duplicate tid detected.!!\n");
        return t;
    }
    
    t = malloc(sizeof *t);
    t->next = tids;
    tids = t;
    num_tids++;
    t->addr = addr;
    t->tid = tid;
    t->type = type;
    t->fd = fd;
    gettimeofday(&t->timestamp, NULL);
    if (t->type == TRANS_TYPE_TASK)
        print_all_tids();
    return t;
}

void rem_tid(struct tid_list **t) {
    struct tid_list *dead = *t;
    *t = dead->next;
    num_tids--;
    //close(dead->fd);  // do not close client fd. we might have other tids
    if (dead->type == TRANS_TYPE_TASK)
        print_all_tids();
    free(dead);
}

/**
 * This function sends close/delete/stop command for all tid
 * - should becareful not to stop the stopping command (infinit loop).
 * - this is called by 'client.c' when a client disconnects.
 **/
void close_all_tid_for_a_client(int client_fd) {
    struct tid_list **t;
    for (t = &tids; *t; ) {
        if ((client_fd == (*t)->fd) && 
            (((*t)->type == TRANS_TYPE_TASK) || ((*t)->type == TRANS_TYPE_CLOSE))) {
            (*t)->type = TRANS_TYPE_NULL;   // will be removed below...
            tr_send_close_task((*t)->tid, (*t)->addr);
            close_transport_connections((*t)->tid);
            rem_tid(t); // removing will move t to next ptr
        } else {
            t = &((*t)->next);
        }
    }
    print_all_tids();
}

void print_all_tids() {
    pstatus();
    #ifdef DEBUG_TIDLIST
        struct tid_list *t;
        for (t = tids; t; t = t->next) {
            printf("[tid_list]: tid=%d, addr=%d\n", t->tid, t->addr);
        }
    #endif
}

struct tid_list ** _find_tid(uint16_t tid) {
    struct tid_list **t;
    for (t = &tids; *t; ) {
        if ((*t)->tid == tid)
            return t;
        else
            t = &((*t)->next);
    }
    return NULL;    // Error, not found
}

struct tid_list * tidlist_find_tid(uint16_t tid) {
    struct tid_list **t;
    t = _find_tid(tid);
    if (t)
        return (*t);
    return NULL;
}

void tidlist_remove_tid(uint16_t tid) {
    struct tid_list **t;
    t = _find_tid(tid);
    if (t)
        rem_tid(t);
}

int find_client_fd(uint16_t tid) {
    struct tid_list **t;
    t = _find_tid(tid);
    if (t)
        return (*t)->fd;
    else
        return -1;  // Error, not found
}

int send_to_tid(const void *packet, int len, uint16_t tid, uint16_t addr) {
    int ok;
    int fd = find_client_fd(tid);

    if (tid == ALL_TID) {
        dispatch_packet(packet, len);
        return 0;
    } else if (fd < 0) {
        #ifdef DEBUG_TIDLIST
            fprintf(stderr, "No client/tid for this packet. ");
            fprintf(stderr, "(tid=%d, addr%d) dropping..\n", tid, addr);
        #endif
        return -1;
    }
    
    ok = write_tr_packet(fd, packet, len);
    
    if (ok < 0) {
        tidlist_remove_tid(tid);
        return -1;
    } else if (ok > 0) {
        #ifdef DEBUG_TIDLIST
            fprintf(stderr, "Note: write to client tid failed\n");
        #endif
        return 1;
    }
    return 0;
}

int tidlist_num_tids() {
    return num_tids;
}

