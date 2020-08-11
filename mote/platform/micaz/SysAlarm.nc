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
 * Date last modified: 12/21/03
 */

/**
 * This interface provides an alarm with SysTime precision. This can
 * be used to actuate with (almost) CPU cycle precision. The <code>fired
 * </code> event is executed in interrupt context with all interrupts 
 * disabled.
 */
interface SysAlarm
{
	/**
	 * Sets the alarm to the specified time. The meaning of <code>time
	 * </code> depends on the value of <code>type</code> as follows:
	 *
	 * SYSALARM_ABSOLUTE: The <code>time</code> is the absolute
	 *	time of the alarm. The <code>fired</code> event will be
	 *	called when the current time (as returned by SysTime)
	 *	is exactly <code>time</code>.
	 *
	 * SYSALARM_DELAY: The <code>time</code> is the delay till the
	 *	alarm time. The <code>fired</code> event will be fired 
	 *	exactly when the time is <code>currentTime + time</code> 
	 *	where <code>currentTime</code> is the current time at
	 *	the invocation of this method. If <code>time</code> 
	 *	is zero, then the <code>fired</code> event will be called 
	 *	while this method is returning, or shortly thereafter.
	 *
	 * SYSALARM_PERIOD: The <code>time</code> is the elapsed
	 *	time since the <code>fired</code> event was (scheduled 
	 *	to be) fired. The <code>fired</code> event will be fired 
	 *	when the current time is <code>prevAlarm + time</code> 
	 *	where <code>prevAlarm</code> is the previously 
	 *	scheduled alarm time.
	 *
	 * If the alarm was already scheduled and not yet fired, it will
	 * be cancelled and replaced with the new alarm time.
	 * It is very important to note that the alarm will be fired
	 * only once after it is set. To obtain periodic interrupts 
	 * set the alarm initially with SYSALARM_DELAY and then with
	 * SYSALARM_PERIOD from the <code>fired</code> event. The 
	 * remaining time till the scheduled alarm must be between 
	 * <code>0</code> and <code>2^31-1</code> ticks, otherwise setting 
	 * the alarm will fail. This feauture is usefull for detecting the
	 * condition when the alarm is set to a time value that has 
	 * already passed. The SYSTIME_SECOND constant is set to the 
	 * number of ticks per second on each platform.
	 *
	 * @return SUCCESS If the alarm is set, FAIL if the scheduled 
	 *	time of the alarm has already passed. If this method
	 *	returns FAIL the previous alarm is still in effect and
	 *	is not cancelled.
	 */
	async command result_t set(uint8_t type, uint32_t time);

	/**
	 * Returns the absolute time the alarm is/was set to the specified
	 * address. Returns SUCCESS if the alarm is currently set, 
	 * FAIL otherwise.
	 */
	async command result_t get(uint32_t *time);

	/**
	 * Cancels the alarm.
	 *
	 * @return SUCCESS if an active alarm was succesfully cancelled,
	 *	FAIL if the <code>fired</code> event was already called
	 *	or the alarm was not set.
	 */
	async command result_t cancel();
	
	/**
	 * Fired at the time to which the alarm was set. WARNING: This event 
	 * is called while all interrupts are disabled. You should do minimal
	 * computation here. Maybe do hardware level actuation, schedule the 
	 * next alarm event by calling <code>set</code>, and/or post a task.
	 * You should not reenable interrupts during this event.
	 */
	async event void fired();
}
