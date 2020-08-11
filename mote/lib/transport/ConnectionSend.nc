/*
* "Copyright (c) 2006~2007 University of Southern California.
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
 * Send interface for connection-oriented transport protocol
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 2/5/2007
 **/


interface ConnectionSend {

	/**
     * Opens a transport connection to the 'dstAddr' with transaction id 'tid'.
     *
     * 'openDone' event will be signalled when connection is successfully opened.
     * 'openDone' event will be signalled only when call to 'open' did not return FAIL.
     * The responsibility of re-opening the failed connection is left to the application.
     * 'cid' is a local id that the application uses to send packets.
     *
     * @param  dstAddr: destination address.
     * @param  tid (transaction id): a connection is identified by (src,dst,tid) triple.
     * @return cid (connection id) if the transport is able to accept the request, FAIL(0) otherwise.
     **/
	command uint8_t open(uint16_t tid, uint16_t dstAddr);


	/**
     * Signals the result of 'open' operation to 'dstAddr'
     * 'cid' is the internal connection id, binded to the requested tid-dstAddr pair.
     **/
	event void openDone(uint8_t cid, uint16_t tid, uint16_t dstAddr, result_t success);


	/**
     * Sends a packet to the opened connection 'cid' (connection id)
     *
     * @param cid must be something that was returned by 'open' command.
     * @param length cannot exceed 'maxPayloadLength()'
     **/
	command result_t send(uint8_t cid, uint8_t length, void *data);


	/**
     *  Send done event for 'send'
     **/
	event void sendDone(uint8_t cid, void *data, result_t success);


	/**
     * Closes the active connection with id 'cid' by sending a FIN.
     * Application assumes successful close as long as it has got sendDone for all packets that it sent out.
     *
     * @param cid must be something that was returned by 'open' command.
     **/
	command result_t close(uint8_t cid);


	/**
     * Get maximum payload(data) length that application can use when sending a packet.
     **/
	command uint8_t maxPayloadLength();

}


