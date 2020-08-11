#ifndef _CENTTREE_H_
#define _CENTTREE_H_

enum {
    CENTTREE_MSG_TYPE = 111,
};

// records whether a packet was generated locally, or is
// forwarded from another node.  Needed by the layer above
// in some circumstances.
typedef enum _send_originator_type_t
{
    SEND_TYPE_LOCAL,
    SEND_TYPE_FORWARDED
} send_originator_type_t;

typedef struct _tree_hdr_t {
    uint16_t src;
    uint16_t tx_seq;
    uint8_t direction:2;
    uint8_t type:6;
    uint8_t client_type;
    char data[0];
} __attribute__ ((packed)) tree_hdr_t;  //6 bytes

//join_fwd_hdr

typedef struct _up_hdr {
    uint16_t orig_src;
    uint16_t final_dst;
//    uint8_t type;
    int8_t path_entries;
  int8_t padding;
    char data[0];
} __attribute__ ((packed)) up_hdr_t;  //5 bytes, padded to 6


typedef struct _join_fwd_hdr {
    uint16_t beacon_round;
    char data[0];
} __attribute__ ((packed)) join_fwd_hdr_t;  //2 bytes


//join_fwd_entry
typedef struct _up_path_entry {
    uint16_t mote_id;
    int8_t retx_count;
    int8_t inbound_quality;
    int8_t outbound_quality;
    int8_t padding;
    char next[0];
} __attribute__ ((packed)) up_path_entry_t;   //5 bytes, padded to 6


typedef struct _down_hdr {
    uint16_t orig_src;
    uint16_t final_dst;
//    uint8_t type;
    int8_t path_entries;
//    int8_t reply;
//    int8_t hops_away;
    int8_t padding;
    char data[0];
} __attribute__ ((packed)) down_hdr_t;    //5 bytes, padded to 6


typedef struct _down_path_entry {
    uint16_t mote_id;
    int8_t retx_count;
    int8_t padding;
    char next[0];
} __attribute__ ((packed)) down_path_entry_t; //3 bytes, padded to 4

/*
typedef struct _join_reply_entry {
    uint16_t mote_id;
} __attribute__ ((packed)) join_reply_entry_t;
*/

// join_reply_hdr_t
typedef struct _join_reply {
    uint16_t beacon_round;
    int8_t reply;
    int8_t hops_away;
} __attribute__ ((packed)) join_reply_t;    //4 bytes


typedef struct _data_hdr {
    uint8_t type:6;     // type of data
    uint8_t ack_set:1;  // if this field is set, the 2nd field is interpreted
    uint8_t ack_type:1;  // 0: request, 1: reply

    uint8_t seq;        // for reliablity purposes
    char payload[0];
} __attribute__ ((packed)) data_hdr_t;  // 2 bytes
    


typedef struct _join_beacon {
    uint16_t mote_id;
    uint16_t beacon_round;
} __attribute__ ((packed)) join_beacon_t;


typedef struct _pd_hdr {
    uint8_t type;
    uint8_t client_type;
    char data[0];
} __attribute__ ((packed)) pd_hdr_t;


typedef struct _pd_beacon {
    join_beacon_t beacon;
    int8_t inbound_quality;
    int8_t outbound_quality;
} __attribute__ ((packed)) pd_beacon_t;



#endif
