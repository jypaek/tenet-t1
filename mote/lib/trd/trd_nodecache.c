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
 * Functions for accessing TRD_NodeCache.
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
 * A TRD_NodeCache entry contains information about the disseminated
 * packets from an origin.
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 8/26/2006
 **/

#ifndef _TRD_NODECACHE_C_
#define _TRD_NODECACHE_C_

#include <stdio.h>
#include "trd_nodecache.h"

// This runs in O(1)
uint8_t remove_index(TRD_NodeCache *ncache, int local_idx) {
    TRD_CacheEntry *last, *dead;
    if (ncache->num_entries <= 0)
        return 0;
    if (local_idx >= ncache->num_entries)
        return 0;
    dead = (TRD_CacheEntry *)&ncache->cache[local_idx];
    last = (TRD_CacheEntry *)&ncache->cache[ncache->num_entries - 1]; // last local index

    dead->memloc = last->memloc;
    dead->seqno = last->seqno;
    dead->age = last->age;

    last->memloc = TRD_NULL_MEMLOC;
    last->seqno = 0;
    last->age = -1;
    ncache->num_entries--;  // reduce one
    return 1;
}

void nodecache_init(TRD_NodeCache *ncache) {
    int i;
    for (i = 0; i < TRD_CACHE_ENTRIES_PER_NODE; i++) {
        ncache->cache[i].memloc = TRD_NULL_MEMLOC;
        ncache->cache[i].seqno = 0;
        ncache->cache[i].age = -1;
    }
    ncache->num_entries = 0;
    ncache->origin = TRD_INVALID_ORIGIN;// assuming no node with ID=0
}

// This runs in O(n)
int find_index(TRD_NodeCache *ncache, uint16_t seqno) {
    int i;
    for (i = 0; i < ncache->num_entries; i++) {
        if (((TRD_CacheEntry *)&ncache->cache[i])->seqno == seqno)
            return i;
    }
    return -1;
}

int find_oldest_seqno_index(TRD_NodeCache *ncache) {
    TRD_CacheEntry *entry;
    uint8_t i;
    uint16_t oldest_age = 0;
    int oldest_idx = TRD_INVALID_INDEX;
    uint16_t oldest_seqno = TRD_SEQNO_UNKNOWN;

    for (i = 0; i < ncache->num_entries; i++) {
        entry = (TRD_CacheEntry *)&ncache->cache[i];
        if (entry->age > oldest_age) {
            oldest_idx = i;
            oldest_age = entry->age;
        } else if (entry->age == oldest_age) { // smaller seqno is older
            if (trd_seqno_cmp(entry->seqno, oldest_seqno) < 0) {
                oldest_idx = i;
                oldest_age = entry->age;
                oldest_seqno = entry->seqno;
            }
        }
    }
    return oldest_idx;
}

uint16_t nodecache_getOldestSeqno(TRD_NodeCache *ncache) {
    TRD_CacheEntry *entry;
    int oldest_idx = find_oldest_seqno_index(ncache);
    if (oldest_idx < 0)
        return TRD_SEQNO_UNKNOWN;
    entry = (TRD_CacheEntry *)&ncache->cache[oldest_idx];
    return entry->seqno;
}

uint8_t nodecache_insert(TRD_NodeCache *ncache, uint16_t seqno, uint16_t memloc, int16_t age) {
    TRD_CacheEntry *entry;
    int idx = find_index(ncache, seqno);

    if (idx >= 0)   // duplicate seqno
        return 0;

    if (ncache->num_entries == TRD_CACHE_ENTRIES_PER_NODE)
        idx = find_oldest_seqno_index(ncache); // will replace oldest
    else
        idx = ncache->num_entries++;

    entry = (TRD_CacheEntry *)&ncache->cache[idx];
    entry->seqno = seqno;
    entry->memloc = memloc;
    entry->age = age;
    return 1;
}

uint8_t nodecache_exist(TRD_NodeCache *ncache, uint16_t seqno) {
    if (find_index(ncache, seqno) < 0)
        return 0;
    return 1;
}

uint8_t nodecache_getMemloc(TRD_NodeCache *ncache, uint16_t seqno, uint16_t *memloc) {
    TRD_CacheEntry *entry;
    int idx = find_index(ncache, seqno);
    if (idx < 0)
        return 0;
    entry = (TRD_CacheEntry *)&ncache->cache[idx];
    if (entry->memloc == TRD_NULL_MEMLOC)
        return 0;
    *memloc = entry->memloc;
    return 1;
}

uint8_t nodecache_getAge(TRD_NodeCache *ncache, uint16_t seqno, uint16_t *age) {
    TRD_CacheEntry *entry;
    int idx = find_index(ncache, seqno);
    if (idx < 0)
        return 0;
    entry = (TRD_CacheEntry *)&ncache->cache[idx];
    *age = entry->age;
    return 1;
}

/* used by 'summarize cache',  run in O(n) */
uint16_t nodecache_getLastSeqno(TRD_NodeCache *ncache, uint16_t *age) {
    TRD_CacheEntry *entry;
    int i;
    uint16_t last_seqno = TRD_SEQNO_UNKNOWN;
    uint16_t last_age = TRD_AGE_MAX;

    for (i = 0; i < ncache->num_entries; i++) {
        entry = (TRD_CacheEntry *)&ncache->cache[i];
        if (entry->age < last_age) {    // trust age over seqno!!
            last_seqno = entry->seqno;
            last_age = entry->age;
        } else if (entry->age == last_age) {
            if (trd_seqno_cmp(entry->seqno, last_seqno) > 0) {
                last_seqno = entry->seqno;
                last_age = entry->age;
            }
        }
    }
    *age = last_age;
    return last_seqno;
}

