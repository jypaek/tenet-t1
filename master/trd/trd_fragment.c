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
 * This file deals with fragmentation and re-assembly of 
 * TRD transport packets on the master.
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

#include <stdlib.h>
#include <string.h>
#include <stddef.h>
#include <unistd.h>
#include "trd_state.h"
#include "trd_interface.h"
#include "trd_fragment.h"
#include "trd_misc.h"
#include "tosmsg.h"

//#define DEBUG_TRD_FRAGMENT

unsigned char *m_fragmented_packet = NULL;
unsigned char *m_next_fragment_ptr = NULL;
uint8_t m_tot_fragment = 0;
uint16_t m_tot_bytes = 0;


void trd_fragment_init() {
    m_fragmented_packet = NULL;
    m_next_fragment_ptr = NULL;
    m_tot_fragment = 0;
    m_tot_bytes = 0;
#ifdef DEBUG_TRD_FRAGMENT
    printf("TOSH_DATA_LENGTH == %d\n", TOSH_DATA_LENGTH);
#endif
    if (((TOSH_DATA_LENGTH - 6) < (offsetof(TRD_FragmentMsg, data) + offsetof(TRD_Msg, data))) ||
        (TOSH_DATA_LENGTH < 20)) {
        printf("Error!! TOSH_DATA_LENGTH too small. Re-define in your Makefile!!\n");
    }
}

int trd_fragment_send(int totlen, unsigned char *msg) {
    unsigned char *packet;
    unsigned char *nextptr;
    TRD_FragmentMsg *fmsg;
    int seqno = -1;
    int maxlen, tmplen, thislen;
    int num_frag, i;

    if ((msg == NULL) || (totlen <= 0))
        return -31;

    maxlen = (TOSH_DATA_LENGTH - 6) - (offsetof(TRD_FragmentMsg, data) + offsetof(TRD_Msg, data));
    tmplen = totlen;
    num_frag = 1;

    while (tmplen > maxlen) {
        tmplen -= maxlen;
        num_frag++;
    } // at this point, 'tmplen' has the length of the last fragment

    nextptr = msg; // pointer to the original packet

#ifdef DEBUG_TRD_FRAGMENT
    if (num_frag > 1) {
        printf("TRD dissemination packet size larger than MTU(%d), fragmenting....\n ", maxlen);
        trd_dump_raw(stdout, msg, totlen);
    }
#endif
    
    for (i = 1; i <= num_frag; i++) {   // STARTING FROM 1, (not 0)
        if (i == num_frag)          // last fragment
            thislen = tmplen;
        else                        // not last
            thislen = maxlen;

        packet = malloc(thislen  + offsetof(TRD_FragmentMsg, data));
        if (packet == NULL)
            return -32;
        
        fmsg = (TRD_FragmentMsg *)packet;
        fmsg->index = i;
        fmsg->tot_fragment = num_frag;
        fmsg->length = thislen;
        fmsg->pad = 0xAB;
        fmsg->tot_bytes = nxs(totlen);
        memcpy(fmsg->data, nextptr, thislen);

        nextptr += thislen;
        thislen += offsetof(TRD_FragmentMsg, data);

        seqno = trd_send(thislen, (uint8_t *) fmsg);
        //usleep(1000);
    #ifdef DEBUG_TRD_FRAGMENT
        if (num_frag > 1) {
            printf(" |fragment %d: ", i);
            trd_dump_raw(stdout, packet, thislen);
        } else {
            printf(" |one-packet : ");
            trd_dump_raw(stdout, packet, thislen);
        }
    #endif
        
        free((void *)packet);
    }    
    return seqno;
}

/* Assumes that receive_trd_fragment function is implemented by user */
void receive_trd(int sender, int len, unsigned char *msg) {
    TRD_FragmentMsg *fmsg = (TRD_FragmentMsg *)msg;
    uint8_t index = fmsg->index;
    uint8_t tot_fragment = fmsg->tot_fragment;
    uint8_t thislen = fmsg->length;
    uint16_t tot_bytes = nxs(fmsg->tot_bytes);

    trd_dump_raw(stdout, msg, len);

    len -= offsetof(TRD_FragmentMsg, data);
    if (len != thislen) {
        printf("length error, len %d, thislen %d\n", len, thislen);
        return;
    }

    if (index == 1) {
        if (m_fragmented_packet != NULL) {
            printf("error, previous fragmented packet not finished\n");
            free((void *)m_fragmented_packet);
            m_fragmented_packet = NULL;
        }
        m_fragmented_packet = malloc(tot_bytes);
        m_tot_fragment = tot_fragment;
        m_tot_bytes = tot_bytes;
        memcpy(m_fragmented_packet, fmsg->data, len);
        m_next_fragment_ptr = m_fragmented_packet + len;
    } else {
        if (m_fragmented_packet == NULL) {
            printf("error, fragmented packet received in wrong sequence\n");
            return;
        }
        memcpy(m_next_fragment_ptr, fmsg->data, len);
        m_next_fragment_ptr = m_next_fragment_ptr + len;
    }
        
    if (tot_fragment == index) {
        if (m_next_fragment_ptr != (m_fragmented_packet + m_tot_bytes))
            printf("this might be a pointer error... check trd_fragment.c\n");
        receive_trd_fragment((uint16_t)sender, m_tot_bytes, m_fragmented_packet);
        free((void *)m_fragmented_packet);
        m_fragmented_packet = NULL;
        m_tot_bytes = 0;
        m_tot_fragment = 0;
        m_next_fragment_ptr = NULL;
    }
}

