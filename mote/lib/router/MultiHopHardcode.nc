
module MultiHopHardcode {
    provides {
        interface StdControl;
        interface RoutingTable;
        interface ParentControl;
        interface RoutingChange;
    }
    uses {
        interface Timer;
        interface SendMsg;
        interface ReceiveMsg;
        interface Random;
        interface NeighborTable;
    }
}

implementation {

#ifndef BS
    #define BS 1
#endif

#if (STATIC_ROUTING == 41) && (FANG == 1) // Fang's setup
                               //   1,  2,  3,  4,  5,  6,  7,  8,  9, 10,
    uint16_t h_parent[41] =     {  BS, BS,  2, BS,  3, BS, BS, BS,  8,  8, // 10
                                    8,  8,  7, 11, 10, 15, 15, 16, 20, 14, // 20
                                   13, 23, 13, 22, 24, 22, 26, 23, 21, 21, // 30
                                   29, 29, 20, 31, 31, 33, 26, 33, 38, 37, // 40
                                   38
                                }; 
#elif STATIC_ROUTING == 30
                                //   1,  2,  3,  4,  5,  6,  7,  8,  9, 10,
    uint16_t h_parent[30] =     {  BS,  1,  1,  1,  1,  1,  1,  1,  1,  8, // 10
                                    8,  1,  1, 12, 13, 13,  8, 17, 17, 17, // 20
                                   17, 17, 17, 17, 23, 17, 17, 26, 17, 16, // 30
                                };
#elif STATIC_ROUTING == 40
                                //   1,  2,  3,  4,  5,  6,  7,  8,  9, 10,
    uint16_t h_parent[40] =     {   7,  1,  5,  5,  7,  7, 12,  9, 12, 12, // 10
                                   13, 14, 16, 16, 20, 20, 20, 20, 20, 29, // 20
                                   29, 18, 19, 22, 23, 25, 25, 25, BS, 31, // 30
                                   29, 31, 31, 31, 33, 34, 35, 36, 38, 38, // 40
                                };
#elif (STATIC_ROUTING == 41)
                               //   1,  2,  3,  4,  5,  6,  7,  8,  9, 10,
    uint16_t h_parent[41] =     {  BS,  1,  2,  1,  3,  1,  3,  1, 13,  9, // 10
                                    1,  7,  8,  8, 13, 13, 16, 16, 16, 15, // 20
                                   17, 19, 15, 23, 23, 19, 25, 26, 17, 17, // 30
                                   32, 17, 30, 33, 33, 34, 35, 36, 37, 37, // 40
                                   34,
                                };
#endif

    uint8_t h_depth = 0;

    command result_t StdControl.init() { return SUCCESS; }
    command result_t StdControl.start() {
        signal RoutingChange.parentChanged(h_parent[TOS_LOCAL_ADDRESS - 1]);
        return SUCCESS;
    }
    command result_t StdControl.stop() { return SUCCESS; }

    uint8_t calculate_h_depth() {
        uint8_t depth = 0;
        uint16_t nexthop = TOS_LOCAL_ADDRESS;
        while ((nexthop != BS) && (nexthop != 0)) {
            depth = depth + 1;
            nexthop = h_parent[nexthop - 1];
        }
        return depth; 
    }

    command uint16_t RoutingTable.getParent() {
        return h_parent[TOS_LOCAL_ADDRESS - 1];
    }
    command uint8_t RoutingTable.getDepth() { 
        if (h_depth == 0)
            h_depth = calculate_h_depth();
        return h_depth;
    }
    command uint16_t RoutingTable.getMaster() {
        return BS;
    }
    command uint16_t RoutingTable.getLinkEst() {
        return 0;
    }
    command int16_t RoutingTable.getLinkRssi() {
        return 0;
    }
    command void ParentControl.reset() { }
    command void ParentControl.hold() { }
    command void ParentControl.unhold() { }
    event result_t Timer.fired() { return SUCCESS; }
    event result_t SendMsg.sendDone(TOS_MsgPtr pMsg, result_t success) { return SUCCESS; }
    event TOS_MsgPtr ReceiveMsg.receive(TOS_MsgPtr Msg) { return Msg; }
}

