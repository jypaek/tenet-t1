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
 * Configuration file for TRD_Timer.
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

#ifndef _TRD_TIMER_H_
#define _TRD_TIMER_H_

#include "trickle_timer.h"
#include <sys/types.h>
#ifdef __CYGWIN__
#include <windows.h>
#include <io.h>
#else
#include <stdint.h>
#endif

void trd_timer_init();
void trd_timer_processed();
void trd_timer_suppress();
void trd_timer_reset();
void trd_timer_set(uint32_t interval);
void trd_timer_printCacheEntry();

void poll_trickle_timer();

#endif

