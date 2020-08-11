/* ex: set tabstop=4 expandtab shiftwidth=4 softtabstop=4: */
includes Joiner;
includes AM;
//includes EmStar;

module JoinerM
{
    provides {
        interface StdControl;
        interface JoinerI;
        interface JoinPayloadI[uint8_t id];
    }

    uses {
        interface BeaconerI as JoinBeacon;
//        interface Timer as AgeTimer;
        interface CentTreeCtrlI;
        interface Random;

        interface StatsI;
    }
}


implementation {

#include "RnpDefs.h"
#include "PktQueue_defs.h"


#ifndef SECOND
#define SECOND  (1000)
#endif

#ifndef MAX_JOINER_TABLE_SLOTS
#define MAX_JOINER_TABLE_SLOTS      4
#endif

#ifndef MAX_TICS_PER_TURN
#define MAX_TICS_PER_TURN           5
#endif

#ifndef TICK_PERIOD_SEC
#define TICK_PERIOD_SEC             1
#endif

#ifndef TURN_PERIOD_SEC 
#define TURN_PERIOD_SEC             30
#endif

#ifndef DEFAULT_TX_THRESHOLD    
#define DEFAULT_TX_THRESHOLD        66
#endif

#define TABLE_FULL      -1
#define NOT_FOUND       -1

#define NEW_ROUND       1
#define NEW_TURN        2
#define OLD_TURN        3
#define SAME_TURN       4

#ifndef MAX_JOIN_PAYLOAD
#define MAX_JOIN_PAYLOAD    0
#endif



jb_element_t join_table[MAX_JOINER_TABLE_SLOTS] = {};


char beacon_buf[sizeof(jb_pkt_t) + MAX_JOIN_PAYLOAD];
jb_pkt_t *local_beacon = (jb_pkt_t *)beacon_buf;

int8_t join_period_timeout = 0;
uint8_t beacon_heard;
uint8_t tx_threshold = DEFAULT_TX_THRESHOLD;
uint32_t evicted=0;


void flush_table();
int8_t find_highest_node_id();
int8_t update_table_element(int8_t idx, jb_pkt_t *rcvd_beacon);
void reset_table_element(int8_t idx);
void create_table_element(int8_t idx, jb_pkt_t *beacon);
int8_t find_node_in_table(uint16_t node_id);
int8_t find_first_empty_slot();
void age_entries();


command result_t StdControl.init()
{
    memset(beacon_buf, 0, (sizeof(jb_pkt_t) + MAX_JOIN_PAYLOAD));
    call Random.init();
    return SUCCESS;
}


command result_t StdControl.start()
{
    

    return SUCCESS;
}


command result_t StdControl.stop()
{
    return SUCCESS;
}


command result_t JoinerI.init(uint8_t join_timeout_sec, uint8_t
        tick_period_sec, uint8_t max_ticks)
{
    if (join_timeout_sec > 0) {
        local_beacon->join_timeout_sec = join_timeout_sec;
    } else {
        local_beacon->join_timeout_sec = TURN_PERIOD_SEC;
    }

    if (tick_period_sec > 0) {
        local_beacon->tick_period_sec = tick_period_sec;
    } else {
        local_beacon->tick_period_sec = TICK_PERIOD_SEC;
    }

    if (max_ticks > 0) {
        local_beacon->max_ticks = max_ticks;
    } else {
        local_beacon->max_ticks = MAX_TICS_PER_TURN;
    }

    local_beacon->mote_id = TOS_LOCAL_ADDRESS;

    // register the beacon with a 1-sec period (filtering will be done
    // on each tick)
    if (call JoinBeacon.init(sizeof(jb_pkt_t)+MAX_JOIN_PAYLOAD, 
                local_beacon->tick_period_sec) != SUCCESS) {
        dbg(DBG_ERROR, "Joiner initialization failed\n");
        return FAIL;
    } else {
        dbg(DBG_USR1, "Joiner initialized (%u, %u, %u)\n",
                local_beacon->join_timeout_sec,
                local_beacon->tick_period_sec,
                local_beacon->max_ticks);
    }
    join_period_timeout = join_timeout_sec;
    //call AgeTimer.start(TIMER_REPEAT, SECOND);

    return SUCCESS;
}


command void JoinerI.set_join_timeout(uint8_t period_sec)
{
    if (period_sec > 0) {
        local_beacon->join_timeout_sec = period_sec;
    }
}


command void JoinerI.set_tick_period(uint8_t period_sec)
{
    if (period_sec > 0) {
        local_beacon->tick_period_sec = period_sec;
    }
}


command void JoinerI.set_max_ticks(uint8_t ticks)
{
    if (ticks > 0) {
        local_beacon->max_ticks = ticks;
    }
}


command uint8_t JoinerI.get_join_timeout()
{
    return local_beacon->join_timeout_sec;
}


command uint8_t JoinerI.get_tick_period()
{
    return local_beacon->tick_period_sec;
}


command uint8_t JoinerI.get_max_ticks()
{
    return local_beacon->max_ticks;
}


command void JoinerI.beacon_enable()
{   
    // when enable is called, we have dissociated, so we increment round
    local_beacon->beacon_round++;
    join_period_timeout = local_beacon->join_timeout_sec;
    local_beacon->beacon_tick = 0;
//    call JoinBeacon.enable();
}


command void JoinerI.beacon_disable()
{
    // this is a NOOP--we don't actually disable the beacon
    // since we are using its timer for aging purposes
//    call JoinBeacon.disable();
//    local_beacon->round++;
}



event int8_t JoinBeacon.beacon_ready(uint16_t time_remaining)
{   
    if (time_remaining>0) {
        // ignore signals when it isn't our time yet
        call JoinBeacon.ignore();
        goto done;
    }



    // XXX XXX XXX
    // we use the beacon_ready as a TIMER for aging purposes
    // if the node is associated
    // first, see if we are associated. if we are, we IGNORE
    if ((call CentTreeCtrlI.is_associated()==1) ||
            (call CentTreeCtrlI.is_sink()==1)) {
        age_entries();
        call JoinBeacon.ignore();
        goto done;
    }


    // not associated
    // check if we have reached max # of ticks, if so we ignore
    if (local_beacon->beacon_tick < local_beacon->max_ticks) {
        // max not reached yet. 
        // increment tick

        // if this is our first tick, check beacon_heard
        if (beacon_heard>0 && local_beacon->beacon_tick==0) {
            // we overheard beacons, need to do suppression
            // roll random number
            uint32_t r = 0;

            r = 1 + (uint32_t)(100.0 * (call Random.rand()) 
                    / (65535.0 + 1.0));
            // if the number is greater than the TX threshold
            if (r < tx_threshold) {
                // tough luck, return
                call StatsI.incr_tx_deferrals();
                call JoinBeacon.ignore();
                goto done;
            }
        }

        local_beacon->beacon_tick++;
        // send out the beacon
        if ((call JoinBeacon.send((char *)local_beacon, 0)) < 0) {
            dbg(DBG_ERROR, "Could not send join beacon!\n");
            // XXX XXX XXX
            // decrementing the tick here is dangerous...
            //local_beacon->tick--;
            goto done;
        } else {
        // NOTE: this is the ONLY case where we actually TX a beacon!
            dbg(DBG_USR2, "Beacon send call succeeded\n");
            call StatsI.incr_tx_pkts();
            call StatsI.incr_tx_bytes(sizeof(local_beacon));
        }
    } else {
        call JoinBeacon.ignore();
    }

    // decrement next turn counter
    join_period_timeout--;
    // if we reach 0, reset tick counter and increment turn
    if (join_period_timeout<=0) {
        local_beacon->beacon_turn++;
        local_beacon->beacon_tick=0;
        join_period_timeout = local_beacon->join_timeout_sec;
    }
    //call JoinBeacon.ignore();

done:

    beacon_heard=0;
    return 0;
}


event void JoinBeacon.send_done(result_t result)
{
}


event void JoinBeacon.receive(uint16_t src, char *data, int8_t length)
{
    jb_pkt_t *rcvd_beacon = (jb_pkt_t *)(data);
    uint16_t parent = call CentTreeCtrlI.get_parent_id();
    int8_t i=0;

    // if we are NOT associated, we don't do anything besides marking
    // beacon_heard
    if ((call CentTreeCtrlI.is_associated()) == 0) {
        beacon_heard++;
        // we just return here; no table maintenance
        return;
    }
    // we are associated

    // if we just received a beacon from our parent, notify CentTree!
    if ((parent == src) && (parent!=TOS_BCAST_ADDR)) {
        signal JoinerI.beacon_from_parent_rcvd();
        // flush table and return
        flush_table();
        return;
    }

    // we are associated and the beacon isn't from the parent; all is well

    i = find_node_in_table(src);

    if (i!=NOT_FOUND) {
        update_table_element(i, rcvd_beacon);
    } else {
        // node not found in table
        int8_t n=0;
        n = find_first_empty_slot();
        if (n == TABLE_FULL) {
            // table is full
            int8_t highest_idx = find_highest_node_id();
            if (highest_idx < 0) {
                dbg(DBG_ERROR, "Negative highest node id but table is"
                        " full?!!\n");
                return;
            }

            // compare highest node id with this received beacon
            if (join_table[highest_idx].beacon.mote_id > src) {
                // highest node id is indeed higher
                // secondary check--beacon's tick is 1, evict old, else
                // ignore beacon
                if (rcvd_beacon->beacon_tick==1) {
                    // tick is 1, evict
                    evicted++;
                    reset_table_element(highest_idx);
                    // put the beacon into the highest slot
                    create_table_element(highest_idx, rcvd_beacon);
                } 
            }   // received beacon's id higher than our highest, IGNORE

        } else {
            // still room 
            create_table_element(n, rcvd_beacon);
        }
    }

}


void flush_table()
{
    memset(&join_table, 0, (sizeof(jb_element_t) * MAX_JOINER_TABLE_SLOTS));
}


int8_t find_highest_node_id()
{
    uint8_t i=0;
    int8_t idx=-1;
    uint16_t highest = 0;

    for (i=0; i<MAX_JOINER_TABLE_SLOTS; i++) {
        if (join_table[i].beacon.mote_id > highest) {
            highest = join_table[i].beacon.mote_id;
            idx = i;
        }
    }

    return idx;
}


int8_t update_table_element(int8_t idx, jb_pkt_t *rcvd_beacon)
{
    jb_pkt_t *stored_beacon = &(join_table[idx].beacon);
    int16_t round = (int16_t)((int16_t)rcvd_beacon->beacon_round - 
            (int16_t)stored_beacon->beacon_round);
    int8_t turn = (int8_t)((int8_t)rcvd_beacon->beacon_turn -
            (int8_t)stored_beacon->beacon_turn);

    if (round > 0) {
        // NEWER round, reset everything
        reset_table_element(idx);
        create_table_element(idx, rcvd_beacon);
        return NEW_ROUND;
    }

    if (turn > 0) {
        // NEW TURN, reset tick and rcvd
        memcpy(stored_beacon, rcvd_beacon, sizeof(jb_pkt_t));
        join_table[idx].rcvd=1;
        join_table[idx].age=0;
        return NEW_TURN;
    } else if (turn < 0) {
        // stored beacon is NEWER than received!
        // this is a weird case
        dbg(DBG_ERROR, "Stored beacon turn NEWER than received beacon"
                " (node id = %u, sb = %d, rb = %d)\n",
                rcvd_beacon->mote_id, 
                stored_beacon->beacon_turn, 
                rcvd_beacon->beacon_turn);
        return OLD_TURN;
    }

    join_table[idx].rcvd++;
    // turn is the same
    return SAME_TURN;
}


void reset_table_element(int8_t idx)
{
    memset(&join_table[idx], 0, sizeof(jb_element_t));
}


void create_table_element(int8_t idx, jb_pkt_t *beacon)
{
    memcpy(&join_table[idx], beacon, sizeof(jb_element_t));
    join_table[idx].rcvd=1;
    // age is set to the beacon's tick
    join_table[idx].age=beacon->beacon_tick;
    join_table[idx].state = 0;
}


int8_t find_node_in_table(uint16_t node_id)
{
    int8_t i=0;

    for (i=0; i<MAX_JOINER_TABLE_SLOTS; i++) {
        if (join_table[i].beacon.mote_id == node_id) {
            return i;
        }
    }

    return NOT_FOUND;
}


int8_t find_first_empty_slot()
{
    int8_t i=0;

    for (i=0; i<MAX_JOINER_TABLE_SLOTS; i++) {
        if (join_table[i].beacon.mote_id==0) {
            return i;
        }
    }

    return TABLE_FULL;
}


void age_entries()
{
    int8_t i=0;

    dbg(DBG_USR3, "Got to age entries\n");

    for (i=0; i<MAX_JOINER_TABLE_SLOTS; i++) {
        jb_element_t *element = &join_table[i];
        // skip empty entries
        if (element->beacon.mote_id==0) {
            continue;
        }
    
        element->age++;

        // check age, if age > (max_beacons + 1) * tick_period, signal
        // up and remove entry from table

        if (element->age > ((element->beacon.max_ticks + 1) *
                element->beacon.tick_period_sec)) {
            // time to signal!
            dbg(DBG_ERROR, "%u beacons out of %u rcvd from node %u,"
                    " signaling and evicting\n",
                    element->rcvd,
                    element->beacon.max_ticks,
                    element->beacon.mote_id);
            
            signal JoinerI.join_request_rcvd(element->beacon.mote_id, 
                    element->beacon.beacon_round, element->rcvd,
                    element->beacon.max_ticks);
            reset_table_element(i);
        }
    }
}


command int8_t JoinPayloadI.init[uint8_t id](int8_t type,
        int8_t length, char *value)
{
    jb_payload_element_t *pel=NULL;
    int8_t offset=0;
    uint8_t elements = local_beacon->payload_elements;
    pel = (jb_payload_element_t *)&(local_beacon->data[offset]);

    while (elements > 0) {
        offset+=sizeof(jb_payload_element_t) + pel->length;
        pel = (jb_payload_element_t *)&(local_beacon->data[offset]);
        elements--;
    }
    // elements should be 0 here
    // check offset, if offset + sizeof(jb_payload)+length > MAX
    // we don't have room
    if ( (offset+sizeof(jb_payload_element_t)+length) >=
            MAX_JOIN_PAYLOAD) {
        return -1;
    }

    // we have room
    pel->type = type;
    pel->length = length;
    memcpy(pel->value, value, length);
    local_beacon->payload_elements++;

    return offset;
}

}
