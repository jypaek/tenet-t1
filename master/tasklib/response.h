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

/*
 * This file defines the struct Response.
 * Response struct is what the application layer receives from the network.
 * Response is a list of attr_node.
 * Attr_node represents an attribute. It could be scalar or vector.
 */

/*
* Authors: Jeongyeup Paek
* Authors: Marcos Vieira
* Embedded Networks Laboratory, University of Southern California
* 
*/
#ifndef _ATTRLIST_
#define _ATTRLIST_
//#define LIST_DEBUG

#include <stdio.h>
#include <string.h>
#include <stdlib.h>

typedef struct attr_node {
    int type;
    int* value;
    int length;
    struct attr_node* next;
} attr_node;

typedef struct response {
    struct attr_node* head;
    int length;
    int tid;
    int mote_addr;
} response;

response* response_create(int tid,int mote_addr);
void response_delete(struct response* list);

attr_node* response_find(struct response* list, int type);

int response_insert(struct response* list, int type, int* value, int length);
int response_length(struct response* list);
int response_tid(struct response* list);
int response_mote_addr(struct response* list);

int response_remove(struct response* list, int type);
attr_node* response_pop(struct response* list);
void response_print(struct response* list);

#endif
