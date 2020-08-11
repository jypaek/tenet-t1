#ifndef _JOINER_H_
#define _JOINER_H_

enum {
    JOINPAYLOADCLIENTS = uniqueCount("JoinPayloadI")
};


typedef struct _jb_pkt {
    uint16_t mote_id;
    uint16_t beacon_round;
    uint8_t beacon_turn;
    uint8_t beacon_tick;
    uint8_t max_ticks;
    uint8_t join_timeout_sec;
    uint8_t tick_period_sec;
    uint8_t payload_elements;
    char data[0];
} jb_pkt_t;    // 6 bytes


typedef struct _jb_element {
    jb_pkt_t beacon;
    uint8_t rcvd;
    uint8_t age;
    uint8_t state;
  uint8_t padding;
} jb_element_t; // 9 bytes padded to 10


typedef struct _jb_payload_element {
    int8_t type;
    int8_t length;
    char value[0];
} jb_payload_element_t;



#endif
