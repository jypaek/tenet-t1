includes RnpLink;
includes AM;


interface RnpLinkI
{
    command uint8_t get_table_size();
    command int8_t get_neighbor_index(uint16_t id);
    command rnp_entry_t *get_table();
    command rnp_entry_t *get_neighbor_by_index(uint8_t idx);
    command void set_active_threshold(int8_t threshold);
    command int8_t get_active_threshold();
    command void outbound_quality_update(int8_t idx, int8_t quality);
    command int8_t is_neighbor(uint16_t id);
    command int8_t get_neighbor_avg_quality(uint16_t id);
    command int8_t get_neighbor_inbound_quality(uint16_t id);
    command int8_t get_neighbor_outbound_quality(uint16_t id);
    command int8_t get_neighbor_status(uint16_t id);
    command uint8_t get_max_payload_length();
    command int8_t get_rampup_entries();
    command int8_t get_num_neighbors();
}
