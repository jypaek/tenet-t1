/**
 * "Copyright (c) 2006~2008 University of Southern California.
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
 **/

/**
 * Master side code for RCRT : Rate-Controlled Reliable Transport.
 *
 * @author Jeongyeup Paek (jpaek@usc.edu)
 * Embedded Networks Laboratory, University of Southern California
 * @modified 2/1/2008
 **/

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <time.h>
#include <math.h>
#include "tosmsg.h"
#include "transport.h"
#include "routinglayer.h"
#include "rcrtransport.h"
#include "tr_seqno.h"
#include "tr_packet.h"
#include "tr_checksum.h"
#include "timeval.h"
#include "uint16list.h"

#include "rcrtmaster.h"

#define LOG_RCRT_PACKET


/* Global variables */
FILE *m_rcrt_log_fptr = NULL;       /* log file for all incoming data pkts */

struct rcrt_conn *m_rcrtcs = NULL;  /* rcrt connection list */
int m_num_rtrc = 0;                 /* number of connection state data structures allocated */

int m_N = 0;        /* number of non-finished connections */
double m_D = 0.0;   /* total requested desired rate, sum{d_i} for all i, pkts/sec */
double m_R = 0.0;   /* total allocated rate,         sum{r_i} for all i, pkts/sec */
double m_rho = 1.0;
int m_slowstart = 1;

unsigned long int last_rate_increase_time_ms = 0;   /* last time when rate was increased */
unsigned long int last_rate_decrease_time_ms = 0;   /* last time when rate was decreased */
double last_congestion_level = 0.0;                 /* cong.level when we last adjusted rate */
double last_dec_p = 1.0;
unsigned long int bootup_time_ms = 0;

int fairness_policy = RCRT_FAIR_RATIO;

enum {
    RCRT_S_ACTIVE = 13, 
    RCRT_S_NACK_WAIT = 15, 
    RCRT_S_FIN_RETX_WAIT = 18,
};


/***************************************************************************/

void rcrt_configure(int setting) {
    int fairness_setting = (setting)%10;

    fairness_policy = fairness_setting;

    printf("[RCRT] Settings: (%d)\n", fairness_policy);

    if (fairness_setting == RCRT_FAIR_RATIO)
        printf(" - FAIR_RATIO");                      // r_i/d_i fair
    else if (fairness_setting == RCRT_FAIR_RATE)
        printf(" - FAIR_RATE");                       // r_i fair (without d_i)
    else if (fairness_setting == RCRT_FAIR_RATE_W_D)
        printf(" - FAIR_RATE_W_D");                   // r_i fair (with d_i)
    else if (fairness_setting == RCRT_FAIR_GOODPUT)
        printf(" - FAIR_GOODPUT");                    // g_i fair (without d_i)
    else
        printf("[RCRT] unknown fairness policy %d\n", fairness_setting);
        
}

/***************************************************************************/

uint16_t rate2interval(double rate) {
    if ((1000.0/rate) < 65534.0)
        return (uint16_t)(1000.0/rate);
    else
        return 65534;
}

unsigned long int gettime_ms() {
    return gettimeofday_ms() - bootup_time_ms;
}

void log_rcrt_packet(connectionlist_t *c, uint16_t seqno, uint16_t used_rate, int retx, uint8_t *data) {
    struct rcrt_conn *cs = (struct rcrt_conn *)c;
    uint32_t time_ms = gettime_ms();
    uint16_t parent;
    memcpy(&parent, &data[2], sizeof(uint16_t));

    if (m_rcrt_log_fptr == NULL) {
        time_t m_time = time(NULL);
        struct tm *tt = localtime(&m_time);
        char filename[50];
        sprintf(filename,"log_rcrt.out-%02d-%02d-%02d-%02d", 
                        (tt->tm_mon+1), tt->tm_mday, tt->tm_hour, tt->tm_min);
        m_rcrt_log_fptr = fopen(filename, "w");
        //m_rcrt_log_fptr = fopen("log_rcrt.out", "w");
        fprintf(m_rcrt_log_fptr, "# time_ms tid addr seqno ");   // 1,2,3,4
        fprintf(m_rcrt_log_fptr, "retx parent fcount ");       // 5,6,7
        fprintf(m_rcrt_log_fptr, "lastRcvSeq ");               // 8
        fprintf(m_rcrt_log_fptr, "mlen plen ");                // 9 10
        fprintf(m_rcrt_log_fptr, "goodput loss_ali ");         // 11 12
        fprintf(m_rcrt_log_fptr, "cur_rate use_rate ");        // 13 14
        fprintf(m_rcrt_log_fptr, "rtt cong pktrate ");  // 15 16 17
        fprintf(m_rcrt_log_fptr, "\n");
    }

#ifdef __CYGWIN__
    fprintf(m_rcrt_log_fptr, "%lu %2d %2d %3d ", time_ms, c->tid, c->addr, seqno);
#else
    fprintf(m_rcrt_log_fptr, "%u %2d %2d %3d ", time_ms, c->tid, c->addr, seqno);
#endif
    fprintf(m_rcrt_log_fptr, "%d %2d %2d %3d %2d %2d %.3f %.3f ", 
                    retx,                   // 5
                    parent,                 // 6
                    cs->fcount,             // 7
                    c->lastRecvSeqNo,       // 8
                    cs->missingList.length, // 9
                    cs->plist.length,       // 10
                    c->goodput.Rcumm,       // 11
                    c->loss_ali.Lavg        // 12
                    );
    fprintf(m_rcrt_log_fptr, "%.3f %.3f %.1f %.2f %.3f", 
                    1000.0/cs->cur_irate, 1000.0/used_rate, // 13,14
                    cs->rtt,                                // 15
                    get_congestion_level(c),                // 16
                    c->pktrate.Ravg                         // 17
                    );
    fprintf(m_rcrt_log_fptr, "\n");
    fflush(m_rcrt_log_fptr);
}

/***************************************************************************/

double recalculate_rho() {
    if (m_D == 0.0) m_rho = 1.0;   // ?? think
    else m_rho = m_R/m_D;
    return m_rho;
}

/* calculate the total allocated rate, sum of r_i for all i */
double recalculate_R() {
    connectionlist_t *c;
    struct rcrt_conn *cs;
    double total_alloc_rate = 0.0;  /* pkts/sec */
    
    for (c = (connectionlist_t *)m_rcrtcs; c; c = c->next) {
        cs = (struct rcrt_conn *)c;
        if (cs->cur_irate != 0)
            total_alloc_rate += 1000.0/(double)cs->cur_irate;
    }
    return total_alloc_rate;
}

/***************************************************************************/

double get_congestion_level(connectionlist_t *c) {
    struct rcrt_conn *cs = (struct rcrt_conn *)c;
    return cs->congestion_ewma;
}

/**
 * Update the current and average congestion level for this connection
 * - don't count the lost packets detected just now.
 * - missing list and out-of-order packet list should have already been updated.
 **/
void update_congestion_level(connectionlist_t *c) {
    struct rcrt_conn *cs = (struct rcrt_conn *)c;
    double ll;  // L_i : list length related to level of congestion
    double cl;  // C_i : congestion level
    double rtt; // RTT : round-trip time
    double norm;

    // use (plist_len + mlist_len)_normalized as measure of congestion
    if (cs->missingList.length > 0)
        ll = (double)((cs->plist.length - 1) + (cs->missingList.length - 1));
    else
        ll = 0.0;

    // it does take some time read flash, and retransmit
    rtt = (double)cs->rtt;
    if (rtt > RCRT_FEEDBACK_TIMEOUT) rtt = RCRT_FEEDBACK_TIMEOUT;

    // normalize congestion level by (r_i * RTT) = (RTT/irate)
    norm = rtt / ((double)cs->cur_irate);
    if (norm < 0.1) norm = 0.1; // normalizer unrealistic

    cl = ll / norm;  // instantaneous cong.level

    // each timeout corresponds to increment of congestion level by 1.0
    cl += cs->timeoutCount;

    // EWMA the congestion level
    cs->congestion_ewma = CONGESTION_EWMA_ALPHA * cl + 
                        (1.0-CONGESTION_EWMA_ALPHA) * cs->congestion_ewma;
}

