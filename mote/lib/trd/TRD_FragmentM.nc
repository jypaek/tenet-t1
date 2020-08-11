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
 * TRD_Fragment module deals with fragmentation and re-assembly of 
 * TRD_Transport packets.
 *
 * Fragmentation is done at end-to-end level, and underlying TRD module
 * is not aware of the fragmentation that happens at this layer. 
 *
 *            APP
 *             |
 *       TRD_Transport
 *             |
 *       TRD_Fragment
 *             |
 *            TRD
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 8/21/2006
 **/

#include "trd_fragmentmsg.h"

module TRD_FragmentM {
    provides interface TRD as TRD_Fragment;
    uses interface TRD;
}

implementation {

    uint8_t m_buf[255]; // cannot exceed 255 bytes anyway (length field is 1byte)
    uint8_t *m_fragmented_packet = NULL;
    uint8_t *m_next_fragment_ptr = NULL;
    uint8_t m_tot_fragment = 0;
    uint16_t m_tot_bytes = 0;

    /**
     * Receive TRD packet and try to re-assemble any fragmented packets.
     * This assumes in-order delivery of fragmented packets, and
     * this is fine since TRD guarantees in-order delivery.
     * -jpaek.
     **/
    event void TRD.receive(uint16_t origin, uint8_t* payload, uint16_t paylen) {
        TRD_FragmentMsg *fmsg = (TRD_FragmentMsg *)payload;
        uint8_t tot_fragment = fmsg->tot_fragment;
        uint8_t thislen = fmsg->length;
        uint16_t tot_bytes = fmsg->tot_bytes;

        if ((fmsg->index == 1) && (tot_fragment == 1)) { // non-fragmented packet.
            signal TRD_Fragment.receive(origin, (void *)fmsg->data, tot_bytes);
            return;
        }
        else {
        
            if (fmsg->index == 1) { // this is the first fragment
                if (m_fragmented_packet != NULL) { // any previous incomplete packet?
                    m_fragmented_packet = NULL;
                }
                m_fragmented_packet = &m_buf[0]; // no un-stable malloc anymore
                m_tot_fragment = tot_fragment;
                m_tot_bytes = tot_bytes;
                memcpy(m_fragmented_packet, fmsg->data, thislen);
                m_next_fragment_ptr = m_fragmented_packet + thislen;
            } 
            else {                 // following fragment
                if (m_fragmented_packet == NULL) {  // we don't have the first fragment
                    return;                         // give up
                } else if ((m_tot_fragment != tot_fragment) || // something is wrong!!
                           (m_tot_bytes != tot_bytes) ||      // mixed fragments
                           ((m_next_fragment_ptr + thislen) 
                             > (m_fragmented_packet + m_tot_bytes))) {// pointer out of bound
                    // no need to check order (within same sender)
                    // since TRD guarantee in-order delivery (within same sender)
                    m_fragmented_packet = NULL;
                    return;
                }

                memcpy(m_next_fragment_ptr, fmsg->data, thislen);
                m_next_fragment_ptr = m_next_fragment_ptr + thislen;

                if (tot_fragment == fmsg->index) { // this is the last fragment
                    signal TRD_Fragment.receive(origin, (void *)m_fragmented_packet, m_tot_bytes);
                    m_fragmented_packet = NULL;
                    m_tot_bytes = 0;
                    m_tot_fragment = 0;
                    m_next_fragment_ptr = NULL;
                }
            }
        }
    }

    default event void TRD_Fragment.receive(uint16_t origin, uint8_t *data, uint16_t len) {
        return;
    }
}

