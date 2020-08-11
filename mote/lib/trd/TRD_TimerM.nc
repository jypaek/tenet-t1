/*                                  tab:4
 * "Copyright (c) 2000-2003 The Regents of the University  of California.
 * All rights reserved.
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose, without fee, and without written agreement is
 * hereby granted, provided that the above copyright notice, the following
 * two paragraphs and the author appear in all copies of this software.
 *
 * IN NO EVENT SHALL THE UNIVERSITY OF CALIFORNIA BE LIABLE TO ANY PARTY FOR
 * DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES ARISING OUT
 * OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN IF THE UNIVERSITY OF
 * CALIFORNIA HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * THE UNIVERSITY OF CALIFORNIA SPECIFICALLY DISCLAIMS ANY WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE.  THE SOFTWARE PROVIDED HEREUNDER IS
 * ON AN "AS IS" BASIS, AND THE UNIVERSITY OF CALIFORNIA HAS NO OBLIGATION TO
 * PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS."
 *
 * Copyright (c) 2002-2003 Intel Corporation
 * All rights reserved.
 *
 * This file is distributed under the terms in the attached INTEL-LICENSE
 * file. If you do not find these files, copies can be found by writing to
 * Intel Research Berkeley, 2150 Shattuck Avenue, Suite 1300, Berkeley, CA,
 * 94704.  Attention:  Intel License Inquiry.
 */

/*
 * Authors:     Gilman Tolle
 * Date last modified:  3/12/03
 */

/**
 * @author Gilman Tolle
 */


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

#include "trickle_timer.h"

module TRD_TimerM {
    provides {
        interface StdControl;
        interface TRD_Timer;
    }
    uses {
        interface Random;
        interface Timer as TrickleTimer;
    }
}
implementation {
    
    uint16_t trickleAnnounce;
    uint16_t trickleCountdown;
    uint8_t  trickleStage;
    uint8_t  trickleSuppress;
    uint8_t  trickleState;

    void trickleReset();
    void trickleSet();

    command result_t StdControl.init() {
        call Random.init();
        return SUCCESS;
    }
    command result_t StdControl.start() {
        call TrickleTimer.start(TIMER_ONE_SHOT, 4 + // make sure not zero
                             call Random.rand() % TRD_TIMER_PERIOD);
        return SUCCESS;
    }
    command result_t StdControl.stop() {
        call TrickleTimer.stop();
        return SUCCESS;
    }

    void trickleSet() {
        //uint16_t trickleStage_x_log2p5_ov_log2 = (4*(uint16_t)trickleStage)/3;
        trickleCountdown = 1 << trickleStage;
        //trickleCountdown = 1 << (uint8_t)trickleStage_x_log2p5_ov_log2;
        if (trickleCountdown < 4) {
            trickleAnnounce = 0;
        } else {
            trickleAnnounce = call Random.rand() % (trickleCountdown / 2);
        } // Announce is less than the half of the CountDown
        trickleSuppress = FALSE;
        trickleState = TRD_PRE_PROCESS;
    }

    void trickleReset() {
        trickleStage = TRD_MIN_INTERVAL;
        trickleSet();
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
            }
        } else if (trickleCountdown == 0) {
            //If the countdown timer goes to 0, double the trickle timer.
            if (trickleStage < TRD_MAX_INTERVAL)
                trickleStage++;
            trickleSet();
        }
    }

    command void TRD_Timer.init() {
        trickleReset();
    }

    command void TRD_Timer.processed() {
        trickleState = TRD_POST_PROCESS;
    }

    command void TRD_Timer.suppress() {
        trickleSuppress = TRUE;
    }

    command void TRD_Timer.reset() {
        trickleReset();
    }

    command void TRD_Timer.set(uint32_t interval) {
        uint16_t countdown = interval/TRD_TIMER_PERIOD;
        uint8_t stage = 1;
        while ((countdown >> stage) > 0) stage++;
        trickleStage = stage & 0xff;
        trickleSet();
    }

    event result_t TrickleTimer.fired() {
        updateCounters();
        if (trickleCountdown <= trickleAnnounce &&
            trickleState == TRD_PRE_PROCESS) {      
            signal TRD_Timer.fired();
        }
        call TrickleTimer.start(TIMER_ONE_SHOT, TRD_TIMER_PERIOD +
                             (call Random.rand() % (TRD_TIMER_PERIOD/2)));
        return SUCCESS;
    }
}

