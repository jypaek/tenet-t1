includes CentTree;

interface CentTreeSendI
{

    // send_raw_pkt_up uses the centtree internal bufs; as such
    // the app doesn't need to provide its own tos_msg 
    // It also DOESNT set any headers, so the user needs to set
    // all the internal headers himself (hence "RAW")
    command int16_t send_raw_pkt_up(char *data, uint8_t type, uint8_t length);
//    command int8_t send_raw_pkt_down(char *data, uint16_t dst, 
//            uint8_t type, uint8_t length);
    // send_pkt_down is only used by the sink
//    event int8_t send_pkt_down_done(char *data, uint16_t dst, uint8_t type,
//            uint8_t length);

    // send_pkt_up assumes that the caller handles its own buffers and 
    // as such doesn't use any of the internal centtree bufs
    command int16_t send_pkt_up(TOS_Msg *msg, char *data, uint8_t length);

    // send_prepared_pkt_up is like send_pkt up with the difference
    // that the packet is assumed to be "prepared"; only the
    // msg->addr will be set (as the parent's addr), every other
    // field is assumed to be set
    command int16_t send_prepared_pkt_up(TOS_Msg *msg);
    event int8_t send_pkt_up_done(char *data, uint8_t type, uint8_t length);
}
