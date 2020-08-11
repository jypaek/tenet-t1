/* ex: set tabstop=4 expandtab shiftwidth=4 softtabstop=4: */
includes CentTree;
includes AM;
#include "PktTypes.h"

module CentTreeM
{
    provides {
        interface StdControl;
        interface CentTreeCtrlI;
        interface CentTreeSinkI;
        interface CentTreeSendI[uint8_t id];
        interface CentTreeSendStatusI[uint8_t id];
        interface CentTreeRecvI[uint8_t id];
        interface RoutingTable;

    }

    uses {
        interface JoinerI;
        interface DupCheckerI;
        // XXX XXX XXX
        // there has to be a better way than manually adding N queues...
        // 20050817
        // going craaaazy with 15 pktbufs yay!
        interface PktQueueI as PktQ1;
        interface PktQueueI as PktQ2;
        interface PktQueueI as PktQ3;
        interface PktQueueI as PktQ4;
        interface PktQueueI as PktQ5;
        /*interface PktQueueI as PktQ6;
        interface PktQueueI as PktQ7;
        interface PktQueueI as PktQ8;
        interface PktQueueI as PktQ9;
        interface PktQueueI as PktQ10;
        interface PktQueueI as PktQ11;
        interface PktQueueI as PktQ12;
        interface PktQueueI as PktQ13;
        interface PktQueueI as PktQ14;
        interface PktQueueI as PktQ15;*/
        interface PktQueueCtrlI as QueueCtrl;
        interface SendMsg;
        interface ReceiveMsg;
#ifdef EMSTAR_NO_KERNEL
        interface EmTimerI as StartupTimer;
#else
        interface Timer as StartupTimer;
#endif
        interface StatsI;
#ifdef NODE_HEALTH
        interface NodeHealthI;
#endif

	interface Leds;
    }
}


