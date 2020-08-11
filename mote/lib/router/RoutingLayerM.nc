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
 * RoutingLayer sends, receives, and forwards routing layer packets.
 *
 * Routing layer:
 *  - assumes 'tree' routing.
 *  - send packets originated at 'this' node to the destination over multihop.
 *  - receive packet destined to 'this' node.
 *  - forward packets that are destined to some other node.
 *  - 'parent' is decided externally by some routing mechanism 
 *    (e.g. MultiHopLQI) and accessed via RoutingTable interface.
 *  - 'children' table is maintained here in a data-driven way.
 *  - decides which way (up/down) to transmit based on last two bits of 
 *    the 'protocol' field in the routing header.
 *
 * @author Jeongyeup Paek
 * @author Omprakash Gnawali
 * Embedded Networks Laboratory, University of Southern California
 * @modified 1/11/2006
 * @modified 1/31/2007 documents added. forwarding queue modified.
 **/


#include "routinglayer.h"
#include "AM.h"

module RoutingLayerM {
    provides {
        interface StdControl;
        interface RoutingSend as Send[uint8_t protocol];
        interface RoutingReceive as Receive[uint8_t protocol];
    }
    uses {
        interface SendMsg as SubSendMsg;
        interface ReceiveMsg as SubReceiveMsg;
        interface RoutingTable;
        interface Timer as RetryTimer;
        interface Timer as AgingTimer;
        interface Random;
        interface RoutingChange;
        interface Leds;
        interface ChildrenTable;
        interface NeighborTable;
    }
}

