includes PktQueue;
includes AM;


interface PktQueueCtrlI
{
//    command void set_retries(int8_t retries);
//    command int8_t get_retries();
    command void use_acks();
    command void dont_use_acks();
    command int8_t get_acks_status();
    command void use_roundrobin();
    command void dont_use_roundrobin();
    command int8_t get_roundrobin_status();
    command int8_t get_client_id_from_buf(TOS_Msg *buf);
    command int8_t get_buf_status(TOS_Msg *buf);
}
