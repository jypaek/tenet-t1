
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <stddef.h>
#include "timeval.h"
#include "tr_seqno.h"
#include "connectionlist.h"


//#define DEBUG_CONNECTION
//#define DEBUG_LOSSRATE
//#define LOG_CONNECTION_PACKET

double ali_w[] = {1.0, 1.0, 1.0, 1.0, 0.8, 0.6, 0.4, 0.2};

FILE *m_conn_fp;

void update_packetrate(rate_info_t *r, int pkt_cnt);
void init_packetrate(rate_info_t *r);
void init_loss_ewma(loss_ewma_info_t *l);
void init_loss_ali(loss_ali_info_t *l);


/********************************************
 * connection list related functions
 ********************************************/

void print_all_connections(connectionlist_t **list) {
    connectionlist_t *c;
    int i = 1;
    for (c = (*list); c; c = c->next) {
        printf(" #[connection %d]: tid=%d, addr=%d\n", i++, c->tid, c->addr);
    }
}

void add_connection(connectionlist_t **list, connectionlist_t *c, uint16_t tid, uint16_t addr) {
    c->next = *list;
    *list = c;
    c->tid = tid;
    c->addr = addr;

    c->connection_type = 0;

    c->lastRecvSeqNo = 0;
    c->totalLostPackets = 0;
    c->totalRecvPackets = 0;
    
    c->alarm_time.tv_sec = 0;
    c->alarm_time.tv_usec = 0;

    init_loss_ewma(&c->loss_ewma);
    init_loss_ali(&c->loss_ali);
    init_packetrate(&c->pktrate);
    init_packetrate(&c->goodput);
}

connectionlist_t *create_connection(connectionlist_t **list, uint16_t tid, uint16_t addr) {
    connectionlist_t *c = malloc(sizeof(connectionlist_t));
    if (c == NULL) {
        fprintf(stderr, "FatalError: Not enough memory, failed to malloc!\n");
        exit(1);
    }
    add_connection(list, c, tid, addr);
    
    #ifdef LOG_CONNECTION_PACKET
    if (m_conn_fp == NULL) {
        m_conn_fp = fopen("log_conn_pkt.out", "w");
    }
    #endif
    return c;
}

void rem_connection(connectionlist_t **c) {
    connectionlist_t *dead = *c;
    *c = dead->next;
    free(dead);
}

connectionlist_t **_find_connection(connectionlist_t **list, uint16_t tid, uint16_t addr) {
    connectionlist_t **c;
    for (c = list; *c; ) {
        if (((*c)->tid == tid) && ((*c)->addr == addr))
            return c;
        else
            c = &((*c)->next);
    }
    return NULL;    // Error, not found
}

connectionlist_t *find_connection(connectionlist_t **list, uint16_t tid, uint16_t addr) {
    connectionlist_t **c;
    c = _find_connection(list, tid, addr);
    if (c)
        return (*c);
    return NULL;
}

void remove_connection(connectionlist_t **list, uint16_t tid, uint16_t addr) {
    connectionlist_t **c;
    c = _find_connection(list, tid, addr);
    if (c)
        rem_connection(c);
}

void delete_all_connection(connectionlist_t **list) {
    connectionlist_t **c;
    connectionlist_t *dead;
    for (c = list; *c; ) {
        dead = *c;
        *c = dead->next;
        free(dead);
    }
}

/********************************************
 * packet rate related functions
 ********************************************/
 
void init_packetrate(rate_info_t *r) {
    clear_timeval(&r->first_arrival_time);
    clear_timeval(&r->last_arrival_time);
    r->cumm_recv_cnt = 0;
    r->avg_arrival_interval = 0.0;
    r->Ravg = 0.0;
    r->Rcumm = 0.0;
    r->restart_averaging = 0;
}

void restart_averaging_packetrate(rate_info_t *r) {
    r->restart_averaging = 1;
}

void update_packetrate(rate_info_t *r, int pkt_cnt) {
    uint32_t interval;
    struct timeval tv_interval;
    struct timeval curr;
    gettimeofday(&curr, NULL);

    r->cumm_recv_cnt += pkt_cnt;

    if (r->first_arrival_time.tv_sec == 0) {    // first packet
        copy_timeval(&r->first_arrival_time, &curr);
    } 
    else {
        subtract_timeval(&curr, &r->first_arrival_time, &tv_interval);
        interval = tv2ms(&tv_interval);
        if (interval < 20) interval = 20;
        r->Rcumm = ((double)r->cumm_recv_cnt - 1.0)/((double)interval/1000.0);
        if (r->cumm_recv_cnt <= 5)
            r->Rcumm = 0.0;

        subtract_timeval(&curr, &r->last_arrival_time, &tv_interval);
        interval = tv2ms(&tv_interval);
        if (interval < 20) interval = 20;
        if ((r->avg_arrival_interval == 0.0) || (r->restart_averaging == 1)) {
            r->avg_arrival_interval = (double)interval/(double)pkt_cnt;
            r->restart_averaging = 0;
        } else {
            r->avg_arrival_interval = rate_alpha*((double)interval/(double)pkt_cnt) +
                                      (1.0-rate_alpha)*r->avg_arrival_interval;
        }
        r->Ravg = 1000.0/r->avg_arrival_interval;
        if (r->cumm_recv_cnt <= 5)
            r->Ravg = 0.0;
    }
    copy_timeval(&r->last_arrival_time, &curr);
}

