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
 * TRD_Transport configuration file does all necessay wirings that 
 * TRD-related modules require to be used in Tenet as the dissemination 
 * transport mechanism.
 *
 * TRD_Transport wraps-around (sits on top of) the TRD module.
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

configuration TRD_TransportC {
    provides interface TRD_Transport;
}
implementation {
    components TRD_TransportM
               , TRD_FragmentM
               , TRD_C
               ;

    TRD_Transport = TRD_TransportM;

    TRD_TransportM.TRD -> TRD_FragmentM; // Transport on top of Fragment
    TRD_FragmentM.TRD -> TRD_C;          // Fragment on top of TRD
}