void nodecache_incrementAge(TRD_NodeCache *ncache) {
    int i;
    for (i = 0; i < ncache->num_entries; i++) {
        if ((ncache->cache[i].age > 0) && 
            (ncache->cache[i].age < TRD_AGE_MAX)) {
            ncache->cache[i].age++;;
        }
    }
}

// O(n)
trd_class_t nodecache_classifySeqno(TRD_NodeCache *ncache, uint16_t seqno, uint16_t age) {
    TRD_CacheEntry *entry;
    int i;
    int exist_idx = TRD_INVALID_INDEX;
    int oldest_idx = TRD_INVALID_INDEX;
    int newest_idx = TRD_INVALID_INDEX;
    uint16_t oldest_seqno = TRD_SEQNO_UNKNOWN;
    uint16_t newest_seqno = TRD_SEQNO_UNKNOWN;

    if (seqno == TRD_SEQNO_UNKNOWN)
        return TRD_CLASS_UNKNOWN;
    else if (seqno == TRD_SEQNO_OLDEST)
        return TRD_CLASS_TOO_OLD;   // Is this right?????????????
    else if (ncache->num_entries == 0)  // origin not in table
        return TRD_CLASS_NULL;

    for (i = 0; i < ncache->num_entries; i++) {
        entry = (TRD_CacheEntry *)&ncache->cache[i];
        if (trd_seqno_cmp(entry->seqno, seqno) == 0)
            exist_idx = i;
        if ((newest_seqno == TRD_SEQNO_UNKNOWN) ||
            (trd_seqno_cmp(entry->seqno, newest_seqno) > 0)) {  // newer
            newest_idx = i;
            newest_seqno = entry->seqno;
        }
        if ((oldest_seqno == TRD_SEQNO_UNKNOWN) ||
            (trd_seqno_cmp(entry->seqno, oldest_seqno) < 0)) {  // older
            oldest_idx = i;
            oldest_seqno = entry->seqno;
        }
    }

    if (newest_seqno != TRD_SEQNO_UNKNOWN) {
        if (seqno == newest_seqno) {
            uint8_t aging = 0;
            while ((age - 1) > ((TRD_CacheEntry *)&ncache->cache[newest_idx])->age + 1) { 
                // too large inconsistency in packet age
                nodecache_incrementAge(ncache); // try to match them
                aging++;
            }
            if (aging > 1)
                return TRD_CLASS_IN_OLD;
            return TRD_CLASS_IN_LAST;
        }
        else if (seqno == trd_seqno_next(newest_seqno))
            return TRD_CLASS_NEXT_NEW;
        else if (trd_seqno_cmp(seqno, trd_seqno_next(newest_seqno)) > 0) { // newer than next
            uint16_t near_seqno = TRD_CACHE_ENTRIES_PER_NODE - 1;
            near_seqno = trd_seqno_add(newest_seqno, near_seqno);
            if (trd_seqno_cmp(seqno, near_seqno) > 0) // too new to regard near_seqno
                return TRD_CLASS_TOO_NEW;
            else
                return TRD_CLASS_NEWER; // slightly newer, recover the missing
        }
        // else go down....
    }
    if (oldest_seqno != TRD_SEQNO_UNKNOWN) {
        if (trd_seqno_cmp(seqno, oldest_seqno) < 0)
            return TRD_CLASS_TOO_OLD;
    }
    if (exist_idx != TRD_INVALID_INDEX)
        // must be.... (oldest_seqno <= seqno <= newest_seqno)
        return TRD_CLASS_IN_OLD;

    return TRD_CLASS_UNKNOWN;
}

void nodecache_printCacheEntry(TRD_NodeCache *ncache) {
#if defined(PLATFORM_PC)
    TRD_CacheEntry *entry;
    int i;
    if (ncache->num_entries > 0)
        dbg(DBG_USR1, " *  NodeCache (origin %d, num_entries %d)\n", 
                ncache->origin, ncache->num_entries);
    for (i = 0; i < ncache->num_entries; i++) {
        entry = (TRD_CacheEntry *)&ncache->cache[i];
        dbg(DBG_USR1, " *   # seqno %d, memloc %d, age %d\n", 
                    entry->seqno, entry->memloc, entry->age);
    }
#elif defined(BUILDING_PC_SIDE)
    TRD_CacheEntry *entry;
    int i;
    if (ncache->num_entries > 0)
        printf(" *  NodeCache (origin %d, num_entries %d)\n", 
                ncache->origin, ncache->num_entries);
    for (i = 0; i < ncache->num_entries; i++) {
        entry = (TRD_CacheEntry *)&ncache->cache[i];
        printf(" *   # seqno %d, memloc %d, age %d\n", 
                    entry->seqno, entry->memloc, entry->age);
    }
#endif
}

uint16_t nodecache_findNewestAge(TRD_NodeCache *ncache) {
    TRD_CacheEntry *entry;
    uint8_t i;
    uint16_t newest_age = TRD_AGE_MAX;
    int newest_idx = TRD_INVALID_INDEX;
    uint16_t newest_seqno = TRD_SEQNO_UNKNOWN;

    for (i = 0; i < ncache->num_entries; i++) {
        entry = (TRD_CacheEntry *)&ncache->cache[i];
        if (entry->age < newest_age) {
            newest_idx = i;
            newest_age = entry->age;
            newest_seqno = entry->seqno;
        } else if (entry->age == newest_age) { // smaller seqno is older
            if (trd_seqno_cmp(entry->seqno, newest_seqno) > 0) {
                newest_idx = i;
                newest_age = entry->age;
                newest_seqno = entry->seqno;
            }
        }
    }
    if (newest_idx == TRD_INVALID_INDEX)
        return -1;
    entry = (TRD_CacheEntry *)&ncache->cache[newest_idx];
    return entry->age;
}

#endif

