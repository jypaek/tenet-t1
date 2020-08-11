/*
 * Copyright (c) 2003 The Regents of the University of California.  All 
 * rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 *
 * - Neither the name of the University nor the names of its
 *   contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS''
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
 * PARTICULAR  PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE REGENTS OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 */

//#include <emrun/fault_logger.h>
//#include <sensors/event_detector.h>
//#include <devel/remote_storage/remote.h>

#ifndef __SSYNC_TYPES_H__
#define __SSYNC_TYPES_H__

//#include "ssync_macros.h"

/*
 *  List of known types that are supported in the library
 */

/*
 *  A simple type for workload testing purposes...
 */

typedef struct wl_info {
  char key[2];
  uint16_t app_seq;
  char data[8+3];
}  __attribute__ ((packed)) wl_info_t;


SSYNC_PUB_TYPESAFE_INLINES(workload,wl_info_t,"wl",4);

/*
 *  Cluster info type
 */

typedef struct cluster_info {
  cl_index_t index;
  node_id_t node_id;  
  if_id_t if_id;
}  __attribute__ ((packed)) cluster_info_t;


SSYNC_PUB_TYPESAFE_INLINES(cluster,cluster_info_t,"cluster",1);

/*
 *  Flow info types
 */

typedef struct flow_map {
  uint8_t flow_index;
  flow_id_t flow_id;
}  __attribute__ ((packed)) flow_map_t;

SSYNC_PUB_TYPESAFE_INLINES(flow_map,flow_map_t,"flow_map",1);


typedef struct flow_status {
  uint8_t flow_index;
  cl_index_t parent;
  uint8_t hops_remain;
  uint8_t log_index;
  log_seqno_t seqno;
}  __attribute__ ((packed)) flow_status_t;

SSYNC_PUB_TYPESAFE_INLINES(flow_status,flow_status_t,"flow_stat",1);


/*
 *  Range Entry
 */

typedef struct range_entry {
  node_id_t source;
  uint32_t distance;    /* mm */
  uint16_t theta;       /* tenths of degrees */
  uint16_t phi;         /* tenths of degrees */
  uint16_t conf;
  uint16_t a_conf;
  int32_t seqno;        /* motion seqno */
}  __attribute__ ((packed)) range_entry_t;

SSYNC_PUB_TYPESAFE_INLINES(range_entry,range_entry_t,"range",sizeof(node_id_t));


/*
 *  Coordinate Entry
 */

typedef struct coord_entry {
  node_id_t node;
  int32_t coord[3];    /* mm */
  int16_t rpy[3];      /* tenths of degrees */
  uint16_t valid:1;
  uint16_t reserved:15;
}  __attribute__ ((packed)) coord_entry_t;

SSYNC_PUB_TYPESAFE_INLINES(coord_entry,coord_entry_t,"coord",sizeof(node_id_t));


// transaction/querier entry
// used in mote herding's resdisc, for leader election

typedef struct le_entry {
    node_id_t my_id;
    node_id_t querier_id;
    int64_t tid;
} __attribute__ ((packed)) le_entry_t;

SSYNC_PUB_TYPESAFE_INLINES(le_entry, le_entry_t, "le", sizeof(node_id_t));


/* Flock entry
 * Used in the mote herding registration protocol
*/

typedef struct flock_member_entry {
    node_id_t uid;        // unique mote id
    uint32_t seqnum;
    uint32_t state;
    uint8_t path_length;
    float etx;
} __attribute__ ((packed)) flock_member_entry_t;

SSYNC_PUB_TYPESAFE_INLINES(flock_member_entry,flock_member_entry_t,"flock",sizeof(node_id_t));


/* herd data stats entry
 * Used by mote herding's data reliability layer
 */

typedef struct _herd_data_entry {
    node_id_t uid;              // unique mote id
    node_id_t shepherd_id;      // the shepherd's id
    uint32_t pkts_rcvd;
    uint32_t total_tx;
    uint32_t dups_rcvd;
    uint32_t pkts_sent;
    uint32_t acks_rcvd;
    uint32_t acks_sent;
    uint32_t ack_timeouts;
    uint32_t pkts_retx;
    uint32_t acks_retx;
    uint32_t pkts_lost;
    uint8_t last_seq_rcvd;
    uint8_t last_seq_sent;
    uint8_t last_seq_ackd;
} herd_data_entry_t;

SSYNC_PUB_TYPESAFE_INLINES(herd_data_entry,herd_data_entry_t,"herd_data",sizeof(node_id_t));


