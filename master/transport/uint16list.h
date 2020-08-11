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
 * Header file for a list data structure that has uint16_t as the content:
 * this is used as a list of sequence numbers in the transport layer
 * (e.g. missing packet list in StreamTransport).
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 2/5/2007
 **/


#ifndef _U16_LIST_H_
#define _U16_LIST_H_

#include <sys/types.h>

struct u16list_entry {
    unsigned short value;
    struct u16list_entry* next;
};

struct uint16list {
    int length;
    struct u16list_entry* head;
    struct u16list_entry* tail;     
};

void u16list_init(struct uint16list *list);  
unsigned short u16list_find(struct uint16list *list, unsigned short x);
unsigned short u16list_delete(struct uint16list *list, unsigned short x);
void u16list_insert(struct uint16list *list, unsigned short x);
unsigned short u16list_deleteFirst(struct uint16list *list);
int u16list_isEmpty(struct uint16list *list);
unsigned short u16list_getLength(struct uint16list *list) ;
unsigned short u16list_getFirst(struct uint16list *list);
unsigned short u16list_get_ith(struct uint16list *list, unsigned short i);
void u16list_clearList(struct uint16list *list);

#endif

