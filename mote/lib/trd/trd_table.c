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
 * Functions for accessing TRD_Table.
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


#ifdef BUILDING_PC_SIDE
#include <stdio.h>
#include <string.h>
#include <stddef.h>
#else
#include "trd_nodecache.c"
#endif
#include "trd_table.h"

uint8_t trd_table_init(TRD_Table *table) {
    uint8_t i;
    //dbg(DBG_USR1, "TRD_TableI.Init (#nodes %d)\n", TRD_NODE_ENTRIES);
    for (i = 0; i < TRD_NODE_ENTRIES; i++)
        nodecache_init(&table->ncache[i]);
    table->num_entries = 0;
    return 1;
}

uint8_t trd_table_numEntries(TRD_Table *table) {
    return table->num_entries;
}

uint8_t trd_table_isFull(TRD_Table *table) {
    if (table->num_entries >= TRD_NODE_ENTRIES)
        return 1;
    return 0;
}

uint8_t trd_table_remove_node_index(TRD_Table *table, int idx) {
    TRD_NodeCache *ncache, *lastncache;
    if (idx < 0)
        return 0;
    lastncache = (TRD_NodeCache *)&table->ncache[table->num_entries - 1];
    if (idx != table->num_entries - 1) {
        ncache = (TRD_NodeCache *)&table->ncache[idx];
        memcpy(ncache, lastncache, sizeof(TRD_NodeCache));
    }
    table->num_entries--;
    nodecache_init(lastncache);
    return 1;
}

int find_oldest_node_index(TRD_Table *table) {
    uint8_t i;
    TRD_NodeCache *ncache;
    uint16_t oldest_age = 0, newest_age;
    int oldest_idx = -1;

    for (i = 0; i < table->num_entries; i++) {
        ncache = &table->ncache[i];
        if (ncache->origin == TRD_INVALID_ORIGIN)
            continue;   
        newest_age = nodecache_findNewestAge(ncache);
        if (newest_age > oldest_age) {
            oldest_age = newest_age;
            oldest_idx = i;
        }
    }
    return oldest_idx;
}

uint8_t trd_table_removeOldest(TRD_Table *table) {
    // looks at newest seqno of each node
    // if the newset seqno is the oldest, remove that node entry
    int oldest_idx;
    if (table->num_entries < TRD_NODE_ENTRIES) // why evict?
        return 1; // just return immediately
    oldest_idx = find_oldest_node_index(table);
    return trd_table_remove_node_index(table, oldest_idx);
}

uint16_t TRD_Table_findOldestOrigin(TRD_Table *table) {
    TRD_NodeCache *ncache;
    int oldest_idx;

    oldest_idx = find_oldest_node_index(table);
    if (oldest_idx < 0)
        return TRD_INVALID_ORIGIN;
    ncache = (TRD_NodeCache *)&table->ncache[oldest_idx];
    return ncache->origin;
}

int get_origin_index(TRD_Table *table, uint16_t origin) {
    uint8_t i;
    TRD_NodeCache *ncache;
    for (i = 0; i < table->num_entries; i++) {
        ncache = (TRD_NodeCache *)&table->ncache[i];
        if (ncache->origin == origin)
            return i;
    }
    return -1;
}

void trd_table_incrementAge(TRD_Table *table) {
    uint8_t i;
    TRD_NodeCache *ncache;
    uint16_t age;
    for (i = 0; i < table->num_entries; i++) {
        ncache = (TRD_NodeCache *)&table->ncache[i];
        nodecache_incrementAge(ncache);
        age = nodecache_findNewestAge(ncache);
        if (age > TRD_AGE_DELETE_OLD) {
            trd_table_remove_node_index(table, i);
            i--;    // since removed one, need to i--
        }
    }
}

uint8_t trd_table_removeNode(TRD_Table *table, uint16_t origin) {
    int idx = get_origin_index(table, origin);
    return trd_table_remove_node_index(table, idx);
}

uint8_t trd_table_insert(TRD_Table *table, uint16_t origin, uint16_t seqno, uint16_t memloc, uint16_t age) {
    TRD_NodeCache *ncache;
    int idx = get_origin_index(table, origin);

    if (idx < 0) {
        /// ADD origin
        if (table->num_entries < TRD_NODE_ENTRIES) {
            ncache = (TRD_NodeCache *)&table->ncache[table->num_entries];
            nodecache_init(ncache);
            ncache->origin = origin;
            table->num_entries++;
        } else {
            // All NodeCache are full which means that we cannot just add a new origin
            // WE CAN TRY TO EVICT AN ORIGIN... but...
            // We rather let the table entries to silently age away....
            return 0;
        }
    } else {
        ncache = (TRD_NodeCache *)&table->ncache[idx];
    }
    return nodecache_insert(ncache, seqno, memloc, age);
    // But... what if fail? we already added the node...
}
    
