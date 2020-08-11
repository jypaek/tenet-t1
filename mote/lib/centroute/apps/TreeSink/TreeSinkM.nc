////////////////////////////////////////////////////////////////////////////
//
// CENS
//
// Copyright (c) 2003 The Regents of the University of California.  All 
// rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions
// are met:
//
// - Redistributions of source code must retain the above copyright
//   notice, this list of conditions and the following disclaimer.
//
// - Neither the name of the University nor the names of its
//   contributors may be used to endorse or promote products derived
//   from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS''
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
// THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
// PARTICULAR  PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE REGENTS OR
// CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
// EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
// PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
// PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
// OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
////////////////////////////////////////////////////////////////////////////

includes AM;
includes PktQueue;
includes Beaconer;
includes CentTree;

module TreeSinkM
{
    provides {
        interface StdControl;
    }

    uses {
#ifdef EMSTAR_NO_KERNEL
	interface EmSocketI as TreePd;
#else
        interface EmPdServerI as TreePd;
#endif
        interface CentTreeCtrlI;
        interface CentTreeSinkI as TreeSinkI;
    }
}



implementation
{

#include "CentTree_defs.h"
#include "PktQueue_defs.h"
#include "mDTN.h"
#include "PktTypes.h"
#include "protocols.h"
#include "QueryTypes.h"

#include "Beaconer_Strings.h"

#ifdef EMSTAR_NO_KERNEL
#include <emstar_interprocess.h>
#endif

int8_t send_pkt_down(pd_hdr_t *hdr, uint8_t type, uint8_t length);

void print_chunk(char *ptr, int length)
{
  int i;

  for (i=0; i<length; i++)
    {
      elog(LOG_ERR, "%x ", *(ptr + i));

    }

  elog(LOG_ERR, "\n");
}

command result_t StdControl.init()
{
    return SUCCESS;
}

command result_t StdControl.start()
{
    
    dbg(DBG_USR3, "Starting treesink!\n");

    call CentTreeCtrlI.i_am_sink();
#ifdef EMSTAR_NO_KERNEL
    // 2 connections (from multicast and non-multicast packets)
    call TreePd.ServerInit(CENTROUTE_TO_EMTOS_CENTROUTE, 2);	
#else
    call TreePd.Init(CENTROUTE_PD_NAME);
#endif
    return SUCCESS;
}

command result_t StdControl.stop()
{
    return SUCCESS;
}


event void TreeSinkI.join_beacon_rcvd(join_beacon_t *beacon,
            int8_t inbound_quality, int8_t outbound_quality)
{
    uint8_t length = sizeof(pd_hdr_t) + sizeof(pd_beacon_t);
    char buf[length];
    pd_hdr_t *pd_hdr=(pd_hdr_t *)buf;
    pd_beacon_t *pd_beacon = (pd_beacon_t *)(pd_hdr->data);

    dbg(DBG_USR2, "Received a join beacon, length should be %d!\n",
	length);

    memset(buf, 0, length);
    // set pd_hdr type to PD_BEACON
    pd_hdr->type = PD_BEACON;
    memcpy(&pd_beacon->beacon, beacon, sizeof(join_beacon_t));
    pd_beacon->inbound_quality = inbound_quality;
    pd_beacon->outbound_quality = outbound_quality;

    // we're set, call ReceiveMsg
#ifdef EMSTAR_NO_KERNEL
    call TreePd.WriteToSocket(buf, length, SERVER_TYPE);
#else
    call TreePd.ReceiveMsg(buf, length);
#endif
}

event void TreeSinkI.up_pkt_rcvd(up_hdr_t *up_hdr, uint8_t type,
        uint8_t client_type, uint8_t length)
{
    uint8_t pd_length = sizeof(pd_hdr_t)+length;
    char buf[pd_length];
    pd_hdr_t *pd_hdr=(pd_hdr_t *)buf;
    data_hdr_t *data_hdr=(data_hdr_t *)(up_hdr->data);
    DsePacket_t *p = (DsePacket_t *)(data_hdr->payload + sizeof(mDTN_pkt_t) + 5);
    QueryResponse_t* qResp = (QueryResponse_t*) p->data;	

    memset(buf, 0, pd_length);
    // set pd_hdr type to the signal's type
    pd_hdr->type = type;
    pd_hdr->client_type = client_type;
    memcpy(pd_hdr->data, up_hdr, length);

#ifdef EMSTAR_NO_KERNEL
    dbg(DBG_USR3,  "Receiving Query Response: ID = %d, bitmask = %d, Src %d, Seq %d\n", qResp->queryID, qResp->bitMask, p->hdr.m_uiSrcAddr, p->hdr.m_uiSeq);

    //print_chunk(buf, pd_length);
    call TreePd.WriteToSocket(buf, pd_length, SERVER_TYPE);
#else
    call TreePd.ReceiveMsg(buf, pd_length);
#endif
}

#ifdef EMSTAR_NO_KERNEL
event result_t TreePd.SendMsg(void *msg, int16_t length)
#else
event int TreePd.SendMsg(void *msg, int16_t length)
#endif
{
    pd_hdr_t *hdr = (pd_hdr_t *)msg;
    int n=0;

    dbg(DBG_USR3, "Asked to send a packet in TreeSink, type %d!\n", hdr->type);

    switch (hdr->type) {
        case JOIN_REPLY:
            n = send_pkt_down(hdr, JOIN_REPLY, length-sizeof(pd_hdr_t));
            break;
        case DATA:
            n = send_pkt_down(hdr, DATA, length-sizeof(pd_hdr_t));
            break;
        case DISSOCIATE:
            n = send_pkt_down(hdr, DISSOCIATE, length-sizeof(pd_hdr_t));
            break;
            
        default:
            dbg(DBG_ERROR, "Unsupported type %u\n", hdr->type);
            break;
    }

    return n;
}


int8_t send_pkt_down(pd_hdr_t *hdr, uint8_t type, uint8_t length)
{
    int8_t n=0;
    // TODO: fix that hardcoded 15 by making the pd a ld and using ext_type
    n = call TreeSinkI.send_pkt_down(hdr, type, hdr->client_type, length);
    dbg(DBG_USR2, "type=%u, client_type=%u, n=%d\n", 
            type, hdr->client_type, n);

    if (n>=0) {
        return -1;
    } else {
        return 0;
    }
}


event int8_t TreeSinkI.send_pkt_down_done(char *data, uint16_t dst,
        uint8_t type, uint8_t client_type, uint8_t length)
{
    dbg(DBG_USR2, "send_pkt_down_done called, type=%u, client_type=%u\n",
            type, client_type);
    return call TreePd.pd_unblock();
}


}
