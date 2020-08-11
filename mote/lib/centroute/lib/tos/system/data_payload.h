#ifndef _DATA_PAYLOAD_H_
#define _DATA_PAYLOAD_H_

typedef struct _data_payload {
    uint32_t count;
    int64_t timestamp;
    uint32_t deferred;
} __attribute__ ((packed)) data_payload_t;

#endif
