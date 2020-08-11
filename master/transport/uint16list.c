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
 * File for accessing a list that has uint16_t as the content:
 * this is used as a list of sequence numbers in the transport layer
 * (e.g. missing packet list in StreamTransport).
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 2/5/2007
 **/

#include "uint16list.h"
#include <string.h>
#include <stdlib.h>

void u16list_init(struct uint16list *list) {
    list->head = NULL;
    list->tail = NULL;      
    list->length = 0;
    return;
}                                                            

unsigned short u16list_find(struct uint16list *list, unsigned short x) {
    struct u16list_entry* entry = list->head;       
    while (entry) {
        if (entry->value == x)
            return entry->value;
        entry = entry->next;
    }
    return 0xffff;
}

unsigned short u16list_delete(struct uint16list *list, unsigned short x) {
    struct u16list_entry* prev, *entry;
    if (u16list_isEmpty(list))
        return 0xffff;
    entry = list->head;
    if (entry->value == x) {
        list->head = entry->next;
        list->length--;
        if (list->tail == entry)
            list->tail = NULL;
        free(entry);
        return x;
    } else {
        prev = list->head;
        entry = list->head->next;
        while (entry) {
            if (entry->value == x) {
                prev->next = entry->next;
                list->length--;
                if (list->tail == entry)
                    list->tail = prev;
                free(entry);
                return x;
            }
            prev = prev->next;
            entry = entry->next;
        }

    }
    return 0xffff;
}

void u16list_insert(struct uint16list *list, unsigned short x) {
    if (u16list_find(list, x) == 0xffff) {
        struct u16list_entry* entry = malloc(sizeof(struct u16list_entry));
        entry->value = x;
        entry->next = NULL;
        if (u16list_isEmpty(list)) {
            list->head = entry;
            list->tail = entry;
        } else {
            list->tail->next = entry;
            list->tail = entry;
        }
        list->length++;
    }
}

unsigned short u16list_deleteFirst(struct uint16list *list) {
    struct u16list_entry* entry = list->head;
    unsigned short val;
    if (list->length == 0)
        return 0xffff;
    val = entry->value;
    list->head = entry->next;
    list->length--;
    free(entry);
    return val;
}

int u16list_isEmpty(struct uint16list *list) {
    if (list->length == 0)
        return 1;
    else
        return 0;
}


unsigned short u16list_getLength(struct uint16list *list) {
    return list->length;
}

unsigned short u16list_getFirst(struct uint16list *list) {
    return list->head->value;
}

unsigned short u16list_get_ith(struct uint16list *list, unsigned short i) {
    struct u16list_entry* entry = list->head;
    unsigned short j;
    if (list->length < i)
        return 0xffff;
    
    for (j = 1; j < i; j++) {
        entry = entry->next;
    }
    return entry->value;
}

void u16list_clearList(struct uint16list *list) {
    struct u16list_entry *entry, *next;
    if (!list)
        return;
    entry = list->head;
    while(entry) {
        next = entry->next;
        free(entry);
        entry = next;
    }
}
