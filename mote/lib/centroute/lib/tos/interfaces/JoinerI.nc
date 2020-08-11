includes Joiner;


interface JoinerI
{
    command result_t init(uint8_t turn_period_sec,
            uint8_t tick_period_sec, uint8_t max_ticks);
    command void set_join_timeout(uint8_t period_sec);
    command void set_tick_period(uint8_t period_sec);
    command void set_max_ticks(uint8_t ticks);
    command uint8_t get_join_timeout();
    command uint8_t get_tick_period();
    command uint8_t get_max_ticks();
    command void beacon_enable();
    command void beacon_disable();
    event void beacon_from_parent_rcvd();
    event void join_request_rcvd(uint16_t node_id, uint16_t round,
            uint8_t beacons_rcvd, uint8_t max_beacons);
}
