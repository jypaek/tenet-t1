
/**
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 12/6/2006
 **/


#include "transport.h"

interface TrPacket
{

    command void setHeader(TransportMsg *tmsg, uint16_t tid, uint16_t seqno, uint8_t flag, uint8_t checksum);

    command uint16_t getTid(TransportMsg *tmsg);

    command uint16_t getSeqno(TransportMsg *tmsg);

    command uint8_t getFlag(TransportMsg *tmsg);

    command uint8_t getChecksum(TransportMsg *tmsg);

    command uint8_t* getPayload(TransportMsg *tmsg);
}

