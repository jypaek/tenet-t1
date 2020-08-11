includes Beaconer;


interface BeaconerI
{
    command result_t init(int8_t length, int16_t period);
    command result_t set_period(int16_t period);
    command int16_t get_period();
    command int8_t send(char *data, int8_t now);
    command void ignore();
    event void send_done(result_t result);
    event void receive(uint16_t src, char *data, int8_t length);
    event int8_t beacon_ready(uint16_t time_remaining);
    command void disable();
    command void enable();
}