uint8_t trd_table_getMemloc(TRD_Table *table, uint16_t origin, uint16_t seqno, uint16_t *memloc) {
    int idx = get_origin_index(table, origin);
    if (idx < 0)
        return 0;
    return nodecache_getMemloc(&table->ncache[idx], seqno, memloc);
}

uint8_t trd_table_getAge(TRD_Table *table, uint16_t origin, uint16_t seqno, uint16_t *age) {
    int idx = get_origin_index(table, origin);
    if (idx < 0)
        return 0;
    return nodecache_getAge(&table->ncache[idx], seqno, age);
}

uint8_t trd_table_exist(TRD_Table *table, uint16_t origin, uint16_t seqno) {
    int idx = get_origin_index(table, origin);
    if (idx < 0)
        return 0;
    return nodecache_exist(&table->ncache[idx], seqno);
}

uint16_t trd_table_getOldestSeqno(TRD_Table *table, uint16_t origin) {
    int idx = get_origin_index(table, origin);
    if (idx < 0)
        return TRD_SEQNO_UNKNOWN;
    return nodecache_getOldestSeqno(&table->ncache[idx]);
}

uint16_t trd_table_getLastSeqno(TRD_Table *table, uint16_t origin, uint16_t *age) {
    int idx = get_origin_index(table, origin);
    if (idx < 0)
        return TRD_SEQNO_UNKNOWN;
    return nodecache_getLastSeqno(&table->ncache[idx], age);
}

uint8_t trd_table_summarize(TRD_Table *table, TRD_SummaryMsg *sMsg, uint8_t *len, uint8_t ignore_old) {
    // Let 'datalen' be the whole SummaryMsg which goes into TOS_Msg->length
    uint8_t i, num_meta = 0;
    TRD_NodeCache *ncache;
    uint16_t seqno;
    uint16_t age;

    for (i = 0; i < table->num_entries; i++) {
        // assume NO origin eviction!!
        ncache = (TRD_NodeCache *)&table->ncache[i];
        seqno = nodecache_getLastSeqno(ncache, &age);
        if (seqno != TRD_SEQNO_UNKNOWN) {
            if ((!ignore_old) || (age < TRD_AGE_NO_SUMMARY)) {
                TRD_Metadata *meta = &sMsg->metadata[num_meta];
            #ifdef BUILDING_PC_SIDE
                meta->origin = hxs(ncache->origin); // htons
                meta->seqno = hxs(seqno);           // htons
                meta->age = hxs(age);               // htons
            #else // nesc compiler takes care of htons on the motes
                meta->origin = ncache->origin;
                meta->seqno = seqno;
                meta->age = age;
            #endif
                num_meta++;
                if (num_meta == TRD_SUMMARY_ENTRIES)
                    break;
            }
        }
    }
    sMsg->num_entries = num_meta;

    *len = offsetof(TRD_SummaryMsg, metadata) + (num_meta * sizeof(TRD_Metadata));
    if (num_meta == 0)
        return 0;
    return 1;
}

trd_class_t trd_table_classify(TRD_Table *table, uint16_t origin, uint16_t seqno, uint16_t age) {
    int idx = get_origin_index(table, origin);
    if (idx < 0)
        return TRD_CLASS_NULL;  // origin not in table!!!
    return nodecache_classifySeqno(&table->ncache[idx], seqno, age);
}

void trd_table_printCacheEntry(TRD_Table *table) {
    uint8_t i;
#if defined(PLATFORM_PC) || defined(BUILDING_PC_SIDE)
    if (table->num_entries > 0) {
    #ifdef PLATFORM_PC
        dbg(DBG_USR1, " * Table (num_node_entries %d)\n", table->num_entries);
    #else
        printf(" * Table (num_node_entries %d)\n", table->num_entries);
    #endif
    }
    for (i = 0; i < table->num_entries; i++)
        nodecache_printCacheEntry(&table->ncache[i]);
#endif
}

uint8_t trd_table_ignoreSummary(TRD_Table *table, TRD_SummaryMsg *smsg) {
    uint8_t i, j;
    TRD_NodeCache *ncache;
    TRD_Metadata *meta;
    uint16_t age;
    for (i = 0; i < table->num_entries; i++) {
        ncache = (TRD_NodeCache *)&table->ncache[i];
        for (j = 0; j < smsg->num_entries; j++) {
            meta = (TRD_Metadata *)&smsg->metadata[i];
        #ifdef BUILDING_PC_SIDE
            if (ncache->origin == nxs(meta->origin)) // match... don't care about this one
        #else
            if (ncache->origin == meta->origin) // match... don't care about this one
        #endif
                break;
        }
        if (j == smsg->num_entries) { // couln't find in summary,
            // ncache->origin is something that I have but not in summary.
            age = nodecache_findNewestAge(ncache);
            if (age < TRD_AGE_IGNORE_OLD) // young... should not ignore
                return 0;   // FALSE, cannot ignore
        }
    }
    return 1; // all mis-matches are old ones... we can ignore
}

