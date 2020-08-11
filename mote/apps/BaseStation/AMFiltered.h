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
 * AMFiltered.h
 *
 * Reserves certain message types that should not be forwarded
 * between the radio and UART.
 *
 * @author Jeongyeup Paek
 * @modified 3/1/2007
 **/

#include "BaseStation.h"
#include "TimeSyncMsg.h"
#include "TestTimeSyncMsg.h"

#ifndef _AM_FILTERING_H_
#define _AM_FILTERING_H_


/* returns TRUE for all messages that should not be forwarded
 * between the radio and UART.
 */

    bool isFiltered(uint8_t typeid) {

        /* FTSP messages */
        if ((typeid == AM_TIMESYNCMSG) || (typeid == AM_TIMESYNCPOLL)) {
            // 0xAA, 0xBA respectively. (AM_TIMESYNCDEBUG = 0xBD)
            // These types are reserved in TimeSyncMsg.h and TimeSyncPollerMsg.h
            // in mote/lib/timesync.
            return TRUE;
        } 
        /* BaseStation Service */
        else if (typeid == AM_BS_SERVICE) {
            // 0xBB
            return TRUE;
        }
        /* AM ID for MultiHopLQI beacons */
        else if (typeid == AM_ROUTING_BEACON) {
            // 0x01
            return TRUE;
        }
        /* All other AM_type's are not filtered */
        else  {
            return FALSE;
        }
    }

#endif