implementation {

//#define DEBUG_CHILDREN 1 // periodically send a packet to parent to maintain
                         // child-parent relationship with my parent.

enum {
    RT_RETRY_TIME = 20,
    RT_MIN_RETRY_TIME = 6,  // when forwarding fails, retry after random backoff

    CHILDREN_AGING_INTERVAL = 60*1024UL,

#ifdef FWD_QUEUE_LEN
    FWD_Q_SIZE = FWD_QUEUE_LEN, // can define forwarding queue size at compile time
#else
    #if defined(PLATFORM_TELOSB) || defined(PLATFORM_IMOTE2) || defined(PLATFORM_TMOTE)
        FWD_Q_SIZE = 10,
    #elif defined(PLATFORM_MICAZ) || defined(PLATFORM_MICA2) || defined(PLATFORM_MICA2DOT)
        FWD_Q_SIZE = 4,
    #endif
#endif
    _QUEUE_SIZE = FWD_Q_SIZE + 1     // at least one space for my own packets
                                     //QUEUE_SIZE variable is already being used at beta/platform/pxa27x/lib/queue.h
};

    TOS_Msg fwd_queue[_QUEUE_SIZE]; // forwarding packet queue
    uint8_t fwd_head;
    uint8_t fwd_tail;
    uint8_t fwd_count;
    bool fwd_busy;
    bool sending;   // sending flag to show packet is still sending
    bool sending_mine;
    bool mybusy;
    TOS_MsgPtr mymsg;

#ifdef DEBUG_CHILDREN
    TOS_Msg ChildrenMsg;
    bool should_send_children_msg;
#endif

    task void forwardTask();

    command result_t StdControl.init() {
        sending = FALSE;
        fwd_busy = FALSE;
        fwd_head = 0;
        fwd_tail = 0;
        fwd_count = 0;
        sending_mine = FALSE;
        mybusy = FALSE;
        mymsg = NULL;
    #ifdef DEBUG_CHILDREN
        should_send_children_msg = TRUE;
    #endif
        call Leds.init();
        call Random.init();
        return SUCCESS;
    }
    command result_t StdControl.start() {
        call Leds.yellowOn();
        call AgingTimer.start(TIMER_REPEAT, CHILDREN_AGING_INTERVAL);
        return SUCCESS;
    }
    command result_t StdControl.stop() {
        return SUCCESS;
    }

    uint16_t get_next_hop(uint16_t dst_address, uint8_t protocol) {
        uint16_t nexthop;
        /* if destination is broadcast... this will not happen in Tenet */
        if (dst_address == TOS_BCAST_ADDR)
            return TOS_BCAST_ADDR;

        /* if up-tree traffic to the master, send to parent */
        if (((protocol & PROTOCOL_MASK) == PROTOCOL_CHILD_MSG) ||
            (protocol & PROTOCOL_UPLINK_BIT)) {
            nexthop = call RoutingTable.getParent();
        }
        /* if down-tree traffic to a mote, find children */
        else if (protocol & PROTOCOL_DOWNLINK_BIT) {
            /* if a child */
            if (call ChildrenTable.isChild(dst_address) == 1) 
                nexthop = call ChildrenTable.lookupChildNextHop(dst_address);
            /* else, try once in 1-hop, and give up */
            else
                nexthop = dst_address;
        }
        else {
        /* if neither up nor down, then what is it? */
        //    nexthop = call RoutingTable.getParent();
            nexthop = dst_address;
        }

        return nexthop;
    }

    // Assumes that the payload part is filled correctly (leaving space for header)
    // by calling 'getPayload' prior to calling this 'send'
    command result_t Send.send[uint8_t proto](uint16_t address, uint8_t length, TOS_MsgPtr msg) {
        RoutingHdr *header;

        if (fwd_count >= _QUEUE_SIZE) // Routing layer queue full
            return FAIL;
        if (mybusy)     // I am already in the queue
            return FAIL;
        if (length > RT_DATA_LENGTH)
            return FAIL;

        header = (RoutingHdr *) msg->data;
        header->srcAddr = TOS_LOCAL_ADDRESS;    // end-2-end source address
        header->dstAddr = address; // end-2-end destination address
        header->prevhop = TOS_LOCAL_ADDRESS;
        header->protocol = proto;
        header->protocol |= PROTOCOL_UPLINK_BIT;
        header->ttl = RT_DEFAULT_TTL;

        /* in Tenet, all motes send to masters */
        msg->addr = call RoutingTable.getParent();
        msg->length = sizeof(RoutingHdr) + length;  // include RoutingHeader

        dbg(DBG_USR1, "[RTL] SendMsg.send: src=%d, dst=%d, nxt-hop=%d, len=%d, type=%d\n",
                header->srcAddr, header->dstAddr, msg->addr, msg->length, msg->type);

        mybusy = TRUE;
        mymsg = msg;

        /* enqueue */
        memcpy(&fwd_queue[fwd_head], mymsg, sizeof(TOS_Msg));
        fwd_head = (fwd_head + 1) % _QUEUE_SIZE;
        fwd_count++;
        if (fwd_busy == FALSE)
            post forwardTask();

        return SUCCESS;
    }

    event result_t SubSendMsg.sendDone(TOS_MsgPtr msg, result_t success) {
        RoutingHdr *header = (RoutingHdr *) msg->data;

        if (sending_mine) {
            /* this packet is something that this node has originated. */
            msg = mymsg;
            msg->length = msg->length - sizeof(RoutingHdr);
            signal Send.sendDone[header->protocol & PROTOCOL_MASK](
                                 header->dstAddr, 
                                 msg->addr, 
                                 msg, 
                                 &msg->data[sizeof(RoutingHdr)], 
                                 success);
            sending_mine = FALSE;
            mybusy = FALSE;
            mymsg = NULL;
        }

        if (fwd_busy == TRUE) {
            fwd_busy = FALSE;
            fwd_tail = (fwd_tail + 1) % _QUEUE_SIZE; // dequeue
            fwd_count--;

        } 
        if (fwd_count > 0)
            post forwardTask();

        sending = FALSE;
        return SUCCESS;
    }

    task void forwardTask() {
        // Assume that the length field does not include RoutingHdr size.
        RoutingHdr *header;
        TOS_MsgPtr fwd_msg = &fwd_queue[fwd_tail];

        if (sending == TRUE)   // radio busy
            return;
        if (fwd_count == 0)    // nothing to send
            return;

        header = (RoutingHdr *) fwd_msg->data;
        header->prevhop = TOS_LOCAL_ADDRESS;

        fwd_msg->addr = get_next_hop(header->dstAddr, header->protocol);

        if (call SubSendMsg.send(fwd_msg->addr, fwd_msg->length, fwd_msg)) {
            sending = TRUE;
            fwd_busy = TRUE;
            if (header->srcAddr == TOS_LOCAL_ADDRESS) {
                sending_mine = TRUE;
            #ifdef DEBUG_CHILDREN
                should_send_children_msg = FALSE;
            #endif
            }
        } else {
            call RetryTimer.start(TIMER_ONE_SHOT, RT_MIN_RETRY_TIME + 
                                (call Random.rand() % RT_RETRY_TIME));
        }
    }

#ifdef DEBUG_CHILDREN
    task void sendChildrenMsgTask() {
        RoutingHdr *header;
        if (sending)
            return;
        if (call RoutingTable.getParent() == TOS_BCAST_ADDR)
            return;

        header = (RoutingHdr *) ChildrenMsg.data;
        header->srcAddr = TOS_LOCAL_ADDRESS;
        header->dstAddr = RT_NON_EXISTENT_ADDR;
        header->prevhop = TOS_LOCAL_ADDRESS;
        header->protocol = PROTOCOL_CHILD_MSG | PROTOCOL_UPLINK_BIT;
        header->ttl = 20;

        ChildrenMsg.data[8] = (uint8_t)(call RoutingTable.getParent() & 0xff);
        ChildrenMsg.data[9] = (uint8_t)((call RoutingTable.getParent() >> 8) & 0xff);

        if (call SubSendMsg.send(call RoutingTable.getParent(), 10, &ChildrenMsg)) {
            sending = TRUE;
        }
        else 
            post sendChildrenMsgTask();
    }
#endif

    event result_t AgingTimer.fired() {
        call ChildrenTable.ageChildren();
        call NeighborTable.ageNeighbors();
    #ifdef DEBUG_CHILDREN
        if (should_send_children_msg)
            post sendChildrenMsgTask();
        else
            should_send_children_msg = TRUE;
    #endif
        return SUCCESS;
    }

    event result_t RetryTimer.fired() {
        post forwardTask();
        return SUCCESS;
    }

    int is_duplicate_packet(TOS_MsgPtr msg) {
        int i;
        uint8_t last_idx;
        if ((fwd_count == 0) && (msg->addr != TOS_BCAST_ADDR)) return 0;
        if (fwd_head == 0) last_idx = (uint8_t)(_QUEUE_SIZE - 1);
        else last_idx = fwd_head - 1;
        for (i = 0; i < msg->length; i++) {
            if (fwd_queue[last_idx].data[i] != msg->data[i])
                return 0;
        }
        return 1;
    }

    event TOS_MsgPtr SubReceiveMsg.receive(TOS_MsgPtr msg) {
        RoutingHdr *header = (RoutingHdr *) msg->data;

        if (msg->length < sizeof(RoutingHdr))
            return msg;

        // We remove the RoutingHdr when signaling up the packet.

        if ((msg->addr != TOS_LOCAL_ADDRESS) && (msg->addr != TOS_BCAST_ADDR)) {
            dbg(DBG_USR1, "[RTL] This node is not the next hop\n");
            return msg;
        }

        // This node is the destination
        if (header->dstAddr == TOS_LOCAL_ADDRESS || header->dstAddr == TOS_BCAST_ADDR) {
            dbg(DBG_USR1, "[RTL] ReceiveMsg: src=%d, dst=%d, msg->addr=%d, ttl=%d\n",
                    header->srcAddr, header->dstAddr, msg->addr, header->ttl);
                
            // Signal if end-2-end destination is this node
            signal Receive.receive[header->protocol & PROTOCOL_MASK](
                            header->srcAddr, msg, 
                            &msg->data[sizeof(RoutingHdr)], 
                            msg->length - sizeof(RoutingHdr));
        } 
        // Routing Loop!!!
        else if (header->srcAddr == TOS_LOCAL_ADDRESS) {
            dbg(DBG_USR1, "[RTL] ReceiveMsg(loop): src=msg->addr=%d, dst=%d, ttl=%d\n",
                           header->srcAddr, header->dstAddr, header->ttl);

            if (msg->addr != TOS_BCAST_ADDR)
                call ChildrenTable.deleteChild(call RoutingTable.getParent()); // REMOVE ROUTING LOOP
        } 
        // TTL expired!!!
        else if (header->ttl == 0) {
            dbg(DBG_USR1, "[RTL] ReceiveMsg(TTL==0): src=msg->addr=%d, dst=%d\n",
                           header->srcAddr, header->dstAddr);

            if ((header->protocol & PROTOCOL_MASK) == PROTOCOL_TCMP) {
                signal Receive.receive[header->protocol & PROTOCOL_MASK](
                                header->srcAddr, msg, 
                                &msg->data[sizeof(RoutingHdr)], 
                                msg->length - sizeof(RoutingHdr));
            }
        } 
        // TTL error?
        else if (header->ttl > RT_DEFAULT_TTL) {
            dbg(DBG_USR1, "[RTL] ReceiveMsg(TTL error): src=msg->addr=%d, dst=%d\n",
                           header->srcAddr, header->dstAddr);
        }
        // based on header info, should forward packet...
        else if ((fwd_count < (_QUEUE_SIZE - 1)) ||      // we have room in the forwarding queue
                 ((fwd_count < _QUEUE_SIZE) && mybusy)) {// (make sure not to take my own space)
                
            if (is_duplicate_packet(msg))  // duplicate packet
                return msg;

            dbg(DBG_USR1, "[RTL] ReceiveMsg(forwarding): src=%d, dst=%d, addr=%d, ttl=%d\n",
                    header->srcAddr, header->dstAddr, msg->addr, header->ttl);

            if (header->protocol & PROTOCOL_UPLINK_BIT) {
                uint16_t cParent = call RoutingTable.getParent();

                if (header->protocol & PROTOCOL_DOWNLINK_BIT)   // up && down? ==> error!
                    return msg;

                if (header->srcAddr == cParent) // src is my parent. should not forward
                    return msg;
                    //call ChildrenTable.deleteChild(header->srcAddr);

                if (header->prevhop != cParent)
                    call ChildrenTable.addChild(header->prevhop, header->srcAddr); // add to children list if valid
            }

            // decrement ttl just before queueing for forwarding
            header->ttl--;

            /* enqueue, regardless of whether it is 
                - uplink (we should forward), or 
                - downlink with route entry (we should forward), or
                - downlink without route entry (try only once), or
                - unknown traffic (bug). */
            memcpy(&fwd_queue[fwd_head], msg, sizeof(TOS_Msg));
            fwd_head = (fwd_head + 1) % _QUEUE_SIZE;
            fwd_count++;

            if (fwd_busy == FALSE)
                post forwardTask();
        }
        // Should forward, but cannot
        else {
            dbg(DBG_USR1, "[RTL] ReceiveMsg(drop): src=%d, dst=%d, msg->addr=%d, ttl=%d\n",
                    header->srcAddr, header->dstAddr, msg->addr, header->ttl);
        }
        return msg;
    }

    command void* Send.getPayload[uint8_t proto](TOS_MsgPtr msg, uint8_t* length) {
        /* if there are any more layers other that GenericComm
           below this module, then we should call 'getPayload' of that module 
           and return the result accordingly */
        if (length != NULL)
            *length = RT_DATA_LENGTH;
        return (void *) &msg->data[sizeof(RoutingHdr)];
    }

    command uint8_t Send.maxPayloadLength[uint8_t proto]() { return RT_DATA_LENGTH; }

    event void RoutingChange.parentChanged(uint16_t parent) {
        if (parent != TOS_BCAST_ADDR)
            call Leds.yellowOff();
        call ChildrenTable.deleteChild(parent); // we have a new parent. 
                             // make sure to delete this from children list
    }

    default event result_t Send.sendDone[uint8_t proto](uint16_t destAddr, 
                                         uint16_t nextHop, TOS_MsgPtr msg, 
                                         void* payload, result_t success) {
        return SUCCESS;
    }
    default event void Receive.receive[uint8_t proto](uint16_t srcAddr, 
                                       TOS_MsgPtr msg, void* payload, uint8_t paylen) {
        return;
    }

}