/***************************************************************************/

/* when sending a feedback packet, 
 * record when we sent it so that we can calculate rtt */
uint16_t update_feedback_send_info(connectionlist_t *c) {
    struct rcrt_conn *cs = (struct rcrt_conn *)c;

    cs->feedback_fid++;   // increase fid
    if (cs->feedback_fid == 0) cs->feedback_fid++;
    cs->feedback_idx++;   // increase f info idx
    if (cs->feedback_idx == FID_LIST_LEN) cs->feedback_idx = 0;
    cs->feedback_fid_list[cs->feedback_idx] = cs->feedback_fid;// record new fid
    cs->feedback_senttime[cs->feedback_idx] = gettime_ms();    // record sent time
    
    cs->last_feedback_time = cs->feedback_senttime[cs->feedback_idx];
    
    return cs->feedback_fid;
}

unsigned long int feedback_timeout(connectionlist_t *c) {
    struct rcrt_conn *cs = (struct rcrt_conn *)c;
    unsigned long int timeout;
   
    if (cs->rtt == 0.0) {
        timeout = RCRT_FEEDBACK_TIMEOUT;    /* if we don't know rtt yet*/
    } else {
        timeout = (cs->rtt + 4*cs->rttvar + 100); /* RTO: RTT + RTTVAR + small const */
    }

    return timeout;
}

/* we don't want to send feedback too often */
int is_feedback_time_ok(connectionlist_t *c) {
    struct rcrt_conn *cs = (struct rcrt_conn *)c;
    unsigned long int currtime = gettime_ms();

    // the mote has received the last feedback that master has sent
    if (cs->feedback_fid_mote == cs->feedback_fid)
        return 1;

    // must wait at least two 'feedback_timeout' time from last feedback
    if ((cs->last_feedback_time > 0) &&
        (currtime < cs->last_feedback_time + 2*feedback_timeout(c) + 2*cs->cur_irate))
        return 0;

    return 1;
}

/* we don't want to do rate adaptation too often */
int is_all_connection_update_time_ok(int inc_dec) {
    connectionlist_t *c;
    struct rcrt_conn *cs;
    unsigned long int waittime, max_waittime = 0;
    unsigned long int currtime = gettime_ms();
    unsigned long int lasttime;

    for (c = (connectionlist_t *)m_rcrtcs; c; c = c->next) {
        cs = (struct rcrt_conn *)c;

        /* wait at least (M RTO + N packet times) */
        waittime = 2*feedback_timeout(c) + 3*cs->cur_irate;

        if (!u16list_isEmpty(&cs->missingList))
            waittime += 3*feedback_timeout(c) + 2*cs->cur_irate;

        if (max_waittime < waittime)
            max_waittime = waittime;
    }

    if (inc_dec > 0) {
        lasttime = last_rate_increase_time_ms;
        if (last_rate_decrease_time_ms > last_rate_increase_time_ms)
            lasttime = last_rate_decrease_time_ms;
    } else {
        lasttime = last_rate_decrease_time_ms;
    }

    if (max_waittime > 20000) max_waittime = 20000;

    if (currtime < (lasttime + max_waittime))
        return 0;

    return 1;
}

/***************************************************************************/

/* allocate R/N to all flows (ri fair, ignore d_i) */
void allocate_R_over_N(double R) {
    connectionlist_t *c;
    struct rcrt_conn *cs;
    uint16_t prev_irate; /* inverse of previous rate, in millisec */

    if (m_N == 0)   // no active flows
        return;
    if (R == 0)     // no rate to distribute
        return;

    for (c = (connectionlist_t *)m_rcrtcs; c; c = c->next) {
        cs = (struct rcrt_conn *)c;

        /* for all active flows */
        prev_irate = cs->cur_irate;
        cs->cur_irate = rate2interval(R/(double)m_N);  /* R/N */

        if (prev_irate != cs->cur_irate) { // if the rate has changed
            #ifdef DEBUG_RCRT
            printf("[RCRT]    - node %2d: (%.3f -> %.3f)(interval %u)\n",
                    c->addr, 1000.0/prev_irate, 1000.0/cs->cur_irate, cs->cur_irate);
            #endif
        }
    }
}

/* allocate new rate for all flows by re-distributing R (ri fair with di limit) */
void distribute_R(double R) {
    connectionlist_t *c;
    struct rcrt_conn *cs;
    double aR = R;  /* remainder of R that we want to distribute */
    int aN = m_N;   /* number of active flows that needs distribution */
    double t;
    int at_least_one;
    uint16_t prev_irate; /* inverse of previous rate, in millisec */
    double d_i;

    if (aN == 0)    // no active flows
        return;

    /* clear all rate allocation... we will re-allocate everything */
    for (c = (connectionlist_t *)m_rcrtcs; c; c = c->next) {
        cs = (struct rcrt_conn *)c;
        cs->alloc = 0;
    }

    do {
        t = aR/(double)aN;
        at_least_one = 0;

        for (c = (connectionlist_t *)m_rcrtcs; c; c = c->next) {
            cs = (struct rcrt_conn *)c;
            if ((cs->req_irate == 0) ||         // d_i = infinity
                (cs->alloc != 0))           // already been allocated
                continue;

            /* for all active flows that the rate has not been allocated, */
            d_i = (1000.0/(double)cs->req_irate);

            if (d_i <= t) {  /* d_i <= t */
                prev_irate = cs->cur_irate;
                cs->cur_irate = cs->req_irate;  /* r_i = d_i */
                cs->alloc = 1;
                aR = aR - d_i;
                aN = aN - 1;
                at_least_one = 1;

                if (prev_irate != cs->cur_irate) { // if the rate has changed
                    #ifdef DEBUG_RCRT
                    printf("[RCRT]    - node %2d: (%.3f -> %.3f)(interval %u)\n",
                            c->addr, 1000.0/prev_irate, 1000.0/cs->cur_irate, cs->cur_irate);
                    #endif
                }
            }
        }
    } while (at_least_one == 1);

    if (aN > 0) {
        t = aR/(double)aN;
        for (c = (connectionlist_t *)m_rcrtcs; c; c = c->next) {
            cs = (struct rcrt_conn *)c;
            if (cs->alloc != 0)           // already been allocated
                continue;

            /* for all active flows that the rate has not been allocated, */
            prev_irate = cs->cur_irate;
            cs->cur_irate = rate2interval(t);  /* r_i = t */
            cs->alloc = 1;

            if (prev_irate != cs->cur_irate) { // if the rate has changed
                #ifdef DEBUG_RCRT
                printf("[RCRT]    - node %2d: (%.3f -> %.3f)(interval %u)\n",
                        c->addr, 1000.0/prev_irate, 1000.0/cs->cur_irate, cs->cur_irate);
                #endif
            }
        }
    }
}

/* update the new rate for all flows using rho (ri/di fair) */
void allocate_rate_by_rho(double rho) {
    connectionlist_t *c;
    struct rcrt_conn *cs;
    uint16_t prev_irate;
    double r_i, d_i;

    if (rho == 0)   // error!!
        return;
        
    /* update the new rate for all flows */
    for (c = (connectionlist_t *)m_rcrtcs; c; c = c->next) {
        cs = (struct rcrt_conn *)c;
        if (cs->req_irate == 0)           // d_i = infinity
            continue;

        prev_irate = cs->cur_irate;
        // what if req_irate == 0???
        d_i = (1000.0/(double)cs->req_irate);
        r_i = rho * d_i;
        cs->cur_irate = rate2interval(r_i);

        if (prev_irate != cs->cur_irate) { // if the rate has changed
            #ifdef DEBUG_RCRT
            printf("[RCRT]    - node %2d: (%.3f -> %.3f) (interval %u) (%lu/%lu)\n",
                    c->addr, 1000.0/prev_irate, 1000.0/cs->cur_irate, cs->cur_irate, 
                    c->totalLostPackets, c->totalRecvPackets);
            #endif
        }
    }
}

