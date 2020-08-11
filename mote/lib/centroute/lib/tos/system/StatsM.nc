
module StatsM
{
    provides {
        interface StdControl;
        interface StatsI;
    }


}


implementation {

typedef struct _stats {
    uint32_t tx_pkts;
    uint32_t tx_errors;
    uint32_t tx_drops;
    uint32_t tx_deferrals;
    uint64_t tx_bytes;
} stats_t;

stats_t stats;

command result_t StdControl.init()
{
    return SUCCESS;
}


command result_t StdControl.start()
{
    return SUCCESS;
}


command result_t StdControl.stop()
{
    return SUCCESS;
}



command void StatsI.incr_tx_pkts()
{
    stats.tx_pkts++;

}


command void StatsI.incr_tx_errors()
{
    stats.tx_errors++;

}

command void StatsI.incr_tx_bytes(uint16_t bytes)
{
    stats.tx_bytes+=bytes;

}

command void StatsI.incr_tx_drops()
{
    stats.tx_drops++;

}

command void StatsI.incr_tx_deferrals()
{
    stats.tx_deferrals++;

}

}
