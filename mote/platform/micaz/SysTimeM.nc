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
 * Date last modified: 12/07/03
 */

includes SysAlarm;

/**
 * This module provides a 921.6 KHz timer on the MICA2 platform,
 * and 500 KHz timer on the MICA2DOT platform. We use 1/8 prescaling.
 */
module SysTimeM
{
	provides 
	{
		interface StdControl;
		interface SysTime;
		interface SysAlarm;
	}
}

implementation
{
	// the high 16 bits of the current time
	uint16_t currentTime;

	// the high 16 bits of the alarm time
	uint16_t alarmTime;

	// SUCCESS if the alarm is set, FAIL otherwise
	uint8_t alarmState = FAIL;

	enum
	{
		// Note: jpaek
		//   - We are using the timer with 1/256 prescaler, 28.8 KHz on Mica2/Z
		//	 - Not 1/8 prescaler (921600Hz)... different from VU...
		//	 - So...
		//CHKTIME = 3,
		//SETTIME = 5,
		CHKTIME = 1,
		SETTIME = 1,
	};

	typedef union time_u
	{
		struct
		{
			uint16_t low;
			uint16_t high;
		};
		uint32_t full;
	} time_u;

	async command uint16_t SysTime.getTime16()
	{
		uint16_t time;
		atomic time = inw(TCNT3L);
		return time;
	}

	// must be called in atomic context
	static inline uint32_t getTime32()
	{
		time_u time;

		time.low = inw(TCNT3L);
		time.high = currentTime;

		/*
		 * Adjust time if we did not handle the overflow interrupt yet
		 * AND the low time we read is already shows this.
		 */
		if( bit_is_set(ETIFR, TOV3) && ((int16_t)time.low) >= 0 )
			++time.high;

		return time.full;
	}

	async command uint32_t SysTime.getTime32()
	{
		uint32_t time;
		atomic time = getTime32();
		return time;
	}

	async command uint32_t SysTime.castTime16(uint16_t time16)
	{
		uint32_t time;
		atomic time = getTime32();
		time += (int16_t)time16 - (int16_t)time;
		return time;
	}

	// Use SIGNAL instead of INTERRUPT to get atomic section
	TOSH_SIGNAL(SIG_OVERFLOW3)
	{
		++currentTime;

		if( alarmState && currentTime == alarmTime )
		{
			// make sure that the interrupt flag is cleared if necessary
			if( (uint16_t)inw(OCR3AL) > (uint16_t)(inw(TCNT3L) + CHKTIME) )
				outb(ETIFR, 1<<OCF3A);

			// the interrupt will happen later
			sbi(ETIMSK, OCIE3A);
		}
	}

	// Interrupts are disabled
	TOSH_SIGNAL(SIG_OUTPUT_COMPARE3A)
	{
		alarmState = FAIL;
		cbi(ETIMSK, OCIE3A);
		signal SysAlarm.fired();
	}

	default async event void SysAlarm.fired()
	{
	}

	// must be called in atomic context
	static inline uint32_t getAlarm()
	{
		time_u time;

		time.low = inw(OCR3AL);
		time.high = alarmTime;

		return time.full;
	}

	async command result_t SysAlarm.get(uint32_t *time)
	{
		atomic
		{
			((time_u*)time)->low = inw(OCR3AL);
			((time_u*)time)->high = alarmTime;
		}

		return alarmState;
	}

	async command result_t SysAlarm.cancel()
	{
		result_t ret;
		atomic
		{
			if( (ret = alarmState) != FAIL )
			{
				alarmState = FAIL;
				cbi(ETIMSK, OCIE3A);
			}
		}
		return ret;
	}

	// must be called in atomic context with a time in the future
	static inline void setAlarm(uint32_t time)
	{
		outw(OCR3AL, ((time_u)time).low);

		if( ((time_u)time).high == currentTime )
		{
			outb(ETIFR, 1<<OCF3A);
			sbi(ETIMSK, OCIE3A);
		}

		alarmTime = ((time_u)time).high;
		alarmState = SUCCESS;
	}

	async command result_t SysAlarm.set(uint8_t type, uint32_t time)
	{
		result_t ret = FAIL;

		switch( type )
		{
		case SYSALARM_PERIOD:
			atomic time += getAlarm();

		case SYSALARM_ABSOLUTE:
			atomic
			{
				if( (int32_t)(time - getTime32()) > SETTIME )
				{
					setAlarm(time);
					ret = SUCCESS;
				}
			}
			break;

		case SYSALARM_DELAY:
			if( (int32_t)time >= 0 )
			{
				time += SETTIME;
				atomic setAlarm(getTime32() + time);
				ret = SUCCESS;
			}
		};

		return ret;
	}
	
	command result_t StdControl.init()
	{
		outb(TCCR3A, 0x00);
		outb(TCCR3B, 0x00);
		outb(ETIMSK, (inb(ETIMSK)&(1<<OCF1C))|(1<<TOIE3));

		return SUCCESS;
	}

	command result_t StdControl.start()
	{
		// start the timer with 1/8 prescaler, 921.6 KHz on MICA2
		// outb(TCCR3B, 0x02);

		// Start the timer with 1/256 prescaler, 28.8 KHz on Mica2/Z
		outb(TCCR3B, 0x04);	// --jpaek
		return SUCCESS;
	}

	command result_t StdControl.stop()
	{
		// stop the timer
		outb(TCCR3B, 0x00);
		return SUCCESS;
	}
}