/***************************************************************************/

void append_dR_by_goodput(double dR) {
    connectionlist_t *c;
    struct rcrt_conn *cs;
    uint16_t prev_rate;
    double r_i, d_i, g_i;
    double tot_diff = 0.0;

    #ifdef DEBUG_RCRT
    printf("[RCRT]  - Append integral (dR %.3f)\n", dR);
    #endif

    for (c = (connectionlist_t *)m_rcrtcs; c; c = c->next) {
        cs = (struct rcrt_conn *)c;
        if (cs->req_irate == 0)           // d_i = infinity
            continue;

        d_i = 1000.0/(double)cs->req_irate;
        g_i = c->goodput.Rcumm;
    
        if (d_i > g_i) {
            tot_diff += (d_i - g_i);
        }
    }

    if (tot_diff == 0.0) return;

    for (c = (connectionlist_t *)m_rcrtcs; c; c = c->next) {
        cs = (struct rcrt_conn *)c;
        if (cs->req_irate == 0)           // d_i = infinity
            continue;

        prev_rate = cs->cur_irate;

        r_i = 1000.0/(double)cs->cur_irate;
        d_i = 1000.0/(double)cs->req_irate;
        g_i = c->goodput.Rcumm;
        
        if (d_i > g_i) {
            r_i += dR * ((d_i - g_i) / tot_diff);
        }
        cs->cur_irate = rate2interval(r_i);

        if (prev_rate != cs->cur_irate) {   // if the rate has changed
            #ifdef DEBUG_RCRT
            printf("[RCRT]    - node %2d: (%.3f -> %.3f)(interval %u)"
                    , c->addr, 1000.0/prev_rate, 1000.0/cs->cur_irate, cs->cur_irate);
            printf("(good %.3f)\n", c->goodput.Rcumm);
            #endif
        }
    }
}

/***************************************************************************/

void allocate_rate_fairly() {
    double prev_R = recalculate_R();

    if (fairness_policy == RCRT_FAIR_RATIO) {           // r_i/d_i fair
        /* r_i = rho*d_i */
        allocate_rate_by_rho(m_rho);
    }
    else if (fairness_policy == RCRT_FAIR_RATE) {       // r_i fair (without d_i)
        /* r_i = R/N */
        distribute_R(m_R);
    }
    else if (fairness_policy == RCRT_FAIR_RATE_W_D) {   // r_i fair (with d_i)
        /* r_i ~ R/N with d_i constraint */
        allocate_R_over_N(m_R);
    }
    else if (fairness_policy == RCRT_FAIR_GOODPUT) {
        if (m_R > prev_R)
            append_dR_by_goodput(m_R - prev_R);
        else
            //distribute_R(m_R);
            allocate_rate_by_rho(m_rho);
    }
    else { // if (fairness_policy == RCRT_FAIR_RATIO) { // r_i/d_i fair
        /* r_i = rho*d_i */
        allocate_rate_by_rho(m_rho);
    }
}

/***************************************************************************/

/* decrease the total rate R multiplicatively (rate adaptation policy) */
int decrease_all_rate(double loss_rate) {
    double prev_R = m_R;
    #ifdef DEBUG_RCRT
    double prev_rho = m_rho;
    #endif
    double p = 1.0 - loss_rate;  // delivery rate
    double dec_ratio;

    /* check the last delivery rate used */
    if (p < last_dec_p)     /* we got worse */
        p = p / last_dec_p;
    else                    /* we are improving */
        p = 1.0;            /* skip once */
    last_dec_p = p;

    /* calculate how much to decrease */
    dec_ratio = p/(2.0 - p);
    if (dec_ratio < 0.5) dec_ratio = 0.5;       /* no more than 1/2 */
    if (dec_ratio > 0.98) dec_ratio = 1.0;      /* let's not bother <2% */
    
    /* decrease rate m_R */
    m_R = dec_ratio * m_R;

    /* bound the mininum rate to be 1pkts/30sec */
    if (m_R < (m_N/30.0)) m_R = m_N/30.0;

    /* if rate decrease did not actually happen */
    if (m_R == prev_R) return 0;

    m_rho = recalculate_rho();

#ifdef DEBUG_RCRT
    printf("[RCRT]  - Decrease: R (%.3f -> %.3f)(D %.3f)(ratio %.3f -> %.3f)\n", 
            prev_R, m_R, m_D, prev_rho, m_rho);
#endif
    /* rate allocation happens after rate adaptation */
    allocate_rate_fairly();

    /* we go out of 'slowstart' period */
    m_slowstart = 0;

    /* update the last rate decrease time */
    last_rate_decrease_time_ms = gettime_ms();
    return 1;
}

/***************************************************************************/

/* increase the total rate R */
int increase_all_rate() {
    double prev_R = m_R;
    #ifdef DEBUG_RCRT
    double prev_rho = m_rho;
    #endif

    if (m_slowstart > 0) {
        m_R = m_R + 2.0*R_ADDITIVE_INCREMENT;
    } else {
        m_R = m_R + R_ADDITIVE_INCREMENT;
    }

    if ((m_R > m_D) && (m_D > 0))
        m_R = m_D;

    m_rho = recalculate_rho();

    /* rate increase did not actually happen */
    if (m_R == prev_R) return 0;

#ifdef DEBUG_RCRT
    printf("[RCRT]  - Increase: R (%.3f -> %.3f) (D %.3f)(rho %.3f -> %.3f)\n", 
            prev_R, m_R, m_D, prev_rho, m_rho);
#endif
    /* rate allocation happens after rate adaptation */
    allocate_rate_fairly();

    /* reset last decrease ratio M(t) */
    last_dec_p = 1.0;

    /* update the last rate increase time */
    last_rate_increase_time_ms = gettime_ms();
    return 1;
}

/***************************************************************************/

/**
 * Can we increase the rate?
 * - YES, if all connections are under utilized.
 * -  NO, if any connection is near being congested.
 **/
int is_all_connection_increasable() {
    connectionlist_t *c;
    struct rcrt_conn *cs;
    
    for (c = (connectionlist_t *)m_rcrtcs; c; c = c->next) {
        cs = (struct rcrt_conn *)c;

        if (get_congestion_level(c) >= CONGESTION_L_THRESH)
            return 0;   // no
        if (cs->missingList.length > 1) // more than 2 losses
            return 0;
    }
    return 1;           // yes
}

int number_of_congested_flows() {
    connectionlist_t *c;
    struct rcrt_conn *cs;
    int result = 0;

    for (c = (connectionlist_t *)m_rcrtcs; c; c = c->next) {
        cs = (struct rcrt_conn *)c;
        if (get_congestion_level(c) >= CONGESTION_L_THRESH)
            result++;
    }
    return result;
}

/**
 * Should we decrease the rate?
 * - YES, if this connection is congested && 
 *   cong.level has increased since last rate adaptation
 **/
int congestion_should_decrease_rate(connectionlist_t *c) {
    struct rcrt_conn *cs = (struct rcrt_conn *)c;
        
    if ((!u16list_isEmpty(&cs->missingList)) &&                 /* there are missing packets */
        (get_congestion_level(c) >= CONGESTION_H_THRESH) &&     /* congesion level is high */
        (get_congestion_level(c) > last_congestion_level)) {    /* higher than before */
        return 1;
    }
    return 0;
}

/***************************************************************************/

