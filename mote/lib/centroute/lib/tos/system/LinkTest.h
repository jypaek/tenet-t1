#ifndef _LINKTEST_H_
#define _LINKTEST_H_



typedef struct _lt_hdr {
    int8_t type;
    char data[0];
} __attribute__ ((packed)) lt_hdr_t;
    

typedef struct _lt_req {
    uint16_t sink;                  // the requesting sink
    uint8_t probe_interval_sec;     // interval between consecutive probes
    uint8_t lt_seq;                 // request sequence number
    uint8_t max_probes;             // probes to be sent out
} __attribute__ ((packed)) lt_req_t;


typedef struct _lt_probe {
    lt_req_t request;
    uint8_t current_probe;
} __attribute__ ((packed)) lt_probe_t;


typedef struct _lt_report {
    lt_req_t request;
    int16_t expiration_time_sec;    // seconds until record expires
    uint16_t sender;                // the mote that sent the probes 
    uint8_t rcvd;                   // number of probes received
} __attribute__ ((packed)) lt_report_t;


#endif
