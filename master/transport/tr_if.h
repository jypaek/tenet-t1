/*
* "Copyright (c) 2006 University of Southern California.
* All rights reserved.
*
* Permission to use, copy, modify, and distribute this software and its
* documentation for any purpose, without fee, and without written
* agreement is hereby granted, provided that the above copyright
* notice, the following two paragraphs and the author appear in all
* copies of this software.
*
* IN NO EVENT SHALL THE UNIVERSITY OF SOUTHERN CALIFORNIA BE LIABLE TO
* ANY PARTY FOR DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL
* DAMAGES ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS
* DOCUMENTATION, EVEN IF THE UNIVERSITY OF SOUTHERN CALIFORNIA HAS BEEN
* ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*
* THE UNIVERSITY OF SOUTHERN CALIFORNIA SPECIFICALLY DISCLAIMS ANY
* WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
* MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.  THE SOFTWARE
* PROVIDED HEREUNDER IS ON AN "AS IS" BASIS, AND THE UNIVERSITY OF
* SOUTHERN CALIFORNIA HAS NO OBLIGATION TO PROVIDE MAINTENANCE,
* SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS."
*
*/

/**
 * Header file for the interface between the application and the transport:
 * format(encapsulate/decapsulate) packets in appropriate way so that
 * the application and the transport layer can communicate with each other.
 * 
 * Applications can use functions below to send commands/packets to
 * the transport layer, and read/understand the packets that the transport
 * layer has sent to the application.
 * 
 * Transport layer can use functions below to send commands/packets to
 * the application, and read/understand the packets that the application
 * layer has sent to the transport layer.
 * 
 * In the Tenet context, the word 'application' in above paragraphs are
 * in fact the tasking libarary.
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 7/11/2007
 **/

#ifndef _TRANSPORT_IF_H_
#define _TRANSPORT_IF_H_

#include "common.h"


/**
 * Any application that connects to the transport layer should call
 * either one of below two functions to send a task:
 *  - tr_send_task
 *  - tr_send_task_uni
 * Latter is for possible unicast (officially no supported in Tenet).
 * The 'transport' waits for response from the mote: maintains the tid-socket 
 * association list and forwards the response packet to the application.
 * This binding between the applications socket descriptor and the tid is 
 * maintained in a tid_list of transport layer;
 **/

/* USE tid=0 to automatically assign tid for a task */
int tr_send_task(int tr_fd, int len, uint8_t *packet);
int tr_close_task(int tr_fd, uint16_t tid);

/* unicast functions (officially NOT supported in Tenet) */
int tr_send_task_uni(int tr_fd, uint16_t addr, int len, uint8_t *packet);
int tr_close_task_uni(int tr_fd, uint16_t tid, uint16_t addr);

/**
 * You can send a command to listen to all packets that are sent from the 
 * transport layer to all applications/clients that are connected to the 
 * transport layerr; You should 'read_transport_msg' after sending this command.
 **/
int tr_listen(int tr_fd);


////////////////////////////////////////////////////////////////////////////////

/**
 * You can directly construct and send a packet to the transport layer
 * using 'write_transport_msg' function instead of above two
 * 'send_*_transactional_task' functions. 
 **/
int write_transport_msg(int fd, uint8_t *msg, int len, int type, uint16_t tid, uint16_t addr);

/**
 * 'read_transport_msg' should be used to read any packet from the 
 * transport layer.
 **/
void *read_transport_msg(int fd, int *len, uint8_t *type, uint16_t *tid, uint16_t *addr, void **payload);


////////////////////////////////////////////////////////////////////////////////

/** 
 * When the application sends messages to the transport layer,
 * the transport layer will respond with the below types of messages. 
 **/
enum {
    TRANS_TYPE_NULL       = 0x00,   // NULL transaction

    // These are the types from PC-app to PC-transport
    TRANS_TYPE_TASK       = 0x01,   // (send) TASK (transactional command)
    TRANS_TYPE_CMD_RETURN = 0x02,   // return tid, but neither ACK nor NACK
    TRANS_TYPE_CMD_ACK    = 0x03,   // ACK for successful command
    TRANS_TYPE_CMD_NACK   = 0x04,   // NACK for un-successful command

    TRANS_TYPE_CLOSE      = 0x05,   // close the transaction (tid association)
    TRANS_TYPE_CLOSE_ACK  = 0x06,   // close done

    TRANS_TYPE_RESPONSE   = 0x11,   // any response from the mote world

    TRANS_TYPE_SERVICE    = 0x22,   // service message (timesync, id, power, etc)
    TRANS_TYPE_PING       = 0x23,   // ping
    TRANS_TYPE_TRACERT    = 0x24,   // trace route

    TRANS_TYPE_BCAST      = 0x30,   // broadcasted message
    TRANS_TYPE_SNOOP      = 0x31,   // try to listen(snoop) to all packets above transport
};

typedef struct tr_if_msg_t {
    uint16_t tid;
    uint16_t addr;
    uint8_t type;
    uint8_t pad;
    uint8_t data[0];
} tr_if_msg_t;


#endif