int do_rate_control(connectionlist_t *c, uint16_t used_irate) {
    struct rcrt_conn *cs = (struct rcrt_conn *)c;

    /* change rate only if previous rate allocation was applied */
    if (used_irate != cs->cur_irate)
        return 0;

    /* decrease rate ? */
    if (is_all_connection_update_time_ok(-1) &&     /* recently updated already ? */
        congestion_should_decrease_rate(c)) {       /* congested */
        #ifdef DEBUG_RCRT
        printf("[RCRT]  node %2d: cong.level(%.2f) > H_THRESH, should decrease (loss %.3f)\n",
                    c->addr, get_congestion_level(c), c->loss_ali.Lavg);
        #endif

        if (decrease_all_rate(c->loss_ali.Lavg)) {  /* decrease the rate of every flow */
            last_congestion_level = get_congestion_level(c);
            return -1;
        }
    }
    /* increase rate ? */
    else if (is_all_connection_update_time_ok(1) && /* recently updated already ? */
        is_all_connection_increasable()) {          /* all nodes non-congested? */

        if (increase_all_rate()) {                  /* increase the rate of every flow */
            last_congestion_level = 0.0;
            return 1;
        }
    }
    
    return 0;
}

/***************************************************************************/

void r_send_SYN_ACK(connectionlist_t *c) {
    struct rcrt_conn *cs = (struct rcrt_conn *)c;
    int len = offsetof(TransportMsg, data) + offsetof(rcrt_feedback_t, nacklist);
    unsigned char *packet = (unsigned char *) malloc(len);
    TransportMsg *tmsg = (TransportMsg *) packet;
    rcrt_feedback_t *fb = (rcrt_feedback_t *) tr_packet_getPayload(tmsg);
    
    fb->rate = cs->cur_irate;
    fb->rtt = RCRT_FEEDBACK_TIMEOUT;
    fb->cack_seqno = 0;
    fb->fid = update_feedback_send_info(c);   // SYN_ACK is a feedback
    fb->nack_len = 0;

    tr_packet_setHeader(tmsg, c->tid, 0, RCRT_FLAG_SYN_ACK, 0);
    // set checksum after setting header and copying payload
    tmsg->checksum = tr_calculate_checksum(tmsg, offsetof(rcrt_feedback_t, nacklist));
    
    #ifdef DEBUG_RCRT2
        printf("[RCRT] send_SYN_ACK: (tid %d, node %2d)(fid %d) \n", c->tid, c->addr, fb->fid);
    #endif
    write_routing_msg(packet, len, PROTOCOL_RCR_TRANSPORT, c->addr, RT_DEFAULT_TTL);
    free((void *) packet);
}

void r_send_SYN_NACK(uint16_t tid, uint16_t addr) {
    int len = offsetof(TransportMsg, data);
    unsigned char *packet = (unsigned char *) malloc(len);
    TransportMsg *tmsg = (TransportMsg *) packet;

    tr_packet_setHeader(tmsg, tid, 0, RCRT_FLAG_SYN_NACK, 0);
    // set checksum after setting header and copying payload
    tmsg->checksum = tr_calculate_checksum(tmsg, 0);
    
    #ifdef DEBUG_RCRT2
        printf("[RCRT] Reject connection: send_SYN_NACK: (tid %d, node %2d)\n", tid, addr);
    #endif
    write_routing_msg(packet, len, PROTOCOL_RCR_TRANSPORT, addr, RT_DEFAULT_TTL);
    free((void *) packet);
}

void _r_send_FIN_ACK(uint16_t tid, uint16_t addr, uint16_t seqno) {
    int len = offsetof(TransportMsg, data);
    unsigned char *packet = (unsigned char *) malloc(len);
    TransportMsg *tmsg = (TransportMsg *) packet;

    tr_packet_setHeader(tmsg, tid, seqno, RCRT_FLAG_FIN_ACK, 0);
    // set checksum after setting header and copying payload
    tmsg->checksum = tr_calculate_checksum(tmsg, 0);

    #ifdef DEBUG_RCRT2
        printf("[RCRT] send_FIN_ACK: (tid %d, node %2d) \n", tid, addr);
    #endif
    write_routing_msg(packet, len, PROTOCOL_RCR_TRANSPORT, addr, RT_DEFAULT_TTL);
    free((void *) packet);
}

void r_send_FIN_ACK(connectionlist_t *c) {
    _r_send_FIN_ACK(c->tid, c->addr, c->lastRecvSeqNo);
}

/***************************************************************************/

int send_FEEDBACK(connectionlist_t *c, int r) {
    struct rcrt_conn *cs = (struct rcrt_conn *)c;
    int paylen = offsetof(rcrt_feedback_t, nacklist) + (RCRT_NACK_MLIST_LEN * sizeof(uint16_t));
    int len = paylen + offsetof(TransportMsg, data);
    unsigned char *packet = (unsigned char *) malloc(len);
    TransportMsg *tmsg = (TransportMsg *) packet; 
    unsigned char *payload = tr_packet_getPayload(tmsg);
    rcrt_feedback_t *fb = (rcrt_feedback_t *) payload;
    int i = 0, nack_cnt = 0, j = 0;
    uint16_t mitem, voidSeq;

    fb->rate = cs->cur_irate;
    if (cs->rtt == 0.0) fb->rtt = RCRT_FEEDBACK_TIMEOUT;
    else fb->rtt = (uint16_t)cs->rtt;
    fb->cack_seqno = cs->nextAckSeqNo;
    fb->fid = update_feedback_send_info(c);
   
    cs->fcount++;

    #ifdef DEBUG_RCRT
        printf("[RCRT] send FEEDBACK(%d): (tid %d, node %2d, seqno %2d) ", r, c->tid, c->addr, c->lastRecvSeqNo);
        printf("[RATE] %u ", fb->rate);
        printf("[CACK] %d ", cs->nextAckSeqNo);
    #endif
    for (i = 0; i < RCRT_NACK_MLIST_LEN; i++) {
        if (i < cs->missingList.length) {
            if (cs->missingList.length <= 1) j = i + 1;
            else j = i + 1;
            //else j = ((cs->next_nack_idx + i) % cs->missingList.length) + 1;
            mitem = (uint16_t)u16list_get_ith(&cs->missingList, j);
            if (tr_seqno_cmp(c->lastRecvSeqNo, tr_seqno_add(mitem, TR_VALID_RANGE)) >= 0) {
                voidSeq = u16list_delete(&cs->missingList, mitem);
                i--;
                continue;
            }
            #ifdef DEBUG_RCRT
                if (i == 0) printf("[NACK] ");
                printf("%d ", mitem);
            #endif
            fb->nacklist[i] = mitem;
            nack_cnt++;
        } else {
            fb->nacklist[i] = 0;
        }
    }
    #ifdef DEBUG_RCRT
        printf("[FID] %d ", fb->fid);
        printf("(rtt %u, cong %.2f, #missing %d, loss %.2f)\n", 
                    fb->rtt, get_congestion_level(c),
                    u16list_getLength(&cs->missingList), c->loss_ali.Lavg);
        fflush(stdout);
    #endif

    if (cs->missingList.length <= 1) cs->next_nack_idx = 0;
    else cs->next_nack_idx = (cs->next_nack_idx + nack_cnt) % cs->missingList.length;
    fb->nack_len = nack_cnt;

    paylen = offsetof(rcrt_feedback_t, nacklist) + (nack_cnt * sizeof(uint16_t));
    len = paylen + offsetof(TransportMsg, data);
    
    tr_packet_setHeader(tmsg, c->tid, c->lastRecvSeqNo, RCRT_FLAG_FEEDBACK, 0);
    // set checksum after setting header and copying payload
    tmsg->checksum = tr_calculate_checksum(tmsg, paylen);
    
    write_routing_msg(packet, len, PROTOCOL_RCR_TRANSPORT, c->addr, RT_DEFAULT_TTL);
    
    cs->lastSentAckSeqNo = cs->nextAckSeqNo;
    
    free((void *)packet);   // free RCR packet
    return 1;
}

/***************************************************************************/

