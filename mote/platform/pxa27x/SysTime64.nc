/*
 * Copyright (c) 2003, Vanderbilt University
 * All rights reserved.
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose, without fee, and without written agreement is
 * hereby granted, provided that the above copyright notice, the following
 * two paragraphs and the author appear in all copies of this software.
 * 
 * IN NO EVENT SHALL THE VANDERBILT UNIVERSITY BE LIABLE TO ANY PARTY FOR
 * DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES ARISING OUT
 * OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN IF THE VANDERBILT
 * UNIVERSITY HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 * 
 * THE VANDERBILT UNIVERSITY SPECIFICALLY DISCLAIMS ANY WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE.  THE SOFTWARE PROVIDED HEREUNDER IS
 * ON AN "AS IS" BASIS, AND THE VANDERBILT UNIVERSITY HAS NO OBLIGATION TO
 * PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS.
 *
 * Author: Miklos Maroti
 * Modified by : Jonathan Huang, Lama Nachman
 * Took out the 16 bit flavors, added a 64 bit flavor. 
 * Date last modified: 6/6/06
 */

/** 
 * This interface provides access to a free-running CPU timer that is 
 * started at startup. The current value of this timer is NOT supposed
 * to be changed. On the Imote2 platform the current implementation 
 * uses OSCR0 running at 3.25 MHz
 */
interface SysTime64
{
	/**
         * This method returns the 64 bit timer in two chunks
         * tLow : the low 32 bits, tHigh : The high 32 bits
         * The low 32 bits are stored in OSCR0, the high 32 bits are 
         * maintained by the software
         */
	async command result_t getTime64(uint32_t *tLow, uint32_t *tHigh);

	/**
	 * This method returns the lower 32 bits of the current time.
	 * It just reads the hardware timer.
	 */
	async command uint32_t getTime32();

    /**
     * This method sets a match register such that when OSCR0 reaches
     * the value, an interrupt is fired.
     */
    async command result_t setAlarm(uint32_t val); 

    /**
     * This event is triggered by the interrupt mentioned above.
     */
    async event result_t alarmFired(uint32_t val);
}
