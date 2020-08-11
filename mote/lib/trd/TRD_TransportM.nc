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
 * TRD_Transport module that wraps-around the TRD module to provide tid.
 *
 * It adds 'tid' (transaction id) information into the header so that
 * Tenet transport layer can identify tasks.
 * Also, it supports fragmentation of dissemination packets through
 * TRD_Fragment module. Fragmentation is done at end-to-end level, and
 * TRD itself is not aware of the fragmentation that happens at higher layers. 
 * TRD is a generic dissemination protocol that reliably delivers
 * packets to all nodes that runs TRD.
 *
 *            APP
 *             |
 *       TRD_Transport
 *             |
 *       TRD_Fragment
 *             |
 *            TRD
 *
 * Embedded Networks Laboratory, University of Southern California
 * @date Nov/19/2007
 * @author Jeongyeup Paek
 **/

#include "trd_transportmsg.h"

module TRD_TransportM {
    provides interface TRD_Transport;
    uses interface TRD; // as TRD_Fragment;
}

implementation {

    event void TRD.receive(uint16_t origin, uint8_t* payload, uint16_t paylen) {
        TRD_TransportMsg *rtmsg = (TRD_TransportMsg *) payload;
        uint16_t tid = rtmsg->tid;
        paylen = paylen - offsetof(TRD_TransportMsg, data);
        signal TRD_Transport.receive(tid, origin, (void *)rtmsg->data, paylen);
    }

    default event void TRD_Transport.receive(uint16_t tid, uint16_t src, void *data, uint16_t len) {
        return;
    }
}

