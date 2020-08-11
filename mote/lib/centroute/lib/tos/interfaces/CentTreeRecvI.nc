includes CentTree;

interface CentTreeRecvI
{
//    event char *up_pkt_rcvd(uint16_t sender, char *data, 
//            uint8_t type, uint8_t length);
    event char *down_pkt_rcvd(uint16_t sender, char *data, 
            uint8_t length);
}
