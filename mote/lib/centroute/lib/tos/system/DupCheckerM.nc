/* ex: set tabstop=4 expandtab shiftwidth=4 softtabstop=4: */

module DupCheckerM
{
    provides {
        interface StdControl;
        interface DupCheckerI;
    }

}


implementation {
#include "DupChecker_defs.h"
//#include "EmStar_Strings.h"

#ifndef MAX_DUPCHECK_ENTRIES
#define MAX_DUPCHECK_ENTRIES        20
#endif

#define ADVANCE(x) x = (((x+1) >= MAX_DUPCHECK_ENTRIES) ? 0 : x+1)


typedef struct _dc_entry {
    uint16_t node_id;
    uint16_t seq;
} dc_entry_t;


typedef struct _dc_stats {
    uint32_t dups;
    uint32_t old;
} dc_stats_t;


dc_stats_t dc_stats={};
dc_entry_t dc_table[MAX_DUPCHECK_ENTRIES];
int8_t next_evicted=-MAX_DUPCHECK_ENTRIES;


int8_t find_entry(uint16_t src);
int8_t find_first_empty_slot();
int8_t move_to_front(int8_t idx);




int8_t find_entry(uint16_t node_id)
{
    int8_t i=0;
    for (i=0; i<MAX_DUPCHECK_ENTRIES; i++) {
        if (dc_table[i].node_id == node_id) {
            return i;
        }
    }

    return -1;
}


int8_t find_first_empty_slot()
{
    int8_t i=0;
    for (i=0; i<MAX_DUPCHECK_ENTRIES; i++) {
        if (dc_table[i].node_id == 0) {
            return i;
        }
    }
    return -1;
}


int8_t insert_entry(int8_t idx, uint16_t node_id, uint16_t seq)
{
    dc_table[idx].node_id = node_id;
    dc_table[idx].seq = seq;
    return idx;
}


int8_t check_seqs(uint16_t new_seq, uint16_t old_seq)
{
    int16_t diff = (int16_t)((int16_t)new_seq-(int16_t)old_seq);
    if (diff > 0) {
        return IS_NEW;
    } else if (diff < 0) {
        return IS_OLD;
    } else {
        return IS_DUPLICATE;
    }
}


command result_t StdControl.init()
{
    return SUCCESS;
}


command result_t StdControl.start()
{
    //call Stats.Init("/dev/herd/jb_stats");

    return SUCCESS;
}


command result_t StdControl.stop()
{
    return SUCCESS;
}


int8_t handle_dup(int8_t idx)
{
    if (idx<0) {
        return idx;
    }

    return (move_to_front(idx));
}


int8_t update_entry(int8_t idx, uint16_t seq)
{
    if (idx<0) {
        return idx;
    }

    dc_table[idx].seq = seq;
    return (move_to_front(idx));
}


int8_t move_to_front(int8_t idx)
{
    int8_t oldest_entry=0;
    dc_entry_t tmp={};

    if (next_evicted < 0) {
        oldest_entry = 0;
    } else if (next_evicted == 0) {
        oldest_entry = MAX_DUPCHECK_ENTRIES;
    } else {
        oldest_entry = next_evicted - 1;
    }
    if (idx==oldest_entry) {
        // ignore
        return oldest_entry;
    }

    memcpy(&tmp, &dc_table[oldest_entry], sizeof(dc_entry_t));
    // copy dup to oldest entry
    memcpy(&dc_table[oldest_entry], &dc_table[idx], sizeof(dc_entry_t));
    // copy tmp to dup's index
    memcpy(&dc_table[idx], &tmp, sizeof(dc_entry_t));

    return oldest_entry;
}



command int8_t DupCheckerI.check_pkt(uint16_t src, uint16_t seq)
{
    int8_t i=0;
    int8_t result=0;
    i=find_entry(src);

    if (seq==0) {
        dbg(DBG_USR1, "WARNING: node %u sent INVALID seq 0\n",
                src);
    }

    if (i<0) {
        int8_t j=0;
        // node not in table
        // check if table is full
        j=find_first_empty_slot();
        if (j<0) {
            // table full. Evict entry
            insert_entry(next_evicted, src, seq);
            ADVANCE(next_evicted);
        } else {
            dbg(DBG_USR2, "Inserting entry (%u, %u) at slot %u\n",
                    src, seq, j);
            insert_entry(j, src, seq);
            if (next_evicted < 0) {
                next_evicted++;
            }
        }
        result = IS_NEW;
        goto done;
    }

    // node found!
    // check seqs for duplicate/old entry
    result = check_seqs(seq, dc_table[i].seq);

    switch (result) {

        case IS_NEW:
            update_entry(i, seq);
            // update the value
            
            break;

        case IS_OLD:        // don't update, just move to front
            dbg(DBG_USR1, "Got OLD pkt from node %u "
                    "(rcvd seq %u, stored seq %u)\n",
                    src, seq, dc_table[i].seq);
            move_to_front(i);
            dc_stats.old++;
            break;

        case IS_DUPLICATE:
            dbg(DBG_USR1, "Got DUP pkt from node %u "
                    "(rcvd seq %u, stored seq %u)\n",
                    src, seq, dc_table[i].seq);
            dc_stats.dups++;
            handle_dup(i);
            break;
    }


done:

    return result;

}





}
