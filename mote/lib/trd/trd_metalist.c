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
 * Functions for accessing MetaList data structure in TRD.
 * - This file provides the structures and the functions for a list of metadatas
 * - To use the MetaList, you must do the following.
 *   - Declare a MetaList:           "MetaList rlist;"
 *   - Declare MetaListEntry array:  "MetaListEntry entry[SIZE];"
 *   - Call initialization function:     "metalist_init(&rlist, entry, SIZE);"
 *   - This allocates(links) memory: "rlist->item = entry"
 * - We can make multiple instances of MetaLists using this method.
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 8/21/2006
 **/


#include <stdlib.h>
#include "trd_metalist.h"

void metalist_clear(MetaList *rlist) {
    int i;
    rlist->head_p = 0;
    rlist->tail_p = 0;
    rlist->length = 0;
    for (i = 0; i < rlist->max_size; i++) {
        rlist->item[i].origin = 0 ;
        //rlist->item[i].seqno = 0 ;
    }
}   

void metalist_init(MetaList *rlist, MetaListEntry *buf, uint8_t list_size) {
    rlist->item = buf;
    rlist->max_size = list_size;
    metalist_clear(rlist);
}                                                            

int metalist_findIndex(MetaList *rlist, uint16_t origin, uint16_t seqno) {
    int i;
    if (rlist->length == 0)
        return -1;
    i = rlist->tail_p;
    do  {
        if ((rlist->item[i].origin == origin) 
                && (rlist->item[i].seqno == seqno))
            return i;
        i++;
        if (i == rlist->max_size)
            i = 0;
    } while (i != rlist->head_p);
    return -1;
}

uint8_t metalist_isInList(MetaList *rlist, uint16_t origin, uint16_t seqno) {
    if (metalist_findIndex(rlist, origin, seqno) < 0)
        return 0;
    else
        return 1;
}

void metalist_insert(MetaList *rlist, uint16_t origin, uint16_t seqno) {
    if (rlist->length < rlist->max_size) {
        if (metalist_findIndex(rlist, origin, seqno) < 0) {
            rlist->item[rlist->head_p].origin = origin;
            rlist->item[rlist->head_p].seqno = seqno;
            rlist->head_p = (rlist->head_p + 1);
            if (rlist->head_p == rlist->max_size)
                rlist->head_p = 0;
            rlist->length++;
        }
    }
}

MetaListEntry* metalist_deleteFirst(MetaList *rlist) {
    MetaListEntry *entry = &rlist->item[rlist->tail_p];
    if (rlist->length == 0)
        return NULL;
    rlist->tail_p = rlist->tail_p + 1;
    if (rlist->tail_p == rlist->max_size)
        rlist->tail_p = 0;
    rlist->length--;
    return entry;
}

uint8_t metalist_isFull(MetaList *rlist) {
    if (rlist->length == rlist->max_size)
        return 1;
    else
        return 0;
}

uint8_t metalist_isEmpty(MetaList *rlist) {
    if (rlist->length == 0)
        return 1;
    else
        return 0;
}

MetaListEntry* metalist_getFirst(MetaList *rlist) {
    if (rlist->length == 0)
        return NULL;
    return &rlist->item[rlist->tail_p];
}


