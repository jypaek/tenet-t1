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
 * File for 'sorted packet list' which is used by the transport
 * layer (e.g. StreamTransport) to temporarily buffer packets for
 * in-order delivery to the application.
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 2/5/2007
 **/


#include "sortedpacketlist.h"
#include "streamtransport.h"

//#define DEBUG_SPLIST

int SPList_isEmpty(struct SortedPacketList *list);
int SPList_getLength(struct SortedPacketList *list);
void SPList_printList(struct SortedPacketList *list);


void SPList_init(struct SortedPacketList *list) {
    list->head = NULL;
    list->length = 0;
    return;
}

int SPList_find(struct SortedPacketList *list, int value) {
    struct SPList_entry* entry = list->head;
    while (entry) {
        if (entry->value == value)
            return entry->value;    // we assume that 'value is positive
        entry = entry->next;
    }
    return -1;
}

void SPList_insert(struct SortedPacketList *list, int value, unsigned char* packet, int len) {
    struct SPList_entry *new_entry, *entry;
    
    if (SPList_find(list, value) >= 0) {
        #ifdef DEBUG_SPLIST
            printf("\t[SPL] Duplicate found: %d\n", value);
        #endif
        return;
    }
    
    new_entry = malloc(sizeof(struct SPList_entry));
    new_entry->value = value;
    new_entry->packet = packet;
    new_entry->len = len;
    new_entry->next = NULL;

    if (list->length == 0) {
        list->head = new_entry;
        #ifdef DEBUG_SPLIST
            printf("\t[SPL] Insert at head (%d, %d), list_len=%d\n", value, len, list->length+1);
        #endif
    } else if (((new_entry->value < list->head->value)
                || (new_entry->value > list->head->value + TR_MAX_SEQNO/2))
                && (new_entry->value + TR_MAX_SEQNO/2 > list->head->value)) {
    //} else if (new_entry->value < list->head->value) {
        new_entry->next = list->head;
        list->head = new_entry;
        #ifdef DEBUG_SPLIST
            printf("\t[SPL] Insert at head (%d, %d) list_len=%d\n", value, len, list->length+1);
        #endif          
    } else {
        entry = list->head;
        while (entry) {
            if (entry->next) {
                if (((new_entry->value < entry->next->value)
                            || (new_entry->value > entry->next->value + TR_MAX_SEQNO/2))
                            && (new_entry->value + TR_MAX_SEQNO/2 > entry->next->value)) {
                //if (new_entry->value < entry->next->value) {
                    #ifdef DEBUG_SPLIST
                        printf("\t[SPL] Insert between %d and %d, (%d, %d) list_len=%d\n", 
                            entry->value, entry->next->value, value, len, list->length+1);
                    #endif
                    new_entry->next = entry->next;
                    entry->next = new_entry;
                    break;
                } // else if (==) : this cannot happen, because we did 'find' already
                // else (<) : we go to next entry
            } else {
                #ifdef DEBUG_SPLIST
                    printf("\t[SPL] Insert at the end after %d (%d, %d) list_len=%d\n", 
                        entry->value, value, len, list->length+1);
                #endif              
                entry->next = new_entry;
                break;
            }
            entry = entry->next;
        }
    }
    list->length++;

}

int SPList_getFirstValue(struct SortedPacketList *list) {
    if (list->length == 0)
        return -1;

    return list->head->value;
}

unsigned char* SPList_deleteFirstPacket(struct SortedPacketList *list, int *value, int *len) {
    struct SPList_entry* entry = list->head;
    unsigned char* packet;
    
    if (list->length == 0) {
        *value = 0;
        *len = 0;
        return NULL;
    } else if (entry == NULL) {
        printf("\t[SPL] Fatal Error... in deleteFirstPacket\n");
    }
    
    *value = entry->value;
    *len = entry->len;
    packet = entry->packet;
    list->head = entry->next;
    list->length--;
    #ifdef DEBUG_SPLIST
        if (list->head) {
            printf("\t[SPL] Delete first (%d, %d), (next is.. %d, list_len=%d)\n", 
                *value, *len, list->head->value, list->length);
        } else {
            printf("\t[SPL] Delete first (%d, %d), (list_len=%d)\n", 
                *value, *len, list->length);
        }
    #endif
    free(entry);
    return packet;
}

int SPList_isEmpty(struct SortedPacketList *list) {
    if (list->length == 0)
        return 1;
    else
        return 0;
}

int SPList_getLength(struct SortedPacketList *list) {
    return list->length;
}

void SPList_printList(struct SortedPacketList *list) {
    #ifdef DEBUG_SPLIST
        struct SPList_entry* entry = list->head;
        printf("\t[SPL] Printing the list\n");
        while(entry) {
            printf("%d ", entry->value);
            entry = entry->next;
        }
        printf("\n");
    #endif
}

void SPList_clearList(struct SortedPacketList *list) {
    struct SPList_entry *entry, *next;
    if (!list)
        return;
    entry = list->head;
    #ifdef DEBUG_SPLIST
        printf("\t[SPL] Clearing the list\n");
    #endif
    while (entry) {
        next = entry->next;
        if (entry->packet)
            free(entry->packet);
        free(entry);
        entry = next;
    }
}

