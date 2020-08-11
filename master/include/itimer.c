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

#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "timeval.h"
#include "itimer.h"

//#define DEBUG_ITIMER
struct itimerlist *itimers;


int signal_itimer_fired(struct itimerlist *t);
void quit_signal_handler(int signo);
void sig_alarm_handler(int signo);
unsigned long remaining_time_till_next_signal();
int set_itimer_interval(struct timeval *interval);
int set_itimer_firetime(struct timeval *atime);
int stop_itimer(struct itimerlist *t);
struct itimerlist *add_itimer(int timer_id, int user_id, itimer_handler_t handler);
struct itimerlist *find_itimer(int timer_id);
int remove_itimer(int timer_id);
void print_itimerlist_state();
void print_itimer(struct itimerlist *t);
void print_all_itimers();	
int get_unique_itimer_id();

/******************************************
  Global variables.
******************************************/
int itimer_initialized = 0;
int num_itimers = 0;
int num_active_itimers = 0;
struct itimerlist *earliest_timer = NULL;


/******************************************
  init
******************************************/
void itimer_initialize() {
	if (itimer_initialized)
		return;
	itimer_initialized = 1;
	if(signal(SIGALRM, sig_alarm_handler) == SIG_ERR) {
		fprintf(stderr, "signal() error");
		exit(-1);
	}
	/*
	if(signal(SIGINT, quit_signal_handler) == SIG_ERR) {
		FatalError("signal() error");
		exit(-1);
	}
	*/
}


/******************************************
  signal handler
******************************************/

int signal_itimer_fired(struct itimerlist *t) {
	if (t == NULL)
		return -1;
	return (*t->handler)(t->user_id);
}

void quit_signal_handler(int signo) {
	return;
}

void sig_alarm_handler(int signo) {
	struct timeval curr, curr_1;
	struct itimerlist *t;
	earliest_timer = NULL;

	gettimeofday(&curr, NULL);
	add_ms_to_timeval(&curr, 1, &curr_1);

#ifdef DEBUG_ITIMER
	printf("itimer_sig_alarm_fired at time %lu\n", tv2ms(&curr));
#endif

	for (t = itimers; t; t = t->next) {
		if (t->state > 0) {
			if (compare_timeval(&t->fire_time, &curr_1) <= 0) {
				if (t->state == ITIMER_REPEAT) { 
					add_timeval(&t->fire_time, &t->interval, &t->fire_time);
				} else { // one shot timer
					stop_itimer(t);
				}
				signal_itimer_fired(t);
				break;
			}
		}
	}
	// must go seperate loop since we 'signal' might have erased 't'
	for (t = itimers; t; t = t->next) {
		if ((t->state > 0)	// re-check, since it might have stopped above
			&& (compare_timeval(&curr, &t->fire_time) < 0)) {
			if (earliest_timer == NULL) {
				earliest_timer = t;
			} else if (compare_timeval(&t->fire_time, &earliest_timer->fire_time) < 0) {
				earliest_timer = t;
			}
		}
	}
	if (earliest_timer) {
		set_itimer_firetime(&earliest_timer->fire_time);
	#ifdef DEBUG_ITIMER
		printf("Next earliest:");
	#endif
		print_itimer(earliest_timer);
	} else {
		set_itimer_firetime(NULL);	// stop timer
	}
}


/******************************************
  getitimer, setitimer
******************************************/

unsigned long remaining_time_till_next_signal() {
	// read the remaining time until the next signal of SIGALRM in ms.
	struct itimerval value;
	if (getitimer(ITIMER_REAL, &value) < 0)
		return (unsigned long)-1;
	return tv2ms(&value.it_value);
}

int set_itimer_interval(struct timeval *interval) {
	struct itimerval value;
	// turn off the itimer internal repeat functionality
	value.it_interval.tv_sec = 0;
	value.it_interval.tv_usec = 0;
	if (interval == NULL) {
		value.it_value.tv_sec = 0;
		value.it_value.tv_usec = 0;
	} else {
		// set the interval, after which the timer will fire
		value.it_value.tv_sec = interval->tv_sec;
		value.it_value.tv_usec = interval->tv_usec;
	}
	if (setitimer(ITIMER_REAL, &value, NULL) < 0)
		return -1;
	return 0;
}

int set_itimer_firetime(struct timeval *atime) {
	struct timeval curr;
	struct timeval interval;
	if (atime == NULL) {
		interval.tv_sec = 0;
		interval.tv_usec = 0;
	} else {
		gettimeofday(&curr, NULL);
		if (subtract_timeval(atime, &curr, &interval) < 0)
			return -1;	// cannot set to time in past
	}
	return set_itimer_interval(&interval);
}


/******************************************
  start itimer
******************************************/

