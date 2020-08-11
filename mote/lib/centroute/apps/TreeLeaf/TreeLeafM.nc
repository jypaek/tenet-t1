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

#ifdef EMSTAR_NO_KERNEL
includes emstar_utils;
#endif

module TreeLeafM
{
    provides {
        interface StdControl;
#ifdef USE_ROUTE_ADAPTATION
        interface RoutingI;
#endif 
}

    uses {
        interface CentTreeCtrlI;
        interface CentTreeSendI as TreeSend;
        interface CentTreeSendStatusI as TreeSendStatus;
        interface CentTreeRecvI as TreeRecv;
        
        interface PktQueueI as PktQ;

    }
}


implementation
{
TOS_Msg pktbuf;
#include "CentTree_defs.h"
#include "PktQueue_defs.h"
#include "DupChecker_defs.h"
#include "PktTypes.h"
#include "CentTree_defs.h"
#include "protocols.h"

#include "Beaconer_Strings.h"


#include "data_payload.h"

#include "link_types.h"


int8_t busy=0;
uint8_t next_seq=0;
int8_t ack_rcvd=0;

typedef struct _data_stats {
    uint32_t pkts_sent;
    uint32_t acks_rcvd;
    uint32_t pkts_retx;
    uint32_t pkts_delayed;
    uint8_t next_seq;
    uint8_t last_ack;
} data_stats_t;


data_stats_t stats={};

int64_t get_time()
{
#ifdef PLATFORM_EMSTAR
    int64_t retval;
    struct timeval now={0};

    gettimeofday(&now, NULL);
    retval = misc_timeval_to_int64(&now);
    return retval;
#else
    return 0;
#endif
}


command result_t StdControl.init()
{
    return SUCCESS;
}

command result_t StdControl.start()
{
    call PktQ.Init(&pktbuf);
    call CentTreeCtrlI.i_am_leaf();

    return SUCCESS;
}


command result_t StdControl.stop()
{
    return SUCCESS;
}



// removed the status for now
event int8_t TreeSend.send_pkt_up_done(char *data, uint8_t type, 
        uint8_t length)
{
    data_hdr_t *data_hdr=(data_hdr_t *)data;

    stats.pkts_sent++;
    // successfully sent pkt, increment next_seq;
    next_seq++;
    stats.next_seq=next_seq;

    // reset ack_rcvd as well
    ack_rcvd=0;

    


    memset(&pktbuf, 0, sizeof(TOS_Msg));

    busy = 0;

    //dbg(DBG_ERROR,  "Send done 2!\n");

    //signal RoutingI.SendToRoutingDone(SUCCESS, type);

    return 0;
}


event int8_t TreeSendStatus.send_complete_status(char *data, uint8_t type, uint8_t length,
	send_originator_type_t orig, result_t status)
{
    //dbg(DBG_ERROR,  "Send done!\n");
    
    
    

    if (type != DATA)
    {
        // no further action necessary on non-data packets
        dbg(DBG_ERROR,"DTN::Failed to send non-data packet %d\n", type);
        return SUCCESS;  
    }

    if (orig == SEND_TYPE_LOCAL)
    {
        
	// a packet generated at this mote was sent - just need to 
    	// notify if it was completed successfully
#ifdef EMSTAR_NO_KERNEL
        util_print_chunk(data, length);
#endif

    	// set the type to 0, it will be calculated at the next layer
	// this refers to the data header type
    	signal RoutingI.SendToRoutingDone(data, length, status, 0);

        
        //signal RoutingI.SendToRoutingDone(data_hdr->payload, length - sizeof(data_hdr)status, type);
    }
    else
    {
        //dbg(DBG_USR3,  "Send done - raw type %d, fixed type %d\n", 
	//data_hdr->type, data_hdr->type + PKT_TYPE_USER0);
	
	if (status != SUCCESS)
	{
            //mDTN_pkt_t* mdtnpkt = (mDTN_pkt_t *)data_hdr->payload;
            //DseHeader_t *dse = (DseHeader_t *)(mdtnpkt->data);
                
            //dbg(DBG_ERROR,"DTN::Failed to forward... From %d, Seq number = %d\n", 
	      //  dse->m_uiSrcAddr, dse->m_uiSeq);

            // this packet was generated at another mote, and we couldn't
            // transmit it successfully - 
            // notify the higher layer
            // in case it needs to be stored
	    signal RoutingI.RouteForwardFailed(data, length);
            //signal RoutingI.RouteForwardFailed((unsigned char *)data_hdr->payload, 
	//	length - sizeof(data_hdr));
        }
    }

    return SUCCESS;
}


command result_t RoutingI.CheckRouteAvailable()
{
    int8_t check=0;

    check = call CentTreeCtrlI.is_associated();

    // we get a response immediately, so signal that this event is done
    // and return the result
    signal RoutingI.CheckRouteAvailableDone(check);

    return SUCCESS;
}

default event result_t RoutingI.CheckRouteAvailableDone(result_t success)
{
    return FAIL;

}


#ifdef USE_ROUTE_ADAPTATION
command result_t RoutingI.SendToRouting(uint8_t* data, uint8_t datasize, uint16_t addr, uint8_t cst, uint8_t rel, uint8_t id){
	int8_t check=0;
	int8_t n=0;
        uint16_t length=0;
        char buf[TOSH_DATA_LENGTH];
	data_hdr_t *data_hdr=(data_hdr_t *)buf;
//	DsePacket_t *p = (DsePacket_t *)(data_hdr->payload + sizeof(mDTN_pkt_t));
	//QueryResponse_t* qResp = (QueryResponse_t*) p->data;        

        length = sizeof(data_hdr_t) + datasize;
        memset(buf, 0, length);

	data_hdr->type = (unsigned char)(id - PKT_TYPE_USER0);

	check = call CentTreeCtrlI.is_associated();

	if (check == 0)
	{
		// no path to sink
 		// FIXME: doesn't have a tos msg header as the upper layer 			// assumes
                //signal RoutingI.SendToRoutingDone(data, datasize, FAIL, (unsigned char)(id - PKT_TYPE_USER0));
		//return SUCCESS;
	        return FAIL;
 	}


	if (busy == 1)
	{
		// already sending a packet... can't handle this atm
                //signal RoutingI.SendToRoutingDone(data, datasize, FAIL, id);
		//return SUCCESS;
                return FAIL;
	}

	
        
        
        // don't use application acks
        //data_hdr->ack_type = DATA_ACK_REQUEST;
	data_hdr->ack_set = 0;

        

	if (datasize > (TOSH_DATA_LENGTH - sizeof(data_hdr_t)))
	{
		dbg(DBG_ERROR, "Packet too long: length = %d\n", datasize);
                //signal RoutingI.SendToRoutingDone(data, datasize, FAIL, id);
		//return SUCCESS;
	        return FAIL;
	}
	else
	{
		memcpy(data_hdr->payload, data, datasize);
	} 

        data_hdr->seq = next_seq;
       

	//dbg(DBG_ERROR,  "Sending Query Response: ID = %d, bitmask = %d, Src %d, Seq %d\n", qResp->queryID, qResp->bitMask, p->hdr.m_uiSrcAddr, p->hdr.m_uiSeq);

        n = call TreeSend.send_pkt_up(&pktbuf, buf, length);
        if (n<0) {
            dbg(DBG_ERROR, "Could not send pkt up the tree: %d", n);
	    //signal RoutingI.SendToRoutingDone(data, datasize, FAIL, id);
	    //return SUCCESS;
            return FAIL;
	} else {
	    dbg(DBG_USR3, "Sending packet from leaf\n");
        }

	return SUCCESS;

}
#endif

event char *TreeRecv.down_pkt_rcvd(uint16_t sender, char *data, 
        uint8_t length)
{
    data_hdr_t *data_hdr = (data_hdr_t *)data;
    
    data_hdr->type = data_hdr->type + PKT_TYPE_USER0;

    dbg(DBG_USR3, "Receiving packet to leaf! Got pkt type %d, SHould be %d, Ack set %d\n",
	data_hdr->type, MULTIHOP_DSE, data_hdr->ack_set);


    if (data_hdr->ack_set==1) {
        if (data_hdr->ack_type==DATA_ACK_REPLY) {
            if (data_hdr->seq != (uint8_t)(next_seq-1)) {

                dbg(DBG_ERROR, "Received ACK pkt for seq %u but expecting one"
                        " for %u!\n", data_hdr->seq, (uint8_t)(next_seq-1));
                
                goto done;
            } else {
                // all is well, set ack_rcvd
                dbg(DBG_USR1, "Received ACK pkt for seq %u from sink %u\n",
                        data_hdr->seq, sender);
                ack_rcvd = 1;
                stats.acks_rcvd++;
                stats.last_ack = data_hdr->seq;
            }

        } else {
            dbg(DBG_ERROR, "Got ack pkt but type is not DATA_ACK_REPLY!");
            goto done;
        }
    } else {

	// signal received packet to the adaptation layer
	// NOTE: we can only receive packets to ourself to here
#ifdef USE_ROUTE_ADAPTATION
        signal RoutingI.RecvFromRouting((unsigned char *)&data_hdr->payload[0], 
		length-sizeof(data_hdr_t), TOS_LOCAL_ADDRESS, sender, 
		data_hdr->type);
#endif  	
    }


   

done:
    return data;
}


event int8_t PktQ.retx_pkt(TOS_Msg *msg)
{
    return RETRANSMIT;
}




}
