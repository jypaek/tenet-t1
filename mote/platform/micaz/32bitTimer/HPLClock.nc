
/*									tab:4
 * "Copyright (c) 2000-2003 The Regents of the University	of California.
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
 * AND FITNESS FOR A PARTICULAR PURPOSE.	THE SOFTWARE PROVIDED HEREUNDER IS
 * ON AN "AS IS" BASIS, AND THE UNIVERSITY OF CALIFORNIA HAS NO OBLIGATION TO
 * PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS."
 *
 * Copyright (c) 2002-2003 Intel Corporation
 * All rights reserved.
 *
 * This file is distributed under the terms in the attached INTEL-LICENSE
 * file. If you do not find these files, copies can be found by writing to
 * Intel Research Berkeley, 2150 Shattuck Avenue, Suite 1300, Berkeley, CA,
 * 94704.	Attention:	Intel License Inquiry.
 */
/*
 *
 * Authors:		Jason Hill, David Gay, Philip Levis
 * Date last modified:	6/25/02
 *
 */
// The Mica-specific parts of the hardware presentation layer.
/**
 * @author Jason Hill
 * @author David Gay
 * @author Philip Levis
 */

/*
 * Modified for ENL-Timer
 * Author: Krishna Kant Chintalapudi
 * Embedded Networks Laboratory, University of Southern California
 *
 * - This was changed by krishna at ENL-USC for having a real time
 *	 system clock which worked on overflow
 */

/*
 * Modified ENL Clock
 * Author: Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 *
 * - Modified so that there is no change to the interface Clock.nc
 *	 (maintain compatibility with the tinyos standard Clock.nc)
 *	 and added two more interfaces: Overflowfire.nc and LocalTime.nc
 * - Moved the system time functionality down to here (HPLClock),
 *	 from the ENL Timer. So, now Clock provides the systime.
 */

module HPLClock {
	provides interface Clock;
	provides interface StdControl;
	provides interface LocalTime;
}
implementation
{
	uint8_t set_flag;
	uint8_t mscale, nextScale, minterval;

	uint32_t systemTime;	// ENL timer

	command result_t StdControl.init() {
		atomic {
			/* // commented for ENL timer
			mscale = DEFAULT_SCALE;
			minterval = DEFAULT_INTERVAL;
			*/
			mscale = 1; 	// 32.768kHz
			//mscale = 2; 	// ENL timer uses fixed rate of 4.096kHz
			//minterval = 255;
			minterval = 128;

			systemTime = 0; // ENL systemTime
		}
		return SUCCESS;
	}

	command result_t StdControl.start() {
		uint8_t mi, ms;
		atomic {
			mi = minterval;
			ms = mscale;
		}
		call Clock.setRate(mi, ms);
		return SUCCESS;
	}

	command result_t StdControl.stop() {
		uint8_t mi;
		atomic {
			mi = minterval;
		}
		call Clock.setRate(mi, 0);
		return SUCCESS;
	}


	async command void Clock.setInterval(uint8_t value) {
		outp(value, OCR0);
	}

	async command void Clock.setNextInterval(uint8_t value) {
		atomic {
			minterval = value;
			set_flag = 1;
		}
	}

	async command uint8_t Clock.getInterval() {
		return inp(OCR0);
	}

	async command uint8_t Clock.getScale() {
		uint8_t ms;
		atomic {
			ms = mscale;
		}
		return ms;
	}

	async command void Clock.setNextScale(uint8_t scale) {
		 //using this function could be injurious to the health of the system
		 //timer, so be careful :o).
		atomic {
			nextScale = scale;
			set_flag = 1;
		}
	}


	async command result_t Clock.setIntervalAndScale(uint8_t interval, uint8_t scale) {
		//in this clock the compare and match interupt does not
		//reinitialize the timer to $00 like the HPLClock
		if (scale > 7) return FAIL;
		atomic {
			cbi(TIMSK, OCIE0); //clear all interrupts before do anything
			cbi(TIMSK, TOIE0);	// ENL: This is added compared to HPLClock
			outp(scale, TCCR0);
			mscale = scale;
			outp(0,TCNT0); //intialize counter0
			outp(interval, OCR0); //copare and match contents
			minterval = interval;
			sbi(TIMSK, OCIE0); //enable compare and match interrupt
			sbi(TIMSK, TOIE0); // ENL: This is added: enable overflow interrupt
		}
		return SUCCESS;
	}

	async command uint8_t Clock.readCounter() {
		uint8_t cnt;
		// disable CLOCK interrupts to get atomic read of time
		cbi(TIMSK, OCIE0);

		cnt = (inp(TCNT0));

		// enable CLOCK interrupts
		sbi(TIMSK, OCIE0);
		return cnt;
	}

	async command void Clock.setCounter(uint8_t n) {
		outp(n, TCNT0);
	}

	async command void Clock.intDisable() {
		cbi(TIMSK, OCIE0); //since the overflow interruptmis used only
							 //by the system time, no need to disable this.
	}
	async command void Clock.intEnable() {
		sbi(TIMSK, OCIE0); //since the overflow was never disable, no need
							 //to enable
	}

	async command result_t Clock.setRate(char interval, char scale) {
		scale &= 0x7;
		//scale |= 0x8;	// ENL: commented
		atomic {
			cbi(TIMSK, TOIE0); //disable the compare and match interrupt
			cbi(TIMSK, OCIE0);		 //Disable TC0 interrupt
			sbi(ASSR, AS0);				//set Timer/Counter0 to be asynchronous
			//from the CPU clock with a second external
			//clock(32,768kHz)driving it.
			outp(scale, TCCR0);		// initial the prescale factor with no reset on compare and match
			outp(0, TCNT0); //initialize the counter0 to $00
			outp(interval, OCR0);	//initialize the compare and match
			sbi(TIMSK, OCIE0); //enable compare match interrupt
			sbi(TIMSK,TOIE0);	// ENL: enable overflow interrupt
		}
		return SUCCESS;
	}

	async command uint32_t LocalTime.read() {
		uint8_t cntVal;
		uint32_t stime;
		atomic {
			cntVal = call Clock.readCounter();
			stime = systemTime + (uint32_t)cntVal;
		}
		return stime;
	}

	default async event result_t Clock.fire() { return SUCCESS; }
		TOSH_INTERRUPT(SIG_OUTPUT_COMPARE0) {
		atomic {
			if (set_flag) {
				mscale = nextScale;
				//nextScale|=0x8;	// ENL: commented
				outp(nextScale, TCCR0);
				outp(minterval, OCR0);
				set_flag = 0;
			}
		}
		signal Clock.fire();
	}

	TOSH_INTERRUPT(SIG_OVERFLOW0) {
		atomic {
			if (set_flag) {
				mscale = nextScale;
				outp(nextScale, TCCR0);
				outp(minterval, OCR0);
				set_flag=0;
			}
		}
		atomic {
			systemTime += 256;	// ENL system time after overflowfire
		}
	}

}

