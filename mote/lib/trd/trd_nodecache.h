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
 * Header file for TRD_NodeCache.
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


#ifndef _TRD_NODECACHE_H_
#define _TRD_NODECACHE_H_

#include "trd.h"
#include "trd_seqno.h"

typedef struct TRD_CacheEntry {
    uint16_t memloc;
    uint16_t seqno;
    uint16_t age;
} TRD_CacheEntry;

typedef struct TRD_NodeCache {
    uint16_t origin;
    int8_t num_entries;
    // it might be possible to move CacheEntry.age to here, per node bases
    TRD_CacheEntry cache[TRD_CACHE_ENTRIES_PER_NODE];
} TRD_NodeCache;

enum {
    TRD_AGE_UNITTIME        = 10240, // (10sec)
    TRD_AGE_MAX             = 0xfffe,
    
    TRD_AGE_IGNORE_OLD      = 90,   // * TRD_AGE_UNIT_TIME = 900sec = 15min
    TRD_AGE_NO_SUMMARY      = 120,  // * TRD_AGE_UNIT_TIME = 1200sec = 20min
    TRD_AGE_DELETE_OLD      = 150,  // * TRD_AGE_UNIT_TIME = 1500sec = 25min
    // Assumption is that TRD dissemination never takes longer than 5 min.
    
    TRD_NULL_MEMLOC         = 0xffff,
    TRD_INVALID_ORIGIN      = 0xfffe  // one must represent EMPTY
};

void nodecache_init(TRD_NodeCache *ncache);
uint16_t nodecache_getOldestSeqno(TRD_NodeCache *ncache);
uint8_t nodecache_insert(TRD_NodeCache *ncache, uint16_t seqno, uint16_t memloc, int16_t age);
uint8_t nodecache_exist(TRD_NodeCache *ncache, uint16_t seqno);
uint8_t nodecache_getMemloc(TRD_NodeCache *ncache, uint16_t seqno, uint16_t *memloc);
uint8_t nodecache_getAge(TRD_NodeCache *ncache, uint16_t seqno, uint16_t *age);
uint16_t nodecache_getLastSeqno(TRD_NodeCache *ncache, uint16_t *age);
trd_class_t nodecache_classifySeqno(TRD_NodeCache *ncache, uint16_t seqno, uint16_t age);
void nodecache_incrementAge(TRD_NodeCache *ncache);
void nodecache_printCacheEntry(TRD_NodeCache *ncache);
uint16_t nodecache_findNewestAge(TRD_NodeCache *ncache);

#endif

