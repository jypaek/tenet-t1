
interface StatsI
{
    command void incr_tx_pkts();
    command void incr_tx_errors();
    command void incr_tx_drops();
    command void incr_tx_deferrals();
    command void incr_tx_bytes(uint16_t bytes);
}
