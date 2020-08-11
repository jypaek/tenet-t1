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
 * TRD_Timer: A timer that fires at exponentially increasing intervals,
 * with conditional suppression of firing.
 *
 * TRD_Timer uses the idea from the work:
 *  - "Trickle: A self-regulating algorithm for code maintenance and propagation 
 *     in wireless sensor networks" P. Levis, N. Patel, D. Culler, and S. Shenker. 
 *     In Proceedings of the First USENIX/ACM Symposium on Network Systems Design 
 *     and Implementation (NSDI), 2004.
 * and re-uses some code segments from:
 *  - "Drip" implementation in 'tinyos-1.x/beta/Drip' by Gilman Tolle.
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 2/26/2006
 **/


#include <stdlib.h>
#include <stdio.h>
#include "trd_state.h"
#include "trd_timer.h"
#include "trickle_timer.h"
#include "timeval.h"

//#define DEBUG_TRD_TIMER

uint16_t trickleAnnounce;
uint16_t trickleCountdown;
uint8_t  trickleStage;
uint8_t  trickleSuppress;
uint8_t  trickleState;

struct timeval trickle_alarm_time;

void trickleReset();
void trickleSet();
void trickleStart(unsigned long int interval_ms);
void trickleStop();
int trickleFired(int user_id);

void trd_timer_init() {
    trickleReset();
    if ((trickle_alarm_time.tv_sec == 0) && (trickle_alarm_time.tv_usec == 0)) {
        trickleStart(TRD_TIMER_PERIOD*1000/1024);
    }
}

void updateCounters() {
    // Decrement the countdown timer.
    if (trickleCountdown > 0)
        trickleCountdown--; 
    if (trickleCountdown <= trickleAnnounce &&
        trickleState == TRD_PRE_PROCESS) {
        // If the countdown timer goes below the send time 
        // and we haven't processed yet:
        if (trickleSuppress) {
            // If we have been suppressed, prevent sending.
            trickleState = TRD_POST_PROCESS;
            #ifdef DEBUG_TRD_TIMER
                printf("TRD_Timer suppressed \n");
            #endif
        }
    } else if (trickleCountdown == 0) {
        //If the countdown timer goes to 0, double the trickle timer.
        if (trickleStage < TRD_MAX_INTERVAL)
            trickleStage++;
        trickleSet();
    }
}

void trd_timer_processed() {
    trickleState = TRD_POST_PROCESS;
}

void trd_timer_suppress() {
    #ifdef DEBUG_TRD_TIMER
        printf("TRD_Timer suppress\n");
    #endif
    trickleSuppress = 1;
}

void trickleSet() {
    //uint16_t trickleStage_x_log2p5_ov_log2 = (4*(uint16_t)trickleStage)/3;
    trickleCountdown = 1 << trickleStage;
    //trickleCountdown = 1 << (uint8_t)trickleStage_x_log2p5_ov_log2;
    if (trickleCountdown < 4) {
        trickleAnnounce = 0;
    } else {
        uint16_t rand = (uint16_t) lrand48() % 65535;
        trickleAnnounce = rand % (trickleCountdown / 2);
    } // Announce is less than the half of the CountDown
    trickleSuppress = 0;
    trickleState = TRD_PRE_PROCESS;
}

void trd_timer_set(uint32_t interval) {
    uint16_t countdown = interval/TRD_TIMER_PERIOD;
    uint8_t stage = 1;
    while ((countdown >> stage) > 0) stage++;
    trickleStage = stage & 0xff;
    #ifdef DEBUG_TRD_TIMER
        printf("trd_timer_set (interval %d, stage %d)\n", interval, stage);
    #endif
    trickleSet();
}

void trickleReset() {
    trickleStage = TRD_MIN_INTERVAL;
    trickleSet();
}

void trd_timer_reset() {
    trickleReset();
}

void trd_timer_printCacheEntry() {
#ifdef DEBUG_TRD_TIMER
    printf(" tstage=%d, tcount=%d, tannounce=%d, tstate=%d\n", 
                  trickleStage, trickleCountdown, 
                  trickleAnnounce, trickleState);
#endif
}

/* trd_timer_fired(int) function must be implemented by the
   user of this trd_timer algorithm.
*/
int trickleFired(int user_id) {
    updateCounters();
    if (trickleCountdown <= trickleAnnounce &&
        trickleState == TRD_PRE_PROCESS) {      
        trd_timer_fired();
    }
    trickleStart(TRD_TIMER_PERIOD + (lrand48() % (TRD_TIMER_PERIOD/2)));
    return 1;
}

void trickleStart(unsigned long int interval_ms) {
    struct timeval curr;
    gettimeofday(&curr, NULL);
    add_ms_to_timeval(&curr, interval_ms, &trickle_alarm_time);
    return;
}

void trickleStop() {
    trickle_alarm_time.tv_sec = 0;
    trickle_alarm_time.tv_usec = 0;
    return;
}

void poll_trickle_timer() {
    struct timeval curr;
    gettimeofday(&curr, NULL);
    if (((trickle_alarm_time.tv_sec > 0) || (trickle_alarm_time.tv_usec > 0))
                && (compare_timeval(&trickle_alarm_time, &curr) <= 0))
        trickleFired((int)&trickleState);
}

