includes Beaconer;

module BeaconerM
{
    provides {
        interface StdControl;
        interface BeaconerI[uint8_t id];
    }

    uses {
        interface PktQueueI as PktQueue;
        interface SendMsg;
        interface ReceiveMsg;

#ifdef EMSTAR_NO_KERNEL
        interface EmTimerI as BeaconerTimer;
#else
        interface Timer as BeaconerTimer;
#endif
#ifdef NODE_HEALTH
        interface NodeHealthI;
#endif
    }
}


implementation {
#include "Beaconer_Strings.h"
#include "PktQueue_defs.h"

#define ADVANCE(x) x = (((x+1) >= BEACONERCLIENTS) ? 0 : x+1)


#ifndef SECOND
#define SECOND  1000
#endif

#ifndef BEACONER_TICK
#define BEACONER_TICK   1000        // 1 second
#endif

#define TIMER_STARTED           (1<<0)
#define BEACON_PAYLOAD_SET      (1<<1)
#define BUF_BUSY                (1<<2)


#define B_CLEAR               0
#define PENDING             1
#define PROCESSED           2
#define DISABLED            3



// The state array entries
typedef struct _beaconer_entry {
    int16_t period;
    int16_t time_remaining;
    int8_t length;
    int8_t state;
} __attribute__ ((packed)) b_entry_t;

// the master header
typedef struct _beaconer_hdr {
    uint16_t src;
    int8_t num_entries;
    int8_t padding;
    char data[0];
} __attribute__ ((packed)) b_hdr_t;

// the header for each entry in the packet
typedef struct _beaconer_entry_hdr {
    int8_t type;
    int8_t padding;
    char data[0];
} __attribute__ ((packed)) b_entry_hdr_t;

#ifdef _RNP_LINK_H_
#define MAX_PAYLOAD (TOSH_DATA_LENGTH - sizeof(rnp_hdr_t) - sizeof(b_hdr_t))
#else
#define MAX_PAYLOAD (TOSH_DATA_LENGTH - sizeof(b_hdr_t))
#endif



b_entry_t b_table[BEACONERCLIENTS];
uint8_t max_length=0;
int8_t flags;
TOS_Msg pktbuf;


int8_t decrement_client_counters();
int8_t reset_client_counters();
int8_t signal_clients();
int8_t assemble_packet(uint8_t type, char *data);
int8_t check_pending();
int8_t send_beacon();
int8_t clear_processed_flags();

void print_chunk(char *ptr, int length)
{
  int i;

  for (i=0; i<length; i++)
    {
      dbg(DBG_ERROR, "%d ", *(ptr + i));

    }

  dbg(DBG_ERROR, "\n");
}


command result_t StdControl.init()
{
    memset(&b_table[0], 0, sizeof(b_table));
    return SUCCESS;
}


command result_t StdControl.start()
{
    call PktQueue.Init(&pktbuf);

    return SUCCESS;
}


command result_t StdControl.stop()
{
    return SUCCESS;
}


command result_t BeaconerI.init[uint8_t id](int8_t length, int16_t period)
{
    if (id>=BEACONERCLIENTS) {
        dbg(DBG_ERROR, "Client id (%d) >= max (%d)!\n",
                id, BEACONERCLIENTS);
        return FAIL;
    }

    if (length==0) {
        dbg(DBG_ERROR, "Client %d: invalid length 0\n", id);
        return FAIL;
    }

    if (b_table[id].length != 0) {
        dbg(DBG_ERROR, "Client %d: entry already initalized!\n", id);
        return FAIL;
    }

    if (period==0) {
        dbg(DBG_ERROR, "Client %d: cannot set 0-value period\n", id);
        return FAIL;
    }

    max_length += (length + sizeof(b_entry_hdr_t));
    if (max_length >= MAX_PAYLOAD) {
        dbg(DBG_ERROR, "Client %d: adding length %d violates max payload"
                " %d\n", id, length, MAX_PAYLOAD);
        return FAIL;
    }

    // all good, proceed with setting up the entry
    b_table[id].period = period;
    b_table[id].length = length;
    b_table[id].time_remaining = period;

    // if the timer isn't running, start it
    if ((flags & TIMER_STARTED) == 0) {
        if (call BeaconerTimer.start(TIMER_REPEAT, BEACONER_TICK) == FAIL)
	 {
      	   dbg(DBG_ERROR, "Oh noes, couldn't start beacon timer!\n");
    	 }
        flags |= TIMER_STARTED;
    }

    
    return SUCCESS;
}


command result_t BeaconerI.set_period[uint8_t id](int16_t period)
{
    if (id>=BEACONERCLIENTS) {
        dbg(DBG_ERROR, "Client id (%d) >= max (%d)!\n",
                id, BEACONERCLIENTS);
        return FAIL;
    }

    if (b_table[id].length==0) {
        dbg(DBG_ERROR, "Cannot set period for client %d: entry not"
                " initialized\n", id);
        return FAIL;
    }

    if (period==0) {
        dbg(DBG_ERROR, "Client %d: cannot set 0-value period\n",id);
        return FAIL;
    }

    b_table[id].period = period;

    return SUCCESS;
}


command int16_t BeaconerI.get_period[uint8_t id]()
{
    if (id>=BEACONERCLIENTS) {
        dbg(DBG_ERROR, "Client id (%d) >= max (%d)!\n",
                id, BEACONERCLIENTS);
        return FAIL;
    }

    return b_table[id].period;
}


command void BeaconerI.ignore[uint8_t id]()
{
    if (id>=BEACONERCLIENTS) {
        dbg(DBG_ERROR, "Client id (%d) >= max (%d)!\n",
                id, BEACONERCLIENTS);
        return;
    }

    if (b_table[id].state==PENDING) {
        b_table[id].state=B_CLEAR;
    }

    if (check_pending()==0) {
        send_beacon();
    }
}


command void BeaconerI.disable[uint8_t id]()
{
    if (id>=BEACONERCLIENTS) {
        dbg(DBG_ERROR, "Client id (%d) >= max (%d)!\n",
                id, BEACONERCLIENTS);
        return;
    }

    b_table[id].state=DISABLED;
}


command void BeaconerI.enable[uint8_t id]()
{
   if (id>=BEACONERCLIENTS) {
        dbg(DBG_ERROR, "Client id (%d) >= max (%d)!\n",
                id, BEACONERCLIENTS);
        return;
    } 

    b_table[id].state=B_CLEAR;
}


command int8_t BeaconerI.send[uint8_t id](char *data, int8_t now)
{
    int8_t n = 0;

    if (id>=BEACONERCLIENTS) {
        dbg(DBG_ERROR, "Client id (%d) >= max (%d)!\n",
                id, BEACONERCLIENTS);
        return B_ENOINIT;
    }

    if (b_table[id].length==0) {
        dbg(DBG_ERROR, "Client %d: cannot send beacon, client not"
                " initialized\n", id);
        return B_ENOINIT;
    }

    if (data==NULL) {
        dbg(DBG_ERROR, "Client %d: cannot send beacon, NULL pointer\n",id);
        return B_ENULLPTR;
    }

    if (b_table[id].state!=PENDING) {
        dbg(DBG_ERROR, "Client %d: cannot send beacon, PENDING" 
                " flag not set (%d)\n", id, b_table[id].state);
        return B_ENOPENDING;
    }

    if (flags & BUF_BUSY) {
        dbg(DBG_ERROR, "Client %d: cannot send beacon, buffer busy\n",
                id);
        return B_EAGAIN;
    }

    // all is good, assemble the packet
    n = assemble_packet(id, data);
    // state is set to processed REGARDLESS of the result
    b_table[id].state=PROCESSED;
    if (n<0) {
        // call check_pending to determine if there are any clients left
        if (check_pending()==0){
            // no more pending packets, send the beacon!
			dbg(DBG_USR2, "Client %d: sending chopped beacon!\n", id);
            send_beacon();
        }
        goto done;
    }

    // see if this is a new packet or an append operation on
    // an existing one
    if ((flags & BEACON_PAYLOAD_SET)==0) {
        flags |= BEACON_PAYLOAD_SET;
    }

    // call check_pending, in order to determine if there are any clients left
    if (check_pending()==0) {
        // no more pending packets, send the beacon!
        send_beacon();
    }

done:        
    return n;
}



int8_t send_beacon()
{
    b_hdr_t *ext_hdr = (b_hdr_t *)(pktbuf.data);

    if (ext_hdr->num_entries==0) {
        //dbg(DBG_ERROR, "Cannot send an empty beacon!\n");
        return -1;
    }

    //print_chunk(pktbuf.data, pktbuf.length);

    dbg(DBG_ERROR, "Start: %d, %s\n", __LINE__, __FILE__);

#ifdef NODE_HEALTH
    dbg(DBG_ERROR, "Start: %d, %s\n", __LINE__, __FILE__);
    call NodeHealthI.ActionStart(TRANSMIT);
#endif

    if (call SendMsg.send(TOS_BCAST_ADDR, 
                pktbuf.length, &pktbuf)!= SUCCESS) {
        dbg(DBG_ERROR, "Cannot send beacon!\n");
        return -1;
    } else {
        flags |= BUF_BUSY;
        return 0;
    }
}



int8_t check_pending()
{
    int8_t i=0;
    int8_t pending=0;

    // iterate through the array, find if any clients are still pending
    for (i=0; i<BEACONERCLIENTS; i++) {
        if (b_table[i].state==PENDING) {
            pending++;
        }
    }

    return pending;
}



event result_t SendMsg.sendDone(TOS_Msg *msg, result_t success)
{
    dbg(DBG_ERROR, "End: %d, %s\n", __LINE__, __FILE__);

#ifdef NODE_HEALTH
    dbg(DBG_ERROR, "End: %d, %s\n", __LINE__, __FILE__);
    call NodeHealthI.ActionEnd(TRANSMIT);
#endif

    // reset busy flag
    flags &= ~BUF_BUSY;
    flags &= ~BEACON_PAYLOAD_SET;
    // zero-out the buffer to make it ready for the next transmission
    memset(msg, 0, sizeof(TOS_Msg));
    clear_processed_flags();
    return SUCCESS;
}



event TOS_Msg *ReceiveMsg.receive(TOS_Msg *msg)
{
    int8_t i=0;
    uint8_t offset=0;
    b_hdr_t *ext_hdr=(b_hdr_t *)(msg->data);

    dbg(DBG_ERROR, "Received a beacon packet!\n");

    if (msg->addr==TOS_LOCAL_ADDRESS) {
        // we received a pkt from ourselves???!!!
        dbg(DBG_ERROR, "Received a packet from a node claiming to be me!"
                "(my_addr=%u, addr=%u)\n",
                TOS_LOCAL_ADDRESS, msg->addr);
        goto done;
    }


    if (ext_hdr->num_entries==0) {
        dbg(DBG_ERROR, "Number of entries in beacon packet was zero!"
                " (length = %u, src = %u, num_entries = %u)\n",
                msg->length, ext_hdr->src, ext_hdr->num_entries);
        goto done;
    }

    // for each of the entries in the beacon packet, dispatch a signal
    // to the corresponding client
    for (i=0; i<ext_hdr->num_entries; i++) {
        // we use the offset as an offset to the ext hdr
        b_entry_hdr_t *int_hdr = (b_entry_hdr_t *)(&ext_hdr->data[offset]);
        // we look up the length in the client table
        int8_t length = b_table[int_hdr->type].length;

        // signal appropriate client
        signal BeaconerI.receive[int_hdr->type]
            (ext_hdr->src, int_hdr->data, length);
        
        // increment the offset to get to the next element
        offset += sizeof(b_entry_hdr_t) + length;
    }


done:
    return msg;
}



int8_t clear_processed_flags()
{
    int8_t processed=0;
    int8_t i=0;

    for (i=0; i<BEACONERCLIENTS; i++) {
        if (b_table[i].state==PROCESSED) {
            b_table[i].state=B_CLEAR;
            // not sure if send_done is needed...
            signal BeaconerI.send_done[i](SUCCESS);
            processed++;
        }
    }

    return processed;
}



event result_t BeaconerTimer.fired()
{
    int8_t ready=0;
    ready = decrement_client_counters();

    if (ready > 0) {
        // we have at least one client whose timer has expired
        signal_clients();
        reset_client_counters();
    }

    return SUCCESS;
}



int8_t decrement_client_counters()
{
    int8_t i=0;
    int8_t ready=0;

    // decrement each client's time_remaining counter
    // if any of those is zero, set ready to the client's id
    for (i=0; i<BEACONERCLIENTS; i++) {
        if (b_table[i].length == 0) {
            continue;
        }

        if (b_table[i].time_remaining <= 0) {
            // hmm, this client's time_remaining was 0
            // the packet took too long to send maybe?
            // we don't reset/decrement it but we 
            // increment ready and continue
            ready++;
            continue;
        }

        b_table[i].time_remaining--;
        if (b_table[i].time_remaining <= 0) {
            // this client's timer has expired
            ready++;
        }
    }

    return ready;
}



int8_t reset_client_counters()
{
    int8_t i=0;
    int8_t reset=0;

    // iterate throught the array and reset
    // each time_remaining to its equivalent period
    for (i=0; i<BEACONERCLIENTS; i++) {
        if (b_table[i].length==0) {
            continue;
        }

        if (b_table[i].time_remaining<=0) {
            b_table[i].time_remaining = b_table[i].period;
            reset++;
        }
    }

    return reset;
}



int8_t signal_clients()
{
    int8_t pending=0;
    int8_t i=0;

    // iterate through the array and signal
    // all clients that have valid entries
    // indicate time_remaining in the signal so that clients
    // can choose whether they want to send early beacons or not
    for (i=0; i<BEACONERCLIENTS; i++) {
        if (b_table[i].length==0 || b_table[i].state==DISABLED) {
            continue;
        }

        if (b_table[i].state == PENDING)
        {
            dbg(DBG_ERROR, "Client %d: Time to signal, but beacon still pending from last time!\n", i);
#ifdef NODE_HEALTH
            // if we are monitoring health, start an event here (which won't 
            // have an end event).  We'll reset the mote when this times out
            call NodeHealthI.ActionStart(TRANSMIT);
#endif
        }

        // the signal usually results in a call to BeaconerI.send,
        // so we need to set the pending flag BEFORE we signal
        b_table[i].state=PENDING;
        pending++;
    }
    // we need to REPEAT the loop, since if we don't, we can end up
    // sending a packet for every client
    // XXX XXX XXX 
    // there might be a better way to do this...
    for (i=0; i<BEACONERCLIENTS; i++) {
        if (b_table[i].length==0 || b_table[i].state==DISABLED) {
            continue;
        }
        signal BeaconerI.beacon_ready[i](b_table[i].time_remaining);
    }

    return pending;
}



int8_t assemble_packet(uint8_t type, char *data)
{
    TOS_Msg *pkt = &pktbuf;
    b_hdr_t *ext_hdr = (b_hdr_t *)(pkt->data);
    uint8_t offset=0;
    b_entry_hdr_t *int_hdr=NULL;

    ext_hdr->src = TOS_LOCAL_ADDRESS;

    // if the length is zero, set it to the length of the external hdr
    // this gets set only the FIRST time assemble_packet is called
    if (pkt->length==0) {
        pkt->length += sizeof(b_hdr_t);
    }

    // we set the offset to be the pkt->length. we start writing at
    // the offset
    offset = pkt->length;
    // set the internal header to point to the offset
    int_hdr = (b_entry_hdr_t *)(&pkt->data[offset]);

    // look up the length of the type from the client array
    if ((b_table[type].length + sizeof(b_entry_hdr_t) + offset)
            >= TOSH_DATA_LENGTH) {

        dbg(DBG_ERROR, "Client %d: cannot add payload (length = %u) "
                "to beacon: max length exceeded (offset = %u, max = %u)\n",
                type, b_table[type].length, offset, TOSH_DATA_LENGTH);
        return B_ENOSPC;
    } else {
        dbg(DBG_USR2, "Client %d: added payload (length = %u)"
                " to beacon at offset %u\n",
                type, b_table[type].length, offset);
    }

    // we increment the number of entries every time assemble_packet
    // is called, since it's called on a send command
    ext_hdr->num_entries++;
    // we also set the internal header type here
    int_hdr->type = type;

    // ok length is good, add it to offset
    offset+=b_table[type].length+sizeof(b_entry_hdr_t);
    // copy the data
    memcpy(int_hdr->data, data, b_table[type].length);

    // write back offset to pkt->length
    pkt->length = offset;

    // good to go
    return 0;
}


#ifdef PLATFORM_EMSTAR
void convert_int8_flags_to_string(int8_t fl, char *str)
{
    int8_t i=0;
    int8_t tmp=fl;
    for (i=0; i<8; i++) {
        if (tmp & 0x1) {
            sprintf(str+i, "1");
        } else {
            sprintf(str+i, "0");
        }
        tmp = tmp >> 1;
    }
}
#endif



event int8_t PktQueue.retx_pkt(TOS_Msg *msg)
{
    // the beaconer sends bcasts so we should NEVER
    // get signalled about a retx
    // even so, we return DONT_RETRANSMIT to be sure
    return DONT_RETRANSMIT;
}


default event void BeaconerI.send_done[uint8_t id](result_t result)
{
}


default event void BeaconerI.receive[uint8_t id]
            (uint16_t src, char *data, int8_t length)
{
}


default event int8_t BeaconerI.beacon_ready[uint8_t id]
            (uint16_t time_remaining)
{
    return -1;
}
    
    

}