int r_detectMissingPacket(connectionlist_t *c, uint16_t seqno) {
    struct rcrt_conn *cs = (struct rcrt_conn *)c;
    int detected = 0;
    uint16_t lastSeqNo = c->lastRecvSeqNo;

    if (tr_seqno_cmp(seqno, tr_seqno_next(lastSeqNo)) > 0) {
        #ifdef DEBUG_RCRT
            printf("[RCRT]  - Missing pkt detected, node %2d, recv_seqno %d, last %d: ", 
                          c->addr, seqno, lastSeqNo);
        #endif
        do {
            lastSeqNo = tr_seqno_next(lastSeqNo);
            #ifdef DEBUG_RCRT
                printf(" %d", lastSeqNo);
            #endif
            u16list_insert(&cs->missingList, lastSeqNo);
            c->totalLostPackets++;
            detected++;
        } while (tr_seqno_cmp(seqno, tr_seqno_next(lastSeqNo)) > 0);
        #ifdef DEBUG_RCRT
            printf(" (total lost till now %lu, while recv'ed %lu)\n", 
                    c->totalLostPackets, c->totalRecvPackets);
        #endif
        fflush(stdout);
    }
    return detected;
}

/***************************************************************************
 * Received packet at the master-side of a rcr connection.
 * Forward it to the application layer.
 **/

void receive_rtr_msg(connectionlist_t *c, uint16_t seqno, int len, unsigned char *msg) {
    struct rcrt_conn *cs = (struct rcrt_conn *)c;
    unsigned char *packet = (unsigned char *) malloc(len);
    unsigned char *ptr;
    uint16_t tid = c->tid;
    uint16_t srcAddr = c->addr;

    #ifdef DEBUG_RCRT4
        printf("-->receive_rtr_msg: len %d, tid %d, addr %d, seq=%d\n",
                   len, tid, srcAddr, seqno);
    #endif

    memcpy(packet, msg, len);   // copy so that we can put it in the queue

    // we will put it in the sorted list here................
    if (tr_seqno_cmp(seqno, cs->nextExpectedSeqNo) == 0) {
        receive_rcrtransport(tid, srcAddr, len, packet);    // pass it to app.
        cs->nextAckSeqNo = seqno;
        cs->nextExpectedSeqNo = tr_seqno_next(cs->nextExpectedSeqNo); // seqno is [1 ~ MAX], not [0 ~ MAX-1]
        free((void *)packet);
    } else if (tr_seqno_cmp(seqno, cs->nextExpectedSeqNo) < 0) {
        #ifdef DEBUG_RCRT4
            printf("  ->unexpected: seqno %d (tid %d, addr %d): expect %d, drop\n",
                          seqno, tid, srcAddr, cs->nextExpectedSeqNo);
        #endif
        free((void *)packet);
    } else { // cannot dispatch yet since out-of-order (or missing) packets exist
        if (SPList_find(&cs->plist, seqno) < 0) {
            SPList_insert(&cs->plist, seqno, packet, len);
            #ifdef DEBUG_RCRT4
                printf("  ->inserting: seqno %d (tid %d, addr %d): \n",seqno, tid, srcAddr);
            #endif
        } else {
            #ifdef DEBUG_RCRT4
                printf("  ->duplicate: seqno %d (tid %d, addr %d): \n",seqno, tid, srcAddr);
            #endif
            free((void *)packet);
        }
    }
    while (1) {
        int first, seq;
        first = SPList_getFirstValue(&cs->plist);    // seqno of head of queue
        if (first == -1) {
            break;
        } else if (tr_seqno_cmp(first, cs->nextExpectedSeqNo) == 0) { // next pkt to dispatch
            ptr = SPList_deleteFirstPacket(&cs->plist, &seq, &len);
            #ifdef DEBUG_RCRT4
                printf("  ->deleting: seqno %d (tid %d, addr %d)\n", first, tid, srcAddr);
            #endif
            receive_rcrtransport(tid, srcAddr, len, ptr);
            cs->nextAckSeqNo = first;
            cs->nextExpectedSeqNo = tr_seqno_next(cs->nextExpectedSeqNo);
            free((void *) ptr);
        } else if (tr_seqno_cmp(first, cs->nextExpectedSeqNo) < 0) { // something in the past
            ptr = SPList_deleteFirstPacket(&cs->plist, &seq, &len);
            #ifdef DEBUG_RCRT4
                printf("  ->dropping: seqno %d (tid %d, addr %d)\n", first, tid, srcAddr);
            #endif
            free((void *) ptr);
        } else if (tr_seqno_cmp(seqno, first) <= 0) {
            break;
        } else if (tr_seqno_cmp(seqno, tr_seqno_add(first, TR_VALID_RANGE)) >= 0) {
            ptr = SPList_deleteFirstPacket(&cs->plist, &seq, &len);
            #if defined(DEBUG_RCRT4) || defined(DEBUG_RCRT2)
                printf("  ->forced deleting: seqno %d (tid %d, addr %d) last %d\n", first, tid, srcAddr, seqno);
            #endif
            receive_rcrtransport(tid, srcAddr, len, ptr);
            cs->nextAckSeqNo = seqno;
            cs->nextExpectedSeqNo = tr_seqno_next(first);
            free((void *) ptr);
        } else {
            /* still out-of-order.... let's wait more */
            break;
        }
    }
}

/***************************************************************************/

double abs_d(double a) {
    if (a > 0.0) return a;
    return -1 * a;
}

void update_rtt_estimate(connectionlist_t *c, uint32_t interval_ms, uint16_t fid) {
    struct rcrt_conn *cs = (struct rcrt_conn *)c;
    uint32_t curr_time_ms = gettime_ms();
    uint32_t time_diff = 0, rtt_est_ms = 0;
    int i;

    for (i = 0; i < FID_LIST_LEN; i++) {
        if ((cs->feedback_senttime[i] != 0) && (cs->feedback_fid_list[i] != 0) &&
            (fid == cs->feedback_fid_list[i])) {
            time_diff = curr_time_ms - cs->feedback_senttime[i];
            if ((interval_ms == 0) || (interval_ms > time_diff)) {
                cs->feedback_fid_list[i] = 0;
                cs->feedback_senttime[i] = 0;     // clear record ?
            #ifdef DEBUG_RTT
                printf("[RCRT] - cannot est.RTT (node %2d): %.1f ms (var %.1f, fid %d, intval %u, diff %d)\n", 
                        c->addr, cs->rtt, cs->rttvar, fid, interval_ms, time_diff);
            #endif
                return;
            }
            rtt_est_ms = time_diff - interval_ms;
            
            // if fid is newer than last fid that mote knows
            if ((fid > cs->feedback_fid_mote) && (fid - cs->feedback_fid_mote < 20))
                cs->feedback_fid_mote = fid;
            break;
        }
    }
    if (i == FID_LIST_LEN)
        return;

    if (rtt_est_ms > 30000) {   // impossible. motetime must've wrapped around. discard.
    #ifdef DEBUG_RCRT
    #ifdef __CYGWIN__
        printf("[RCRT]  - too large RTT (node %2d): %lu ms (avg %.1f)(fid %d, interval %lu, diff %lu)\n", 
                c->addr, rtt_est_ms, cs->rtt, fid, interval_ms, time_diff);
    #else
        printf("[RCRT]  - too large RTT (node %2d): %u ms (avg %.1f)(fid %d, interval %u, diff %d)\n", 
                c->addr, rtt_est_ms, cs->rtt, fid, interval_ms, time_diff);
    #endif
    #endif
        return;
    }

    if (cs->rtt == 0.0) {
        cs->rtt = (double)rtt_est_ms;
        cs->rttvar = 0.0;
    } else {
        if (number_of_congested_flows() == 0) {
            cs->rtt = RTT_EWMA_ALPHA*(double)rtt_est_ms + (1.0-RTT_EWMA_ALPHA)*cs->rtt;
            cs->rttvar = RTT_EWMA_BETA*abs_d((double)rtt_est_ms - cs->rtt) + (1.0-RTT_EWMA_BETA)*cs->rttvar;
        }
    }
    #ifdef DEBUG_RTT
        printf("[RCRT] - est.RTT (node %2d): %.1f ms (var %.1f, fid %d, interval %u, diff %d)\n", 
                 c->addr, cs->rtt, cs->rttvar, fid, interval_ms, time_diff);
    #endif
}