#define MAX_REG_ENTRY_SENSOR_TYPES  4
// herd registration entry
typedef struct _herd_res_entry {
    node_id_t node_id;
    node_id_t shepherd_id;
    // hardcoding the entry for now...
    loc_t location;
    int num_sensors;
    int8_t sensor_types[MAX_REG_ENTRY_SENSOR_TYPES];
    int64_t regtime;
    int8_t regseq;
    int8_t pad[3];
} herd_res_entry_t;

SSYNC_PUB_TYPESAFE_INLINES(herd_res_entry,herd_res_entry_t,"herd_res",sizeof(node_id_t));



/*
 *  Interest entry
 *  Used by the sink tree implementation
 */        

typedef struct interest_entry {
  int interest_type;
} __attribute__ ((packed)) interest_entry_t;

SSYNC_PUB_TYPESAFE_INLINES(interest,interest_entry_t,"interest",sizeof(interest_entry_t));


/**************************
 *
 *  Debugging types for "compressed proxy"  
 *
 */

typedef struct cp_neighbor_entry {
  if_id_t src_if_id;
  if_id_t dst_if_id;
  uint8_t link_index;
  uint8_t quality;
  uint8_t out_quality;          // used when src_if_id is set
  uint8_t bidirectional:1;      // set this if src_if_id is used
  uint8_t state:7;              // state is now 7-bit
}  __attribute__ ((packed)) cp_neighbor_entry_t;
SSYNC_PUB_TYPESAFE_INLINES(cp_neighbor_entry,cp_neighbor_entry_t,"cp_neigh",sizeof(if_id_t)*2+1);

typedef struct cp_link_state {
  uint8_t link_index;
  if_id_t if_id;
  uint32_t bytes_tx;
  uint32_t bytes_rx;
}  __attribute__ ((packed)) cp_link_state_t;
SSYNC_PUB_TYPESAFE_INLINES(cp_link_state,cp_link_state_t,"cp_link",1);

/*
 *  Fault reporting  (see emrun/fault_logger.h)
 */

SSYNC_PUB_TYPESAFE_INLINES(fault_entry,fault_entry_t,"faults",2);


/*
 *  AENSBox Network Control 
 */

#define NETREC_APP_OFF        0
#define NETREC_APP_RECORDING  1
#define NETREC_APP_DETECTOR   2

typedef struct aensbox_net_control {
  uint32_t seqno;
  node_id_t my_master;
  uint16_t nominal_sample_rate;
  uint16_t sample_rate;
  uint16_t have_sync:1;
  uint16_t am_master:1;
  uint16_t application_mode:2;
  uint16_t reserved:12;
  uint16_t external_flash_MB;
  uint16_t onboard_flash_MB;
  uint16_t load_avg;
  uint32_t gps_seconds;
  uint16_t record_pid;
  uint16_t last_status;
  uint8_t levels[4];
  remote_status_t remote_storage;
  evdet_status_t detector_state;
  evrec_status_t recorder_state;
  crec_status_t crec_state;
}  __attribute__ ((packed)) aensbox_net_control_t;
SSYNC_PUB_TYPESAFE_INLINES(netrec,aensbox_net_control_t,"netrec",0);


/*
 *  Martin's filemover sink tree
 */
/*
  typedef struct {
  uint32_t node_id;
  //  uint16_t seqno;
  uint32_t sink_node;
  uint16_t hops_to_sink;
  uint32_t my_next_hop;
  float etx_to_sink;
  char data[0];
  }  __attribute__ ((packed)) sink_tree_t;
  SSYNC_PUB_TYPESAFE_INLINES(sink_tree,sink_tree_t,"sink_tree",4);
*/

/*
 * DTS sequence number tables
 */
typedef struct _dts_sequence_number {
  node_id_t src_node;
  uint32_t sequence_number;
} __attribute__ ((packed)) dts_sequence_number_t;
SSYNC_PUB_TYPESAFE_INLINES(dts_sequence_numbers,dts_sequence_number_t,"seqnos",4);

/*
 * The filemover entries of what files to delete
 */
typedef struct _filemover_deleter {
  long int date;
  char site[4];
} __attribute__ ((packed)) filemover_deleter_t;
SSYNC_PUB_TYPESAFE_INLINES(filemover_deleter,filemover_deleter_t,"deleter",8);



/*
 *  unparse function table
 */

typedef void (* ssync_unparse_cb_t) (buf_t *buf, void *entry, int len, char *indent);

ssync_unparse_cb_t ssync_lookup_unparse(ssync_type_t *type);

void workload_unparse(buf_t *buf, void *entry, int len, char *indent);
void cluster_unparse(buf_t *buf, void *entry, int len, char *indent);

#endif
