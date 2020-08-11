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

/*
* Authors: Jeongyeup Paek
* Embedded Networks Laboratory, University of Southern California
* Modified: 2/26/2006
*/

interface TRD_Transport {

    // TRD_Transport.receive
    //  - Received an TRD_Transport packet from 'srcAddr' with specific 'tid'
    event void receive(uint16_t tid, uint16_t srcAddr, void *data, uint16_t len);


#ifdef TRD_SEND_ENABLED
    // TRD_Transport.send
    //  - Sends a single transport packet with specified 'tid'
    command result_t send(uint16_t tid, uint8_t length, void *data);

    // TRD_Transport.sendDone
    //  - Send done event for 'send'
    event result_t sendDone(uint16_t tid, void *data, result_t success);

    command uint8_t getDataLength();
#endif
}