/***************************************************************************/

void rcrtransport_receive(int len, unsigned char *packet, uint16_t srcAddr) {
    TransportMsg *tmsg = (TransportMsg *) packet;
    rcrt_msg_t *rmsg = (rcrt_msg_t *) tr_packet_getPayload(tmsg);
    connectionlist_t *c;
    struct rcrt_conn *cs;
    uint16_t voidSeq, seqno, tid;
    uint8_t flag;
    int missingCnt = 0;
    int newpkt = 0;
    int rate_control = 0;
    int send_feedback = 0, reason = 0;

    if (packet == NULL) return;
    len =  len - (offsetof(TransportMsg, data));
    if (len < 0) return;
    if (tr_checksum_check(tmsg, len) < 0) {
        printf("[RCRT] invalid checksum: ");
        fdump_packet(stdout, packet, len);
        return;
    }

    seqno = tr_packet_getSeqno(tmsg);
    tid = tr_packet_getTid(tmsg);
    flag = tr_packet_getFlag(tmsg);
    c = find_connection((connectionlist_t **)&m_rcrtcs, tid, srcAddr);
    cs = (struct rcrt_conn *)c;

    switch (flag) {

        case (RCRT_FLAG_SYN):            /** SYN received **/
            if (c == NULL) {
                #ifdef DEBUG_RCRT
                    printf("[RCRT] SYN recv'ed (tid %d, node %2d)\n", tid, srcAddr);
                #endif
                /* create new rcrt connection */
                c = create_rcrt_connection(tid, srcAddr, rmsg->rate);
                if (c == NULL) {
                    r_send_SYN_NACK(tid, srcAddr);
                    return;
                }
            } // else Duplicate SYN received...
            r_send_SYN_ACK(c);
            break;

        case (RCRT_FLAG_FIN):            /** FIN received **/
            #ifdef DEBUG_RCRT
                printf("[RCRT] FIN recv'ed (tid %d, node %2d, seqno %2d)\n", tid, srcAddr, seqno);
            #endif
            if (c == NULL) {    // even if we don't know about this connection,
                _r_send_FIN_ACK(tid, srcAddr, seqno);   // send an ACK
                return;
            }

            if (tr_seqno_cmp(seqno, c->lastRecvSeqNo) > 0) {
                // any newly detected missing packets?
                missingCnt = r_detectMissingPacket(c, seqno);
                c->lastRecvSeqNo = seqno;
            }

            if (u16list_isEmpty(&cs->missingList)) {  
                // no missing packets, so schedule to send FIN ACK
                r_send_FIN_ACK(c);
                delete_rcrt_connection(c);
            } else {
                /* missing packets left... must recover */
                if (cs->state != RCRT_S_FIN_RETX_WAIT) {
                    cs->state = RCRT_S_FIN_RETX_WAIT;
                    cs->timeoutCount = 0;
                }
                send_FEEDBACK(c, 7);
                RCRT_Timer_start(c, feedback_timeout(c));
            }
            break;

        case (RCRT_FLAG_DATA):        /** DATA packet received **/
        case (RCRT_FLAG_DATA | RCRT_FLAG_ACK_REQ):
        case (RCRT_FLAG_DATA_RETX):   /** Retransmitted packet received **/
        case (RCRT_FLAG_DATA_RETX | RCRT_FLAG_ACK_REQ):
            if (c == NULL) {
            #ifdef DEBUG_RCRT
                printf("[RCRT] Data recved but c==NULL (tid %d, node %2d, seqno %2d, fid %2d)\n", tid, srcAddr, seqno, rmsg->fid);
            #endif
                return;
            }
 
            if ((tr_seqno_cmp(seqno, c->lastRecvSeqNo) > 0) &&
                (tr_seqno_diff(seqno, c->lastRecvSeqNo) > 100)) {
            #ifdef DEBUG_RCRT
                printf("[RCRT]  - Something is wrong, debug, node %2d, recv_seqno %d, last %d\n", 
                        c->addr, seqno, c->lastRecvSeqNo);
            #endif
                return;
            }

            /* is it a new unique packet ? */
            if ((tr_seqno_cmp(seqno, cs->nextExpectedSeqNo) >= 0) &&    
                /* if newer than what I already got AND */
                (SPList_find(&cs->plist, seqno) < 0)) {
                /* if not in the packet list yet */
                newpkt = 1;
                c->totalRecvPackets++;
            }
            
        #ifdef DEBUG_RCRT2
            if (newpkt) {
                if (flag & RCRT_FLAG_RETX)
                    printf("[RCRT] Retx'ed pkt recved ");
                else
                    printf("[RCRT] New pkt recved     ");
            } else {
                if ((tr_seqno_cmp(seqno, cs->lastSentAckSeqNo) <= 0) && (seqno != c->lastRecvSeqNo))
                    printf("[RCRT] Old Dup pkt recved ");
                else
                    printf("[RCRT] Dup pkt recved     ");
            }
            printf("(tid %d, node %2d, seqno %2d, fid %2d)", tid, srcAddr, seqno, rmsg->fid);
            if (!newpkt)
                printf("(lastAckd %2d nextExpt %2d last %2d)", 
                        cs->lastSentAckSeqNo, cs->nextExpectedSeqNo, c->lastRecvSeqNo);
            if (flag & RCRT_FLAG_ACK_REQ) printf("+\n");
            else printf("\n");
        #endif

            /* if retransmitted packet, delete from missing list */
            if (flag & RCRT_FLAG_RETX) {
                voidSeq = u16list_delete(&cs->missingList, seqno);
            } else if (tr_seqno_cmp(seqno, c->lastRecvSeqNo) < 0) {
                voidSeq = u16list_delete(&cs->missingList, seqno);
            }

            /* for every packet newer than the newest packet */
            if (tr_seqno_cmp(seqno, c->lastRecvSeqNo) > 0) {
                missingCnt = r_detectMissingPacket(c, seqno);
                update_estimated_rate(c, missingCnt+1);
                update_connection_lossrate(c, seqno);   /* loss rate calculation does not include retx */
                c->lastRecvSeqNo = seqno;
            }

            /* for every unique packet, */
            if (newpkt) {
                /* reset timeout count since we got something */
                cs->timeoutCount = 0;

                /* update rtt  */
                update_rtt_estimate(c, rmsg->interval, rmsg->fid);

                /* dispatch(forward) to the application layer */
                len =  len - (offsetof(rcrt_msg_t, data));
                receive_rtr_msg(c, seqno, len, rmsg->data);

                /* update information */
                update_connection_goodput(c); /* update goodput */
                
                /* for new packet recovered via e2e retx */
                if (flag & RCRT_FLAG_RETX) {
                    cs->totalRetxPackets++;
                }
            
                /* update congestion ewma level */
                update_congestion_level(c);
            
                /* for new (non-retx) pkt */
                if (!(flag & RCRT_FLAG_RETX)) {
                    /* do rate control here */
                    rate_control = do_rate_control(c, rmsg->rate);
                }

                /* log packet for debugging */
                #ifdef LOG_RCRT_PACKET
                if (flag & RCRT_FLAG_RETX)  /* if retransmitted packet */
                    log_rcrt_packet(c, seqno, rmsg->rate, 1, rmsg->data);
                else
                    log_rcrt_packet(c, seqno, rmsg->rate, 0, rmsg->data);
                #endif
            }

            /* send feedback if..... */
            if (missingCnt > 0) {
                /* there are new lost packets, or */
                send_feedback = 1;
                reason = 1;
            } else if (rate_control < 0) {
                /* decrease rate triggered by this flow */
                send_feedback = 1;
                reason = 2;
            } else if (is_feedback_time_ok(c)) {
                if (tr_seqno_cmp(seqno, cs->lastSentAckSeqNo) <= 0) {
                    /* received a duplicate packet that I've already acked */
                    send_feedback = 1;
                    reason = 3;
                } else {
                #ifdef __CYGWIN__
                    if (cs->cur_irate != rmsg->rate) {
                #else
                    if ((cs->cur_irate != rmsg->rate) && (drand48() > 0.5)) {
                #endif
                        /* mote is using different rate.. */
                        send_feedback = 1;
                        reason = 4;
                #ifdef __CYGWIN__
                    } else if (flag & RCRT_FLAG_ACK_REQ) {
                #else
                    } else if ((flag & RCRT_FLAG_ACK_REQ) && (drand48() > 0.5)) {
                #endif
                        /* ack was explicitely requested */
                        send_feedback = 1;
                        reason = 5;
                    }
                } 
            }

            /* check state and set timeout..... */
            if (u16list_isEmpty(&cs->missingList)) {
                /* is the missing list empty yet? */

                if (cs->state == RCRT_S_FIN_RETX_WAIT) {
                    /* All missing pkts recved after FIN, scheduling FIN ACK */
                    r_send_FIN_ACK(c);
                    delete_rcrt_connection(c);
                    send_feedback = 0; // don't need to send FEEDBACK
                    break;
                }
                else if (cs->state == RCRT_S_NACK_WAIT) {
                    /* get out of RCRT_S_NACK_WAIT state */
                    cs->state = RCRT_S_ACTIVE;
                }
            } else {
                if (cs->state == RCRT_S_ACTIVE) {
                    /* there are new lost packets*/
                    /* get in to RCRT_S_NACK_WAIT state */
                    cs->state = RCRT_S_NACK_WAIT;
                }
            }

            if (send_feedback == 1) {
                send_FEEDBACK(c, reason);
                if (c->alarm_time.tv_sec == 0)  // if no timer running,
                    RCRT_Timer_start(c, feedback_timeout(c));
            }
            break;

        default:
            #ifdef DEBUG_RCRT
                printf("[RCRT] packet with unidentified flag received\n");
                fdump_packet(stdout, packet, len);
            #endif
            break;
    }// End of switch
    return;
}

 
/********************************************************
 * Timer functions for each connections
 ********************************************************/
int RCRT_Timer_start(connectionlist_t *c, unsigned long int interval_ms) {
    struct timeval curr;
    if (c == NULL) return 0;
    gettimeofday(&curr, NULL);
    add_ms_to_timeval(&curr, interval_ms, &c->alarm_time);
    return 1;
}

void RCRT_Timer_stop(connectionlist_t *c) {
    if (c == NULL) return;
    clear_timeval(&c->alarm_time);
    return;
}

int RCRT_Timer_fired(int user_id) {
    connectionlist_t *c = (connectionlist_t *)user_id;
    struct rcrt_conn *cs = (struct rcrt_conn *)c;

    RCRT_Timer_stop(c);

    if ((cs->state == RCRT_S_NACK_WAIT) || (cs->state == RCRT_S_FIN_RETX_WAIT)) {
        /* timeout occured while there are unrecovered missing packets */
        cs->timeoutCount++;

        #ifdef DEBUG_RCRT
            printf("[RCRT] Timeout: (tid %d, node %2d)(timeoutCnt %d)", c->tid, c->addr, cs->timeoutCount);
            if (cs->state == RCRT_S_NACK_WAIT) printf(" NACK_WAIT\n");
            if (cs->state == RCRT_S_FIN_RETX_WAIT) printf(" FIN_RETX_WAIT\n");
        #endif

        if (cs->deletePending) {
            if (cs->timeoutCount >= RCRT_MAX_ALIVE_TIMEOUT) {
            #ifdef DEBUG_RCRT
                printf("[RCRT] CONNECTION Timeout2: (tid %d, node %2d) Terminating.\n", c->tid, c->addr);
            #endif
                delete_rcrt_connection(c);
            } else {
                RCRT_Timer_start(c, RCRT_CONNECTION_TIMEOUT);
            }
            return user_id;
        }

        /* update congestion ewma level */
        update_congestion_level(c);

        if (cs->timeoutCount >= 2) {
            /* decrease rate ? */
            if (is_all_connection_update_time_ok(-1) &&     /* recently updated already ? */
                    congestion_should_decrease_rate(c)) {   /* congested */
            #ifdef DEBUG_RCRT
                printf("[RCRT]  node %2d: cong.level(%.2f) > H_THRESH, should decrease (loss %.3f)\n",
                        c->addr, get_congestion_level(c), c->loss_ali.Lavg);
            #endif
                
                /* decrease the rate of all flows */
                if (decrease_all_rate(c->loss_ali.Lavg)) {
                    last_congestion_level = get_congestion_level(c);
                }
                cs->timeoutCount = 0;
            }
        }

        send_FEEDBACK(c, 8);
        RCRT_Timer_start(c, feedback_timeout(c));
    }
    else if (cs->state == RCRT_S_ACTIVE) {
        if (cs->deletePending) {
            cs->timeoutCount++;
            if (cs->timeoutCount >= RCRT_MAX_ALIVE_TIMEOUT) {
            #ifdef DEBUG_RCRT
                printf("[RCRT] CONNECTION Timeout: (tid %d, node %2d) Terminating.\n", c->tid, c->addr);
            #endif
                delete_rcrt_connection(c);
            }
            if (c->totalRecvPackets == 0) {
            #ifdef DEBUG_RCRT
                printf("[RCRT] This must be a dead connection (tid %d, node %2d) Terminating.\n", c->tid, c->addr);
            #endif
                delete_rcrt_connection(c);
            }
            RCRT_Timer_start(c, RCRT_CONNECTION_TIMEOUT);
        }
    }
    return user_id;
}

void polling_rcrtransport_timer() {
    connectionlist_t *c;
    struct timeval curr;
    gettimeofday(&curr, NULL);

    for (c = (connectionlist_t *)m_rcrtcs; c; c = c->next) {
        if ((c->alarm_time.tv_sec > 0)
                && (compare_timeval(&c->alarm_time, &curr) <= 0)) {
            RCRT_Timer_fired((int)c);
            break;
        }
    }
}

/********************************************************/
/**  rcrt_conn (RCRT connection) functions  **************/
/********************************************************/

void print_all_rtrc() {
#ifdef DEBUG_RCRT
    printf("[rcrt_conn %d] %d\n", m_num_rtrc, m_N);
    print_all_connections((connectionlist_t **)&m_rcrtcs);
    fflush(stdout);
#endif
}

void adjust_rates_at_node_join(struct rcrt_conn *cs) {

    /* if we are at the beginning, increase m_R by small value.
     * otherwise, do not increase m_R */
    if ((m_R == 0.0) || (m_N == 0) || (m_slowstart && (m_R <= 25.0))) {
        if (cs->req_irate < (1000/RCRT_INIT_RATE)) {
            m_R = m_R + RCRT_INIT_RATE;
        } else {
            m_R = m_R + (double)1000.0/(double)cs->req_irate;
        }
    }
    
    /* increase the total requested desired rate D */
    if (cs->req_irate != 0)
        m_D = m_D + (double)1000.0/(double)cs->req_irate;
        
    /* re-calculate rho, given correct m_R and m_D */
    m_rho = recalculate_rho();

    /* increase the number of active flows */
    m_N++;

    /* re-allocate the rate to all flows */
    allocate_rate_fairly();

    /* set the last rate increase time to NOW */
    last_rate_increase_time_ms = gettime_ms();

    printf("[RCRT] Adjust rates at node join: N %2d, R %.3f, D %.3f, rho %.3f\n", m_N, m_R, m_D, m_rho);
}

connectionlist_t *create_rcrt_connection(uint16_t tid, uint16_t srcAddr, uint16_t req_irate) {
    struct rcrt_conn *cs = malloc(sizeof(struct rcrt_conn));
    connectionlist_t *c = (connectionlist_t *)cs;
    int i;
    if (c == NULL) {
        printf("[RCRT] Failed create more connections...\n");
        return NULL;
    }
#ifdef DEBUG_RCRT
    printf("[RCRT] Creating new rcr connections (tid %d, node %2d, req_irate %u)!!\n", 
            tid, srcAddr, req_irate);
#endif
    if (bootup_time_ms == 0)
        bootup_time_ms = gettimeofday_ms() - 1;

    add_connection((connectionlist_t **)&m_rcrtcs, c, tid, srcAddr);

    c->connection_type = PROTOCOL_RCR_TRANSPORT;
    c->lastRecvSeqNo = 0;

    cs->lastSentAckSeqNo = 0;
    cs->nextAckSeqNo = 0;
    cs->nextExpectedSeqNo = 1;
    cs->state = RCRT_S_ACTIVE;
    cs->deletePending = 0;
    cs->timeoutCount = 0;
    cs->congestion_ewma = 0.0;
    for (i = 0; i < FID_LIST_LEN; i++) {
        cs->feedback_fid_list[i] = 0;
        cs->feedback_senttime[i] = 0;
    }
    cs->feedback_fid = 0;
    cs->feedback_idx = -1;
    cs->last_feedback_time = 0;
    cs->next_nack_idx = 0;
    cs->rtt = 0.0;
    cs->rttvar = 0.0;
    cs->alloc = 0;
    cs->fcount = 0;
    cs->totalRetxPackets = 0;
   
    u16list_init(&cs->missingList);
    SPList_init(&cs->plist); // must init.....

    /* artificially limit the max rate by 50pkts/sec */
    if (req_irate == 0) req_irate = 20;

    cs->req_irate = req_irate;  // write down the requested desired rate d_i
    
    m_num_rtrc++;

    adjust_rates_at_node_join(cs);   // re-compute R, D, r_i, rho

    print_all_rtrc();
    return c;
}

/**
 * Mark the rcrt connection as 'finished'
 * - So that it has no effect on the rate adaptation & allocation.
 * - Adjust R, D, N accordingly.
 **/
void finish_rcrt_connection(connectionlist_t *c) {
    struct rcrt_conn *cs = (struct rcrt_conn *)c;

    /* if delete 'tid' was requested and if this was the last one pending,
     * then signal 'delete_done' */
    if (cs->deletePending && !rcrtransport_tid_is_alive(cs->c.tid))
        rcrtransport_tid_delete_done(cs->c.tid);

    /* reduce the allocated rate R */
    m_R = m_R - (double)1000.0/(double)cs->cur_irate;

    /* reduce the total requested desired rate D */
    if ((fairness_policy != RCRT_FAIR_RATE) && (cs->req_irate != 0)) {
        m_D = m_D - (double)1000.0/(double)cs->req_irate;
        if (m_R > m_D) m_R = m_D;
    }

    /* decrement the number of active flows */
    m_N--;

    /* no more active flows */
    if (m_N == 0) {
        m_slowstart = 1;
        /* these shouldn't be required... but there might be remainders from
           floating point <-> uint32_t conversion errors */
        m_D = 0.0;
        m_R = 0.0;
    }

    /* re-calculate rho, given correct m_R and m_D */
    m_rho = recalculate_rho();

    /* set the last rate decrease time to NOW */
    last_rate_decrease_time_ms = gettime_ms();

#ifdef DEBUG_RCRT
    printf("[RCRT] Adjust rates at node leave: addr %2d, N %2d, R %.3f, D %.3f, rho %.3f\n", 
            c->addr, m_N, m_R, m_D, m_rho);
#endif
#ifdef DEBUG_RCRT
    printf("[RCRT] Closing connection (tid %d, node %2d)", c->tid, c->addr);
    printf("(lost %lu, retx %u, pkts %lu, fdbk %u)\n", 
            c->totalLostPackets, cs->totalRetxPackets, c->totalRecvPackets, cs->fcount);
    fflush(stdout);
#endif
}

/* delete & deallocate rcrt connection data structure */
void _delete_rcrtc(connectionlist_t **c) {
    connectionlist_t *d;
    struct rcrt_conn *cs = (struct rcrt_conn *)(*c);
    if ((c == NULL) || ((*c) == NULL))
        return;

#ifdef DEBUG_RCRT
    printf("[RCRT] _deleting rcrt conn tid %d, node %2d\n", (*c)->tid, (*c)->addr);
    fflush(stdout);
#endif

    m_num_rtrc--;

    SPList_clearList(&(cs->plist));    // don't forget these!!
    u16list_clearList(&(cs->missingList));

    d = (*c)->next;
    (*c)->next = NULL;
    *c = d;
    free(cs);
}

/* delete a rcrt connection now, after closing it */
void delete_rcrt_connection(connectionlist_t *c) {
    connectionlist_t **d;
    if (c == NULL)
        return;

    finish_rcrt_connection(c);

    d = _find_connection((connectionlist_t **)&m_rcrtcs, c->tid, c->addr);
    _delete_rcrtc(d);
    print_all_rtrc();
}

/* terminate rcrt module */
void rcrtransport_terminate() {
    connectionlist_t **c;
    for (c = (connectionlist_t **)&m_rcrtcs; *c; )
        _delete_rcrtc(c);
    if (m_rcrt_log_fptr) {
        fflush(m_rcrt_log_fptr);
        fclose(m_rcrt_log_fptr);
    }
}

/**
 * Delete all rcrt connections with tid='tid' 
 * - if the connection is finished, delete immediately.
 *   otherwise, mark as deletePending and delete after a timeout.
 * - return 
 *    -1 , if at least one connection is not finished
 *     1 , if all has been deleted.
 *     0 , if no matching 'tid' exists.
 **/
int rcrtransport_delete_tid(uint16_t tid) {
    connectionlist_t **c;
    int result = 0; // if there is no matching tid, will return 0.
    
    if (m_num_rtrc == 0)
        return 0;

#ifdef DEBUG_RCRT
    printf("[RCRT] delete_tid requested by transport (tid %d)\n", tid);
#endif

    for (c = (connectionlist_t **)&m_rcrtcs; *c; ) {
        struct rcrt_conn *cs = (struct rcrt_conn *)(*c);
        if ((*c)->tid == tid) {
            if (result == 0)    // if there is at least one matching tid,
                result = 1;     // will return 1 as long as nothing is pending.
                
            if ((*c)->totalRecvPackets == 0) {
            #ifdef DEBUG_RCRT
                printf("[RCRT] This must be a dead connection (tid %d, node %2d) Terminating.\n", tid, (*c)->addr);
            #endif
                delete_rcrt_connection((*c));
                continue;   // should not move to next pointer
            } else {
            #ifdef DEBUG_RCRT
                printf("[RCRT] cannot delete tid %d yet for node %2d\n", tid, (*c)->addr);
            #endif
                if ((*c)->alarm_time.tv_sec == 0)   // if no timer running,
                    RCRT_Timer_start(*c, RCRT_CONNECTION_TIMEOUT);
                cs->deletePending = 1;
                result = -1;    // at least one connection is not finished.
                // transportmain can expect/wait for rcrtransport_tid_delete_done();
            }
        }
        c = &((*c)->next);
    }
    print_all_rtrc();
    return result;
}

/* check whether there is a connection with 'tid' */
int rcrtransport_tid_is_alive(uint16_t tid) {
    connectionlist_t *c;
    for (c = (connectionlist_t *)m_rcrtcs; c; ) {
        // if there exist a matching tid, and if that connection is not finished
        if (c->tid == tid)
            return 1;   // there exist a live connection with 'tid'
        c = c->next;
    }
    return 0;
}

