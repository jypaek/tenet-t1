
/**
 * Authors: Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * Modified: 12/6/2006
 **/

#ifndef _TR_PACKET_H_
#define _TR_PACKET_H_

#include "transport.h"

void tr_packet_setHeader(TransportMsg *tmsg, uint16_t tid, uint16_t seqno, uint8_t flag, uint8_t checksum);

uint16_t tr_packet_getTid(TransportMsg *tmsg);

uint16_t tr_packet_getSeqno(TransportMsg *tmsg);

uint8_t tr_packet_getFlag(TransportMsg *tmsg);

uint8_t tr_packet_getChecksum(TransportMsg *tmsg);

uint8_t* tr_packet_getPayload(TransportMsg *tmsg);

#endif

