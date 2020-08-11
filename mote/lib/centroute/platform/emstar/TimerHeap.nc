/*      
 *
 *
 * "Copyright (c) 2003 and The Regents of the University 
 * of California.  All rights reserved.
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose, without fee, and without written agreement is
 * hereby granted, provided that the above copyright notice and the following
 * two paragraphs appear in all copies of this software.
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
 * Authors:  Deepak Ganesan
 * EmTOS modifications by Thanos Stathopoulos
 *
 */



#define CLOCK_COUNTER_NUM  ITC_16  // Includes the right defines in timer.h


includes heap_timer;

module TimerHeap{

  provides {
    interface HeapTimers;
 
  }


} // End Interfaces 


implementation {

// ==============     Includes   ==================== 

#include <inttypes.h>
#include "timerdefs.h"


// default variables if not defined otherwise in timer.h
 
#ifndef HEAP_SIZE
#define HEAP_SIZE 15
#endif

#ifndef CLOCK_INTERVAL
#define CLOCK_INTERVAL 15625 * 4     // microsecond interval
#endif

// Inline Functions

#define PARENT(i) (((i) - 1) / 2)
#define CHILD1(i) ((i) * 2 + 1)
#define CHILD2(i) ((i) * 2 + 2)
#define TIME(i) heap[i]->abstime




// ============= Local Variable - State ================


  Timer * heap[HEAP_SIZE];            // Heap Tree
  Timer * st;                         // Saved Timer
  uint8_t num_timers;                 // Corrent Timers Num ( cannot exceed the defined number)
  uint8_t heap_size;                  // Corrent Heap Size
  uint32_t clock,counter;             // Clocks
  uint8_t heap_p,check_p,fire_p, check_m; // Flags
  // int test,test1;
  uint8_t mutex;                      // Mutex - Shared Data Protection
  uint8_t int_isset=0;


// =============== Function Prototypes ===============

task void resetHeapTask();
// Post - Heapify
task void timerFireTask();
// Post- Execute timed tasks



// =============== Helper Functions ===================

// ===================== Mutex =======================

/* Clear mutex */

static inline void v() { mutex = 0; }

/* Test and set mutex (need to rewrite in assembly)*/

static inline uint8_t p() {
  cli();
  if ( mutex ) {sei();return 0;} 
  else { mutex = 1;sei();return 1;}
}

// ================= Clock Init =====================

void initClock()
// Initialize the hardware Clock
{
	int_isset=0;
	emtos_init_timer(MAIN_TIMER, CLOCK_INTERVAL);
}



void clockGetTime()
{
  clock = counter;
  /* get clock value */
  clock += emtos_get_time(MAIN_TIMER);
  /* if the interrupt is pending, adjust clock forward */
  if (int_isset==1) {
	  clock += emtos_get_time(AUX_TIMER);
  }
}

// ================= Reset Heap  ======================

void resetHeap(Timer *t) {
    int pos, min;

    /* Free the timer, saving its heap position. */
    pos = getHeapPos(t);
    
    if (pos != num_timers - 1) {
        /* Replace the timer with the last timer in the heap and
         * restore the heap, propagating the timer either up or
         * down, depending on which way it violates the heap
         * property to insert the last timer in place of the
         * deleted timer. */
        if (pos > 0 && TIME(num_timers - 1) < TIME(PARENT(pos))) {
            do {
                heap[pos] = heap[PARENT(pos)];
                setHeapPos(heap[pos],pos);
                pos = PARENT(pos);
            } while (pos > 0 && TIME(num_timers - 1) < TIME(PARENT(pos)));
            heap[pos] = heap[num_timers - 1];
            setHeapPos(heap[pos],pos);
        } else {
            while (CHILD2(pos) < num_timers) {
                min = num_timers - 1;
                if (TIME(CHILD1(pos)) < TIME(min))
                    min = CHILD1(pos);
                if (TIME(CHILD2(pos)) < TIME(min))
                    min = CHILD2(pos);
                heap[pos] = heap[min];
                setHeapPos(heap[pos],pos);
                pos = min;
            }
            if (pos != num_timers - 1) {
                heap[pos] = heap[num_timers - 1];
                setHeapPos(heap[pos],pos);
            }
        }
    }
    num_timers--;
} // end reset timer


// ================= Timer Fire ======================

void timer_fire() {
  Timer *t;
  void (*f) ();

  /* Remove the first timer from the heap, remembering its
   * function and argument. */
  t = heap[0];

  f = t->f;

  st = t;

  post resetHeapTask();

  /* Run the function. */
  f();
} // end timer fire


// ================= check timer ======================

/*
Compare Current value of Clock with Timeout of top of heap.
If less than CLOCK granularity, set timeout for delta on 
timer compareb (OCIE1B)
*/
void check_timer() {
  int32_t temp;

  if (num_timers == 0) return;

  clockGetTime();
  temp = heap[0]->abstime - clock;
  if (temp > (int32_t)CLOCK_INTERVAL) return;
  else {
    if (temp < 0) {
      /* CRITICAL SECTION: Lock while operation on state variables */
      if (!p()) return;
      if (!heap_p && !fire_p) {
          post timerFireTask(); 
	fire_p = 1;
	heap_p = 1;
      }
      v();
      /* END CRITICAL SECTION */
    } else {

      outp((temp >> 8)&0xFF, OCR_ITC_16BH);
      outp(temp & 0xFF, OCR_ITC_16BL);    
      sbi(TIMSK, OCIE_ITC_16B);      // enable timer1b interupt for remaining delta
    }
  }
} // end


// ===================== Tasks =========================

/* check_timer() is called after all operations on heap have completed
   in each task. This is so that interrupts dont fire while heap re-organization
   is in progress
*/

  task void checkTimerTask()
  {
       check_timer();
       check_p = 0;

  } // end checkTimerTask

  task void timerFireTask()
  {
      timer_fire();
      fire_p = 0;
  } // end timerFireTask

  task void addTimerAbsoluteTask()
  {
  
      int pos;

      pos = num_timers;
      while (pos > 0 && st->abstime < TIME(PARENT(pos))) {
          heap[pos] = heap[PARENT(pos)];
          setHeapPos(heap[pos],pos);
          pos = PARENT(pos);
      }
      heap[pos] = st;
      setHeapPos(heap[pos],pos);
      num_timers++;
      st = NULL;

      if (!check_p) {
          post checkTimerTask();
          check_p = 1;
      }
      heap_p = 0;
  } // end add_timer absolute task


task void resetHeapTask() {

  /* Consistency Check: Check if timer exists in heap. Is this check necc?? */
  if ( st != heap[getHeapPos(st)]) return;

  resetHeap(st);

  if (isPeriodic(st) && !getDeleteFlag(st)) {
    st->abstime += st->periodic_offset;
    post addTimerAbsoluteTask(); 
  } else {
    setFree(st); /* Free the timer to be reused by app */
    resetDeleteFlag(st);
    heap_p = 0;
    st = NULL;

    /* check heap */
    if (!check_p) {
      post checkTimerTask(); 
      check_p = 1;
    }
  }
}



// ============== Interface timerHeap =================

command  char HeapTimers.initTimerHeap()
// Post : Initialize the Timer Heap
{

    static uint8_t initialized = 0;

    if ( initialized == 0 )
      {
          dbg(DBG_PROG, ("Timer Initialized\n"));
          num_timers = 0;
          heap_size = 0;

          v();

          initClock();

          initialized++;

       } // End first time initialized

  return 1;

}

command  char HeapTimers.addRelativeTimer(Timer * t, uint32_t trel)
{ 
  if ( heap_p || !isFree(t)) return 0;

  clockGetTime();
  t->abstime = clock + trel;

  return call  HeapTimers.addAbsoluteTimer(t) ;
  
}

command  char HeapTimers.addAbsoluteTimer( Timer * t )
{
    uint8_t ret = 0;
  
  /* Insert the Timer *into the heap. */
  //   dbg(DBG_PROG, ("ADD_TIMER %l\n", t->abstime));  // DEBUG - Warning error ( no cast from integer )

  /* CRITICAL SECTION: Lock while operation on state variables */

  if (!p()) return 0;
   if ( heap_p || !isFree(t)) {
    ret=0;
    if (!check_p) {
      post checkTimerTask();
      check_p = 1;
    }
  } else {
    ret=1;
    heap_p = 1;
    setUsed(t);
    st = t;
    post addTimerAbsoluteTask();
  }
  v();
  /* END CRITICAL SECTION */

  // TODO - CHECK pos?  dbg(DBG_PROG, ("ADD_TIMER %l at position:%d\n", t->abstime,pos));
  return ret;
   
}
command  char HeapTimers.deleteTimer( Timer * t )
{
    uint8_t ret=0;

  /* CRITICAL SECTION: Lock while operation on state variables */
  if (!p()) return 0;
  /* reject request if either
        reset pending
	the passed timer does not exist on the heap
	the passed timer has been fucked with by the app
  */
  if ( heap_p || isFree(t) || (t!= heap[getHeapPos(t)])) {
    ret=0;
    if (!check_p) {
      post checkTimerTask();
      check_p = 1;
    }
  } else {
    ret=1;
    heap_p = 1;
    st = t;
    setDeleteFlag(t);
    post resetHeapTask();
  }
  v();
  /* END CRITICAL SECTION */

  return ret;
  
}


// ============== Get Time ========================

command void HeapTimers.getLocalTime32(uint32_t *time) 
{
  uint32_t tmp;
  uint8_t old_int_flag;
  
  tmp = counter;

  // save intrrupt flag and disable interrupts

  old_int_flag=inp(SREG) & 0x80;
  cli();

  tmp+= __inw(TCNT_ITC_16L);
  if (inp(MATCH_TIFR) & OCF_ITC_16A) 
	clock += __inw(OCR_ITC_16AL);
  
  // enable interrupts if they were enabled previously
  if(old_int_flag) 
	sei();
  
  // the value returned is the current value of the
  // 32-bit counter and SHOULD NOT BE MASKED
  *time=tmp /* & 0x7fffffff */;
}


// ============ Interups Handler ===================



TOSH_INTERRUPT(SIG_OUTPUT_COMPARE_ITC_16A) 
{
  // Count the elapsed ticks
  counter += __inw_atomic(OCR_ITC_16AL);

  if (!check_p) {
    post checkTimerTask();
    check_p = 1;
  }
} // end clock init


TOSH_INTERRUPT(SIG_OUTPUT_COMPARE_ITC_16B) {
  cbi(TIMSK, OCIE_ITC_16B);      // disable timer1b interupt
  if (p()) {
    if (!heap_p && !fire_p) {
      post timerFireTask();
      fire_p = 1;
      heap_p = 1;
    }
    v();
  }
}


} // end implementation