void print_packetrate(rate_info_t *r) {
    printf("%.2f, %.2f pkts/sec ", r->Ravg, r->Rcumm);
}

void restart_averaging_goodput(connectionlist_t *c) {
    restart_averaging_packetrate(&c->goodput);
}

void restart_averaging_estimated_rate(connectionlist_t *c) {
    restart_averaging_packetrate(&c->pktrate);
}

void update_connection_goodput(connectionlist_t *c) {
    update_packetrate(&c->goodput, 1);
    #ifdef DEBUG_CONNECTION
    printf("[GOODPUT] "); print_packetrate(&c->goodput); printf("\n");
    #endif
}

void update_estimated_rate(connectionlist_t *c, int pkt_cnt) {
    update_packetrate(&c->pktrate, pkt_cnt);
    #ifdef DEBUG_CONNECTION
    printf("[PKTRATE] "); print_packetrate(&c->pktrate); printf("\n");
    #endif
}

/********************************************
 * lossrate related functions
 ********************************************/

void init_loss_ewma(loss_ewma_info_t *l) {
    l->Di = 1.0;
    l->Davg = 1.0;
    l->Lavg = 0.0;
    clear_timeval(&l->last_update_time);
    l->last_update_seqno = 0;
    l->epoch_recv_cnt = 0;
    l->restart_averaging = 0;
}

void restart_averaging_loss_ewma(loss_ewma_info_t *l) {
    l->Davg = 1.0;
    l->Lavg = 0.0;
    l->restart_averaging = 1;
}

void update_loss_ewma(connectionlist_t *c, uint16_t seqno) {
    loss_ewma_info_t *l = &c->loss_ewma;
    struct timeval tv_interval;
    uint16_t epoch_seq_diff;
    uint32_t epoch_time_diff;
    struct timeval curr;
    gettimeofday(&curr, NULL);

    if (tr_seqno_cmp(seqno, c->lastRecvSeqNo) <= 0)
        return;
    
    l->epoch_recv_cnt++;

    if (l->last_update_time.tv_sec == 0) {
        l->Di = 1.0/(double)seqno;
        l->Davg = l->Di;
        l->Lavg = 1.0 - l->Davg;
        copy_timeval(&l->last_update_time, &curr);
        l->last_update_seqno = seqno;
        l->epoch_recv_cnt = 0;
    } else {
        epoch_seq_diff = tr_seqno_diff(seqno, l->last_update_seqno);
        subtract_timeval(&curr, &l->last_update_time, &tv_interval);
        epoch_time_diff = tv2ms(&tv_interval)/1000;

        if ((epoch_seq_diff >= loss_ewma_epoch_window) || 
            (epoch_time_diff > loss_ewma_epoch_interval)) {
            if (l->epoch_recv_cnt > 0) {
                l->Di = (double)l->epoch_recv_cnt/(double)epoch_seq_diff;
                if (l->restart_averaging == 1) {
                    l->Davg = l->Di;
                    l->restart_averaging = 0;
                } else {
                    l->Davg = loss_ewma_alpha*l->Di + (1.0-loss_ewma_alpha)*l->Davg;
                }
                l->Lavg = 1.0 - l->Davg;
            }
            #ifdef DEBUG_LOSSRATE
                printf("[lossrate] (time %6lu)(seqcnt %d)(intval %d):",
                        tv2ms(&curr)%1000000, epoch_seq_diff, epoch_time_diff);
                printf(" %.2f, %.2f, %.2f, %.2f %%\n", (l->Lavg*100.0), (l->Di*100.0), (l->Davg*100.0));
            #endif
            copy_timeval(&l->last_update_time, &curr);
            l->last_update_seqno = seqno;
            l->epoch_recv_cnt = 0;
        }
    }
}

void init_loss_ali(loss_ali_info_t *l) {
    l->last_loss_seqno = 0;
    l->s_head = -1;
    l->s_len = 0;
    l->Savg = 0.0;
    l->Lavg = 0.0;
    l->restart_averaging = 0;
}

void restart_averaging_loss_ali(loss_ali_info_t *l) {
    l->s_len = 0;
    l->Savg = 0.0;
    l->Lavg = 0.0;
    //l->restart_averaging = 1;
}

