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
 * Header file for TRD_Table.
 *
 * A TRD_Table is an array of TRD_NodeCache's,
 * - where a TRD_NodeCache is a per-origin entry in TRD_Table.
 * TRD_NodeCache is an array of TRD_CacheEntry's,
 * - where a TRD_CacheEntry is a per-sequence_number entry in TRD_NodeCache.
 *
 *          TRD_Table
 *              |
 *         TRD_NodeCache[]
 *              |
 *         TRD_CacheEntry[][]
 *
 * TRD_Table can maintain information about dissemination activities from
 * upto TRD_NODE_ENTRIES number of origins (senders).
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 8/21/2006
 **/


#ifndef _TRD_TABLE_H_
#define _TRD_TABLE_H_

#include "trd.h"
#include "trd_nodecache.h"
#include "trd_seqno.h"

typedef struct TRD_Table {
    uint8_t  num_entries;   // number of node cache entries
    TRD_NodeCache ncache[TRD_NODE_ENTRIES];
} TRD_Table;


#ifdef BUILDING_PC_SIDE
uint8_t trd_table_init(TRD_Table *table);
uint8_t trd_table_numEntries(TRD_Table *table);
uint8_t trd_table_isFull(TRD_Table *table);
uint8_t trd_table_removeOldest(TRD_Table *table);
void trd_table_incrementAge(TRD_Table *table);
uint8_t trd_table_removeNode(TRD_Table *table, uint16_t origin);
uint8_t trd_table_insert(TRD_Table *table, uint16_t origin, uint16_t seqno, uint16_t memloc, uint16_t age);
uint8_t trd_table_getMemloc(TRD_Table *table, uint16_t origin, uint16_t seqno, uint16_t *memloc);
uint8_t trd_table_getAge(TRD_Table *table, uint16_t origin, uint16_t seqno, uint16_t *age);
uint8_t trd_table_exist(TRD_Table *table, uint16_t origin, uint16_t seqno);
uint16_t trd_table_getOldestSeqno(TRD_Table *table, uint16_t origin);
uint16_t trd_table_getLastSeqno(TRD_Table *table, uint16_t origin, uint16_t *age);
uint8_t trd_table_summarize(TRD_Table *table, TRD_SummaryMsg *sMsg, uint8_t *len, uint8_t ignore_old);
trd_class_t trd_table_classify(TRD_Table *table, uint16_t origin, uint16_t seqno, uint16_t age);
void trd_table_printCacheEntry(TRD_Table *table);
uint8_t trd_table_ignoreSummary(TRD_Table *table, TRD_SummaryMsg *smsg);
#endif

#endif

