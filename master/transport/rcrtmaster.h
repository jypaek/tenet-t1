
#ifndef _RCRT_MASTER_H_
#define _RCRT_MASTER_H_

#include <stddef.h>
#include "sortedpacketlist.h"
#include "connectionlist.h"
#include "uint16list.h"

#define FID_LIST_LEN 5
#define RTT_EWMA_ALPHA 0.125
#define RTT_EWMA_BETA 0.25
#define CONGESTION_EWMA_ALPHA 0.5
#define CONGESTION_L_THRESH 0.2
#define CONGESTION_H_THRESH 2.0
#define R_ADDITIVE_INCREMENT 1.0
#define RCRT_INIT_RATE 0.5


struct rcrt_conn {  // rcr transport connection list entry
    connectionlist_t c;

    int state;          /* state of the connection */
    int deletePending;  /* whether connection(tid) is pending to be terminated */
    int timeoutCount;   /* feedback timeout */
    
    uint16_t lastSentAckSeqNo;  /* last cumulative-ack sequence-number sent via feedback */
    uint16_t nextAckSeqNo;      /* next cumulative-ack sequence-number that can be sent */
    uint16_t nextExpectedSeqNo; /* next expected-to-receive sequence-number */

    struct SortedPacketList plist;  /* out-of-order received packet list */

    struct uint16list missingList;  /* missing sequence number list */
    int next_nack_idx;

    uint16_t req_irate;  /* rate that the mote has requested expressed as inter-packet interval in ms */
    uint16_t cur_irate;  /* currently assigned rate for this connection expressed as inter-packet interval in ms */
    int alloc;
    
    double congestion_ewma;     /* EWMA'ed congestion level */
    
    uint16_t feedback_fid;
    uint16_t feedback_fid_list[FID_LIST_LEN];
    uint16_t feedback_fid_mote;
    unsigned long int feedback_senttime[FID_LIST_LEN];
    unsigned long int last_feedback_time;
    int feedback_idx;

    double rtt;         /* RTT estimate for only when not congested */
    double rttvar;      /* RTT mean deviation */

    unsigned int fcount;    /* number of feedback packets sent for this connection */
    unsigned int totalRetxPackets;  /* total number of packets recovered via e2e retx */
};

enum {
    RCRT_FAIR_RATIO         = 1, // r_i/d_i fair
    RCRT_FAIR_RATE          = 2, // r_i fair (without d_i)
    RCRT_FAIR_RATE_W_D      = 3, // r_i fair (with d_i limit)
    RCRT_FAIR_GOODPUT       = 4, // g_i fair
};

connectionlist_t *create_rcrt_connection(uint16_t tid, uint16_t srcAddr, uint16_t req_irate);
void delete_rcrt_connection(connectionlist_t *c);
int RCRT_Timer_start(connectionlist_t *c, unsigned long int interval_ms);
void RCRT_Timer_stop(connectionlist_t *c);
unsigned long int feedback_timeout(connectionlist_t *c);
double get_congestion_level(connectionlist_t *c);
uint16_t rate2interval(double rate);

#endif

