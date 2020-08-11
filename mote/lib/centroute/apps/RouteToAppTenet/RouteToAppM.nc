////////////////////////////////////////////////////////////////////////////
//
// CENS
//
// Copyright (c) 2006 The Regents of the University of California.  All
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
//includes MultihopTypes;
//includes QueryTypes;
//includes ConfigConst;
//includes eeprom_logger;
//includes mDTN;

module RouteToAppM
{
  provides
  {
    interface StdControl;
    interface RoutingSend as Send[uint8_t protocol];
    interface RoutingReceive as Receive[uint8_t protocol];
    
    
    
  }
  uses
  {
    interface RoutingI; 
    
  }
}
implementation
{
 
#include "link_types.h"
#include "routinglayer.h"

  command result_t StdControl.init( ){
    dbg(DBG_ERROR, "Starting RouteToApp!\n");	

    return SUCCESS;
  }

  command result_t StdControl.start( ){
    dbg(DBG_ERROR, "Starting RouteToApp!\n");	
    
    return SUCCESS;
  }

  command result_t StdControl.stop( ){
    return SUCCESS;
  }

  // packet sent from application layer, to be forwarded to routing layer
  command result_t Send.send[uint8_t proto](uint16_t address, uint8_t length, TOS_MsgPtr msg) {
    result_t res;

    dbg(DBG_ERROR, "Asked to send packet of type %d from application\n", proto);
  
    msg->addr = address;
    msg->type = PKT_TYPE_CENTROUTE_DATA;	
    msg->group = TOS_AM_GROUP;
    msg->length = length;

    res = call RoutingI.SendToRouting(msg->data, length, address, 0, 0, proto);
    
    return res;
  }


  command void* Send.getPayload[uint8_t proto](TOS_MsgPtr msg, uint8_t* length) {
        // note that the centroute header is variable length (since it adds
	// an entry for each hop)
        if (length != NULL)
            *length = TOSH_DATA_LENGTH - sizeof(up_hdr_t);
        return (void *) &msg->data;
    }

    command uint8_t Send.maxPayloadLength[uint8_t proto]() { 
        // note that the centroute header is variable length (since it adds
	// an entry for each hop)
	return TOSH_DATA_LENGTH - sizeof(up_hdr_t); 
    }

  
  event result_t RoutingI.CheckRouteAvailableDone(result_t success)
  {
    if (success != SUCCESS)
    {
      dbg(DBG_USR3,"Route to sink not available!\n");
    }

    return SUCCESS;
  }

  

  // a packet has been received 
  event result_t RoutingI.RecvFromRouting(uint8_t *data, uint8_t datasize,uint16_t to_address, uint16_t from_address, uint8_t type)
    {
	TOS_Msg *tos_msg = (TOS_Msg *)data;

	dbg(DBG_ERROR, "Got a packet of type %d, %u from Routing\n", type,
	(unsigned char)(type - PKT_TYPE_USER0));

	// subtract size of the TOS_Msg header
	signal Receive.receive[type](
                            from_address, data, 
                            (tos_msg->data), datasize - offsetof(TOS_Msg, data));
                            

    return SUCCESS;
  }


  event result_t RoutingI.SendToRoutingDone(uint8_t *data, uint8_t datasize,
	result_t success, uint8_t type){
	TOS_Msg *msg = (TOS_Msg *)data;
	tree_hdr_t *tree_hdr = (tree_hdr_t *)(msg->data);
	up_hdr_t *up_hdr=(up_hdr_t *)(tree_hdr->data);
        uint8_t offset = sizeof(up_hdr_t) + sizeof(up_path_entry_t) *
                up_hdr->path_entries;
        data_hdr_t *data_hdr;
	int length;
	uint8_t my_type;	
	uint8_t *my_data;

        data_hdr = (data_hdr_t *)(&tree_hdr->data[offset]);
	length = msg->length - sizeof(tree_hdr_t) - offset + 2;
		
	if (type == 0)
	{
            dbg(DBG_ERROR, "Type from data header\n");
	    // get the type from the data header
            my_type = data_hdr->type;
            my_data = data_hdr->payload;
	}
        else
        {
	    dbg(DBG_ERROR, "Type from parameters\n");
            // the type is provided in the parameter list
            my_type = type;
	    my_data = data;
        }

	dbg(DBG_ERROR, "Send done of packet type %d, fixed type %u\n", my_type,
	(unsigned char)(my_type + PKT_TYPE_USER0));

      signal Send.sendDone[my_type + PKT_TYPE_USER0](
                                 up_hdr->final_dst, 
                                 msg->addr, 
                                 msg, 
                                 my_data, 
                                 success);

      //signal ApplicationI.SendFromApplicationDone(success);
      return SUCCESS;
  }

  event result_t RoutingI.RouteForwardFailed(uint8_t *data, uint8_t datasize)
  {

//      signal ApplicationI.RouteForwardFailed(data, datasize);

      return SUCCESS;
  }

  

  default event result_t Send.sendDone[uint8_t proto](uint16_t destAddr, 
                                         uint16_t nextHop, TOS_MsgPtr msg, 
                                         void* payload, result_t success) {
	dbg(DBG_ERROR, "Oh noes, invalid type %d\n", proto);
        return SUCCESS;
    }
    default event void Receive.receive[uint8_t proto](uint16_t srcAddr, 
                                       TOS_MsgPtr msg, void* payload, uint8_t paylen) {

	dbg(DBG_ERROR, "Oh noes, invalid type %d\n", proto);
        return;
    }

}
