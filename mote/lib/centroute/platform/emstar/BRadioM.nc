/* -*- Mode: C; c-basic-indent: 4; indent-tabs-mode: nil -*- */
/* ex: set tabstop=4 expandtab shiftwidth=4 softtabstop=4: */

includes tos_emstar;
includes EmStar;

module BRadioM {
	provides {
		interface StdControl as Control;
		interface ReceiveMsg as Receive;
		interface BareSendMsg as Send;
	}

	uses {
		interface StdControl;
                interface SysTime;
//		interface Pot;
	}
}


#define MAX_RECV_BUF_SIZE       4096

implementation {
  
  #include "emtos_i.h"
#include "trd.h"
#include "emstar_interprocess.h"
#include "tos_emstar.h"

TOS_Msg *sendBuf;
TOS_Msg recvBuf;

// Adding the receive pointer to keep 'buffer swapping' semantics correct
TOS_Msg *recvPtr = &recvBuf;

uint8_t send_pending=0;
uint8_t receive_pending=0;
uint32_t packet_dropped=0;
uint8_t bradio_initialized=0;



/*
 *  conversion functions from link pkt <-> tos msg
 */

 link_pkt_t *convert_tos_msg_to_link_pkt(TOS_Msg *msg, int *length_to_send)
{
    link_pkt_t *pkt=NULL;
    char *buf=NULL;

    if (msg==NULL) {
        printf("NULL TOS_Msg\n");
        fflush(stdout);
        exit(1);
    }


    // I am probably allocating a few more bytes than needed but it's ok
    buf = (char *)malloc(sizeof(TOS_Msg) + sizeof(link_pkt_t) + msg->length);

    // Again, copying off of bradio
    memset(buf, 0, sizeof(TOS_Msg) + sizeof(link_pkt_t) + msg->length);
    
    pkt = (link_pkt_t *)buf;

    if (msg->addr == TOS_BCAST_ADDR) {
        pkt->dst.id=LINK_BROADCAST;
    } else {
        /* extend address with high order bits of full IF address */ 
        pkt->dst.id=msg->addr | (get_my_if_id() & 0xFFFF0000);
    }


    pkt->type=PKT_TYPE_TOS; // use native, no-encap mode

    pkt->ext_type = msg->type;
    pkt->ext_group = msg->group;

    // do we want to copy the tos header and the payload, or just the payload?
    if ((msg->type == AM_TRD_MSG) ||
        (msg->type == AM_TRD_CONTROL))
      {
        // copy the tos header and the payload
        memcpy(pkt->data, (char *)msg, msg->length + MSG_HEADER_SIZE);
        *length_to_send = msg->length + MSG_HEADER_SIZE;

      }
    else
      {
        // copy the payload only
        memcpy(pkt->data, (msg->data), (msg->length));
        *length_to_send = msg->length;
      }

    return pkt;

}



void convert_link_pkt_to_tos_msg(TOS_Msg *pkt, link_pkt_t *data, int16_t datalen, int valid, int ignore_group)
{
  //link_pkt_t *link_pkt = (link_pkt_t *)data;

  if (datalen > TOSH_DATA_LENGTH) { 
      dbg(DBG_ERROR, 
           "Invalid length %d, max is %d.  Marking pkt as invalid (crc field was %d)\n",
           datalen, TOSH_DATA_LENGTH, valid);
      datalen = TOSH_DATA_LENGTH;
      valid = 0;
    }
    
  // if this is a tenet raw type packet, just copy it through unmodified
  if ((data->ext_type == AM_TRD_CONTROL) ||
      (data->ext_type == AM_TRD_MSG))
    {
      memcpy((char *)pkt, data->data, datalen);
      pkt->crc = valid;
    }
  else
    {

      pkt->addr = (uint16_t)(data->dst.id & 0xFFFF);
      pkt->type = data->ext_type;
      pkt->group = ignore_group ? TOS_AM_GROUP : data->ext_group;
      pkt->length = datalen;
      memcpy(pkt->data, data->data, datalen);
      pkt->crc = valid;
      pkt->strength = data->rssi;
      pkt->lqi = data->lqi;
      pkt->time = emtos_gettimeofday();
    }
    

    dbg(DBG_USR3, "Got to here 2: out tos msg %p, length = %d, without link pkt %d, in link pkt %p, in data %p, out data %p, in diff %lu, out diff %lu\n",
        pkt, datalen, datalen - sizeof(link_pkt_t), data, data->data, pkt->data, (unsigned long)data->data - (unsigned long)data, 
        (unsigned long)pkt->data - (unsigned long)pkt);

    //print_chunk(pkt->data, datalen);
    
    dbg(DBG_USR3, "Original: \n");
    //print_chunk(data->data, datalen);
}


void task pktReceivedTask()
{
  if (receive_pending==1) {
#if 0
      /* this is removed because both sim and motenic pass through am_group.
       * udp does not, but that is a bug that needs to be fixed (along with
       * passing through ext_type -LDG */
    	if (recvPtr->group != TOS_AM_GROUP) {
    		recvPtr->group=TOS_AM_GROUP;
    	}
#endif
        
        signal Receive.receive(recvPtr);
        //recvPtr = signal Receive.receive(recvPtr);
        receive_pending=0;
        emtos_bradio_enable_readable();

    } else {
        dbg(DBG_ERROR, "***** receive_pending was 0 inside received Task! THIS IS BAD*****\n");
        //exit(0);
    }
        
}


void sendDone(int8_t retval)
{
  dbg(DBG_USR3, "Sending send done signal!\n");

    if (send_pending==1) {
        send_pending=0;
        // TODO: Use defines and fix this...
        sendBuf->ack = (retval == SD_SUCCESS_ACK) ? 1 : 0;
        signal Send.sendDone(sendBuf, (retval == SD_FAIL) ? FAIL : SUCCESS);
        // Normally, we should NEVER have been called with send_pending==0
    } else {
        dbg(DBG_ERROR, "***** send_pending was 0 inside senddone! THIS IS BAD*****\n");
        exit(1);
    }
}


 void pktReceived(link_pkt_t *link_pkt, int16_t datalen, int8_t valid, 
                  int8_t ignore_group, client_socket_type_t socket_type)
{
  
  
    if (receive_pending==0) {

      dbg(DBG_USR3, "Received here: %p, len %d, valid %d, ignore group %d, recvptr %p\n",
      link_pkt, datalen, valid, ignore_group, recvPtr);

      if (socket_type == CLIENT_TYPE_TCP)
        {
          dbg(DBG_USR3, "Got TCP tos_msg!\n");
          //print_chunk(link_pkt, datalen);
          memcpy(recvPtr, link_pkt, datalen);
          recvPtr->crc = valid;
        }
      else
        {
          dbg(DBG_USR3, "Got UNIX link_pkt!\n");
  
          convert_link_pkt_to_tos_msg(recvPtr, link_pkt, datalen, valid, 
                                      ignore_group);
        }

      
      receive_pending=1;
      if ((post pktReceivedTask())==0) {
        dbg(DBG_ERROR, "Error adding pkt received task!\n");
        // great...
        //emtos_bradio_enable_readable();
        packet_dropped++;
        receive_pending=0;
      }
      

    } else {
        dbg(DBG_ERROR, "******* Receive_pending was 1 THIS IS ALSO BAD!\n");
        // XXX: making it failstop for now
        //exit(1);
    }
  

}


command result_t Control.init()
{
    emtos_state_t *emt = emstar_getState();
    fp_list_t *fplist=get_fplist();
    if (bradio_initialized==1) {
        return SUCCESS;
    } else {
        bradio_initialized=1;
    }
    // set the fps for sendDone and pkt_rcvd
    fplist->RadioSendDone=sendDone;
    fplist->RadioReceive=pktReceived;
    recvPtr = &recvBuf;

    emtos_init_bradio_link(fplist, emt->channel_type, emt->host_str, 
                           emt->port_number);
}


command result_t Control.start()
{
    return SUCCESS;
}


command result_t Control.stop()
{
    return SUCCESS;
}


default event TOS_Msg *Receive.receive(TOS_Msg *msg)
{
  dbg(DBG_ERROR, "Oh noes, bad id for ReceiveMsg.receive 1\n");
	return NULL;
}


command result_t Send.send(TOS_Msg *msg)
{
    link_pkt_t *pkt=NULL;
    int length_to_send;
#ifdef USE_TENET
    if (send_pending==0) {
        sendBuf=msg;
        // add 5 bytes for length of tos header
        if (emtos_send_bradio_packet(msg, msg->length + MSG_HEADER_SIZE, CLIENT_TYPE_TCP) == 1) {
            send_pending=1;
            sendDone(SD_SUCCESS_ACK);
            return SUCCESS;
        } else {
            return FAIL;
        }
    } else {
        return FAIL;
    }
    

#else
    pkt = convert_tos_msg_to_link_pkt(msg, &length_to_send);


    if (send_pending==0) {
        sendBuf=msg;
        if (emtos_send_bradio_packet(pkt, length_to_send, CLIENT_TYPE_UNIX) == 1) {
            send_pending=1;
            return SUCCESS;
        } else {
            return FAIL;
        }
    } else {
        return FAIL;
    }
#endif
}


}
