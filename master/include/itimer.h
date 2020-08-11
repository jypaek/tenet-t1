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
* Modified: 1/11/2006
*/


#ifndef _ITIMER_H_
#define _ITIMER_H_

#include <sys/time.h>
typedef int (*itimer_handler_t)(int);

/******************************************
  interfaces to access itimer
******************************************/


/* this should be called once when the process boots up */
void itimer_initialize();

/* you must 'create' a timer instance before using.
	- return 'timer_id' to the caller
	- user_id is something that you want to be returned to you later
	  when the timer fires and handler is called */
int itimer_create(int user_id, itimer_handler_t handler);

/* you can always start/stop the created timer as many times as you want
	- you must access the timer using the 'timer_id' returned by 'create'
	- 'type' can be either ITIMER_ONE_SHOT, or ITIMER_REPEAT */
int itimer_start(int timer_id, char type, unsigned long int interval_ms);

/*  - 'stop' does not remove the timer. it just stops firing. */
int itimer_stop(int timer_id);

/* once you are done, remove the timer instance to avoid memory leak. */
int itimer_remove(int timer_id);



////////////////////////////////////////////////////////////////////

struct itimerlist {
	struct itimerlist *next; 	// linked list pointer
	int timer_id;				// timer id
	int user_id;				// user-assigned id, returned through handler
	int state;					// state & type
	struct timeval fire_time;	// next fire time
	struct timeval interval;	// repeat interval
	itimer_handler_t handler;	// fire handler
};

enum {
	ITIMER_IDLE = 0,	// stopped
	ITIMER_ONE_SHOT = 1,	// running, once
	ITIMER_REPEAT = 2,	// running, repeat
};

#endif

