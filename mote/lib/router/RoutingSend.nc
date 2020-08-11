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
 * Send interface that the routing layer provides to upper layers.
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 1/24/2007
 **/



includes AM;

interface RoutingSend {

	/**
     * Command the routing layer to send the 'msg' to 'dstAddr'.
     *
     * 'dstAddr' may be multiple hops away.
     * Upper layer should maintain the actual buffer space for 'msg'.
     * Upper layer should use the 'getPayload' command to get the pointer
     * to which it writes the payload to; (within TOS_Msg). 
     *
     * @param msg TOS_Msg pointer that contains the packet.
     * @param length length of the payload.
     **/
	command result_t send(uint16_t dstAddr, uint8_t length, TOS_MsgPtr msg);


	/**
     * Routing layer has sent the 'msg' to 'dstAddr' via 'nextHop'.
     *
     **/
	event result_t sendDone(uint16_t dstAddr, uint16_t nextHop, 
	                        TOS_MsgPtr msg, void* payload, result_t success);


	/**
     * Returns the pointer to the payload part of the routing msg.
	 * This does the same thing as getPayload command in Send.nc interface.
     *
     **/
	command void* getPayload(TOS_MsgPtr msg, uint8_t* length);


	/**
	 * Returns the maximum payload length that can be used.
     *
     **/
	command uint8_t maxPayloadLength();
}

