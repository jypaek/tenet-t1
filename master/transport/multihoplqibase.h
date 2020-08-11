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
 * Header file for MultihopLQI routing protocol, for beaconing from the master.
 *
 * BELOW STRUCTURES ARE COPIED FROM MOTE/LIB/ROUTER/MULTIHOPLQI/MULTIHOP.H
 * BELOW STRUCTURES ARE COPIED FROM MOTE/LIB/ROUTER/MULTIHOPRSSI/MULTIHOP.H
 *
 * This is an optional functionality at the master transport.
 * Default behavior is that the BaseStation mote send out MultihopLQI beacons
 * so that other motes can attach to that BaseStation. And the transport layer
 * has nothing to do with this mote routing.
 * But optionally, we can substitue the BaseStation mote with a TOSBase mote
 * (which does not have routing func.), and let this module send out the
 * routing beacons so that motes can behave identically.
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 8/19/2007
 **/

#include "tosmsg.h"

typedef struct MultihopMsg {
  uint16_t sourceaddr;
  uint16_t originaddr;
  int16_t seqno;
  uint8_t data[(TOSH_DATA_LENGTH - 6)];
} TOS_MHopMsg;

typedef struct BeaconMsg {
  uint16_t parent;
  uint16_t cost;
  uint16_t hopcount;
} BeaconMsg;

enum {
    BEACON_PERIOD        = 32,
};

void multihoplqi_beacon_timer_start();
void polling_multihoplqi_beacon_timer();

