includes PktQueue;
includes AM;


interface PktQueueI
{
    command result_t Init(TOS_Msg *pktbuf);
    command void set_retries(int8_t retries);
    command int8_t get_retries();
    command TOS_Msg *get_buf();
    command int8_t get_buf_status();
    command result_t flush();
    event int8_t retx_pkt(TOS_Msg *msg);
}
