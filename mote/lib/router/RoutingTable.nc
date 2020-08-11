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
 * Routing Table Interface
 *
 * This interface defines the functions used to access the routing
 * next hop (parent) and the number of hops from the root.
 *
 * @author Omprakash Gnawali
 * @author Jeongyeup Paek
 * @modified 1/11/2006
 * @modified 6/16/2006 - added 'getMaster'
 * @modified 5/19/2008 - added 'getLinkRssi'
 **/

interface RoutingTable {
    command uint16_t getParent();   // my 1-hop parent towards the nearest master
    command uint8_t getDepth();     // hop count to the nearest master
    command uint16_t getMaster();   // nearest master id
    command uint16_t getLinkEst();  // get converted link estimation value (to it's parent)
    command int16_t getLinkRssi();  // get dBm value of rssi (to it's parent)
}

