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
 * Header file for 'sorted packet list' which is used by the transport
 * layer (e.g. StreamTransport) to temporarily buffer packets for
 * in-order delivery to the application.
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 2/5/2007
 **/

#ifndef _SORTED_PACKET_LIST_H_
#define _SORTED_PACKET_LIST_H_

#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>

struct SPList_entry {
    int value;  // sequence number, which we sort by.
    int len;        // length of the packet
    unsigned char* packet;  // packet pointer
    struct SPList_entry* next;
};

struct SortedPacketList {
    int length;
    struct SPList_entry* head;
};

void SPList_init(struct SortedPacketList *list); 
void SPList_insert(struct SortedPacketList *list, int value, unsigned char* packet, int len);
int SPList_getFirstValue(struct SortedPacketList *list);
unsigned char* SPList_deleteFirstPacket(struct SortedPacketList *list, int *value, int *len);
void SPList_clearList(struct SortedPacketList *list);
int SPList_find(struct SortedPacketList *list, int value);

#endif

