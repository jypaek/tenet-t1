includes CentTree;

interface CentTreeCtrlI
{
    command void i_am_sink();
    command void i_am_leaf();
    command result_t is_sink();
    command uint8_t get_max_payload_length();
    command int8_t is_associated();
    command uint16_t get_parent_id();
    command uint16_t get_sink_id();
}