implementation {
//#include "EmStar_Strings.h"
#include "CentTree_defs.h"
#include "PktQueue_defs.h"
#include "DupChecker_defs.h"

//#include "mDTN.h"
#include "PktTypes.h"
#include "CentTree_defs.h"
#include "protocols.h"
//#include "QueryTypes.h"

#ifdef NODE_HEALTH
#include "NodeHealth.h"
#endif 

#define DEFAULT_PERIOD              (10)

#define PROPAGATE       1
#define DONT_PROPAGATE  0

#define BUF1_BUSY       (1<<0)
#define BUF2_BUSY       (1<<1)
#define BUF3_BUSY       (1<<2)
#define BUF4_BUSY       (1<<3)
#define BUF5_BUSY       (1<<4)
#define BUF6_BUSY       (1<<5)
#define BUF7_BUSY       (1<<6)
#define BUF8_BUSY       (1<<7)
#define BUF9_BUSY       (1<<8)
#define BUF10_BUSY      (1<<9)
#define BUF11_BUSY      (1<<10)
#define BUF12_BUSY      (1<<11)
#define BUF13_BUSY      (1<<12)
#define BUF14_BUSY      (1<<13)
#define BUF15_BUSY      (1<<14)
//#define QUEUE_OCCUPIED  (1<<2)

// the max payload of the raw packet
#define MAX_RAW_PAYLOAD (TOSH_DATA_LENGTH)
// the max available payload after all headers have been accounted for
#define MAX_UPSTREAM_PAYLOAD (MAX_RAW_PAYLOAD - sizeof(tree_hdr_t) - sizeof(up_hdr_t))

// the maximum number of entries that we can have in the forwarded join
// packet
#define MAX_ENTRIES (MAX_UPSTREAM_PAYLOAD / sizeof(up_path_entry_t))

#ifdef NODE_HEALTH
// copied from JoinerM.nc - think this is right
#define MAX_BEACON_TIME (5 * 1000)
#endif

typedef struct _tree_stats {
    uint32_t beacons_sent;
    uint32_t join_fwds_sent;
    uint32_t up_pkts_sent;
    uint32_t up_pkts_fwd;
    uint32_t join_replies_rcvd;
    uint32_t down_pkts_rcvd;
    uint32_t down_ptks_fwd;
    uint32_t data_pkts_sent;
    uint32_t data_pkts_rcvd;
    uint32_t parent_beacon;
    uint32_t parent_retx_fail;
    uint32_t parent_not_associated;
    uint32_t associations;
    uint32_t dissociations;
    uint32_t bufs_busy;
    uint32_t dest_unreachable_sent;
    uint32_t dest_unreachable_rcvd;
} tree_stats_t;


typedef struct _tree_state {
    uint16_t sink;
    uint16_t parent;
    uint16_t beacon_seq;
    uint16_t tx_seq;
    uint8_t hops_away;
    uint8_t is_sink:1;
    uint8_t associated:1;
    uint8_t parent_valid:1;
    uint8_t status:5;
} __attribute__ ((packed)) tree_state_t;



tree_stats_t stats;


tree_state_t g_state;

//#define NUM_PKTBUFS 15
#define NUM_PKTBUFS 5

TOS_Msg pktbuf[NUM_PKTBUFS];

int16_t flags;

int8_t handle_tx_retx_fail(tree_hdr_t *tree_hdr, TOS_Msg *msg);
int8_t handle_up_tree_pkt(tree_hdr_t *tree_hdr, uint8_t length);
int8_t handle_down_tree_pkt(tree_hdr_t *tree_hdr, uint8_t length);
int8_t handle_join_reply(down_hdr_t *down_hdr, uint16_t parent);
int8_t handle_dissociate_pkt(down_hdr_t *down_hdr, uint16_t parent);
int8_t handle_not_associated(down_hdr_t *down_hdr, uint16_t parent);
int8_t handle_data_pkt(down_hdr_t *down_hdr, uint8_t client_type,
        uint16_t parent, uint8_t length);

int8_t create_join_fwd_pkt(join_beacon_t *beacon, int8_t in_q, int8_t out_q);
void set_tree_hdr(tree_hdr_t *hdr, uint8_t destination, 
        uint8_t type, uint8_t client_type);
int8_t set_upstream_entry(up_path_entry_t *entry, uint16_t downstream_id);
TOS_Msg *get_buf();
void release_buf(TOS_Msg *buf);
int8_t find_buf_id(TOS_Msg *buf);
int8_t add_to_up_path_entry_list(up_hdr_t *hdr, 
        uint16_t downstream_id, uint8_t up_payload_len);
int8_t propagate_downstream_pkt(down_hdr_t *hdr, uint8_t type, 
        uint8_t client_type, uint8_t length);
int8_t tx_buf(uint16_t dst, int8_t buf_id);
int16_t send_pkt(char *data, uint16_t dst, uint8_t type, 
        uint8_t client_type, uint8_t direction, uint8_t length);
int8_t propagate_upstream_pkt(up_hdr_t *hdr, uint8_t type,
        uint8_t client_type, uint8_t up_payload_len, uint16_t originator);
void dissociate(tree_state_t *state);
int8_t send_dest_unreachable_pkt(TOS_Msg *msg);
int8_t send_not_associated_pkt(tree_hdr_t *tree_hdr);
int8_t create_down_tree_entries_from_up_tree_hdr(up_hdr_t *up_hdr, 
        down_hdr_t *down_hdr);
int8_t handle_retx_signal(TOS_Msg *msg);
int8_t handle_up_tree_retx(tree_hdr_t *tree_hdr, uint8_t length);
int8_t handle_down_tree_retx(tree_hdr_t *tree_hdr, uint8_t length);
up_path_entry_t *find_own_entry_in_up_path_entry_list(up_hdr_t *up_hdr);
down_path_entry_t *find_own_entry_in_down_path_entry_list(down_hdr_t
        *down_hdr);
void increment_tx_seq();
int16_t tx_pkt_to_parent(TOS_Msg *msg);

// number of consecutive packet failures to our parent before we try and find
// a new connection
#define MAX_CONSECUTIVE_PACKET_FAILURES 3
uint16_t consecutive_packet_failures;

command result_t StdControl.init()
{
    return SUCCESS;
}


command result_t StdControl.start()
{
    tree_state_t *state = &g_state;
    state->tx_seq = 1;

    consecutive_packet_failures = 0;

    call PktQ1.Init(&pktbuf[0]);
    call PktQ2.Init(&pktbuf[1]);
    call PktQ3.Init(&pktbuf[2]);
    call PktQ4.Init(&pktbuf[3]);
    call PktQ5.Init(&pktbuf[4]);
    //call PktQ6.Init(&pktbuf[5]);
    //call PktQ7.Init(&pktbuf[6]);
    //call PktQ8.Init(&pktbuf[7]);
    //call PktQ9.Init(&pktbuf[8]);
    //call PktQ10.Init(&pktbuf[9]);
    //call PktQ11.Init(&pktbuf[10]);
    //call PktQ12.Init(&pktbuf[11]);
    //call PktQ13.Init(&pktbuf[12]);
    //call PktQ14.Init(&pktbuf[13]);
    //call PktQ15.Init(&pktbuf[14]);

    return SUCCESS;
}


command result_t StdControl.stop()
{
    return SUCCESS;
}


command int8_t CentTreeCtrlI.is_associated()
{
    tree_state_t *state = &g_state;
    return (uint8_t)(state->associated);
}


command uint16_t CentTreeCtrlI.get_parent_id()
{
    tree_state_t *state = &g_state;
    if (state->parent_valid==1) {
        return state->parent;
    } else {
        return TOS_BCAST_ADDR;
    }
}


command uint16_t CentTreeCtrlI.get_sink_id()
{
    tree_state_t *state = &g_state;
    if (state->associated==1) {
        return state->sink;
    } else {
        return TOS_BCAST_ADDR;
    }
}


command void CentTreeCtrlI.i_am_sink()
{
    tree_state_t *state = &g_state;
    state->sink = TOS_LOCAL_ADDRESS;
    state->parent = TOS_LOCAL_ADDRESS;
    state->is_sink = 1;
    state->associated = 1;
    // don't register the beacon 
    // To be 100% correct, we should disable it (in case for some
    // reason we switched from being a leaf to being a sink)
    call JoinerI.init(0,0,0);
}


command void CentTreeCtrlI.i_am_leaf()
{
    tree_state_t *state = &g_state;
    state->is_sink = 0;
    state->associated = 0;
    // start the pre-init timer
    if (call StartupTimer.start(TIMER_ONE_SHOT, (/*TOS_LOCAL_ADDRESS **/ 1000)) == FAIL)
    {
       dbg(DBG_ERROR, "Oh noes, couldn't start centtree timer!\n");
    }
}


command result_t CentTreeCtrlI.is_sink()
{
    tree_state_t *state = &g_state;

    if (state->is_sink==0) {
        return FAIL;
    } else {
        return SUCCESS;
    }
}


void reset_state()
{
    tree_state_t *state = &g_state;

    state->associated=0;
    state->parent_valid=0;
    state->hops_away=0;
    state->sink=0;
    state->parent=0;
}


event void JoinerI.beacon_from_parent_rcvd()
{
    tree_state_t *state = &g_state;

    if (state->associated == 0) {
        // ignore, if not associated
        return;
    }

    dbg(DBG_USR1, "Our parent (%u) is not associated! Dissociating\n",
            state->parent);
    dissociate(state);
}


event void JoinerI.join_request_rcvd(uint16_t node_id, uint16_t round,
        uint8_t beacons_rcvd, uint8_t max_beacons)
{
    tree_state_t *state = &g_state;
    join_beacon_t beacon={};
    uint16_t in_q=0;

    if ((state->associated == 0) || 
        ((state->associated == 1) && (state->parent == TOS_BCAST_ADDR))) {
            dbg(DBG_ERROR, "We not associated (%d), or we are associated to sink %u but our "
                    "parent is set to the BCAST_ADDR!\n", 
        state->associated, state->sink);
        // ignore if not associated
        return;
    }

    // if the request is from our parent, DISSOCIATE immediately
    // XXX XXX XXX
    // TODO: find out why the joiner signal fails! this case should
    // be handle by that!
/*
    if (node_id == state->parent) {
        dbg(DBG_USR1, "Our parent (%u) transmitted a JOIN_REQUEST!"
                " Dissociating\n", state->parent);
        dissociate(state);
        // return immediately
        return;
    }
*/

    beacon.mote_id = node_id;
    beacon.beacon_round = round;
    // calculate in_quality by dividing rcvd by max
    // NOTE: we use the in_quality as an out_quality as well, until
    // we have an outbound estimation
    in_q = (100 * beacons_rcvd) / max_beacons;


    if (state->is_sink == 1) {
        // we are the sink
        dbg(DBG_USR1, "Received JOIN_REQ from node %u (round=%u),"
                "passing up\n",
                node_id, round);
        signal CentTreeSinkI.join_beacon_rcvd(&beacon, 
                (uint8_t)in_q, (uint8_t)in_q);
    } else {

        // we are not the sink, but we are associated with one
        // we need to forward the packet UP
        int8_t n = create_join_fwd_pkt(&beacon, in_q, in_q);

#ifdef NODE_HEALTH
        dbg(DBG_ERROR, "Start: %d, %s\n", __LINE__, __FILE__);
        call NodeHealthI.ActionStart(TRANSMIT);
#endif

        dbg(DBG_USR1, "Received JOIN_REQ from node %u (round=%u),"
                "forwarding to parent %u\n",
                node_id,round, state->parent);
        // try to transmit
        tx_buf(state->parent, n);
    }
}

int8_t set_up_hdr(up_hdr_t *up_hdr, uint16_t orig_src, 
                  uint16_t final_dst, int8_t path_entries)
{
    if (up_hdr == NULL)
    {
        dbg(DBG_ERROR, "NULL up_hdr ptr\n");
        return -1;
    }

    // memset up_hdr area to 0
    memset(up_hdr, 0, sizeof(up_hdr_t));

    up_hdr->orig_src = orig_src;
    up_hdr->final_dst = final_dst;
    up_hdr->path_entries = path_entries;

    return 0;
}

int8_t SendToHardware(tree_hdr_t *tree_hdr, uint16_t dest,
                      uint16_t length, TOS_Msg *msg)
{
    tree_state_t *state = &g_state;
//    tree_hdr_t *my_tree_hdr = (tree_hdr_t *)(msg->data);
//    up_hdr_t *up_hdr = (up_hdr_t *)(my_tree_hdr->data);
//    data_hdr_t *data_hdr=(data_hdr_t *)(up_hdr->data);
//    DsePacket_t *p = (DsePacket_t *)(data_hdr->payload + sizeof(mDTN_pkt_t));
//    QueryResponse_t* qResp = (QueryResponse_t*) p->data;

    tree_hdr->tx_seq = state->tx_seq;
    dbg(DBG_USR3, "Tree hdr tx seq set to %u(%u)\n",
            tree_hdr->tx_seq, state->tx_seq);

//    dbg(DBG_USR3,  "Sending Query Response: ID = %d, bitmask = %d, Src %d, Seq %d\n", qResp->queryID, qResp->bitMask, p->hdr.m_uiSrcAddr, p->hdr.m_uiSeq);

    if (call SendMsg.send(dest, length, msg)
            != SUCCESS) {
        handle_tx_retx_fail(tree_hdr, msg);
        dbg(DBG_ERROR, "Cannot TX pktbuf %p\n", msg);
        if ((tree_hdr->type == JOIN_FORWARD)
            || (tree_hdr->type == JOIN_REPLY)
            || (tree_hdr->type == NOT_ASSOCIATED)
            || (tree_hdr->type == DST_UNREACHABLE)) {

            call StatsI.incr_tx_errors();
        }
        release_buf(msg);
        return 0;
    } 

    // tx succeeded, increment tx seq
    increment_tx_seq();

    if ((tree_hdr->type == JOIN_FORWARD)
        || (tree_hdr->type == JOIN_REPLY)
        || (tree_hdr->type == NOT_ASSOCIATED)
        || (tree_hdr->type == DST_UNREACHABLE)) {

        call StatsI.incr_tx_pkts();
        call StatsI.incr_tx_bytes(length);
        
    }
    return 0;

}

int8_t tx_buf(uint16_t dst, int8_t buf_id)
{
    tree_hdr_t *tree_hdr = NULL;

    if ((buf_id < 0) || (buf_id > NUM_PKTBUFS)) {
        dbg(DBG_ERROR, "Cannot TX: illegal buf id %d\n", buf_id);
        return EINVALIDENTRY;
    }

    if (pktbuf[buf_id].length==0) {
        dbg(DBG_ERROR, "Pktbuf%d: 0-length\n", buf_id+1);
        return ENOSPACE;
    }

    tree_hdr = (tree_hdr_t *)(pktbuf[buf_id].data);
    
    SendToHardware(tree_hdr, dst, pktbuf[buf_id].length, 
                   &pktbuf[buf_id]);

    return buf_id;
}


TOS_Msg *get_buf()
{
    TOS_Msg *buf=NULL;
    if ((flags & BUF1_BUSY)==0) {
        flags |= BUF1_BUSY;
        buf = &pktbuf[0];
        goto done;
    }

    if ((flags & BUF2_BUSY)==0) {
        flags |= BUF2_BUSY;
        buf = &pktbuf[1];
        goto done;
    } 

    if ((flags & BUF3_BUSY)==0) {
        flags |= BUF3_BUSY;
        buf = &pktbuf[2];
        goto done;
    }

    if ((flags & BUF4_BUSY)==0) {
        flags |= BUF4_BUSY;
        buf = &pktbuf[3];
        goto done;
    } 

    if ((flags & BUF5_BUSY)==0) {
        flags |= BUF5_BUSY;
        buf = &pktbuf[4];
        goto done;
    }

    /*if ((flags & BUF6_BUSY)==0) {
        flags |= BUF6_BUSY;
        buf = &pktbuf[5];
        goto done;
    }

    if ((flags & BUF7_BUSY)==0) {
        flags |= BUF7_BUSY;
        buf = &pktbuf[6];
        goto done;
    } 

    if ((flags & BUF8_BUSY)==0) {
        flags |= BUF8_BUSY;
        buf = &pktbuf[7];
        goto done;
    }

    if ((flags & BUF9_BUSY)==0) {
        flags |= BUF9_BUSY;
        buf = &pktbuf[8];
        goto done;
    } 

    if ((flags & BUF10_BUSY)==0) {
        flags |= BUF10_BUSY;
        buf = &pktbuf[9];
        goto done;
    }
    if ((flags & BUF11_BUSY)==0) {
        flags |= BUF11_BUSY;
        buf = &pktbuf[10];
        goto done;
    }

    if ((flags & BUF12_BUSY)==0) {
        flags |= BUF12_BUSY;
        buf = &pktbuf[11];
        goto done;
    } 

    if ((flags & BUF13_BUSY)==0) {
        flags |= BUF13_BUSY;
        buf = &pktbuf[12];
        goto done;
    }

    if ((flags & BUF14_BUSY)==0) {
        flags |= BUF14_BUSY;
        buf = &pktbuf[13];
        goto done;
    } 

    if ((flags & BUF15_BUSY)==0) {
        flags |= BUF15_BUSY;
        buf = &pktbuf[14];
        goto done;
    }*/
done:
    if (buf!=NULL) {
        memset(buf, 0, sizeof(TOS_Msg));
    }
    return buf;
}


command uint8_t CentTreeCtrlI.get_max_payload_length()
{
    uint8_t length=0;
    length = TOSH_DATA_LENGTH;
    // we always include tree_hdr_t, so that's what we subtract
    length -= sizeof(tree_hdr_t);
    return length;
}

command int16_t CentTreeSendI.send_raw_pkt_up[uint8_t id](char *data, 
        uint8_t type, uint8_t length)
{
    tree_state_t *state = &g_state;

    // see if we are associated, have a parent and are NOT a sink
    if (state->associated==0) {
        return ENOTASSOCIATED;
    }

    if (state->parent_valid==0) {
        return ENOPARENT;
    }

    if (state->is_sink==1) {
        return EISSINK;
    }

    return send_pkt(data, state->parent, type, id, UP_TREE, length);
}


command int16_t CentTreeSendI.send_prepared_pkt_up[uint8_t id]
    (TOS_Msg *msg)
{
#ifdef NODE_HEALTH
    dbg(DBG_ERROR, "Start: %d, %s\n", __LINE__, __FILE__);
    call NodeHealthI.ActionStart(TRANSMIT);
#endif

    return tx_pkt_to_parent(msg);
}


int16_t tx_pkt_to_parent(TOS_Msg *msg)
{
    tree_state_t *state= &g_state;
    tree_hdr_t *tree_hdr = (tree_hdr_t *)(msg->data);

    // see if we are associated, have a parent and are NOT a sink
    if (state->associated==0) {
        return ENOTASSOCIATED;
    }

    if (state->is_sink==1) {
        // we are the sink. We're sending a packet to ourselves. This
        // is possible in modules like link_test
        // XXX XXX XXX
        // XXX XXX XXX
        // XXX XXX XXX
        // NOTE: this can create problems, so care must be taken in general
        // I.e. apps, in general should NOT use this to send packets from the
        // shepherd-attached mote to the shepherd.

        up_hdr_t *up_hdr = (up_hdr_t *)(tree_hdr->data);
        uint8_t up_payload_len = msg->length - sizeof(tree_hdr_t);

        signal CentTreeSinkI.up_pkt_rcvd
            (up_hdr, tree_hdr->type, tree_hdr->client_type,
             up_payload_len + sizeof(up_path_entry_t));

        // unfortunately, signalling here won't work very well
        // for code that depends on split-phase ops
        // Even worse, we can;t post a task to do it because
        // there is no task context....boo!
        // as a result, I am commenting it out
        /*
        signal CentTreeSendI.send_pkt_up_done[tree_hdr->client_type]
                (tree_hdr->data, tree_hdr->type,
                 msg->length - sizeof(tree_hdr_t));
        */
        return msg->length;
    }

    if (state->parent_valid==0) {
        return ENOPARENT;
    }

    // set msg destination
    msg->addr = state->parent;

    if (SendToHardware(tree_hdr, msg->addr, msg->length, msg) < 0)
    {
        return ETXERROR;
    }
    
    return msg->length;
}


command int16_t CentTreeSendI.send_pkt_up[uint8_t id]
    (TOS_Msg *msg, char *data,  uint8_t length)
{
    tree_state_t *state = &g_state;
    up_hdr_t *up_hdr=NULL;
    tree_hdr_t *tree_hdr=NULL;
    uint8_t offset = sizeof(up_hdr_t) + sizeof(tree_hdr_t);

    if (length>=MAX_UPSTREAM_PAYLOAD) {
        return ELENGTH;
    }

#ifdef NODE_HEALTH
    dbg(DBG_ERROR, "Start: %d, %s\n", __LINE__, __FILE__);
    call NodeHealthI.ActionStart(TRANSMIT);
#endif

    // copy the data
    memcpy(&msg->data[offset], data, length);
    // cast tree_hdr
    tree_hdr = (tree_hdr_t *)(msg->data);
    // memset tree_hdr area to 0
    memset(tree_hdr, 0, sizeof(tree_hdr_t));
    // cast up_hdr
    up_hdr = (up_hdr_t *)(tree_hdr->data);
    
    // set tree_hdr fields
    set_tree_hdr(tree_hdr, UP_TREE, DATA, id);
    tree_hdr->tx_seq = state->tx_seq;

    // set up_hdr fields
    if (set_up_hdr(up_hdr, TOS_LOCAL_ADDRESS, TOS_BCAST_ADDR, 0) == -1)
    {
       return ENOSPACE;
    }
    
    // set msg->length
    msg->length = length + offset;

    // msg ready, try to send
    return tx_pkt_to_parent(msg);

}



command int16_t CentTreeSinkI.send_pkt_down
    (pd_hdr_t *pd_hdr, uint8_t type, uint8_t client_type, uint8_t length)
{
    down_hdr_t *down_hdr = (down_hdr_t *)(pd_hdr->data);
    down_path_entry_t *entry = (down_path_entry_t *)(down_hdr->data);

    return send_pkt(pd_hdr->data, entry->mote_id, type, client_type, 
            DOWN_TREE, length);
}




int16_t send_pkt(char *data, uint16_t dst, uint8_t type, 
        uint8_t client_type, uint8_t direction, uint8_t length)
{
    TOS_Msg *buf = get_buf();
    tree_hdr_t *tree_hdr = NULL;
    int8_t buf_id;

#ifdef NODE_HEALTH
    dbg(DBG_ERROR, "Start: %d, %s\n", __LINE__, __FILE__);
    call NodeHealthI.ActionStart(TRANSMIT);
#endif

    if (buf==NULL) {
        dbg(DBG_ERROR, "Unable to send packet, all bufs"
                " busy\n");
        call StatsI.incr_tx_drops();
        return ENOBUFFERS;
    }

    buf->addr = dst;
    tree_hdr = (tree_hdr_t *)(buf->data);
    set_tree_hdr(tree_hdr, direction, type, client_type);
    
    memcpy(tree_hdr->data, data, length);
    buf->length = length + sizeof(tree_hdr_t);

    buf_id = find_buf_id(buf);
    if (buf_id == -1)
    {
        dbg(DBG_ERROR, "Couldn't get buf id for %p\n", buf);
        release_buf(buf);
        return ENOBUFFERS;
    }  

    return tx_buf(dst, buf_id);
}



void set_tree_hdr(tree_hdr_t *hdr, uint8_t direction, 
        uint8_t type, uint8_t client_type)
{
    if (hdr==NULL) {
        dbg(DBG_ERROR, "NULL tree_hdr ptr\n");
        return;
    }

    hdr->src = TOS_LOCAL_ADDRESS;
    hdr->direction = direction;
    hdr->type = type;
    hdr->client_type = client_type;
}




int8_t set_upstream_entry(up_path_entry_t *entry, uint16_t downstream_id)
{
    if (entry!=NULL) {
        entry->mote_id = TOS_LOCAL_ADDRESS;
        entry->retx_count=0;

        // zero-out the quality values
        entry->inbound_quality = 0;
        entry->outbound_quality = 0;
        return 0;
    } else {
        dbg(DBG_ERROR, "set_upstream_entry: NULL entry ptr!\n");
        return -1;
    }

}


void release_buf(TOS_Msg *buf)
{
    // memset buf to 0!!!
    memset(buf, 0, sizeof(TOS_Msg));
    if (buf == &pktbuf[0]) {
        flags &= ~BUF1_BUSY;
    }

    if (buf == &pktbuf[1]) {
        flags &= ~BUF2_BUSY;
    }

    if (buf == &pktbuf[2]) {
        flags &= ~BUF3_BUSY;
    }

    if (buf == &pktbuf[3]) {
        flags &= ~BUF4_BUSY;
    }

    if (buf == &pktbuf[4]) {
        flags &= ~BUF5_BUSY;
    }

    if (buf == &pktbuf[5]) {
        flags &= ~BUF6_BUSY;
    }

    /*if (buf == &pktbuf[6]) {
        flags &= ~BUF7_BUSY;
    }

    if (buf == &pktbuf[7]) {
        flags &= ~BUF8_BUSY;
    }

    if (buf == &pktbuf[8]) {
        flags &= ~BUF9_BUSY;
    }

    if (buf == &pktbuf[9]) {
        flags &= ~BUF10_BUSY;
    }

    if (buf == &pktbuf[10]) {
        flags &= ~BUF11_BUSY;
    }

    if (buf == &pktbuf[11]) {
        flags &= ~BUF12_BUSY;
    }

    if (buf == &pktbuf[12]) {
        flags &= ~BUF13_BUSY;
    }

    if (buf == &pktbuf[13]) {
        flags &= ~BUF14_BUSY;
    }

    if (buf == &pktbuf[14]) {
        flags &= ~BUF15_BUSY;
    }*/

}


int8_t find_buf_id(TOS_Msg *buf)
{
    int8_t i=0;

    for (i=0; i<NUM_PKTBUFS; i++) {
        if (buf==&pktbuf[i]) {
            return i;
        }
    }
    dbg(DBG_ERROR, "Can't find buf id!! buf = %p, Possible buf pointers are: \n", buf);

    for (i=0; i<NUM_PKTBUFS; i++) {
         dbg(DBG_ERROR, "%p, ", &pktbuf[i]);   
    }

    dbg(DBG_ERROR, "\n");

    return -1;
}


int8_t propagate_upstream_pkt(up_hdr_t *orig_hdr, uint8_t type, 
        uint8_t client_type, uint8_t up_payload_len, uint16_t originator)
{
    tree_state_t *state = &g_state;
    TOS_Msg *msg = get_buf();
    tree_hdr_t *tree_hdr = NULL;
    up_hdr_t *new_hdr=NULL;
    uint8_t adjusted_up_payload_len = up_payload_len + 
        sizeof(up_path_entry_t);
    int8_t n=0;
    int8_t buf_id;

#ifdef NODE_HEALTH
    dbg(DBG_ERROR, "Start: %d, %s\n", __LINE__, __FILE__);
    call NodeHealthI.ActionStart(TRANSMIT);
#endif
    if (msg==NULL) {
        dbg(DBG_ERROR, "Unable to propagate upstream pkt, all bufs"
                " busy\n");
        call StatsI.incr_tx_drops();
        return ENOBUFFERS;
    }

    tree_hdr = (tree_hdr_t *)(msg->data);
    set_tree_hdr(tree_hdr, UP_TREE, type, client_type);
    new_hdr = (up_hdr_t *)(tree_hdr->data);

    msg->length = adjusted_up_payload_len + sizeof(tree_hdr_t);

    if (msg->length >= MAX_RAW_PAYLOAD) {
        dbg(DBG_ERROR, "Unable to propagate upstream pkt, max length"
                " exceeded (%u >= %u)\n", msg->length, MAX_RAW_PAYLOAD);
        release_buf(msg);
#ifdef NODE_HEALTH
    dbg(DBG_ERROR, "End: %d, %s\n", __LINE__, __FILE__);
    call NodeHealthI.ActionEnd(TRANSMIT);
#endif

        return ELENGTH;
    }
    // copy the orig_hdr AND its payload into the new_hdr
    memcpy(new_hdr, orig_hdr, up_payload_len);

    // Add ourselves to the entry list of the NEW hdr
    if ((n = add_to_up_path_entry_list(new_hdr, originator,
                up_payload_len)) < 0) {
        dbg(DBG_ERROR, "Couldn't add entry to entry list: %d\n",n);
        release_buf(msg);
        return EENTRYERR;
    } else {
        dbg(DBG_USR2, "Added node %u to entry list\n", originator);
    }

    buf_id = find_buf_id(msg);
    if (buf_id == -1)
    {
        dbg(DBG_ERROR, "Couldn't get buf id for %p\n", msg);
        call StatsI.incr_tx_drops();
        return ENOBUFFERS;
    }  

    // pkt ready to go
    return (tx_buf(state->parent, buf_id));
}
    



int8_t create_join_fwd_pkt(join_beacon_t *beacon, int8_t in_q, int8_t out_q)
{
    TOS_Msg *msg=get_buf();
    tree_hdr_t *tree_hdr=NULL;
    up_hdr_t *up_hdr=NULL;
    join_fwd_hdr_t *j_f_hdr=NULL;
    up_path_entry_t *entry=NULL;
    int8_t buf_id;

    if (msg==NULL) {
        dbg(DBG_ERROR, "Unable to create join_fwd packet, all bufs busy\n");
        call StatsI.incr_tx_drops();
        return ENOBUFFERS;
    }

    tree_hdr = (tree_hdr_t *)(msg->data);

    set_tree_hdr(tree_hdr, UP_TREE, JOIN_FORWARD, 0);
    up_hdr = (up_hdr_t *)(tree_hdr->data);
   
    // the original source of the join message is the source of the
    // beacon
    // set final destination to BROADCAST since we have no clue
    // about availability of sinks
    // set number of entries to 1: ourselves (2, us + the original source)
    if (set_up_hdr(up_hdr, beacon->mote_id, TOS_BCAST_ADDR, 1) == -1)
    {
       return ENOSPACE;
    }

    // since this is the first entry, we cast the j_f_e directly into the
    // beginning of the data field of the header
    entry = (up_path_entry_t *)(up_hdr->data);
    /*
    set_upstream_entry(entry, TOS_LOCAL_ADDRESS);
    entry->mote_id = beacon->mote_id;
    entry->inbound_quality = in_q;
    entry->outbound_quality = out_q;
    entry++;
    */
    // since we only have 1 entry, we can use the entry->next field
    j_f_hdr = (join_fwd_hdr_t *)(entry->next);
    // assign the beacon seq
    j_f_hdr->beacon_round = beacon->beacon_round;

    // set the entry and if this is a neighbor, return--we are done

    if (set_upstream_entry(entry, beacon->mote_id) < 0) {
        release_buf(msg);
        return ENONEIGHBOR;
    } else {
        // XXX XXX XXX
        // OVERRIDE entry quality values
        entry->inbound_quality = in_q;
        entry->outbound_quality = out_q;
        // set length and return buffer id
        // length is size of tree_hdr and up_hdr and one path entry
        // and join_fwd hdr
        msg->length = sizeof(tree_hdr_t) + sizeof(up_hdr_t) +
            (sizeof(up_path_entry_t)) + sizeof(join_fwd_hdr_t);
        buf_id = find_buf_id(msg);
        if (buf_id == -1)
        {
            dbg(DBG_ERROR, "Couldn't get buf id for %p\n", msg);
            release_buf(msg);
            return ENOBUFFERS;
        }  

        return buf_id;
    }

}


void dissociate(tree_state_t *state)
{
    // nuke state
    state->parent_valid=0;
    state->associated=0;
    state->parent=TOS_BCAST_ADDR;
    state->hops_away=0;
    state->sink=0;
    // increment beacon sequence number so that the sink can distinguish
    // between old and new paths
    state->beacon_seq++;

    // enable the join beacon
//    call JoinBeacon.enable();
    call JoinerI.beacon_enable();

#ifdef NODE_HEALTH
    // transmit module always active, while not associated
    // should be sending beacon packets regularly, when
    // associated set to the data generation rate
    call NodeHealthI.SetParameters(TRANSMIT, 
                                   DEFAULT_PROCESSING_TIME,
                                   MAX_BEACON_TIME,
                                   FLAG_RESERVED);
#endif
}


int8_t send_not_associated_pkt(tree_hdr_t *orig_tree_hdr)
{
    up_hdr_t *orig_up_hdr = (up_hdr_t *)(orig_tree_hdr->data);
    down_hdr_t *down_hdr = NULL;
    down_path_entry_t *down_entry=NULL;
    // estimated length is size of down hdr
    // plus the number of up_entries PLUS ONE, since in the
    // down_hdr entries we add ourselves
    uint8_t est_length = TOSH_DATA_LENGTH;
/*
    uint8_t est_length=sizeof(down_hdr_t) +
        sizeof(down_path_entry_t) * (orig_up_hdr->path_entries+1);
*/
    int8_t n=0;
    // down length is used as a verifier
    uint8_t down_length=0;
    char buf[est_length];

    memset(buf, 0, est_length);

    down_hdr = (down_hdr_t *)buf;
    // we are the original source
    down_hdr->orig_src = TOS_LOCAL_ADDRESS;
    // the final destination is the originator of the UP_TREE pkt
    down_hdr->final_dst = orig_up_hdr->orig_src;

    n = create_down_tree_entries_from_up_tree_hdr(orig_up_hdr, down_hdr);
    // 0 path entries created means the node is 1-hop away, so a retval of 
    // 0 is still ok
    if (n<0) {
        dbg(DBG_ERROR, "Unable to send NOT_ASSOCIATED pkt to node %u: Invalid"
                " number of down_entries (%d)\n", down_hdr->final_dst, n);
        return EINVALIDENTRY;
    }
    // we need to add one more down_entry, the final dst
    down_hdr->path_entries=n;
    down_entry = (down_path_entry_t *)(down_hdr->data) +
                down_hdr->path_entries;
    down_entry->mote_id = down_hdr->final_dst;
    down_hdr->path_entries++;

    // set buf length
    down_length = sizeof(down_hdr_t) +
        sizeof(down_path_entry_t) * down_hdr->path_entries;
/*
    if (down_length != est_length) {
        dbg(DBG_ERROR, "down_length != est_length (%d!=%d)\n",
                down_length, est_length);
        return EINVALIDLENGTH;
    }
*/
    // propagate_downstream_pkt subtracts tree_hdr_t length, so we
    // need to add it
    down_length += sizeof(tree_hdr_t);

    

    if (down_length > est_length) {
        dbg(DBG_ERROR, "down_length > max est length (%d>%d)\n",
                down_length, est_length);
        return EINVALIDLENGTH;
    }

    // buf ready to go, send it
    n = propagate_downstream_pkt(down_hdr, NOT_ASSOCIATED, 0, down_length);

    if (n < 0)
    {
       dbg(DBG_ERROR, "Unable to propagate downstream %d\n", n);
    }

    return n; 
}


int8_t create_down_tree_entries_from_up_tree_hdr(up_hdr_t *up_hdr, 
        down_hdr_t *down_hdr)
{
    int8_t i=0;
    uint8_t created=0;
    up_path_entry_t *up_entry=NULL;
    down_path_entry_t *down_entry=(down_path_entry_t *)(down_hdr->data);

    dbg(DBG_USR3, "Adding down entry: ");

    for (i=up_hdr->path_entries-1; i>=0; i--) {
        if (i<0) {
            break;
        }
        up_entry = (up_path_entry_t *)(up_hdr->data) + i;
        if (up_entry->mote_id==0 || up_entry->mote_id==TOS_BCAST_ADDR) {
            dbg(DBG_ERROR, "Cannot create down entry from up entry:"
                    " Invalid node ID %u\n", up_entry->mote_id);
            return EINVALIDENTRY;
        }

        dbg(DBG_USR3, "%d, ", up_entry->mote_id);

        down_entry->mote_id = up_entry->mote_id;
        // move down_entry to the next element
        down_entry++;
        created++;
    }

    dbg(DBG_USR3, "\nCount of down tree entries: %d, %d\n", created, up_hdr->path_entries);

    return created;
}


int8_t send_dest_unreachable_pkt(TOS_Msg *msg)
{
    tree_state_t *state = &g_state;
    TOS_Msg tmpbuf={};
    TOS_Msg *buf=NULL;
    tree_hdr_t *up_tree_hdr = NULL;
    tree_hdr_t *down_tree_hdr = NULL;
    up_hdr_t *up_hdr = NULL;
    down_hdr_t *down_hdr = NULL;
    up_path_entry_t *up_entry = NULL;
    int8_t buf_id;

#ifdef NODE_HEALTH
    dbg(DBG_ERROR, "Start: %d, %s\n", __LINE__, __FILE__);
    call NodeHealthI.ActionStart(TRANSMIT);
#endif

    memcpy(&tmpbuf, msg, sizeof(TOS_Msg));
    buf = get_buf();    // we can safely use get_buf now
    down_tree_hdr = (tree_hdr_t *)(&(tmpbuf.data));
    down_hdr = (down_hdr_t *)(down_tree_hdr->data);
    if (buf==NULL) {
        dbg(DBG_ERROR, "Unable to send DST_UNREACHABLE to node %u," 
                " all bufs busy\n", down_hdr->orig_src);
        call StatsI.incr_tx_drops();
        return ENOBUFFERS;
    }

    up_tree_hdr = (tree_hdr_t *)(buf->data);
    set_tree_hdr(up_tree_hdr, UP_TREE, DST_UNREACHABLE, 0);

    up_hdr = (up_hdr_t *)(up_tree_hdr->data);
    // set up_hdr fields
    if (set_up_hdr(up_hdr, down_hdr->final_dst, down_hdr->orig_src, 1) == -1)
    {
       return ENOSPACE;
    }

    up_entry = (up_path_entry_t *)(up_hdr->data);

    set_upstream_entry(up_entry, tmpbuf.addr);
    // set length and tx packet
    msg->length = sizeof(tree_hdr_t) + sizeof(up_hdr_t) +
        sizeof(up_path_entry_t);
    
    buf_id = find_buf_id(msg);
    if (buf_id == -1)
    {
        dbg(DBG_ERROR, "Couldn't get buf id for %p\n", msg);
        release_buf(msg);
        return ENOBUFFERS;
    }  

    return tx_buf(state->parent, buf_id);
}


int8_t handle_tx_retx_fail(tree_hdr_t *tree_hdr, TOS_Msg *msg)
{
    tree_state_t *state = &g_state;

    // Link-level retransmissions (or a normal TX) failed!
    if (tree_hdr->direction == UP_TREE) {
        // if direction is UP_TREE, we have a problem
        // it seems we've lost our parent
        // we need to dissociate, only if we were associated in
        // the first place
        // this will avoid unnecessary work when we failed to 
        // retransmit a NOT_ASSOCIATED pkt for example
        
        if (state->associated) {
            consecutive_packet_failures++;

            if (consecutive_packet_failures > MAX_CONSECUTIVE_PACKET_FAILURES)
            {
                consecutive_packet_failures = 0;
                dbg(DBG_USR1, "TX/RETX to parent %u FAILED, dissociating\n",
                    state->parent);
                dissociate(state);
            }
        }
    } else {
        // if direction is DOWN_TREE, our child is not responding
        // send a DST_UNREACHABLE message to the originator
        // only do this in the NON-sink case!
        if (state->is_sink==0) {
            // XXX XXX XXX
            // don't send D_U for now!
            //send_dest_unreachable_pkt(msg);
        } else {
            // TODO: handle this case, perhaps signal up?
            // the sink needs to know!
        }
    }
    return tree_hdr->direction;
}


void increment_tx_seq()
{
    tree_state_t *state = &g_state;
    state->tx_seq++;
    if (state->tx_seq==0) {
        state->tx_seq=1;
    }
}


event result_t SendMsg.sendDone(TOS_Msg *msg, result_t success)
{
    tree_state_t *state = &g_state;
    tree_hdr_t *tree_hdr = (tree_hdr_t *)(msg->data);
    // see what happened to our buf
    int8_t status = call QueueCtrl.get_buf_status(msg);
    result_t send_status = FAIL;
    int i;

    // handle the buf status
    switch(status) {

        case INVALID:
            dbg(DBG_ERROR, "Buf status is invalid! (buf=%p)\n",
                    (char *)msg);
            break;

        case SEND_DONE_ACK:
            // all good
            send_status = SUCCESS;
            break;

        case SEND_DONE_NOACK:
            // this is bad only if the addr isn't broadcast
            // in that case we haven't turned on acks in PktQueue
            // otherwise S_D_NOACK is returned when a packet has a bcast addr
            if (msg->addr != TOS_BCAST_ADDR) {
                dbg(DBG_ERROR, "Buf status is SEND_DONE_NOACK but"
                        " buf addr is NOT broadcast! (%u)\n",
                        msg->addr);
            }
	    else
	    {
	        send_status = SUCCESS;
	    }
            break;

        case SEND_FAILED:
        case SEND_DONE_RETX_FAIL:
            handle_tx_retx_fail(tree_hdr, msg);
            break;

        default:
            dbg(DBG_ERROR, "Got unexpected buf status %u\n",
                    status);
            break;
    }


#if 0
    if (tree_hdr->client_type != 0) {
        if (tree_hdr->direction == UP_TREE) {
            if (tree_hdr->type != DATA) {
                // this was a RAW call
		// set the type to 0 here, it will be decoded at a higher 
		// layer
                signal CentTreeSendI.send_pkt_up_done[tree_hdr->client_type]
                    (tree_hdr->data, 0,
                     msg->length - sizeof(tree_hdr_t));
            } else {
                // type was data, we need to decapsulate
                up_hdr_t *up_hdr=(up_hdr_t *)(tree_hdr->data);
                uint8_t offset = sizeof(up_hdr_t) + sizeof(up_path_entry_t) *
                    up_hdr->path_entries;

                signal CentTreeSendI.send_pkt_up_done[tree_hdr->client_type]
                    (&tree_hdr->data[offset], 0,
                     msg->length - sizeof(tree_hdr_t) - offset);
            }
        } else {
            // only the SINK is allowed to send pkts down
            signal CentTreeSinkI.send_pkt_down_done
                (tree_hdr->data, msg->addr, tree_hdr->type,
                 tree_hdr->client_type,
                 msg->length - sizeof(tree_hdr_t));
        }
    }
#endif
    // if this is a packet sent from a client, signal client
    // NOTE: rewriting this, since it doesn't handle the sink case well

    if ((tree_hdr->direction == UP_TREE) && (send_status == SUCCESS))
    {
        if (msg->addr != TOS_BCAST_ADDR)
        {
            // successfully transmitted packet to sink - clear the count of
            // consecutive packet failures
            consecutive_packet_failures = 0;
        }
    }
    

    
    if ((tree_hdr->client_type != 0) && (tree_hdr->direction == UP_TREE)) {
        up_hdr_t *up_hdr=(up_hdr_t *)(tree_hdr->data);
        uint8_t offset = sizeof(up_hdr_t) + sizeof(up_path_entry_t) *
                up_hdr->path_entries;
	        
	char *data;
	int length;
	uint8_t type_sent = tree_hdr->client_type;
        uint8_t is_data = tree_hdr->type;

	if (is_data != DATA)
        {
	    data = tree_hdr->data;
            length = msg->length - sizeof(tree_hdr_t) + 2;
	}
	else
	{
	    data = &tree_hdr->data[offset];
	    length = msg->length - sizeof(tree_hdr_t) - offset + 2;
	}

        for (i=0; i<length - sizeof(tree_hdr_t); i++)
        {
            dbg(DBG_USR2,"%d ", tree_hdr->data[i]);
        }
        dbg(DBG_USR2,"\n");

        // XXX XXX XXX
        // XXX XXX XXX
        // NOTE: ONLY SIGNAL/CHECK WHEN WE ARE THE ORIGINATORS!!!
        if (up_hdr->orig_src == TOS_LOCAL_ADDRESS)  {
            dbg(DBG_USR3, "Send done LOCAL, length of packet %u, type %d, offset %d\n",
                    length, tree_hdr->type, offset);
            
	    // signal that we have completed transmission before we signal
            // that we are done with this packet (since that will clear the packet
            // and mark for re-use)
	    signal CentTreeSendStatusI.send_complete_status[type_sent]((char *)msg, 
                        is_data, msg->length,
                        SEND_TYPE_LOCAL, send_status);


            signal CentTreeSendI.send_pkt_up_done[tree_hdr->client_type]
                (data, tree_hdr->type, length);
	    
            
        } else {
            // we are not the originators, ignore
            dbg(DBG_USR2, "Pkt originated at node %u, ignoring\n",
                    up_hdr->orig_src);
            dbg(DBG_USR3, "Send done FORWARD, length of packet %u, type %d, offset %d\n",
                    length, tree_hdr->type, offset);
            signal CentTreeSendStatusI.send_complete_status[type_sent]((char *)msg, 
                       is_data, msg->length, 
                       SEND_TYPE_FORWARDED, send_status);
        }
    }


    if ((state->is_sink==1) && (tree_hdr->direction==DOWN_TREE)) {
        // if we are a sink and the packet was heading down, 
        // we need to signal
        signal CentTreeSinkI.send_pkt_down_done
            (tree_hdr->data, msg->addr, tree_hdr->type,
             tree_hdr->client_type,
             msg->length - sizeof(tree_hdr_t));
    }

#ifdef NODE_HEALTH
    dbg(DBG_ERROR, "End: %d, %s\n", __LINE__, __FILE__);
    call NodeHealthI.ActionEnd(TRANSMIT);
#endif

    // release the buf BEFORE the switch so we can use it again if we need
    // to transmit
    release_buf(msg);
    return success;
}


/*
event void JoinBeacon.send_done(result_t result)
{
    if (result==SUCCESS) {
        call StatsI.incr_tx_pkts();
        call StatsI.incr_tx_bytes(sizeof(join_beacon_t));
    } else {
        call StatsI.incr_tx_errors();
    }
}
*/


event TOS_Msg *ReceiveMsg.receive(TOS_Msg *msg)
{
    // we don't receive beacons through receiveMsg
    // so we KNOW this is a tree_hdr_t packet
    tree_hdr_t *tree_hdr = (tree_hdr_t *)msg->data;
//    up_hdr_t *up_hdr = (up_hdr_t *)(tree_hdr->data);
//    data_hdr_t *data_hdr=(data_hdr_t *)(up_hdr->data);
//    DsePacket_t *p = (DsePacket_t *)(data_hdr->payload + sizeof(mDTN_pkt_t));
//    QueryResponse_t* qResp = (QueryResponse_t*) p->data;

    int8_t n=0;

    n = call DupCheckerI.check_pkt(tree_hdr->src, tree_hdr->tx_seq);
    if (n==IS_DUPLICATE) {
        dbg(DBG_ERROR, "Got duplicate packet, returning!\n");
        return msg;
    }

    // switch on type, each handler checks direction
    switch (tree_hdr->direction) {

        case UP_TREE:
            dbg(DBG_USR3, "Got up tree packet %d bytes long!\n", 
                msg->length);
            //dbg(DBG_ERROR,  "Receiving Query Response: ID = %d, bitmask = %d, Src %d, Seq %d\n", qResp->queryID, qResp->bitMask, p->hdr.m_uiSrcAddr, p->hdr.m_uiSeq);
            handle_up_tree_pkt(tree_hdr, msg->length);
            break;

        case DOWN_TREE:
            dbg(DBG_USR3, "Got down tree packet %d bytes long!\n", 
                msg->length);
            handle_down_tree_pkt(tree_hdr, msg->length);
            break;

        default:
            dbg(DBG_ERROR, "Unknown tree_hdr type %d\n", tree_hdr->type);
            break;
    }

    return msg;
}


int8_t add_to_up_path_entry_list(up_hdr_t *hdr, 
        uint16_t downstream_id, uint8_t up_payload_len)
{
    up_path_entry_t *entry=NULL;
    uint8_t offset = hdr->path_entries * sizeof(up_path_entry_t);
    int8_t data_payload_len = up_payload_len - sizeof(up_hdr_t) - offset;
    // find number of entries and cast accordingly
    if ((hdr->path_entries + 1) > (int8_t)MAX_ENTRIES) {
        // adding this entry would bring us over the max payload--return
        dbg(DBG_ERROR, "Adding entry would make packet too long: Current %d, Max %d\n", hdr->path_entries, MAX_ENTRIES);
        return ENOSPACE;
    }

    if (data_payload_len>0) {
        memmove((char *)(&hdr->data[offset+sizeof(up_path_entry_t)]), 
                (char *)(&hdr->data[offset]), data_payload_len);
                /*sizeof(up_path_entry_t));*/
    } else {
        dbg(DBG_USR2, "Data payload is %u, will not memmove\n",
                data_payload_len);
    }


    entry = (up_path_entry_t *)(hdr->data) + hdr->path_entries;
    if (set_upstream_entry(entry, downstream_id) < 0) {
        return ENONEIGHBOR;
    }
    hdr->path_entries++;

    dbg(DBG_USR3, "Entry (id=%u, i_q=%u, o_q=%u) added to path list, Path entry count %d)\n",
            entry->mote_id, entry->inbound_quality, entry->outbound_quality,
            hdr->path_entries);

    return hdr->path_entries;
}


// this is a generic UP_TREE handler
// it doesn't matter what kind of packet this is
int8_t handle_up_tree_pkt(tree_hdr_t *tree_hdr, uint8_t length)
{
    up_hdr_t *up_hdr = (up_hdr_t *)(tree_hdr->data);
    tree_state_t *state = &g_state;
    uint8_t up_payload_len = length - sizeof(tree_hdr_t);
    int8_t n=0;
    int i;

    if (state->associated==0) {
        uint8_t offset;
        char *up_data;
	int up_length;
        uint8_t type_sent = tree_hdr->client_type;
        uint8_t is_data = tree_hdr->type;
        
        dbg(DBG_ERROR, "Got UP_TREE pkt from node %u but "
                "I am not associated!\n", tree_hdr->src);
        // first, add ourselves. send_not_associated needs at least one
        // up_hdr entry
        if ((n = add_to_up_path_entry_list
                    (up_hdr, tree_hdr->src, up_payload_len)) < 0) {
            dbg(DBG_ERROR, "Couldn't add entry to entry list: %d\n",n);
            return EENTRYERR;
        } else {
            dbg(DBG_USR2, "Added node %u to entry list\n", 
                    tree_hdr->src);
        }
        
        offset = sizeof(up_hdr_t) + sizeof(up_path_entry_t) *
                up_hdr->path_entries;

        if (is_data != DATA)
        {
	    up_data = tree_hdr->data;
            up_length = up_payload_len + 2;
            dbg(DBG_ERROR, "Failed to send non-data packet\n");
	}
	else
	{
            // add extra up_path_entry_t because this was added when adding a path entry
	    up_data = &tree_hdr->data[offset];
	    up_length = up_payload_len - offset + sizeof(up_path_entry_t) + 2;
	}
        
        
        for (i=0; i<length - sizeof(tree_hdr_t); i++)
        {
            dbg(DBG_USR3,"%d ", tree_hdr->data[i]);
        }
        dbg(DBG_USR3,"\n");

        // notify the higher layer in case this packet should be stored
        signal CentTreeSendStatusI.send_complete_status[type_sent](up_data, 
                        is_data, up_length,
                        SEND_TYPE_FORWARDED, FAIL); 
        
        // now, send the NOT_ASSOCIATED pkt back
        send_not_associated_pkt(tree_hdr);
        return ENOTASSOCIATED;
    }

    if (tree_hdr->type == JOIN_REPLY ||
            tree_hdr->type == NOT_ASSOCIATED) {
        dbg(DBG_ERROR, "Got invalid type for UP_TREE pkt (%u)\n",
                tree_hdr->type);
        return EBADDIRECTION;
    }

    // if the request's destination is not broadcast
    if (up_hdr->final_dst != TOS_BCAST_ADDR &&
            // and it isn't destined to my sink
            up_hdr->final_dst != state->sink) {
        // dont forward
        dbg(DBG_ERROR, "Invalid final destination %u for UP_TREE pkt"
                "(my sink=%u)\n", up_hdr->final_dst, state->sink);
        return EINVALIDSINK;
    }

    // am I a sink? if so, i signal & return
    if (state->is_sink) {
        // Add ourselves to the entry list, then signal
        if ((n = add_to_up_path_entry_list
                    (up_hdr, tree_hdr->src, up_payload_len)) < 0) {
            dbg(DBG_ERROR, "Couldn't add entry to entry list: %d\n",n);
            return EENTRYERR;
        } else {
            dbg(DBG_USR3, "Added node %u to entry list\n", 
                    tree_hdr->src);
        }
        signal CentTreeSinkI.up_pkt_rcvd
            (up_hdr, tree_hdr->type,
             tree_hdr->client_type,
                up_payload_len + sizeof(up_path_entry_t));
        return SINK_REACHED;
    } 

    // not a sink but associated. Packet needs to be forwarded further up
    return propagate_upstream_pkt(up_hdr, tree_hdr->type,
            tree_hdr->client_type, up_payload_len, tree_hdr->src);
}


int8_t handle_down_tree_pkt(tree_hdr_t *tree_hdr, uint8_t length)
{
    down_hdr_t *down_hdr = (down_hdr_t *)(tree_hdr->data);
    int8_t propagate=0;


    

    switch (tree_hdr->type) {

        case JOIN_REPLY:
            
            propagate = handle_join_reply(down_hdr, tree_hdr->src);
            // call Leds.greenOff();   
	
            break;

        case DATA:
            dbg(DBG_USR3, "Sending a down data packet!\n");
            call Leds.redToggle();
            propagate = handle_data_pkt(down_hdr, tree_hdr->client_type,
                    tree_hdr->src, (length - sizeof(tree_hdr_t)));
            call Leds.greenToggle();   
            break;

        case NOT_ASSOCIATED:
            propagate = handle_not_associated(down_hdr, tree_hdr->src);
            break;

        case DISSOCIATE:
            propagate = handle_dissociate_pkt(down_hdr, tree_hdr->src);
            break;


        case JOIN_FORWARD:
        case DST_UNREACHABLE:
        default:
            dbg(DBG_ERROR, "Received invalid type for DOWN_TREE (%u)\n",
                tree_hdr->type);
            return EBADDIRECTION;
            break;
    }

    if (propagate>0) {
        int8_t n=0;
        n = propagate_downstream_pkt(down_hdr, tree_hdr->type, 
                tree_hdr->client_type, length);
        if (n < 0)
        {
           dbg(DBG_ERROR, "Unable to propagate downstream %d\n", n);
        }

        return n; 

        dbg(DBG_USR2, "Propagate_downstream returned %d\n", n);
    }

    return propagate;
}


int8_t handle_not_associated(down_hdr_t *down_hdr, uint16_t parent)
{
    tree_state_t *state = &g_state;

    // regardless of whether the packet is for us or not, we dissociate
    if (state->associated && parent==state->parent) {
        dbg(DBG_USR1, "Got NOT_ASSOCIATED pkt from parent node %u,"
                "dissociating\n", parent);
        dissociate(state);
    }

    // if the packet is for us
    if (down_hdr->final_dst == TOS_LOCAL_ADDRESS) {
        if (down_hdr->path_entries > 1) {
            dbg(DBG_ERROR, "Final destination reached but "
                    " there are still %d entries remaining!\n",
                    down_hdr->path_entries);
            return EINVALIDENTRY;
        } else {
            return DONT_PROPAGATE;
        }
    } else {
        // packet was not for us, forward
        return PROPAGATE;
    }

    return DONT_PROPAGATE;
}


int8_t handle_dissociate_pkt(down_hdr_t *down_hdr, uint16_t parent)
{
    int8_t retval=DONT_PROPAGATE;
    tree_state_t *state = &g_state;
//    uint8_t offset = down_hdr->path_entries * sizeof(down_path_entry_t);
    // dissociate pkts have no payload

    if (down_hdr->final_dst == TOS_LOCAL_ADDRESS) {
        if (down_hdr->path_entries > 1) {
            dbg(DBG_ERROR, "Final destination reached but "
                    " there are still %d entries remaining!\n",
                    down_hdr->path_entries);
            retval = EINVALIDENTRY;
            goto done;
        }

        // are we associated?
        if (state->associated==1) {
            // regardless of whether this is our sink or not,
            // we dissociate
            dbg(DBG_USR1, "Got DISSOCIATE pkt from sink %u,"
                        " dissociating!\n", state->sink);
            dissociate(state);
            retval = DONT_PROPAGATE;
            goto done;
        } else {
            // we aren't associated anyway so we just ignore this
            retval = DONT_PROPAGATE;
            goto done;
        }
    } else {
        // this pkt is not for us, fwd
        retval = PROPAGATE;
        goto done;
    }

done:
    return retval;
}



int8_t handle_join_reply(down_hdr_t *down_hdr, uint16_t parent)
{
    tree_state_t *state = &g_state;
    uint8_t offset=down_hdr->path_entries * sizeof(down_path_entry_t);
    join_reply_t *reply = (join_reply_t *)(&down_hdr->data[offset]);

    dbg(DBG_ERROR, "Got join reply packet to address %d, we are %d\n",
	down_hdr->final_dst, TOS_LOCAL_ADDRESS);

    // if the packet is for us
    if (down_hdr->final_dst == TOS_LOCAL_ADDRESS) {
        if (down_hdr->path_entries > 1) {
            dbg(DBG_ERROR, "Final destination reached but "
                    " there are still %d entries remaining!\n",
                    down_hdr->path_entries);
            return EINVALIDENTRY;
        }

        // see if we are already associated
        if (state->associated==1) {
            // if it's our sink, we ignore it but print a msg
            if (state->sink==down_hdr->orig_src) {
                dbg(DBG_USR1, "Got JOIN_REPLY message from sink %u but I am"
                    " already associated to it\n",
                    down_hdr->orig_src);
            } else {
                // this isn't our sink. Perhaps we could send a message
                // to it. But better yet, statesync should resolve the
                // ambiguity between sinks
                dbg(DBG_USR1, "Got JOIN_REPLY message from sink %u but I am"
                        " already associated to sink %u\n",
                        down_hdr->orig_src, state->sink);
        	return DONT_PROPAGATE;    
	    }

            // we're done
            //return DONT_PROPAGATE;
        }

        // not associated
        // check reply code
        if (reply->reply == RACK) {
            call Leds.redToggle();
            // if the sink has accepted us, we set it as our sink
            // and change status to associated
            state->associated = 1;
            state->sink = down_hdr->orig_src;
            // we also set the node that relayed us the message as
            // our parent
            state->parent = parent;
            state->parent_valid = 1;
            state->hops_away = reply->hops_away;
            dbg(DBG_ERROR, "ASSOCIATED with sink %u, via parent %u\n",
                    state->sink, state->parent);
            // finally, disable the beacon
            //call JoinBeacon.disable();
            call JoinerI.beacon_disable();

#ifdef NODE_HEALTH
            // transmit module always active, while not associated
            // should be sending beacon packets regularly, when
            // associated set to the data generation rate
            call NodeHealthI.SetParameters(TRANSMIT, 
                                   DEFAULT_PROCESSING_TIME,
                                   0,
                                   MIRROR_BETWEEN_DATA_GENERATION);
#endif
            call Leds.greenToggle();
            return DONT_PROPAGATE;

        } else {
            // negative reply
            dbg(DBG_ERROR, "Got RNACK from sink %u\n",
                    down_hdr->orig_src);
            return DONT_PROPAGATE;
        }

    } else {
        // The packet is NOT for us. we need to forward it further down
        return PROPAGATE;
    }

    return DONT_PROPAGATE;
}


int8_t handle_data_pkt(down_hdr_t *down_hdr, uint8_t client_type, 
        uint16_t parent, uint8_t length)
{
//    tree_state_t *state = &g_state;
    uint8_t offset = down_hdr->path_entries * sizeof(down_path_entry_t);
    uint8_t data_len = length - sizeof(down_hdr_t) - offset;

    // if the packet is for us
    if (down_hdr->final_dst == TOS_LOCAL_ADDRESS) {
        if (down_hdr->path_entries > 1) {
            dbg(DBG_ERROR, "Final desitnation reached but there are"
                    " still %d entries remaining!\n",
                    down_hdr->path_entries);
            return EINVALIDENTRY;
        }

        dbg(DBG_ERROR, "DATA pkt received from node %u via node %u, type %d, should be %d, length %d\n",
                down_hdr->orig_src, parent, client_type, CR_TYPE_DATAREL, data_len);
        // ok all is good, signal 
        signal CentTreeRecvI.down_pkt_rcvd[client_type](down_hdr->orig_src, 
                &down_hdr->data[offset], data_len);
        return DONT_PROPAGATE;
    } else {
        // packet is not for us, return propagate
        dbg(DBG_USR2, "Propagating DATA pkt (client_type=%d) "
                "to node %u\n", 
                client_type,
                down_hdr->final_dst);
        return PROPAGATE;
    }


    return DONT_PROPAGATE;
}



int8_t propagate_downstream_pkt(down_hdr_t *orig_hdr, uint8_t type, 
        uint8_t client_type, uint8_t length)
{
    tree_hdr_t *tree_hdr=NULL;
    down_hdr_t *new_hdr=NULL;
    down_path_entry_t *entry=NULL;
    TOS_Msg *buf = get_buf();
    uint16_t dst=0;
    uint8_t payload_offset=0;
    uint8_t payload_length=0;
    uint8_t adjusted_offset=0;
    int8_t buf_id;

#ifdef NODE_HEALTH
    dbg(DBG_ERROR, "Start: %d, %s\n", __LINE__, __FILE__);
    call NodeHealthI.ActionStart(TRANSMIT);
#endif

    if (buf==NULL) {
        dbg(DBG_ERROR, "Unable to propagate downstream pkt to node %u," 
                " all bufs busy\n", orig_hdr->final_dst);
        call StatsI.incr_tx_drops();
        return ENOBUFFERS;
    }


    // payload offset is the first byte after the list of entries
    payload_offset = (orig_hdr->path_entries * sizeof(down_path_entry_t));
    // payload length is length - offset
    payload_length = length - sizeof(tree_hdr_t) 
        - sizeof(down_hdr_t) - payload_offset;

    dbg(DBG_USR2, "Length=%u, tree_hdr=%u, down_hdr=%u, entries=%u,"
            " entry size=%u, payload=%u\n",
            length, sizeof(tree_hdr_t), sizeof(down_hdr_t), 
            orig_hdr->path_entries, 
            orig_hdr->path_entries * sizeof(down_path_entry_t),
            payload_length);

    // extract our entry
    orig_hdr->path_entries--;
    if (orig_hdr->path_entries < 1) {
        dbg(DBG_ERROR, "Unable to propagate downstream pkt to node %u, "
                " no entries left\n", orig_hdr->final_dst);
        release_buf(buf);
        return ENOENTRIES;
    }

    entry = (down_path_entry_t *)(orig_hdr->data);
    if (entry->mote_id != TOS_LOCAL_ADDRESS) {
        dbg(DBG_ERROR, "Unable to propagate downstream pkt to node %u, "
                "I am not part of its path! (first entry was %u)\n",
                orig_hdr->final_dst, entry->mote_id);
        release_buf(buf);
        return EINVALIDENTRY;
    }

    // move past our own entry
    entry++;
    // save the destination
    dst = entry->mote_id;


    // set tree_hdr
    tree_hdr = (tree_hdr_t *)(buf->data);
    new_hdr = (down_hdr_t *)(tree_hdr->data);
    set_tree_hdr(tree_hdr, DOWN_TREE, type, client_type);
    // copy the join_reply header
    memcpy(new_hdr, orig_hdr, sizeof(down_hdr_t));
    // copy the entries
    memcpy(new_hdr->data, entry, 
            (sizeof(down_path_entry_t) * new_hdr->path_entries));
    // set length
    buf->length = length - sizeof(down_path_entry_t);
    /*
    buf->length = sizeof(tree_hdr_t) + sizeof(down_hdr_t) +
                    (sizeof(down_path_entry_t) * down_hdr->path_entries);
    */

    // if the packet is carrying additional payload, copy it as well
    if (payload_length > 0) {
        adjusted_offset = payload_offset - sizeof(down_path_entry_t);
        dbg(DBG_USR2, "Moving payload from offset %u to offset %u\n",
                payload_offset, adjusted_offset);

        memcpy(&new_hdr->data[adjusted_offset], 
                &orig_hdr->data[payload_offset], payload_length);
    }

    // ready to go!
    buf_id = find_buf_id(buf);
    if (buf_id == -1)
    {
        dbg(DBG_ERROR, "Couldn't get buf id for %p\n", buf);
        release_buf(buf);
        return ENOBUFFERS;
    }  
    return (tx_buf(dst, buf_id));
}


up_path_entry_t *find_own_entry_in_up_path_entry_list(up_hdr_t *up_hdr)
{
    up_path_entry_t *entry=NULL;
    int8_t i=0;
    entry = (up_path_entry_t *)(up_hdr->data);
    for (i=0; i<up_hdr->path_entries; i++) {
        if (entry->mote_id == TOS_LOCAL_ADDRESS) {
            return entry;
            break;
        }
        entry++;
    }
    
    return NULL;
}


down_path_entry_t *find_own_entry_in_down_path_entry_list(down_hdr_t
        *down_hdr)
{
    down_path_entry_t *entry=NULL;
    int8_t i=0;
    entry = (down_path_entry_t *)(down_hdr->data);
    for (i=0; i<down_hdr->path_entries; i++) {
        if (entry->mote_id == TOS_LOCAL_ADDRESS) {
            return entry;
            break;
        }
        entry++;
    }
    
    return NULL;
}


int8_t handle_up_tree_retx(tree_hdr_t *tree_hdr, uint8_t length)
{
    up_hdr_t *up_hdr = (up_hdr_t *)(tree_hdr->data);
    up_path_entry_t *entry=NULL;

    entry = find_own_entry_in_up_path_entry_list(up_hdr);

    if (entry==NULL) {
        // we couldn't find ourselves! odd!
        dbg(DBG_ERROR, "Could not find local entry (%u) in entry list\n",
                TOS_LOCAL_ADDRESS);
    } else {
        entry->retx_count++;
        dbg(DBG_USR2, "src = %u, dir = %u, type = %u, c_t = %u, "
                "entries = %u, entry->id = %u, entry->retx_count = %u\n", 
                tree_hdr->src,
                tree_hdr->direction,
                tree_hdr->type,
                tree_hdr->client_type,
                up_hdr->path_entries,
                entry->mote_id,
                entry->retx_count);
    }

    return 0;
}


int8_t handle_down_tree_retx(tree_hdr_t *tree_hdr, uint8_t length)
{
// XXX XXX XXX
// NOTE: this doesn't work because we've already REMOVED ourselves
// from the list when we transmit!!!
// This is in contrast to UPSTREAM where we keep adding
#if 0
    down_hdr_t *down_hdr = (down_hdr_t *)(tree_hdr->data);
    down_path_entry_t *entry=NULL;

    entry = find_own_entry_in_down_path_entry_list(down_hdr);

    if (entry==NULL) {
        // we couldn't find ourselves! odd!
        dbg(DBG_ERROR, "Could not find local entry (%u) in entry list\n",
                TOS_LOCAL_ADDRESS);
    } else {
        entry->retx_count++;
    }
#endif

    return 0;
}


int8_t handle_retx_signal(TOS_Msg *msg)
{
    tree_hdr_t *tree_hdr = NULL;
/*
    if (msg->type != CENTTREE_MSG_TYPE) {
        // not our pkt
        dbg(DBG_ERROR, "RETX pkt is not ours (type %d != %d)\n",
                msg->type, CENTTREE_MSG_TYPE);
        goto done;
    }
*/

    tree_hdr = (tree_hdr_t *)(msg->data);

    switch (tree_hdr->direction) {

        case UP_TREE:
            dbg(DBG_USR2, "Got RETX SIGNAL for buffer %p\n", msg);
            handle_up_tree_retx(tree_hdr, msg->length);
            break;

        case DOWN_TREE:
            handle_down_tree_retx(tree_hdr, msg->length);
            break;

        default:
            dbg(DBG_ERROR, "Unknown direction %d\n", tree_hdr->direction);
            break;
    }

//done:
    return RETRANSMIT;
}



event result_t StartupTimer.fired()
{
    // register the beacon
/*
    if (call JoinBeacon.init(sizeof(join_beacon_t), 
                DEFAULT_PERIOD) != SUCCESS) {
        dbg(DBG_ERROR, "JoinBeacon initialization failed!\n");
    }
*/
    // use default values for now
    call JoinerI.init(0,0,0);
#ifdef NODE_HEALTH
    // transmit module always active, while not associated
    // should be sending beacon packets regularly, when
    // associated set to the data generation rate
    call NodeHealthI.SetParameters(TRANSMIT, 
                                   DEFAULT_PROCESSING_TIME,
                                   MAX_BEACON_TIME,
                                   FLAG_RESERVED);
    call NodeHealthI.Enable(TRANSMIT, ENABLE); 
#endif
    return SUCCESS;
}


event int8_t PktQ1.retx_pkt(TOS_Msg *msg)
{
    return handle_retx_signal(msg);
}


event int8_t PktQ2.retx_pkt(TOS_Msg *msg)
{
    return handle_retx_signal(msg);
}


event int8_t PktQ3.retx_pkt(TOS_Msg *msg)
{
    return handle_retx_signal(msg);
}


event int8_t PktQ4.retx_pkt(TOS_Msg *msg)
{
    return handle_retx_signal(msg);
}


event int8_t PktQ5.retx_pkt(TOS_Msg *msg)
{
    return handle_retx_signal(msg);
}


/*event int8_t PktQ6.retx_pkt(TOS_Msg *msg)
{
    return handle_retx_signal(msg);
}


event int8_t PktQ7.retx_pkt(TOS_Msg *msg)
{
    return handle_retx_signal(msg);
}


event int8_t PktQ8.retx_pkt(TOS_Msg *msg)
{
    return handle_retx_signal(msg);
}


event int8_t PktQ9.retx_pkt(TOS_Msg *msg)
{
    return handle_retx_signal(msg);
}


event int8_t PktQ10.retx_pkt(TOS_Msg *msg)
{
    return handle_retx_signal(msg);
}


event int8_t PktQ11.retx_pkt(TOS_Msg *msg)
{
    return handle_retx_signal(msg);
}


event int8_t PktQ12.retx_pkt(TOS_Msg *msg)
{
    return handle_retx_signal(msg);
}


event int8_t PktQ13.retx_pkt(TOS_Msg *msg)
{
    return handle_retx_signal(msg);
}


event int8_t PktQ14.retx_pkt(TOS_Msg *msg)
{
    return handle_retx_signal(msg);
}


event int8_t PktQ15.retx_pkt(TOS_Msg *msg)
{
    return handle_retx_signal(msg);
}

*/
default event int8_t CentTreeSendI.send_pkt_up_done[uint8_t id]
        (char *data, uint8_t type, uint8_t length)
{
    return -1;
}

default event int8_t CentTreeSendStatusI.send_complete_status[uint8_t id]
        (char *data, 
        uint8_t type, uint8_t length,
	send_originator_type_t orig, result_t status)
{
    return 0;
}

default event int8_t CentTreeSinkI.send_pkt_down_done
        (char *data, uint16_t dst, uint8_t type, uint8_t client_type, 
         uint8_t length)
{
    return -1;
}

/*
default event char *CentTreeRecvI.up_pkt_rcvd[uint8_t id]
        (uint16_t sender, char *data, uint8_t type, uint8_t length)
{
    return data;
}
*/

default event void CentTreeSinkI.join_beacon_rcvd(join_beacon_t *beacon,
            int8_t inbound_quality, int8_t outbound_quality)
{
}

default event void CentTreeSinkI.up_pkt_rcvd
        (up_hdr_t *up_hdr, uint8_t type, uint8_t client_type, uint8_t length)
{
}



default event char *CentTreeRecvI.down_pkt_rcvd[uint8_t id]
        (uint16_t sender, char *data, uint8_t length)
{
    dbg(DBG_ERROR, "Invalid id for packet recevied from wireless %d\n", id);
    return data;
}


    command uint16_t RoutingTable.getMaster()
    {
        return g_state.sink;
    
    }


    command uint8_t RoutingTable.getDepth()
    {
        return g_state.hops_away;	
    }

    command uint16_t RoutingTable.getParent()
    {
        return g_state.parent;
    }


    // neither of these queries can have valid responses from centroute
    // get converted link estimation value (to it's parent)
    command uint16_t RoutingTable.getLinkEst()
    {
         return 0;
    }
    command int16_t RoutingTable.getLinkRssi()
    {
        return 0;
    }

   

}
