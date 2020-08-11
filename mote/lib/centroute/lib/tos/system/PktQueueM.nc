includes PktQueue;

module PktQueueM
{
    provides {
        interface StdControl;
        interface PktQueueI[uint8_t id];
        interface PktQueueCtrlI;
        interface SendMsg as PktQueueSendMsg[uint8_t id];
    }

    uses {

        interface SendMsg as SerialSendMsg[uint8_t id];
#if defined(TOSH_HARDWARE_MICA2DOT) || defined(TOSH_HARDWARE_MICA2)
        interface MacControl;
        command uint8_t enableHPLPowerM();
        command result_t SetListeningMode(uint8_t power);
        command result_t SetTransmitMode(uint8_t power);
#endif

        

    }
}


implementation {
//#include "EmStar_Strings.h"
#include "PktQueue_defs.h"

#ifndef DEFAULT_MAX_RETRIES
#define DEFAULT_MAX_RETRIES         5
#endif


#define RADIO_BUSY          (1<<0)
#define USE_ACKS            (1<<1)
#define USE_ROUNDROBIN      (1<<2)


#define ADVANCE(x) x = (((x+1) >= PKTQUEUECLIENTS) ? 0 : x+1)


typedef struct _stats {
    uint32_t pkts_sent;
    uint32_t unicasts_sent;
    uint32_t broadcasts_sent;
    uint32_t pkts_retx;
    uint32_t pkts_fail_ack;
    uint32_t pkts_fail_tx;
} stats_t;

uint8_t peak_occupancy=0;
stats_t stats;

typedef struct _queued_pkt {
    TOS_Msg *pktbuf;
    int8_t status;
    int8_t retries;
    int8_t max_retries;
    int8_t padding;
} __attribute__ ((packed)) queued_pkt_t;        // 4 bytes per entry


//int8_t max_retries=MAX_RETRIES;
int8_t starting_pos=0;
int8_t serving=0;
int8_t flags=0;
queued_pkt_t queue[PKTQUEUECLIENTS];

task void trySend();
int8_t compute_peak();


command result_t StdControl.init()
{
    memset(&queue[0], 0, sizeof(queue));
    return SUCCESS;
}


command result_t StdControl.start()
{
    uint8_t lpl_mode;
    
#ifdef LPL_MODE
    lpl_mode = LPL_MODE;
#else
    lpl_mode = 0;
#endif

    call PktQueueCtrlI.use_acks();
    call PktQueueCtrlI.use_roundrobin();

    
#if defined(TOSH_HARDWARE_MICA2DOT) || defined(TOSH_HARDWARE_MICA2)
    call enableHPLPowerM();
    call SetListeningMode(lpl_mode);
    call SetTransmitMode(lpl_mode);

#endif

    return SUCCESS;
}


command result_t StdControl.stop()
{
    return SUCCESS;
}


command void PktQueueCtrlI.use_acks()
{
    flags |= USE_ACKS;
#if defined(TOSH_HARDWARE_MICA2DOT) || defined(TOSH_HARDWARE_MICA2)
    call MacControl.enableAck();
#endif
}


command void PktQueueCtrlI.dont_use_acks()
{
    flags &= ~USE_ACKS;
#if defined(TOSH_HARDWARE_MICA2DOT) || defined(TOSH_HARDWARE_MICA2)
    call MacControl.disableAck();
#endif
}


command int8_t PktQueueCtrlI.get_acks_status()
{
    return (flags & USE_ACKS);
}


command void PktQueueCtrlI.use_roundrobin()
{
    flags |= USE_ROUNDROBIN;
}


command void PktQueueCtrlI.dont_use_roundrobin()
{
    flags &= ~USE_ROUNDROBIN;
}


command int8_t PktQueueCtrlI.get_roundrobin_status()
{
    return (flags & USE_ROUNDROBIN);
}



command void PktQueueI.set_retries[uint8_t id](int8_t retries)
{
    if (id >= PKTQUEUECLIENTS) {
        dbg(DBG_ERROR, "Client id (%d) greater than max array "
                " size (%d)!\n", id, PKTQUEUECLIENTS);
        return;
    }

    queue[id].max_retries=retries;
}


command int8_t PktQueueI.get_retries[uint8_t id]()
{
    if (id >= PKTQUEUECLIENTS) {
        dbg(DBG_ERROR, "Client id (%d) greater than max array "
                " size (%d)!\n", id, PKTQUEUECLIENTS);
        return FAIL;
    }

    return queue[id].max_retries;
}


command result_t PktQueueI.Init[uint8_t id](TOS_Msg *pktbuf)
{
    // PktQueue is using UNIQUE, so we can use the id as an
    // INDEX to the array
    if (id >= PKTQUEUECLIENTS) {
        dbg(DBG_ERROR, "Client id (%d) greater than max array "
                " size (%d)!\n", id, PKTQUEUECLIENTS);
        return FAIL;
    }

    if (pktbuf == NULL)
    {
        dbg(DBG_ERROR, "Invalid pktbuf for PktQueue %d!\n", id);
        return FAIL;
    }

    // assign the packet buffer to its right place in the queue
    queue[id].pktbuf = pktbuf;
    // set status to clear
    queue[id].status = CLEAR;
    queue[id].max_retries = DEFAULT_MAX_RETRIES;

    // we're done
    return SUCCESS;
}


command TOS_Msg *PktQueueI.get_buf[uint8_t id]()
{
    if (id >= PKTQUEUECLIENTS) {
        dbg(DBG_ERROR, "Client id (%d) greater than max array "
                " size (%d)!\n", id, PKTQUEUECLIENTS);
        return NULL;
    }

    return queue[id].pktbuf;
}


command int8_t PktQueueCtrlI.get_client_id_from_buf(TOS_Msg *buf)
{
    int8_t i=0;

    for (i=0; i<PKTQUEUECLIENTS; i++) {
        if (buf == queue[i].pktbuf) {
            return i;
        }
    }

    return INVALID;
}


command int8_t PktQueueCtrlI.get_buf_status(TOS_Msg *buf)
{
    int8_t i=0;

    i = call PktQueueCtrlI.get_client_id_from_buf(buf);
    if (i == INVALID)
    {
        return INVALID;
    }
    else 
    {
        return queue[i].status;
    }
}


command int8_t PktQueueI.get_buf_status[uint8_t id]()
{
    if (id >= PKTQUEUECLIENTS) {
        dbg(DBG_ERROR, "Client id (%d) greater than max array "
                " size (%d)!\n", id, PKTQUEUECLIENTS);
        return INVALID;
    }

    return queue[id].status;
}


command result_t PktQueueI.flush[uint8_t id]()
{
    if (id >= PKTQUEUECLIENTS) {
        dbg(DBG_ERROR, "Client id (%d) greater than max array "
                " size (%d)!\n", id, PKTQUEUECLIENTS);
        return FAIL;
    }

    // set status to CLEAR
    queue[id].status = CLEAR;

    return SUCCESS;
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




command result_t PktQueueSendMsg.send[uint8_t id]
        (uint16_t address, uint8_t length, TOS_Msg *msg)
{
    int8_t i=0;
    int8_t retcode=0;
    // iterate through the client queue, try to find the client
    // that has the same pktbuf as *msg

    compute_peak();

    i = call PktQueueCtrlI.get_client_id_from_buf(msg);
    if (i == -1)
    {
        // if we reach this part, we couldn't find which client this buf
        // belonged to!
        dbg(DBG_ERROR, "Couldn't find matching client for ptr %p\n",
                msg);
        return FAIL;
    }

    // found it!
    // check client's status
    switch (queue[i].status) {
        // good cases
        case CLEAR:
        case SEND_DONE_ACK:
        case SEND_DONE_NOACK:
        case SEND_DONE_RETX_FAIL:
            // set status to SEND_PENDING
            queue[i].status = SEND_PENDING;
            // set the packet's type to be id (we need it 
            // for when we try to TX, since we will have lost
            // the parametrized iface's id then
            msg->type = id;
            // set address and length
            msg->addr = address;
            msg->length = length;
            retcode = 1;
            queue[i].retries=0;
            break;

        case SEND_FAILED:
            // send_failed is a special case, reset to CLEAR
            queue[i].status=CLEAR;
            // FALL-THROUGH to the rest

        // bad cases
        case EMPTY:
        case SEND_PENDING:
        case SEND_INPROGRESS:
        default:
            retcode = -1;
            break;
    }
    
    if (retcode == 1) {
        // we succeeded, post trysend and return success
        if (post trySend() == FAIL)
        {
            // uh oh - couldn't post a task!
            dbg(DBG_ERROR, "Couldn't post trySend task!!\n");
            return FAIL;
        }
        return SUCCESS;
    } else {
        // return fail
        return FAIL;
    }

    return FAIL;
}


result_t SendToHardware(uint8_t position)
{
    TOS_Msg *buf = queue[position].pktbuf;
    
    if ((call SerialSendMsg.send[buf->type](buf->addr,
        buf->length, buf)) != SUCCESS ) {
            // failed to send!
            dbg(DBG_ERROR, "Failed to TX packet "
                   "(id = %d, type = %d, addr = %d, length = %d, "
                   "buf = %p)\n", position,
                   buf->type, buf->addr, buf->length, buf);
            queue[position].status = SEND_FAILED;
            // signal send_done with a failure retcode
            signal PktQueueSendMsg.sendDone[position](buf, FAIL);
            stats.pkts_fail_tx++;
            flags &= ~RADIO_BUSY;
            return FAIL;

    } else {
        dbg(DBG_USR3, "Transmitting client %d's packet"
            " (dst = %d, length = %d, retries = %d, buffer %p)\n", 
            position, buf->addr, 
            buf->length,
            queue[position].retries, queue[position].pktbuf);
        // retx was successful, increment retries
        queue[position].status = SEND_INPROGRESS;
        // set RADIO_BUSY
        flags |= RADIO_BUSY;
        return SUCCESS;
        
    }

}

event result_t SerialSendMsg.sendDone[uint8_t id]
            (TOS_MsgPtr msg, result_t success)
{
    // TODO: make this smaller and use functions!
    int8_t i=0;
    // reset radio_busy flag; we'll set it again later if we have to
    flags &= ~RADIO_BUSY;
    stats.pkts_sent++;

    compute_peak();
    // iterate through the client queue, try to find the client
    // with SEND_INPROGRESS set
    for (i=0; i<PKTQUEUECLIENTS; i++) {
        if (queue[i].status == SEND_INPROGRESS) {
            TOS_Msg *buf = queue[i].pktbuf;

            dbg(DBG_USR3, "Send done found for buffer %p\n", queue[i].pktbuf);

            if (msg->addr==TOS_BCAST_ADDR) {
                stats.broadcasts_sent++;
            } else {
                stats.unicasts_sent++;
            }
            // found it!
            // check flags for use_acks
            // TODO: reorder the ifs to make it more efficient!
            if ( ((flags & USE_ACKS) == 0) ||
                (msg->addr == TOS_BCAST_ADDR)) {
                // either we are in no ack mode or 
                // this was a bcast. Either way, set status to
                // SEND_DONE_NOACK and signal
                queue[i].status = SEND_DONE_NOACK;
                signal PktQueueSendMsg.sendDone[id](msg, success);
                goto done;
            }

            if ((flags & USE_ACKS) && (msg->addr != TOS_BCAST_ADDR)) {
                int8_t n=0;
            // ack requested. check ack field
		if (msg->ack == 1) {
                    // we got an ack, set status to 
                    // send_done_ack and signal
                    queue[i].status = SEND_DONE_ACK;
                    signal PktQueueSendMsg.sendDone[id](msg, success);
                    goto done;
                }

                // ack field was 0
                // check # of retries
                if (queue[i].retries >= queue[i].max_retries) {
                    dbg(DBG_ERROR, "Max retries (%d, %d) reached for "
                            " client %d's packet, To address %d, giving up\n",
                            queue[i].retries, queue[i].max_retries, i,  buf->addr);
                    queue[i].status = SEND_DONE_RETX_FAIL;
                    signal PktQueueSendMsg.sendDone[id](msg, success);
                    stats.pkts_fail_ack++;
                    goto done;
                }

                // signal client that we are about to retx
                n = signal PktQueueI.retx_pkt[i](buf);

                if (n==DONT_RETRANSMIT) {
                    // upper layer doesn't want to retransmit, break out
                    goto done;
                }
                
                // upper layer wants to retransmit 
                // we still have retries left, try to send
                if (SendToHardware(i) == SUCCESS)
                {
                    queue[i].retries++;
                    stats.pkts_retx++;
                }

                goto done;
            }
        }
    }

    // if we reach this part, we couldn't find which client this buf
    // belonged to!
    dbg(DBG_USR3, "Couldn't find matching client for ptr %p, sent from another module?\n", msg);
    signal PktQueueSendMsg.sendDone[id](msg, FAIL);
done:
    // always post trysend on send_done to move the queue around
    // trySend doesn't post itself, so if nothing needs to go out
    // it won't loop forever in the task queue
    if ((flags & RADIO_BUSY) == 0) {
        post trySend();
    }
    // returning success always 
    // because i dont' know what the implications of FAIL
    // are...
//    call PktStats.Notify();
    return SUCCESS;
}



// our old friend, trySend, of hostmote/transceiver fame
task void trySend()
{
    int8_t i=0;
    // idx is the next slot that will be checked
    // initially it has the same value as starting_pos
    int8_t idx = starting_pos;
    // radio is busy, bug out
    if (flags & RADIO_BUSY) {
        return;
    }

    // iterate through the queue, try to find the first
    // element that needs to go out (send_pending)
    for (i=0; i<PKTQUEUECLIENTS; i++) { 
        // we check if the idx element needs to go
        // at first, the idx element points to start_pos
        if (queue[idx].status == SEND_PENDING) {
            // element found!
            // if we are using roundrobin,
            // assign starting_pos to idx, then advance the starting_pos
            // NOTE: we do this REGARDLESS of whether we successfully TXed
            // or not
#if 0
            if (flags & USE_ROUNDROBIN) {
                starting_pos = idx;
                ADVANCE(starting_pos);
            }
#endif
            
            if (SendToHardware(idx) == SUCCESS)
            {
                serving = idx;
            }

            goto done;

        } else { // not send_pending

            // ok that one didn't need to go so we advance the INDEX
            dbg(DBG_USR3, "Skipping buf %u\n", idx);
            ADVANCE(idx);
            // the idx will advance up to PKTQUEUECLIENTS, with wrapparound
        }
    }


done:
    if (flags & USE_ROUNDROBIN) {
        // advance the starting position
        ADVANCE(starting_pos);
    }
}


default event result_t PktQueueSendMsg.sendDone[uint8_t id]
    (TOS_Msg *msg, result_t success) 
{
    return SUCCESS;
}


default event int8_t PktQueueI.retx_pkt[uint8_t id](TOS_Msg *msg)
{
    return RETRANSMIT;
}

default command result_t SerialSendMsg.send[uint8_t id] 
        (uint16_t address, uint8_t length, TOS_Msg *msg)
{
    dbg(DBG_ERROR, "Default SerialSendMsg.send\n");
    return SUCCESS;
}


int8_t compute_peak()
{
    int8_t i=0;
    int8_t inst_occ=0;
    for (i=0; i<PKTQUEUECLIENTS; i++) {
        if (queue[i].status == SEND_PENDING
            || queue[i].status == SEND_INPROGRESS) {
            inst_occ++;
        }
    }

    if (inst_occ > peak_occupancy) {
        peak_occupancy = inst_occ;
    }

    return peak_occupancy;
}

}
