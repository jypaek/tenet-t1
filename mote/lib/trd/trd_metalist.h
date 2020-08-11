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
 * Header file for accessing MetaList data structure in TRD.
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



#ifndef _TRD_METALIST_H_
#define _TRD_METALIST_H_

#include "trd_seqno.h"

#ifdef BUILDING_PC_SIDE
#include "trd.h"
#endif

typedef struct MetaListEntry {
    uint16_t origin;
    uint16_t seqno;
} MetaListEntry;

typedef struct MetaList {
    uint8_t head_p;
    uint8_t tail_p;
    uint8_t length;
    uint8_t max_size;
    MetaListEntry *item;
} MetaList;

void metalist_init(MetaList *rlist, MetaListEntry *buf, uint8_t list_size);
uint8_t metalist_isInList(MetaList *rlist, uint16_t origin, uint16_t seqno);
void metalist_insert(MetaList *rlist, uint16_t origin, uint16_t seqno);
MetaListEntry* metalist_deleteFirst(MetaList *rlist);
uint8_t metalist_isFull(MetaList *rlist);
uint8_t metalist_isEmpty(MetaList *rlist);
MetaListEntry* metalist_getFirst(MetaList *rlist);

#endif // _TRD_METALIST_H_

