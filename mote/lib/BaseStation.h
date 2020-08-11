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
 * Header file for BaseStation services.
 *
 * - AM ID allocation for base station functionalities.
 * - Time query/response message structure.
 * - BaseStation node ID query/response message structure.
 * - BaseStation RF power query/response message structure.
 *
 * @author Jeongyeup Paek
 * @author Omprakash Gnawali
 * @modified 3/1/2007
 **/

#ifndef _BASESTATION_H_
#define _BASESTATION_H_

enum {
    AM_BS_SERVICE = 0xBB,
};

enum {
    BS_SERVICE_TIME = 0xC1,
    BS_SERVICE_ID = 0xC2,
    BS_SERVICE_POWER = 0xC3,
};

typedef struct BaseStationServiceMsg {
    uint16_t tid;   // TID, transaction id
    uint16_t type;  // sequence number used at transport layer
    uint8_t data[0];
}  __attribute__ ((packed)) BaseStationServiceMsg;

typedef struct BS_IdMsg {
	uint16_t base_id;
} __attribute__ ((packed)) bs_idMsg;

typedef struct BS_PowerMsg {
	uint16_t base_power;
} __attribute__ ((packed)) bs_powerMsg;

/**
 * Message structure for Time Query and Response.
 * tid is necessary to return the response to the client that
 * issued the query.
 **/
typedef struct BS_TimeRequestMsg {
	uint32_t time;
} __attribute__ ((packed)) bs_timeRequestMsg;

typedef struct BS_TimeResponseMsg {
	uint32_t time;
	uint32_t localfreq;
	uint16_t root;
	float skew;
} __attribute__ ((packed)) bs_timeResponseMsg;

#endif