void update_loss_ali(connectionlist_t *c, uint16_t seqno) {
    loss_ali_info_t *l = &c->loss_ali;
    unsigned int num_loss, loss_interval, s0, si;
    double wssum, wsum;
    double s_avg_n, s_avg_n_1;
    int k;

    // if we have detected new loss(es)
    if (tr_seqno_cmp(seqno, tr_seqno_next(c->lastRecvSeqNo)) > 0) {
        /**
         *   seqno       lastRecv       last_loss
         *      |           |               |
         *      O   X   X   O   O   O   O   X   O  
         *
         * ex>  9   8   7   6   5   4   3   2   1
         **/

        // ex>  9 - 6 - 1 = 2
        num_loss = tr_seqno_diff(seqno, c->lastRecvSeqNo) - 1;

        // ex>  6 - 2 + 1 = 5
        loss_interval = tr_seqno_diff(c->lastRecvSeqNo, l->last_loss_seqno) + 1;

        // if there were no loss(es) before,
        if (l->last_loss_seqno == 0) {

            // if we have never received any packets before,
            if (c->lastRecvSeqNo == 0) {
                /** 
                 * first received packet detected loss(es) for the first time
                 *      | 
                 *      O   X   X   X   X
                 **/
                loss_interval = 2;  
                // ==> s_avg_n = 0.5
                s_avg_n_1 = (double)num_loss/(double)(num_loss + 1);
            } else {
                /**
                 *      O   X   O   O   O
                 **/
                // first loss occurs after long run of no losses which under-estimates recent loss rate.
                // want to say... recent loss rate is no smaller than 10%
                if (loss_interval > 10) loss_interval = 10;
            }
        }
        else {
            /**
             *      O   X   X   O   O   O   O   X   O  
             **/
            //loss_interval /= num_loss;
            if (loss_interval < 2) loss_interval = 2;
            if (loss_interval > 20) loss_interval = 20;
        }
        
        l->last_loss_seqno = tr_seqno_prev(seqno);
        l->s_head = (l->s_head + 1) % ali_n;
        l->s[l->s_head] = loss_interval;
        if (l->s_len < ali_n)
            l->s_len++;
    }

    s0 = tr_seqno_diff(seqno, l->last_loss_seqno);

    if (l->s_len > 0) {
        wssum = 0.0;
        wsum = 0.0;
        for (k = 0; k < l->s_len; k++) {
            si = (l->s_head + ali_n - k) % ali_n;
            wssum += ((double)ali_w[k]*(double)l->s[si]);
            wsum += (double)ali_w[k];
        }
        s_avg_n = wssum/wsum;

        if (l->s_len > 1) {
            wssum = (double)ali_w[0]*(double)s0;
            wsum = (double)ali_w[0];
            for (k = 0; k < l->s_len-1; k++) {
                si = (l->s_head + ali_n - k) % ali_n;
                wssum += ((double)ali_w[k+1]*(double)l->s[si]);
                wsum += (double)ali_w[k+1];
            }
            s_avg_n_1 = wssum/wsum;
        } else {
            s_avg_n_1 = 0.0;
        }
        
        if (s_avg_n < s_avg_n_1)
            l->Savg = s_avg_n_1;
        else
            l->Savg = s_avg_n;
            
        l->Lavg = 1.0/l->Savg;
    }

    #ifdef DEBUG_LOSSRATE
        printf("[loss_ali] %.2f, (s0 %d, sn %.3f, sn1 %.3f)\n", (l->Lavg*100.0), s0, s_avg_n, s_avg_n_1);
    #endif
}

void update_connection_lossrate(connectionlist_t *c, uint16_t last_seqno) {
    update_loss_ewma(c, last_seqno);
    update_loss_ali(c, last_seqno);
}

void restart_averaging_lossrate(connectionlist_t *c) {
    restart_averaging_loss_ewma(&c->loss_ewma);
    restart_averaging_loss_ali(&c->loss_ali);
}

/********************************************
 * log packet information for a connection 
 ********************************************/

void log_connection_packet(connectionlist_t *c) {
    #ifdef LOG_CONNECTION_PACKET
    uint32_t time_ms;
    struct timeval curr;
    gettimeofday(&curr, NULL);
    time_ms = tv2ms(&curr);
#ifdef __CYGWIN__
    fprintf(m_conn_fp, "%lu %d %d %d %.3f %.3f %.3f %.3f\n", 
#else
    fprintf(m_conn_fp, "%u %d %d %d %.3f %.3f %.3f %.3f\n", 
#endif
                    time_ms, c->tid, c->addr, c->lastRecvSeqNo
                    c->goodput.Ravg, c->pktrate.Ravg, c->loss_ewma.Lavg, c->loss_ewma.Davg);
    fflush(m_conn_fp);
    #endif
}

