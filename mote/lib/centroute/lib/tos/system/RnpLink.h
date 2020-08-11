#ifndef _RNP_LINK_H_
#define _RNP_LINK_H_

typedef struct _rnp_hdr {
    uint16_t src;
    uint8_t seq;
} __attribute__ ((packed)) rnp_hdr_t;

typedef struct _rnp_entry {
    uint16_t id;
    uint8_t prev_seq;
    uint8_t rnp_out;
    float rnp_in;
    uint8_t num_packets:3;     // for rampup
    uint8_t occupied:1;
    uint8_t rampup:1;
    uint8_t status:3;
    uint8_t down_status;
} __attribute__ ((packed)) rnp_entry_t;


#endif
