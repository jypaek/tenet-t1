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
 * TRD packet logger that logs TRD packets in memory.
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 2/25/2006
 **/

//#define DEBUG_TRD_MEMORY

#include <stddef.h>
#include <string.h>
#include "trd_memory.h"

void trd_memory_init(TRD_Memory *mem) {
    int i;
    for (i = 0; i < TRD_MEM_NUM_PKTS; i++)
        mem->array[i].len = 0;
    mem->curr_mem_ptr = 0;
}                                                            

// Should we malloc & copy the packet???????????? think!!!
int trd_memory_write(TRD_Memory *mem, uint16_t *memloc, unsigned char* data, int len) {
    TRD_MemoryEntry *entry;

#ifdef DEBUG_TRD_MEMORY
    printf("MEM.write (ori %d, seq %d, len %d, memloc=%d)\n", origin, seqno, len, memloc);
#endif

    if ((mem->curr_mem_ptr < 0) || (mem->curr_mem_ptr >= TRD_MEM_NUM_PKTS)) {
        printf("\t[TRD_MEM] Fatal Error... pointer out of boud\n");
        return -1;
    }
    entry = &mem->array[mem->curr_mem_ptr];
    if ((entry == NULL) || (data == NULL)) {
        printf("\t[TRD_MEM] Fatal Error... segmentation fault\n");
        return -1;
    } else if ((len <= 0) || (len >= 128)) {
        printf("\t[TRD_MEM] Fatal Error... writing length <= 0 \n");
        return -1;
    }

    memcpy(entry->packet, data, len);
    //entry->packet = data;
    entry->len = len;

    *memloc = mem->curr_mem_ptr;
    mem->curr_mem_ptr++;
    if (mem->curr_mem_ptr >= TRD_MEM_NUM_PKTS)
        mem->curr_mem_ptr = 0;  // flash wrap-around
    
    return 1;
}

unsigned char* trd_memory_read(TRD_Memory *mem, uint16_t memloc, int *len) {
    TRD_MemoryEntry* entry;
    if (memloc >= TRD_MEM_NUM_PKTS) {
        printf("\t[TRD_MEM] Fatal Error... memloc overflow\n");
        return NULL;
    }
    entry = &mem->array[memloc];
    if (entry == NULL) {
        printf("\t[TRD_MEM] Fatal Error... segmentation fault\n");
        return NULL;
    } else if (entry->len <= 0) {
        printf("\t[TRD_MEM] Fatal Error... accessing empty packet\n");
        return NULL;
    }
    *len = entry->len;
    return entry->packet;
}

