includes RnpLink;
includes AM;
includes EmStar;

module RnpLinkM
{
    provides {
        interface StdControl;
        interface RnpLinkI;
        interface SendMsg as RnpSendMsg[uint8_t id];
        interface ReceiveMsg as RnpReceiveMsg[uint8_t id];
    }

    uses {
        interface SendMsg as CommSendMsg[uint8_t id];
        interface ReceiveMsg as CommReceiveMsg[uint8_t id];
        interface EmStatusServerI as RnpStatus;
        interface CommControl;
    }
}


implementation {
#include "EmStar_Strings.h"
#include "RnpDefs.h"

#define ADVANCE(x) x = (((x+1) >= BEACONERCLIENTS) ? 0 : x+1)


#ifndef SECOND
#define SECOND  1000
#endif


#define TIMER_STARTED           (1<<0)
#define BEACON_PAYLOAD_SET      (1<<1)
#define BUF_BUSY                (1<<2)


#define CLEAR               0
#define PENDING             1
#define PROCESSED           2


#define RNP_NULL_PTR        -1
#define RNP_TABLE_FULL      -2
#define RNP_ENTRY_ADDED     0
#define RNP_ENTRY_UPDATED   1


#define DEFAULT_ACTIVE_THRESHOLD    70



// The state array entries
#define RNP_MAX_PAYLOAD (TOSH_DATA_LENGTH - sizeof(rnp_hdr_t))

#define D_UP    0
#define D_IN    1
#define D_OUT   2
#define D_BOTH  3

typedef struct _rnp_state {
    rnp_entry_t table[MAX_RNP_NEIGHBORS];
    uint8_t seq;
    int8_t threshold;
} __attribute__ ((packed)) rnp_state_t;


rnp_state_t g_state;



int8_t check_down(uint16_t addr);
void check_status(rnp_entry_t *entry, int8_t ignore_down);
void add_encapsulation(TOS_Msg *msg, uint8_t length, rnp_hdr_t *hdr);
void remove_encapsulation(TOS_Msg *msg);
int8_t find_first_empty_table_slot(rnp_entry_t table[]);
int8_t find_last_occupied_table_slot(rnp_entry_t table[]);
int8_t rnp_calc(rnp_hdr_t *hdr, rnp_state_t *state);
int8_t find_id_in_table(uint16_t id, rnp_entry_t table[]);
int8_t neighbor_up(uint16_t node);
int8_t neighbor_down(uint16_t node, int8_t direction);



command result_t StdControl.init()
{
    return SUCCESS;
}


command result_t StdControl.start()
{
    rnp_state_t *state = &g_state;
    state->threshold = DEFAULT_ACTIVE_THRESHOLD;
#ifndef NON_PROMISC
    call CommControl.setPromiscuous(TRUE);
#else
    call CommControl.setPromiscuous(FALSE);
#endif
    //call RnpStatus.Init("/dev/link/mh/neighbors");
    call RnpStatus.Init(RNP_NEIGH_DEV_NAME);
    return SUCCESS;
}


command result_t StdControl.stop()
{
    return SUCCESS;
}



command uint8_t RnpLinkI.get_max_payload_length()
{
    return RNP_MAX_PAYLOAD;
}


void add_encapsulation(TOS_Msg *msg, uint8_t length, rnp_hdr_t *hdr)
{
    // shift the payload 
    memmove((char *)(&msg->data[sizeof(rnp_hdr_t)]), (char *)(msg->data),
            length);

    // XXX XXX XXX
    // we DONT adjust the length here because GC sets the length
    // we set the adjusted length in the function call
    // add to the length
    //msg->length += sizeof(rnp_hdr_t);
    // copy the rnp header in the pkt
    memcpy((char *)(msg->data), (char *)(hdr), sizeof(rnp_hdr_t));
}



void remove_encapsulation(TOS_Msg *msg)
{
    //memmove the data payload and adjust length
    msg->length -= sizeof(rnp_hdr_t);
    memmove((char *)(msg->data), (char *)(&msg->data[sizeof(rnp_hdr_t)]),
                msg->length);
}



command void RnpLinkI.outbound_quality_update(int8_t idx, int8_t quality)
{
    rnp_state_t *state = &g_state;
    rnp_entry_t *entry = &state->table[idx];

    entry->rnp_out = quality;

    check_status(entry, 0);
}


command int8_t RnpLinkI.is_neighbor(uint16_t id)
{
    int8_t i=0;
    rnp_state_t *state = &g_state;
    rnp_entry_t *entry = NULL;

    i = find_id_in_table(id, state->table);

    if (i<0) {
        return -1;
    }

    entry = &state->table[i];

    // we consider the node a neighbor if it's not in rampup and
    // isn't marked as DEAD
    if (entry->rampup==0 /*&& entry->status!=N_DEAD*/) {
        return i;
    } else {
        return -1;
    }
}


command int8_t RnpLinkI.get_neighbor_avg_quality(uint16_t id)
{
    int8_t i=0;
    rnp_state_t *state = &g_state;
    rnp_entry_t *entry=NULL;

    i = find_id_in_table(id, state->table);

    if (i<0) {
        return -1;
    }

    entry = &state->table[i];
    return ((entry->rnp_out + (int8_t)((float)100 / entry->rnp_in)) / 2);
}


command int8_t RnpLinkI.get_neighbor_inbound_quality(uint16_t id)
{
    int8_t i=0;
    rnp_state_t *state = &g_state;
    rnp_entry_t *entry=NULL;

    i = find_id_in_table(id, state->table);

    if (i<0) {
        return -1;
    }

    entry = &state->table[i];


    return (int8_t)((float)100 / entry->rnp_in);
}


command int8_t RnpLinkI.get_neighbor_outbound_quality(uint16_t id)
{
    int8_t i=0;
    rnp_state_t *state = &g_state;
    rnp_entry_t *entry=NULL;

    i = find_id_in_table(id, state->table);

    if (i<0) {
        return -1;
    }

    entry = &state->table[i];

    return (int8_t)entry->rnp_out;
}


command int8_t RnpLinkI.get_neighbor_status(uint16_t id)
{
    int8_t i=0;
    rnp_state_t *state = &g_state;
    rnp_entry_t *entry=NULL;

    i = find_id_in_table(id, state->table);

    if (i<0) {
        return i;
    }

    entry = &state->table[i];

    return entry->status;
}


command void RnpLinkI.set_active_threshold(int8_t threshold)
{
    rnp_state_t *state = &g_state;
    state->threshold = threshold;
}


command int8_t RnpLinkI.get_active_threshold()
{
    rnp_state_t *state = &g_state;
    return state->threshold;
}



command result_t RnpSendMsg.send[uint8_t id]
    (uint16_t address, uint8_t length, TOS_Msg *msg)
{
    rnp_hdr_t hdr={};
    rnp_state_t *state = &g_state;

    // set the header fields
    hdr.src = TOS_LOCAL_ADDRESS;
    hdr.seq = state->seq;
    
    // XXX XXX XXX
    // before adding encap or anything else, check down
    if (msg->addr != TOS_BCAST_ADDR) {
        int8_t n=0;
        n = check_down(msg->addr);
        dbg(DBG_USR2, "Check_down returned %d\n",n);
        if (n==D_OUT || n==D_BOTH) {
            // we shouldn't send this packet out!
            msg->ack=0;
            return FAIL;
        }
    }

    add_encapsulation(msg, length, &hdr);

    if (call CommSendMsg.send[id](address, 
                (length + sizeof(rnp_hdr_t)), msg) == SUCCESS) {
        // we succeeded in TXing, increment seqnum
        state->seq++;
        return SUCCESS;
    } else {
        // dont increment seqnum on failures
        return FAIL;
    }
}




event result_t CommSendMsg.sendDone[uint8_t id](TOS_Msg *msg, result_t success)
{
    int8_t n=0;
    // remove the encapsulated header
    remove_encapsulation(msg);
    // now signal
    // XXX XXX XXX
    // check down status of destination
    // if it's in DOWN_USR and direction is out or both, change sendDone's ack
    // field to 0
    if (msg->addr != TOS_BCAST_ADDR) {
        n = check_down(msg->addr);
        dbg(DBG_USR2, "Check_down returned %d for node %u\n",
                n, msg->addr);
        if (n==D_OUT || n==D_BOTH) {
            // reset ack field to 0
            dbg(DBG_USR1, "Node %u is set to N_DOWN_USR, setting ack field"
                    " to 0 (was %d)\n",
                    msg->addr, msg->ack);
            msg->ack = 0;
        }
    }
    signal RnpSendMsg.sendDone[id](msg, success);
    
    return success;
}



event TOS_Msg *CommReceiveMsg.receive[uint8_t id](TOS_Msg *msg)
{
    rnp_hdr_t *hdr = (rnp_hdr_t *)(msg->data);
    rnp_state_t *state = &g_state;

    // do the calculations
    rnp_calc(hdr, state);
    call RnpStatus.Notify();


    if ((call CommControl.getPromiscuous())==FALSE) {
        dbg(DBG_ERROR, "Promiscuous mode is NOT set!\n");
    }

    // since we're using AMPromiscuous, we only signal and remove encap
    // if the packet is indeed for us

    if ((msg->addr == TOS_BCAST_ADDR) || (msg->addr == TOS_LOCAL_ADDRESS)) {
        // check status, if USR_DOWN, drop pkt
        int8_t n=0;
        n = check_down(hdr->src);
        if (n==D_IN || n==D_BOTH) {
            dbg(DBG_USR1, "Node %u is in DOWN_USR state, ignoring pkt\n",
                    hdr->src);
            goto done;
        } 

        // restore the pkt
        remove_encapsulation(msg);
        // signal client
        signal RnpReceiveMsg.receive[id](msg);
    } else {
        dbg(DBG_AM, "Received pkt is not for us (dst = %u, our addr ="
            " %u)\n", msg->addr, TOS_LOCAL_ADDRESS);
    }

done:
    return msg;
}


int8_t check_down(uint16_t node)
{
    rnp_state_t *state = &g_state;
    rnp_entry_t *entry=NULL;
    int8_t i=0;

    i = find_id_in_table(node, state->table);
    if (i<0) {
        return i;
    } else {
        entry = &state->table[i];
        if (entry->status == N_DOWN_USR) {
            return entry->down_status;
        }
    }

    return 0;
}


event void RnpStatus.Printable(buf_t *buf)
{
    rnp_state_t *state = &g_state;
    int8_t i=0;

    bufprintf(buf, 
            "Node %3u Link Estimator Status\n"
            "------------------------------------------------\n"
            "Entry    ID  EWMA_IN    EWMA_OUT   Last   Status\n", 
            TOS_LOCAL_ADDRESS);

    for (i=0; i<MAX_RNP_NEIGHBORS; i++) {
        rnp_entry_t *entry = &state->table[i];
        if (entry->occupied==0) {
            break;
        }

        bufprintf(buf,
            "%5u   %3u   %6.2f   %9u   %4u   %6d\n",
            i,
            entry->id,
            ((float)100 / entry->rnp_in),
            entry->rnp_out,
            entry->prev_seq,
            entry->status);
    }
    bufprintf(buf, "\n");
}


event void RnpStatus.Binary(buf_t *buf)
{
    uint8_t i=0;
    rnp_state_t *state = &g_state;

    for (i=0; i<MAX_RNP_NEIGHBORS; i++) {
        rnp_entry_t *entry = &state->table[i];
        if (entry->occupied==0) {
            break;
        } else {
            neighbor_t n = {
                node_id: entry->id,
                if_id:   entry->id,
                conn_from: (int)((float)100 / entry->rnp_in),
                conn_to:   entry->rnp_out,
            };
            // TODO: fix the hardcoding
            n.state = ACTIVE;
            bufcpy(buf, &n, sizeof(n));
        }
    }

    // null term
    {
        neighbor_t n = {};
        bufcpy(buf, &n, sizeof(n));
    }
}


event void RnpStatus.Write(buf_t *buf)
{
    parser_state_t *ps = misc_parse_init(buf_get(buf),
            MISC_PARSE_COMMA_SCHEME);
    uint16_t node=0;

    while (misc_parse_next_kvp(ps) >= 0) {
        dbg(DBG_USR2, "Key: %s, value: %s\n", ps->key, ps->value);
        if (strcmp(ps->key, "node") == 0) {
            node = atoi(ps->value);
        } else if (strncasecmp(ps->key, "up", strlen("up")) == 0) {
            neighbor_up(node);
        } else if (strncasecmp(ps->key, "down", strlen("down")) == 0) {
            int8_t direction=D_BOTH;
            if (ps->value!=NULL) {
                if (strncasecmp(ps->value, "in", strlen("in")) == 0) {
                    direction = D_IN;
                } else if (strncasecmp(ps->value, "out", strlen("out")) == 0) {
                    direction = D_OUT;
                }
            }
            neighbor_down(node, direction);
        }
    }

    misc_parse_cleanup(ps);
}


int8_t neighbor_up(uint16_t node)
{
    rnp_state_t *state = &g_state;
    rnp_entry_t *entry=NULL;
    int8_t i=0;

    i = find_id_in_table(node, state->table);
    if (i<0) {
        return i;
    } else {
        entry = &state->table[i];
        if (entry->status == N_DOWN_USR) {
            // node was down by user, call check_status
            dbg(DBG_USR1, "Restoring node %u status from DOWN_USR\n",
                    node);
            check_status(entry, 1);
            entry->down_status = D_UP;
            return 1;
        } else {
            // if not in down_usr, ignore
            return 0;
        }
    }

    return -1;
}


int8_t neighbor_down(uint16_t node, int8_t direction)
{
    rnp_state_t *state = &g_state;
    rnp_entry_t *entry=NULL;
    int8_t i=0;

    i = find_id_in_table(node, state->table);
    if (i<0) {
        return i;
    } else {
        entry = &state->table[i];
        if (entry->status == N_DOWN_USR) {
            // node is already down, ignore
            entry->down_status = direction;
            return 0;
        } else {
            dbg(DBG_USR1, "Setting node %u status to DOWN_USR, direction %d\n",
                    node, direction);
            entry->status = N_DOWN_USR;
            entry->down_status = direction;
            // if not in down_usr, ignore
            return 1;
        }
    }

    return -1;

}


event int8_t RnpStatus.CompressedBinary(char *buf, uint8_t *type,
        uint8_t length)
{
    return -1;
}


int8_t find_last_occupied_table_slot(rnp_entry_t table[])
{
    return ((find_first_empty_table_slot(table)) - 1);
}


int8_t find_first_empty_table_slot(rnp_entry_t table[])
{
    int8_t i=0;
    for (i=0; i<MAX_RNP_NEIGHBORS; i++) {
        if (table[i].occupied == 0) {
            return i;
        }
    }

    // table full
    return -1;
}



int8_t find_id_in_table(uint16_t id, rnp_entry_t table[])
{
    int8_t i=0;
    for (i=0; i<MAX_RNP_NEIGHBORS; i++) {
        if (table[i].id == id) {
            return i;
        }
    }

    return -1;
}


int8_t add_entry(rnp_hdr_t *hdr, rnp_state_t *state)
{
    int8_t i=0;

    i = find_first_empty_table_slot(state->table);
    if (i>=0) {
        rnp_entry_t *entry = &state->table[i];
        // empty space found, add entry
        entry->id = hdr->src;
        entry->occupied=1;
        entry->rampup=1;
        entry->num_packets++;
        entry->rnp_in=DEFAULT_INIT_RNP;
        entry->rnp_out=0;
        entry->prev_seq=hdr->seq;
        entry->status = N_ASYMMETRIC_INBOUND;
    }

    return i;
}


command int8_t RnpLinkI.get_num_neighbors()
{
    int8_t i=0;
    int8_t count=0;
    rnp_state_t *state = &g_state;

    for (i=0; i<MAX_RNP_NEIGHBORS; i++) {
        if (state->table[i].occupied==0) {
            break;
        }
        if (state->table[i].status!=N_DEAD) {
            count++;
        }
    }

    return count;
}


command int8_t RnpLinkI.get_rampup_entries()
{
    int8_t i=0;
    int8_t count=0;
    rnp_state_t *state = &g_state;

    for (i=0; i<MAX_RNP_NEIGHBORS; i++) {
        if (state->table[i].occupied==0) {
            break;
        }
        if (state->table[i].rampup==1) {
            count++;
        }
    }

    return count;
}



int8_t rnp_calc(rnp_hdr_t *hdr, rnp_state_t *state)
{
    int8_t i=0;
    int8_t seq_diff=0;
    rnp_entry_t *entry=NULL;
    if (hdr==NULL || state==NULL) {
        dbg(DBG_ERROR, "Null state/hdr pointer\n");
        return RNP_NULL_PTR;
    }

    i = find_id_in_table(hdr->src, state->table);

    if (i<0) {
        // New entry
        if (add_entry(hdr, state)<0) {
            dbg(DBG_ERROR, "Cannot add node %u: Table FULL\n", hdr->src);
            return RNP_TABLE_FULL;
        } else {
            // this is a new entry so we need to return here
            return RNP_ENTRY_ADDED;
        }
    }

    // old entry, see if we are ramping up
    entry = &state->table[i];

    if (entry->status == N_DOWN_USR) {
        return RNP_ENTRY_UPDATED;
    }


    if (entry->rampup!=0) {
        // still ramping up, increment num_packets and return
        entry->num_packets++;
        if (entry->num_packets == RAMPUP_PACKETS) {
            // we are done with rampup
            entry->rampup=0;
        }
    }

    // check seqnums
    if (hdr->seq == entry->prev_seq) {
        // we treat this as a duplicate packet
        seq_diff = 0;
    } else {
        seq_diff = (int8_t)(hdr->seq) - (int8_t)(entry->prev_seq);
    }

    // now it's time to apply ewma
    // RNP(x) = (1-a)*RNP(x-1) + (a*diff)
    if (seq_diff != 0) {
        entry->rnp_in = 
            (1.0 - DEFAULT_ALPHA)*entry->rnp_in + (DEFAULT_ALPHA*seq_diff);
    
        entry->prev_seq = hdr->seq;
    }

    check_status(entry, 0);


    return RNP_ENTRY_UPDATED;
}


command int8_t RnpLinkI.get_neighbor_index(uint16_t id)
{
    uint8_t i=0;
    rnp_state_t *state = &g_state;
    rnp_entry_t *entry=NULL;
    
    for (i=0; i<MAX_RNP_NEIGHBORS; i++) {
        entry = &state->table[i];
        if (entry->occupied==0) {
            break;
        }

        if (entry->id == id) {
            // found
            return i;
        }
    }

    return -1;
}


command rnp_entry_t *RnpLinkI.get_neighbor_by_index(uint8_t idx)
{
    rnp_state_t *state = &g_state;
    rnp_entry_t *entry = NULL;

    if (idx>=MAX_RNP_NEIGHBORS) {
        return NULL;
    }

    entry = &state->table[idx];

    if (entry->occupied==0) {
        return NULL;
    } else {
        return entry;
    }
}


command uint8_t RnpLinkI.get_table_size()
{
    return MAX_RNP_NEIGHBORS;
}


command rnp_entry_t *RnpLinkI.get_table()
{
    rnp_state_t *state = &g_state;
    return state->table;
}


void check_status(rnp_entry_t *entry, int8_t ignore_down)
{
    // TODO: fix the 0,1,2 magic numbers!
    rnp_state_t *state = &g_state;

    if (entry->status==N_DOWN_USR && ignore_down==0) {
        // node link is down by the user, skip check
        return;
    }

    if ((int8_t)((float)100 / entry->rnp_in) >= state->threshold) {
        // if inbound >= threshold, check outbound
        if (entry->rnp_out >= state->threshold) {
            entry->status = N_ACTIVE;
        } else {
            entry->status = N_ASYMMETRIC_INBOUND;
        }
    } else {
        // inbound < threshold
        if (entry->rnp_out >= state->threshold) {
            entry->status = N_ASYMMETRIC_OUTBOUND;
        } else {
            entry->status = N_DEAD;
        }
    }
}



default event result_t RnpSendMsg.sendDone[uint8_t id](TOS_Msg *msg,
        result_t success)
{
    return SUCCESS;
}


default event TOS_Msg *RnpReceiveMsg.receive[uint8_t id](TOS_Msg *msg)
{
    return msg;
}



}
