

/**
 * Define command and response data structure for test-transport application.
 *
 * Command data structure will be sent from a master application to the motes.
 * Response data structure is the payload of packet sent from the motes to 
 * the test-transport master application.
 *
 * Embedded Networks Laboratory, University of Southern California
 *
 * @author Jeongyeup Paek
 * @modified 1/11/2006
 **/

#ifndef _TEST_TRANSPORT_TASK_H_
#define _TEST_TRANSPORT_TASK_H_

enum {
    TASK_MSG_TYPE_DATA = 0xe2,
    TASK_MSG_TYPE_TEST_TRANSPORT_TASK = 0xe4,
    TASK_MSG_TYPE_ROUTE_CONTROL_TASK = 0xe7,
    TASK_MSG_TYPE_REBOOT_TASK = 0xe8,
    TASK_MSG_TYPE_PING_TASK = 0xe9,
    TASK_MSG_TYPE_RETX_CONTROL_TASK = 0xe6,

    TASK_MSG_TYPE_STOP_TASK = 0x03,
};

#ifndef task_msg_t
typedef struct task_msg_s {
    uint8_t type;
    uint8_t param;
    uint8_t data[0];
} task_msg_t;
#endif


typedef struct testTransportCmd {
    uint32_t start_time;
    uint32_t interval;
    uint32_t num_packets;
    uint8_t transport_type;
    uint8_t option;
} testTransportCmd;

typedef struct testTransportDataMsg {
    uint32_t timestamp;
    uint8_t data[0];
} testTransportDataMsg;


#endif

