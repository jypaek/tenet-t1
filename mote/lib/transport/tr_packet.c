
/**
 * Authors: Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * Modified: 12/6/2006
 **/

#ifndef _TR_PACKET_C_
#define _TR_PACKET_C_

#include "transport.h"

void tr_packet_setHeader(TransportMsg *tmsg, uint16_t tid, uint16_t seqno, uint8_t flag, uint8_t checksum) {
    tmsg->tid = tid;
    tmsg->seqno = seqno;
    tmsg->flag = flag;
    tmsg->checksum = checksum;
}

uint16_t tr_packet_getTid(TransportMsg *tmsg) {
    return tmsg->tid;
}

uint16_t tr_packet_getSeqno(TransportMsg *tmsg) {
    return tmsg->seqno;
}

uint8_t tr_packet_getFlag(TransportMsg *tmsg) {
    return tmsg->flag;
}

uint8_t tr_packet_getChecksum(TransportMsg *tmsg) {
    return tmsg->checksum;
}

uint8_t* tr_packet_getPayload(TransportMsg *tmsg) {
    return tmsg->data;
}

#endif

