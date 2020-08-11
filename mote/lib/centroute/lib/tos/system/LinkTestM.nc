/* ex: set tabstop=4 expandtab shiftwidth=4 softtabstop=4: */
includes AM;
includes PktQueue;
includes CentTree;
includes LinkTest;

module LinkTestM
{
    provides {
        interface StdControl;
//        interface LinkTestI[unt8_t id];
    }

    uses {
//        interface PktQueueI as PktQ;
        interface BeaconerI as ProbeBeacon;

        interface CentTreeSendI as TreeSend;
        interface CentTreeRecvI as TreeRecv;
        interface PktQueueI as PktQ;
        interface CentTreeCtrlI;
#ifdef EMSTAR_NO_KERNEL
        interface EmTimerI as LinkTimer;
#else
        interface Timer as LinkTimer;
#endif
    }
}


implementation {
#include "CentTree_defs.h"
#include "LinkTest_defs.h"
#include "PktQueue_defs.h"
#include "PktTypes.h"

#define CLIENT_NOT_FOUND   -1

#ifndef SECOND
#define SECOND  1
#endif

#define BEACON_ERROR        -2
#define ACK_TX_FAIL         -1
#define ACK_RESENT          2
#define BEACON_STARTED      1
#define IGNORE_REQ          0

#define EINVALIDADDR        -1

#define TIMER_SECOND    1000
#define BEACONER_SECOND 1


#define DEFAULT_BEACON_PERIOD   (1*BEACONER_SECOND) // used for beaconer init
#define MAX_CONCURRENT_PROBES       4
#define PROBE_SIZE  (sizeof(lt_hdr_t) + sizeof(lt_probe_t))
#define DEFAULT_EXPIRATION_TIMER_PERIOD_SEC   1 
#define DEFAULT_EXPIRATION_TIMER_PERIOD_MSEC  (DEFAULT_EXPIRATION_TIMER_PERIOD_SEC*TIMER_SECOND)  


typedef struct _lt_state {
    uint8_t buf_busy:1;
    uint8_t timer_started:1;
    uint8_t beaconing:1;
    uint8_t ack_sent:1;
    uint8_t reserved:4;

    lt_req_t request;
    lt_report_t probe_table[MAX_CONCURRENT_PROBES];

    char beacon_buf[PROBE_SIZE];

} __attribute__ ((packed)) lt_state_t;


lt_state_t g_state = {};
TOS_Msg pktbuf;


int16_t send_lt_ack(lt_req_t *lt_req);
int8_t handle_lt_request(lt_hdr_t *hdr);
int8_t start_beaconing();
int8_t stop_beaconing();
int8_t find_node_in_table(uint16_t node_id);
int8_t find_first_empty_slot();
int8_t age_entries();
void handle_expired_entries();
int16_t send_report(int8_t idx);
void reset_table_entry(int8_t idx);




int8_t find_node_in_table(uint16_t node_id)
{
    lt_state_t *state = &g_state;
    int8_t i=0;

    for (i=0; i<MAX_CONCURRENT_PROBES; i++) {
        if (state->probe_table[i].sender == node_id) {
            return i;
        }
    }

    return -1;
}


int8_t find_first_empty_slot()
{
    lt_state_t *state = &g_state;
    int8_t i=0;

    for (i=0; i<MAX_CONCURRENT_PROBES; i++) {
        if (state->probe_table[i].sender == 0) {
            return i;
        }
    }

    return -1;
}





command result_t StdControl.init()
{
    return SUCCESS;
}


command result_t StdControl.start()
{
    call PktQ.Init(&pktbuf);
    if (call ProbeBeacon.init(PROBE_SIZE,
            DEFAULT_BEACON_PERIOD) != SUCCESS) {
        dbg(DBG_ERROR, "Probe beacon initialization failed\n");
        return FAIL;
    }

    call LinkTimer.start(TIMER_REPEAT, DEFAULT_EXPIRATION_TIMER_PERIOD_MSEC);

    return SUCCESS;
}


command result_t StdControl.stop()
{
    return SUCCESS;
}


int16_t send_lt_ack(lt_req_t *lt_req)
{
    lt_state_t *state = &g_state;
    uint8_t length = sizeof(data_hdr_t) + sizeof(lt_hdr_t) + sizeof(lt_req_t);
    char buf[length];
    int16_t n=0;
    data_hdr_t *data_hdr = (data_hdr_t *)buf;
    lt_hdr_t *lt_hdr = (lt_hdr_t *)(data_hdr->payload);

    // clear buf
    memset(buf, 0, length);

    // set hdr fields
    data_hdr->type = CR_TYPE_LINKTEST;
    data_hdr->ack_set = 0;

    lt_hdr->type = LT_ACK_REQ;
    memcpy(lt_hdr->data, lt_req, sizeof(lt_req_t));

    n = call TreeSend.send_pkt_up(&pktbuf, buf, length);

    if (n<0) {
        dbg(DBG_ERROR, "Could not send lt_ack for request # %u: %d\n", 
                lt_req->lt_seq, n);
    } else {
        if ((call CentTreeCtrlI.is_sink()) != SUCCESS) {
            state->buf_busy=1;
        }
    }

    return n;
}


int8_t start_beaconing()
{
    lt_state_t *state = &g_state;
    lt_hdr_t *lt_hdr = (lt_hdr_t *)(state->beacon_buf);
    lt_probe_t *lt_probe = (lt_probe_t *)(lt_hdr->data);

    if (state->request.probe_interval_sec==0) {
        dbg(DBG_ERROR, "Cannot send probes with interval of 0!\n");
        return BEACON_ERROR;
    }

    state->beaconing = 1;
    memset(state->beacon_buf, 0, PROBE_SIZE);
    lt_hdr->type = LT_PROBE;
    memcpy(&lt_probe->request, &state->request, sizeof(lt_req_t));

    // set the beaconer's period to match the request's period
    if (call ProbeBeacon.set_period
            (state->request.probe_interval_sec) != SUCCESS) {
        dbg(DBG_ERROR, "Could not set period to %d\n",
                state->request.probe_interval_sec);
        return BEACON_ERROR;
    }

    return BEACON_STARTED;
}


int8_t stop_beaconing()
{
    lt_state_t *state = &g_state;

    state->beaconing=0;
    memset(state->beacon_buf, 0, PROBE_SIZE);
    memset(&state->request, 0, sizeof(lt_req_t));

    return 1;
}


int8_t handle_lt_request(lt_hdr_t *hdr)
{
    lt_state_t *state = &g_state;
    lt_req_t *lt_req=(lt_req_t *)(hdr->data);

    if (state->beaconing == 0) {
        // we aren't beaconing, we can handle the request
        memcpy(&state->request, lt_req, sizeof(lt_req_t));
        if (send_lt_ack(lt_req) < 0) {
            // we couldn't send an ack!
            return ACK_TX_FAIL;
        } else {
            dbg(DBG_USR1, "Starting beaconing upon request from sink %u\n",
                    lt_req->sink);
            return start_beaconing();
        }
    } else {
        // we are already beaconing
        // if the req # is the same as the one we have in our state,
        // we ack the pkt. Otherwise we ignore it
        if (state->request.lt_seq == lt_req->lt_seq) {
            if (send_lt_ack(lt_req) < 0) {
                // we couldn't send an ack!
                return ACK_TX_FAIL;
            } else {
                dbg(DBG_USR1, "Received lt req (%u) but we are already "
                        "beaconing . Ack resent\n", lt_req->lt_seq);
                return ACK_RESENT;
            }
        } else {
            // beacons are different, we ignore this
            dbg(DBG_USR1, "Receive lt req %u but we havent"
                    " finished handling req %u. Ignoring req\n",
                    lt_req->lt_seq, state->request.lt_seq);
            return IGNORE_REQ;
        }
    }

    return IGNORE_REQ;
}



event char *TreeRecv.down_pkt_rcvd(uint16_t sender, char *data, 
        uint8_t length)
{
    data_hdr_t *data_hdr = (data_hdr_t *)data;
    lt_hdr_t *lt_hdr = (lt_hdr_t *)(data_hdr->payload);


    if (data_hdr->type != CR_TYPE_LINKTEST) {
        dbg(DBG_ERROR, "Received unsupported type %u, can only handle %u\n",
                data_hdr->type, CR_TYPE_LINKTEST);
        goto done;
    }

    dbg(DBG_USR1, "Received LINKTEST pkt from %u\n", sender);


    switch (lt_hdr->type) {

        case LT_REQUEST:
            handle_lt_request(lt_hdr);
            break;

        default:
            dbg(DBG_USR1, "Only LT_REQUEST type is handled in TreeRecv (%u)\n",
                    lt_hdr->type);
    }


done:
    return data;
}



event int8_t TreeSend.send_pkt_up_done(char *data, uint8_t type,
        uint8_t length)
{
    lt_state_t *state = &g_state;
    lt_hdr_t *hdr = (lt_hdr_t *)(data);

    state->buf_busy=0;
    memset(&pktbuf, 0, sizeof(TOS_Msg));

    if (hdr->type == LT_REPORT) {
        // call handle_expired_entries. if no entries have expired,
        // the call won't do anything (it wont repost anything)
        // 
        // however, if more entries had expired, it will send them out as
        // well, one at a time
        handle_expired_entries();
    }

    return 0;
}



event int8_t ProbeBeacon.beacon_ready(uint16_t time_remaining)
{
    lt_state_t *state = &g_state;
    lt_hdr_t *lt_hdr = (lt_hdr_t *)state->beacon_buf;
    lt_probe_t *lt_probe = (lt_probe_t *)(lt_hdr->data);

    if (time_remaining>0 || state->beaconing==0) {
        // ignore signals when it's not our time or when we aren't beaconing
        call ProbeBeacon.ignore();
        goto done;
    }


    lt_probe->current_probe++;
    if (lt_probe->current_probe > lt_probe->request.max_probes) {
        // we've reached our max probes, stop beaconing
        stop_beaconing();
        goto done;
    }

    if ((call ProbeBeacon.send((char *)lt_hdr, 0)) < 0) {
        dbg(DBG_ERROR, "Could not send beacon probe!\n");
        goto done;
    } else {
        dbg(DBG_USR1, "Sending beacon %u of %u (request=%u)\n",
                lt_probe->current_probe, lt_probe->request.max_probes,
                lt_probe->request.lt_seq);
    }

done:
    return 0;
}


event void ProbeBeacon.send_done(result_t result)
{
}


event void ProbeBeacon.receive(uint16_t src, char *data, int8_t length)
{
    lt_state_t *state = &g_state;
    lt_hdr_t *lt_hdr = (lt_hdr_t *)data;
    lt_probe_t *lt_probe = (lt_probe_t *)(lt_hdr->data);
    lt_report_t *lt_report=NULL;
    int8_t i=0;

    i = find_node_in_table(src);
    if (i<0) {
        // new mote, create entry
        i = find_first_empty_slot();
        if (i<0) {
            // table full!
            dbg(DBG_ERROR, "Cannot create new probe entry for node %u"
                    ": table full\n", src);
            return;
        }
        // i is valid, create entry
        lt_report = &state->probe_table[i];
        memcpy(&lt_report->request, &lt_probe->request, sizeof(lt_req_t));
        lt_report->sender = src;
        // expiration time is probe_interval times max_probes PLUS 2 SECONDS
        // (as a guardband)
        lt_report->expiration_time_sec =
            (lt_report->request.probe_interval_sec *
            lt_report->request.max_probes) + (2*SECOND);


    } else {    // found node
        lt_report = &state->probe_table[i];
    }

    lt_report->rcvd++;

}


int8_t age_entries()
{
    lt_state_t *state = &g_state;
    lt_report_t *lt_report=NULL;
    int8_t i=0;
    int8_t expired=0;

    for (i=0; i<MAX_CONCURRENT_PROBES; i++) {
        lt_report = &state->probe_table[i];
        if (lt_report->sender != 0) {
            lt_report->expiration_time_sec -=
                (int16_t)DEFAULT_EXPIRATION_TIMER_PERIOD_SEC;
            if (lt_report->expiration_time_sec <= 0) {
                dbg(DBG_USR1, "Entry %u expired\n", i);
                expired++;
            }
        }
    }

    return expired;
}


void handle_expired_entries()
{
    lt_state_t *state = &g_state;
    lt_report_t *lt_report=NULL;
    int8_t i=0;

    for (i=0; i<MAX_CONCURRENT_PROBES; i++) {
        lt_report = &state->probe_table[i];
        if (lt_report->sender != 0 
                && (int16_t)lt_report->expiration_time_sec <= 0) {
            if (state->buf_busy==0) {
                int16_t n=0;
                n = send_report(i);
                if (n<0) {
                    dbg(DBG_ERROR, "Could not send report for node %u: %d\n",
                            lt_report->sender, n);
                } else {
                    dbg(DBG_USR1, "Sending report for node %u\n",
                            lt_report->sender);
                    reset_table_entry(i);
                }
            }
        }
    }
}


void reset_table_entry(int8_t idx)
{
    lt_state_t *state = &g_state;
    lt_report_t *lt_report = &state->probe_table[idx];
    dbg(DBG_USR1, "Clearing entry %u\n", idx);

    memset(lt_report, 0, sizeof(lt_report_t));
}


int16_t send_report(int8_t idx)
{
    lt_state_t *state = &g_state;
    lt_report_t *lt_report = &state->probe_table[idx];
    uint8_t length = 
        sizeof(data_hdr_t) + sizeof(lt_hdr_t) + sizeof(lt_report_t);
    char buf[length];
    data_hdr_t *data_hdr = (data_hdr_t *)buf;
    lt_hdr_t *lt_hdr = (lt_hdr_t *)(data_hdr->payload);
    int16_t n=0;

    if (lt_report->sender == 0) {
        dbg(DBG_ERROR, "Cannot send report to invald address 0!\n");
        return EINVALIDADDR;
    }

    memset(buf, 0, length);

    data_hdr->type = CR_TYPE_LINKTEST;
    data_hdr->ack_set = 0;
    // set type to LT_REPORT
    lt_hdr->type = LT_REPORT;
    // set the payload to be lt_report
    memcpy(lt_hdr->data, lt_report, sizeof(lt_report_t));

    // send pkt over
    n = call TreeSend.send_pkt_up(&pktbuf, buf, length);

    if (n<0) {
        dbg(DBG_ERROR, "Could not send lt_report for node  %u: %d\n", 
                lt_report->sender, n);
    } else {
        dbg(DBG_USR1, "lt_report for node %u sent to sink\n",
                lt_report->sender);
        // unfortunately, we have to make linkstats sink-knowledgeable...
        // 
        // if we are not a sink, set buf_busy
        if ((call CentTreeCtrlI.is_sink()) != SUCCESS)  {
            state->buf_busy=1;
        }
    }

    return n;
}



event result_t LinkTimer.fired()
{
    int8_t expired=0;
    expired = age_entries();

    if (expired > 0) {
        handle_expired_entries();
    }

    return SUCCESS;
}


event int8_t PktQ.retx_pkt(TOS_Msg *msg)
{
    // always retransmit
    return RETRANSMIT;
}


}
