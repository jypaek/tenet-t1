// $Id: sched.c,v 1.2 2007/03/04 23:51:29 lnachman Exp $

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
/*
 *
 * Authors:		Jason Hill, Philip Levis
 * Revision:		$Id: sched.c,v 1.2 2007/03/04 23:51:29 lnachman Exp $
 * Modifications:       Removed unecessary code, cleanup.(5/30/02)
 *
 *                      Moved from non-blocking list to simple
 *                      critical section.  Changed task queue to
 *                      length 8 (more efficient). (3/10/02)
 */

/*
 * Scheduling data structures
 *
 * There is a list of size MAX_TASKS, stored as an cyclic array buffer.
 * TOSH_sched_full is the index of first used slot (head of list).
 * TOSH_sched_free is the index of first free slot (after tail of list).
 * If free equals full, the list is empty.
 * The list keeps at least one empty slot; one cannot add a task if
 * advancing free would make it equal to full.
 *
 * Each entry consists of a task function pointer.
 *
 */

typedef struct {
  void (*tp) ();
  void *postingFunction;
  uint32_t timestamp;
  uint32_t executeTime;
} TOSH_sched_entry_T;

enum {
#ifdef TOSH_MAX_TASKS_LOG2
#if TOSH_MAX_TASKS_LOG2 > 8
#error "Maximum of 256 tasks, TOSH_MAX_TASKS_LOG2 must be <= 8"
#endif
  TOSH_MAX_TASKS = 1 << TOSH_MAX_TASKS_LOG2,
#else
  TOSH_MAX_TASKS = 8,
#endif
  TOSH_TASK_BITMASK = (TOSH_MAX_TASKS - 1)
};

uint32_t sys_task_bitmask;
uint32_t sys_max_tasks;

volatile TOSH_sched_entry_T TOSH_queue[TOSH_MAX_TASKS];
uint8_t TOSH_sched_full;
volatile uint8_t TOSH_sched_free;

#ifdef TASK_QUEUE_DEBUG
uint8_t max_occupancy;
uint8_t occupancy;
uint32_t failed_post;
#endif

void TOSH_sched_init(void)
{
  int i;
  sys_task_bitmask = TOSH_TASK_BITMASK;
  sys_max_tasks = TOSH_MAX_TASKS;
  TOSH_sched_free = 0;
  TOSH_sched_full = 0;
  for (i = 0; i < TOSH_MAX_TASKS; i++)
    TOSH_queue[i].tp = NULL;

#ifdef TASK_QUEUE_DEBUG
  max_occupancy = 0;
  occupancy = 0;
  failed_post = 0;
#endif
}

bool TOS_post(void (*tp) ());

#ifndef NESC_BUILD_BINARY

/*
 * TOS_post (thread_pointer)
 *  
 * Put the task pointer into the next free slot.
 * Return 1 if successful, 0 if there is no free slot.
 *
 * This function uses a critical section to protect TOSH_sched_free.
 * As tasks can be posted in both interrupt and non-interrupt context,
 * this is necessary.
 */
bool TOS_post(void (*tp) ()) __attribute__((spontaneous)) {
  __nesc_atomic_t fInterruptFlags;
  uint8_t tmp;

  //  dbg(DBG_SCHED, ("TOSH_post: %d 0x%x\n", TOSH_sched_free, (int)tp));
  
  fInterruptFlags = __nesc_atomic_start();

  tmp = TOSH_sched_free;
  
  if (TOSH_queue[tmp].tp == NULL) {
#ifdef TASK_QUEUE_DEBUG
    occupancy++;
    if (occupancy > max_occupancy) {
       max_occupancy = occupancy;
    }
#endif
    TOSH_sched_free = (tmp + 1) & TOSH_TASK_BITMASK;
    TOSH_queue[tmp].tp = tp;
    TOSH_queue[tmp].postingFunction = (void *)__builtin_return_address(0);
    TOSH_queue[tmp].timestamp = OSCR0;
    __nesc_atomic_end(fInterruptFlags);

    return TRUE;
  }
  else {	
#ifdef TASK_QUEUE_DEBUG
    failed_post++;
#endif
    __nesc_atomic_end(fInterruptFlags);
    printFatalErrorMsg("TaskQueue Full.  Size = ", 1, TOSH_MAX_TASKS);
    return FALSE;
  }
}

#endif

/*
 * TOSH_schedule_task()
 *
 * Remove the task at the head of the queue and execute it, freeing
 * the queue entry. Return 1 if a task was executed, 0 if the queue
 * is empty.
 */

bool TOSH_run_next_task ()
{
  __nesc_atomic_t fInterruptFlags;
  uint8_t old_full;
  void (*func)(void);
  
  fInterruptFlags = __nesc_atomic_start();
  old_full = TOSH_sched_full;
  func = TOSH_queue[old_full].tp;
  if (func == NULL)
    {
      __nesc_atomic_sleep();
      return 0;
    }

#ifdef TASK_QUEUE_DEBUG
  occupancy--;
#endif
  TOSH_queue[old_full].tp = NULL;
  TOSH_sched_full = (old_full + 1) & TOSH_TASK_BITMASK;
  TOSH_queue[old_full].executeTime = OSCR0;
  __nesc_atomic_end(fInterruptFlags);
  func();
  TOSH_queue[old_full].executeTime = OSCR0 - TOSH_queue[old_full].executeTime;
  
  return 1;
}

void TOSH_run_task() {
  for (;;)
    TOSH_run_next_task();
}

void TOSH_reset_debug_counters() {
  __nesc_atomic_t fInterruptFlags;
#ifdef TASK_QUEUE_DEBUG
  fInterruptFlags = __nesc_atomic_start();
  max_occupancy = 0;
   __nesc_atomic_end(fInterruptFlags);
#endif
}

void TOSH_get_debug_counters(uint8_t *mo, uint32_t *fp) {
#ifdef TASK_QUEUE_DEBUG
  *mo = max_occupancy;
  *fp = failed_post;
#endif
}

