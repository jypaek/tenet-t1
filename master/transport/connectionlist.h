
#ifndef _CONNECTION_LIST_H_
#define _CONNECTION_LIST_H_

#include "common.h"
#include <sys/time.h>

#define rate_alpha 0.05     /* EWMA constant for computing rate */

#define loss_ewma_alpha 0.10     /* EWMA constant for computing loss rate Lavg */
#define loss_ewma_epoch_window 10   /* an epoch ends when more than this # of pkts are recved */
#define loss_ewma_epoch_interval 10 /* an epoch ends when more than this time has passed */

#define ali_n 8

typedef struct rate_info {
    struct timeval first_arrival_time;
    struct timeval last_arrival_time;
    unsigned long int cumm_recv_cnt;
    double avg_arrival_interval;        /* current EWMA'ed pkt arrival interval (1/rate) */
    double Ravg;
    double Rcumm;
    int restart_averaging;
} rate_info_t;

typedef struct loss_ewma_info {
    struct timeval last_update_time;
    uint16_t last_update_seqno;
    unsigned int epoch_recv_cnt;
    double Di;                  /* instantaneous delivery rate of this epoch */
    double Davg;                /* current EWMA'ed delivery rate */
    double Lavg;                /* current EWMA'ed loss rate (1 - Davg) */
    int restart_averaging;
} loss_ewma_info_t;

typedef struct loss_ali_info {
    uint16_t last_loss_seqno;
    unsigned int s[ali_n];
    int s_head;
    int s_len;
    double Savg;
    double Lavg;
    int restart_averaging;
} loss_ali_info_t;

typedef struct connectionlist {  // connpkt transport passive connection list
    struct connectionlist *next;
    uint16_t addr;
    uint16_t tid;
    int connection_type;

    uint16_t lastRecvSeqNo;
    unsigned long int totalLostPackets;
    unsigned long int totalRecvPackets;
    
    struct timeval alarm_time;

    rate_info_t pktrate;
    rate_info_t goodput;
    loss_ewma_info_t loss_ewma;
    loss_ali_info_t loss_ali;
} connectionlist_t;


void print_all_connections(connectionlist_t **list);
void add_connection(connectionlist_t **list, connectionlist_t *c, uint16_t tid, uint16_t addr);
connectionlist_t *create_connection(connectionlist_t **list, uint16_t tid, uint16_t addr);
void rem_connection(connectionlist_t **c);
connectionlist_t **_find_connection(connectionlist_t **list, uint16_t tid, uint16_t addr);
connectionlist_t *find_connection(connectionlist_t **list, uint16_t tid, uint16_t addr);
void remove_connection(connectionlist_t **list, uint16_t tid, uint16_t addr);
void update_connection_goodput(connectionlist_t *c);
int is_all_connection_goodput_good(connectionlist_t **list, double threshold);
void update_estimated_rate(connectionlist_t *c, int pkt_cnt);
void update_connection_lossrate(connectionlist_t *c, uint16_t last_seqno);
int is_all_connection_lossrate_good(connectionlist_t **list, double threshold);
void log_connection_packet(connectionlist_t *c);
void restart_averaging_lossrate(connectionlist_t *c);
void restart_averaging_goodput(connectionlist_t *c);
void restart_averaging_estimated_rate(connectionlist_t *c);

#endif

