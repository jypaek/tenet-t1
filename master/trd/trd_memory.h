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
 * Header file for TRD packet logger that logs TRD packets in memory.
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 2/25/2006
 **/


#ifndef _TRD_MEMORY_H_
#define _TRD_MEMORY_H_

#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>

#include "trd.h"
#include "trd_table.h"
#include "trd_seqno.h"

enum {
    TRD_MEM_NUM_PKTS = TRD_NODE_ENTRIES * TRD_CACHE_ENTRIES_PER_NODE,
};

typedef struct TRD_MemoryEntry {
    int len;        // length of the packet
    unsigned char packet[128];  // packet pointer
} TRD_MemoryEntry;

typedef struct TRD_Memory {
    int length;
    TRD_MemoryEntry array[TRD_MEM_NUM_PKTS];
    int curr_mem_ptr;
} TRD_Memory;

void trd_memory_init(TRD_Memory *mem);
int trd_memory_write(TRD_Memory *mem, uint16_t *memloc, unsigned char* data, int len);
unsigned char* trd_memory_read(TRD_Memory *mem, uint16_t memloc, int *len);

#endif

