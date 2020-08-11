
/**
 * @modified Feb/16/2008
 * @author Jeongyeup Paek (jpaek@enl.usc.edu)
 *
 * - separate TestCyclopsMsg and QueryMsg:
 *   - TestCyclopsMsg is the packet structure that is used for communication
 *     between stargate/pc and mote.
 *   - it can be used for either query msg or response msg.
 **/

#ifndef TEST_CYCLOPS_MSG_H
#define TEST_CYCLOPS_MSG_H

enum {
    AM_QUERY_CYCLOPS = 0x06
};

/**
 * Definition of TestCyclopsMsg. 
 *
 * - This is the structure of the messages communicated between
 *   the stargate and the mote. (for both query and response)
 *
 * - if (TestCyclopsMsg->type == CYCLOPS_MSG_TYPE_QUERY)
 *       then, QueryMsg is encapsulated in 'TestCyclopsMsg->data',
 *   elif (TestCyclopsMsg->type == CYCLOPS_MSG_TYPE_RESPONSE)
 *       then, CyclopsResponse is encapsulated in 'TestCyclopsMsg->data',
 **/
typedef struct TestCyclopsMsg {
    uint16_t sender;        //sender addr
    uint8_t qid;            //query id
    uint8_t type;           //query, query-cancel, response, etc
    uint8_t data[0];        //pointer to either QueryMsg or CyclopsResponse
} __attribute__((packed)) TestCyclopsMsg_t;

enum {
    TEST_CYCLOPS_MSG_TYPE_QUERY = 1,
    TEST_CYCLOPS_MSG_TYPE_RESPONSE = 2,
    TEST_CYCLOPS_MSG_TYPE_CANCEL = 3,
};


#endif

