
#ifdef BUILDING_PC_SIDE
#include "nx.h"
#endif

enum {
    AM_TEST_TRD = 241,
};

typedef struct TestTRD_UartMsg {
    nx_uint16_t id;
    nx_uint16_t recvcnt;
    nx_uint16_t origin;
    uint8_t  data[0];
} TestTRD_UartMsg;
//} __attribute__ ((packed)) TestTRD_UartMsg;