int itimer_start(int timer_id, char type, unsigned long int interval_ms) {
	struct timeval curr;
	struct itimerlist *t = find_itimer(timer_id);
	if (t == NULL)
		return -1;
	if ((type != ITIMER_ONE_SHOT) && (type != ITIMER_REPEAT))
		return -1;
	gettimeofday(&curr, NULL);

	if (t->state == 0)
		num_active_itimers++;
	t->state = type;	// set to 1 or 2

	t->interval.tv_sec = 0;
	t->interval.tv_usec = 0;
	if (type == ITIMER_REPEAT) {
		add_ms_to_timeval(&t->interval, interval_ms, &t->interval);	// set interval
	}
	add_ms_to_timeval(&curr, interval_ms, &t->fire_time);	// set next fire time
	if (earliest_timer == NULL) { //no timer was started before this one
		earliest_timer = t;
	} else {
		if (compare_timeval(&t->fire_time, &earliest_timer->fire_time) < 0)
			earliest_timer = t;
	}
	if (earliest_timer == t) {
		if (set_itimer_firetime(&t->fire_time) < 0) {
			num_active_itimers--;
			return -1;
		}
	}
	print_itimerlist_state();
	print_itimer(t);
	return 0;
}


/******************************************
  stop itimer
******************************************/

int stop_itimer(struct itimerlist *t) {
	if (t == NULL)
		return -1;
	if (t->state > 0) { // if the timer is running
		t->state = 0;
		num_active_itimers--;
	}
	return 0;
}

int itimer_stop(int timer_id) {
	struct itimerlist *t = find_itimer(timer_id);
	if (stop_itimer(t) < 0)
		return -1;
	print_itimer(t);
	return 0;
}


/******************************************
  itimerlist data structure interfaces
******************************************/

struct itimerlist *add_itimer(int timer_id, int user_id, itimer_handler_t handler) {
	struct itimerlist *t = (struct itimerlist *) malloc(sizeof *t);
	t->next = itimers;
	itimers = t;
	t->timer_id = timer_id;
	t->user_id = user_id;
	t->handler = handler;
	t->state = ITIMER_IDLE;
	t->fire_time.tv_sec = 0;
	t->fire_time.tv_usec = 0;
	t->interval.tv_sec = 0;
	t->interval.tv_usec = 0;
	num_itimers++;
	print_itimerlist_state();
	return t;
}

int itimer_create(int user_id, itimer_handler_t handler) {
	struct itimerlist *t;
	int new_timer_id = get_unique_itimer_id();

	if (!itimer_initialized)
		itimer_initialize();

	t = add_itimer(new_timer_id, user_id, handler);
	if (t == NULL)
		return -1;
	return t->timer_id;
}

struct itimerlist **_find_itimer(int timer_id) {
	struct itimerlist **t;
	for (t = &itimers; *t; ) {
		if ((*t)->timer_id == timer_id)
			return t;
		else
			t = &((*t)->next);
	}
	return NULL;	// Error, not found
}

struct itimerlist *find_itimer(int timer_id) {
	struct itimerlist **t;
	t = _find_itimer(timer_id);
	if (t)
		return (*t);
	return NULL;
}

void rem_itimer(struct itimerlist **t) {
	struct itimerlist *dead = *t;
	*t = dead->next;
	free(dead);
	print_itimerlist_state();
}

int remove_itimer(int timer_id) {
	struct itimerlist **t;
	t = _find_itimer(timer_id);
	if (t == NULL)
		return -1;
	if ((*t)->state > 0)
		stop_itimer((*t));
	rem_itimer(t);
	num_itimers--;
	print_itimerlist_state();
	return 0;
}

int itimer_remove(int timer_id) {
	return remove_itimer(timer_id);
}


/******************************************
  print debugging messages
******************************************/

void print_itimerlist_state() {
	#ifdef DEBUG_ITIMER
		struct timeval curr;
		gettimeofday(&curr, NULL);
		printf("[itimerlist]: %lu num_timers %d, num_active %d\n", 
	          tv2ms(&curr), num_itimers, num_active_itimers);
	#endif
}

void print_itimer(struct itimerlist *t) {
	#ifdef DEBUG_ITIMER
		if (t == NULL)
			return;
		printf("[itimer %d]: user_id %d, interval %lu, next_fire_at %lu\n", 
	          t->timer_id, t->user_id, tv2ms(&t->interval), tv2ms(&t->fire_time));
	#endif
}

void print_all_itimers() {	
	#ifdef DEBUG_ITIMER
		struct itimerlist *t;
		print_itimerlist_state();
		for (t = itimers; t; t = t->next) {
			print_itimer(t);
		}
	#endif
}

/******************************************
  others...
******************************************/

int get_unique_itimer_id() {
	struct itimerlist *t;
	int id = 1, ok;
	while(1) {
		ok = 1;
		for (t = itimers; t; t = t->next) {
			if (t->timer_id == id) {
				ok = 0;
				id++;
				break;
			}
		}
		if (ok == 1)
			return id;
	}
	return id;
}

