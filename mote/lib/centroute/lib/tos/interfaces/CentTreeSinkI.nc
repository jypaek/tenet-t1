includes CentTree;

interface CentTreeSinkI
{
    event void join_beacon_rcvd(join_beacon_t *beacon,
            int8_t inbound_quality, int8_t outbound_quality);

    event void up_pkt_rcvd(up_hdr_t *hdr, uint8_t type, uint8_t client_type,
            uint8_t length);

    command int16_t send_pkt_down(pd_hdr_t *hdr, uint8_t type, uint8_t
            client_type, uint8_t length);
    event int8_t send_pkt_down_done(char *data, uint16_t dst, uint8_t type,
            uint8_t client_type, uint8_t length);
}
