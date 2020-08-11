
/**
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 12/6/2006
 **/


#include "transport.h"

module TrPacketM {
    provides interface TrPacket;
}
implementation {
    #include "tr_packet.c"

    command void TrPacket.setHeader(TransportMsg *tmsg, uint16_t tid, uint16_t seqno, 
                                    uint8_t flag, uint8_t checksum) {
        tr_packet_setHeader(tmsg, tid, seqno, flag, checksum);
    }

    command uint16_t TrPacket.getTid(TransportMsg *tmsg) {
        return tr_packet_getTid(tmsg);
    }

    command uint16_t TrPacket.getSeqno(TransportMsg *tmsg) {
        return tr_packet_getSeqno(tmsg);
    }

    command uint8_t TrPacket.getFlag(TransportMsg *tmsg) {
        return tr_packet_getFlag(tmsg);
    }

    command uint8_t TrPacket.getChecksum(TransportMsg *tmsg) {
        return tr_packet_getChecksum(tmsg);
    }
    
    command uint8_t* TrPacket.getPayload(TransportMsg *tmsg) {
        return tr_packet_getPayload(tmsg);
    }
}

