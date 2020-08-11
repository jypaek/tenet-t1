/* -*- Mode: C; tab-width: 4; c-basic-indent: 4; indent-tabs-mode: nil -*- */
/* ex: set tabstop=4 expandtab shiftwidth=4 softtabstop=4: */


/*									tab:4
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

#include <sys/time.h>
#include "tos_emstar.h"

#ifndef MILLION_I
#define MILLION_I   1000000
#endif

// clockScales is in fact bit flips (ticks) per second
static int clockScales[] = {-1, 32768, 4096, 1024, 512, 256, 128, 32};

TOS_INTERRUPT_HANDLER(SIG_OUTPUT_COMPARE0, (void));
TOS_INTERRUPT_HANDLER(SIG_OUTPUT_COMPARE1A, (void));

void misc_int64_to_timeval(struct timeval *tv, int64_t myindex);
int64_t misc_timeval_to_int64(struct timeval *tv);


void trigger_clock_interrupt();


norace static int64_t basetime = 0;
norace static int scale_g = 3;
norace static int interval_g = 200;
norace static int interrupt_pending = 0;

int64_t conv_ticks2usec(int64_t ticks)
{
  int64_t retval = ticks * MILLION_I / clockScales[scale_g];
  return retval;
}

int64_t conv_usec2ticks(int64_t usec)
{
  int64_t retval = usec * clockScales[scale_g] / MILLION_I;
  return retval;
}


int readcounter()
{
  struct timeval now;
  int64_t offset;
  gettimeofday(&now, NULL);
  offset = misc_timeval_to_int64(&now);
  offset -= basetime;

  if (offset < 0) offset = 0;
  return conv_usec2ticks(offset) % interval_g;
}


int update_basetime()
{
  struct timeval now;
  int64_t offset;

  gettimeofday(&now, NULL);
  offset = misc_timeval_to_int64(&now);

  /* offset is usec past basetime */
  offset -= basetime;
  if (basetime == 0 || offset < 0) {
      if (offset < 0) 
        dbg(DBG_ERROR,"***Clock went backwards?... resetting basetime\n");
      offset = 0;
      basetime = misc_timeval_to_int64(&now);
  }

  /* give up and reset basetime if we're more than 1 second behind */
  if (offset > MILLION_I) {
    dbg(DBG_ERROR, "***Lost a lot of time... resetting basetime %li offset, %li basetime\n", offset, basetime);
    //basetime += offset;
    basetime = misc_timeval_to_int64(&now);
    offset = 0;
  }

  /* increment one tick into basetime */
  /* convert offset to ticks up to last interval_g, 
   * and back to usec, add to basetime  */
  if (conv_usec2ticks(offset) >= interval_g) {
    basetime += conv_ticks2usec(interval_g);

    /* issue the interrupt */
    TOS_ISSUE_INTERRUPT(SIG_OUTPUT_COMPARE0)();
    interrupt_pending = 1;
    return -1;
  }

  /* otherwise, return time till next interval_g */
  offset = misc_timeval_to_int64(&now);
  offset = basetime + conv_ticks2usec(interval_g) - offset;
  if (offset < 0) offset = 0;

  return offset / 1000;
}


void retrigger_timer()
{
  /* update */
  if (!interrupt_pending) {
    int remain = update_basetime();
    
    /* now, reset timer */
 //   printf("remain=%d, interval =%d\n", remain, interval_g);
    if (remain >= 0)
      emtos_start_clock(remain, trigger_clock_interrupt);
  }
}


void setinterval(int myinterval, int myscale)
{
//  int remain;

  /* clear pending flag */
  interrupt_pending = 0;

  /* save the new interval_g */
  interval_g = myinterval + 1;
  scale_g = myscale;

  /* retrigger */
  retrigger_timer();
}


uint8_t getinterval()
{
    return (uint8_t)interval_g;
}



void trigger_clock_interrupt()
{
//	printf("trigger_clock_interrupt---TICK\n");

  /* update basetime and do any dropped interrupts */
  retrigger_timer();
}


void TOSH_clock_set_rate(char myinterval, char myscale) 
{

  long ticks=0;
  double bitspersec=0;

  	bitspersec = (double)clockScales[(uint8_t)(myscale & 0x07)];
	ticks = ((1000*(double)(myinterval & 0xff))/(double)bitspersec);
  
	if (ticks > 0) {
		emtos_start_clock(ticks, trigger_clock_interrupt);
	}
  return ; 
}


// Adc functions. Noops. The higher layer ADC is implemented in another
// component
void TOSH_adc_init()
{

}


void TOSH_adc_set_sampling_rate(uint8_t rate)
{

}


void TOSH_adc_sample_port(uint8_t port)
{

}


void TOSH_adc_sample_again()
{

}


void TOSH_adc_sample_stop()
{

}



