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
 * Issue(starttime, period, abs): Issue a task to run.
 *
 * - wait until/for 'starttime' to run the rest of the tasklet
 *   then run it periodically every 'period'
 * - 'starttime' specified in FTSP/mote-ticks, if abs==1
 *   'period' always in millisec
 *
 * Notes for all cases: (when x and y are non-zero)
 * 1- issue(x,0,0)    ==   wait(x,0)
 * 2- issue(x,0,1)    ==   alarm(x)
 * 3- issue(0,y,0)    ==   wait(y,1)
 * 4- issue(x,y,0)    ==   wait(x,0)->wait(y,1)
 * 5- issue(x,y,1)    ==   alarm(x)->wait(y,1)
 * 6- issue(0,0,*)    ==   ERROR!
 * 7- issue(0,y,1)    ==   convert to case-3 ? or convert to case-5: issue(NOW,y,1) ?
 *
 * Aliases: 
 * - Wait(interval, repeat)
 * - Alarm(alarm_time)
 *
 * @author Jeongyeup Paek
 * @author Ben Greenstein
 * @modified 2/5/2007
 **/

/* OG: support periodic tasks with globaltime */

#include "tenet_task.h"

module Issue {
    provides {
        interface StdControl;
        interface Element;
    }
    uses {
#ifdef EMSTAR_NO_KERNEL
        interface EmTimerI as IssueTimer;
#else
        interface Timer as IssueTimer;
#endif
    #ifdef GLOBAL_TIME
        interface AbsoluteTimer; // Global, using FTSP
        interface GlobalTime;    // Global, using FTSP
    #endif
        interface LocalTime;
        interface LocalTimeInfo;
        interface Schedule;
        interface TenetTask;
        interface List;
        interface Memory;
        interface TaskError;
    }
}
implementation {

  /* time units for curstarttime and period in mote-ticks if abs==1,
   * otherwise in ms. if period == 0, execute just one (similar to
   * one shot timer) othewise, execute every period (similar to
   * a periodic timer).
   */
    typedef struct issue_element_s {
        element_t e;
        uint32_t curstarttime;
        uint32_t period;
        uint8_t abs;
        uint8_t pad;
    } __attribute__((packed)) issue_element_t;

    typedef struct {
        active_task_t *active_task;
        uint32_t time_left_ms;
    } issue_item_t;

    /* global data */

    /* list of all waiting timers, including both abs and interval timers */
    list_t m_timer_list;

    /* interval timer related */
    uint32_t m_offset_update_time_ticks = 0;    // last updated reference point
    uint32_t m_next_interval_offset_ms = 0;     // time interval till next fire

    /* absolute timer related */
    uint32_t m_next_alarm_time = 0;             // next fire time


#ifdef GLOBAL_TIME

    list_action_t compare_abs_time(void *item, void *meta) {
        active_task_t *at;
        issue_item_t *c = (issue_item_t *)item;
        issue_element_t *te = (issue_element_t *)call TenetTask.element_this(c->active_task);
        uint32_t curr_time = *(uint32_t *)meta;

        if (te->abs == 0) {         /* do nothing if not abs mode */
            return LIST_CONT;
        }

        /* abs mode: global-time absolute timer */

        if (curr_time == 0) {
            /* timesynch is not working?? */
            call TaskError.report(c->active_task->t, ERR_TIMESYNC_FAILURE, ELEMENT_ISSUE, c->active_task->element_index);
            /* DO NOT kill task here, nor free(c), nore remove timer from list:
               - curr_time == 0 means that timesync is not working.
                 error report must be delivered to ALL tasks using abs time.
                 but 'kill' will require 'LIST_BREAK', which will prevent notifying all tasks.
                 so, when application gets the error report, they should kill the task */
        } else if ((curr_time - te->curstarttime) <= 32768U) { 
            /* we might have fired
                - 32768 is a guard band
                - check for error and if periodic set the next timer,
                  otherwise we are done 
            */
            if (te->period > 0) {
                /* case-5 : repeat using globaltime-ticks */
                if ((at = call TenetTask.active_task_clone(c->active_task)) != NULL) {
                    call Schedule.next(at); /* schedule the cloned task to run */
                } else {
                    call TaskError.report(c->active_task->t, ERR_MALLOC_FAILURE, ELEMENT_ISSUE, c->active_task->element_index);
                }
                te->curstarttime += call LocalTimeInfo.msToTicks(te->period);

                if ((m_next_alarm_time == 0) ||     /* if no alarm set yet, OR */
                    ((te->curstarttime - curr_time) < (m_next_alarm_time - curr_time))) {
                    /* if my alarm time is earlier than the earliest alarm time,
                       (considering time wrap-around) */
                    m_next_alarm_time = te->curstarttime;
                }
            } else {
                /* case-2 : we are done */
                call Schedule.next(c->active_task); /* schedule active task immediately */
                call Memory.free(c);                /* delete list item */
                return LIST_REMOVE;                 /* remove from timer list */
            }
        } else {
            if ((m_next_alarm_time == 0) ||     /* if no alarm set yet, OR */
                ((te->curstarttime - curr_time) < (m_next_alarm_time - curr_time))) {
                /* if my alarm time is earlier than the earliest alarm time,
                   (considering time wrap-around) */
                m_next_alarm_time = te->curstarttime;
            }
        }
        return LIST_CONT;
    }

    void set_next_alarm_time() {
        uint32_t curr_gtime;
        if (call GlobalTime.getGlobalTime(&curr_gtime) == FAIL) { // if not synchronized,
            curr_gtime = 0; // this will send error reports to all tasks using abs mode.
        }
        m_next_alarm_time = 0; // init next_alarm_time so that compare_abs_time() can set a new one
        call List.iterate(&m_timer_list, compare_abs_time, &curr_gtime);

        if (m_next_alarm_time == 0) { /* no more waiting atimer */
            return;
        } else if (call AbsoluteTimer.set(m_next_alarm_time) == FAIL) {
            m_next_alarm_time = 0;
            curr_gtime = 0; // this will make all tasks to be scheduled immediately
            call List.iterate(&m_timer_list, compare_abs_time, &curr_gtime);
        }
    }

    event result_t AbsoluteTimer.fired() {
        /* update global absolute timer and set the next timer to fire */
        set_next_alarm_time();
        return SUCCESS;
    }

#endif  // GLOBAL_TIME


    list_action_t compare_interval_time(void *item, void *meta) {
        active_task_t *at;
        issue_item_t *c = (issue_item_t *)item;
        issue_element_t *te = (issue_element_t *)call TenetTask.element_this(c->active_task);

        if (te->abs) {              /* do nothing if abs mode */
            return LIST_CONT;
        }

        /* not abs mode == interval timer */
        if (c->time_left_ms == 0) {         /* fired */
            if (te->period > 0) {           /* repeat interval timer */
                if ((c->active_task->t->block_cloning == FALSE) &&  // TODO
                    (c->active_task->t->sendbusy == FALSE)) {       // this task has a packet pending to be sent
                    // ideally, we should not use 'num_atasks' to decide whether to clone or not
                #if defined(PLATFORM_MICAZ) || defined(PLATFORM_MICA2) || defined(PLATFORM_MICA2DOT)
                    if (c->active_task->t->num_atasks < 2)
                #else
                    if (c->active_task->t->num_atasks < 5)
                #endif
                    {
                        if ((at = call TenetTask.active_task_clone(c->active_task)) != NULL) {
                            call Schedule.next(at); /* schedule the cloned task to run */
                        } else {
                            call TaskError.report(c->active_task->t, ERR_MALLOC_FAILURE, ELEMENT_ISSUE, c->active_task->element_index);
                        }
                    } /* too fast... just skip this time */
                    else {
                        call TaskError.report(c->active_task->t, ERR_RESOURCE_BUSY, ELEMENT_ISSUE, c->active_task->element_index);
                    }
                }
                
                c->time_left_ms = te->period;   /* interval till next periodic execution */

            } else {                    /* not repeat mode == one shot timer */
                call Schedule.next(c->active_task); /* schedule the current active task */
                c->active_task = NULL;
                call Memory.free(c);
                return LIST_REMOVE;     /* remove from timer list */
            }
        } //else {}  /* not fired yet */

        if ((m_next_interval_offset_ms == 0) || 
                (c->time_left_ms < m_next_interval_offset_ms)) {
            m_next_interval_offset_ms = c->time_left_ms;        /* find next earliest fire time */
        }
        return LIST_CONT;
    }

    void set_next_itimer() {
        m_next_interval_offset_ms = 0;
        call List.iterate(&m_timer_list, compare_interval_time, NULL);
        // compare all issueing items in list, and either
        //  - issue more, or
        //  - schedule to move the expired active task to the next element.

        if (m_next_interval_offset_ms == 0) { // no more tasks waiting.
            call IssueTimer.stop();
        } else {
            /* set the next timer to fire */
            call IssueTimer.start(TIMER_ONE_SHOT, 
                    call LocalTimeInfo.msToTimerInterval(m_next_interval_offset_ms));
                    //m_next_interval_offset_ms);   // 1000/1024 is not that big an issue?
        }
    }
    
    list_action_t update_offset(void *item, void *meta) {
        // *meta is the 'offset' amount of time that has passed since last update.
        // For all the issueing items, decrease the remaining time by offset amount.
        issue_element_t *te;
        issue_item_t *c = (issue_item_t *)item;
        uint32_t curr_offset = *(uint32_t *)meta;
        
        te = (issue_element_t *)call TenetTask.element_this(c->active_task);

        if (te->abs == 0) {                     /* interval timer */
            if (c->time_left_ms < curr_offset)  /* time has passed */
                c->time_left_ms = 0;
            else                                /* not yet */
                c->time_left_ms -= curr_offset;
        #if defined(PLATFORM_MICAZ) || defined(PLATFORM_MICA2) || defined(PLATFORM_MICA2DOT)
            if (c->time_left_ms <= 3)
        #else
            if (c->time_left_ms <= 1)   // b/c 'ticksToMs' might lose precision
        #endif
                c->time_left_ms = 0;
        }
        return LIST_CONT;
    }

    /* update remaining times for all the active tasks in interval timer list */
    void update_interval_timers() {
        uint32_t curr_time, offset_ms;
        curr_time = call LocalTime.read();
        offset_ms = curr_time - m_offset_update_time_ticks;
        offset_ms = call LocalTimeInfo.ticksToMs(offset_ms);    // convert ticks into ms
        // "offset_ms" is the time that has passed since last update
        call List.iterate(&m_timer_list, update_offset, &offset_ms);
        m_offset_update_time_ticks = curr_time;
    }

    event result_t IssueTimer.fired() {
        /* update interval timer */
        update_interval_timers();

        /* set the next timer to fire */
        set_next_itimer();
        return SUCCESS;
    }

    sched_action_t issue_run(active_task_t *active_task, element_t *e) {
        issue_element_t *te = (issue_element_t *)e;
        issue_item_t *tc;
        bool can_do_abs = FALSE;

    #ifdef GLOBAL_TIME
        uint32_t curr_time;
        if (call GlobalTime.getGlobalTime(&curr_time) == SUCCESS)
            can_do_abs = TRUE;
    #endif

        /* total of five possible cases:
            1- issue(x,0,0)    ==   wait(x,0)
            2- issue(x,0,1)    ==   alarm(x)
            3- issue(0,y,0)    ==   wait(y,1)
            4- issue(x,y,0)    ==   wait(x,0)->wait(y,1)
            5- issue(x,y,1)    ==   alarm(x)->wait(y,1)
            7- issue(0,y,1)    ==   convert to case-5: issue(NOW,y,1) ?
           other cases are filtered out in construct.
        */

        /* check whether we can handle case-2, 5, 7 */
        if ((te->abs == 1) && (can_do_abs == FALSE)) {  // if cannot do globaltime stuff
            // terminate the task
            call TaskError.kill(active_task->t, ERR_TIMESYNC_FAILURE, ELEMENT_ISSUE, active_task->element_index);
            return SCHED_TERMINATE;
        }

        if ((tc = (issue_item_t *)call Memory.malloc(sizeof(issue_item_t))) == NULL) {
            call TaskError.kill(active_task->t, ERR_MALLOC_FAILURE, ELEMENT_ISSUE, active_task->element_index);
            return SCHED_TERMINATE;
        }

        tc->active_task = active_task;
        tc->time_left_ms = (((te->abs == 0) && (te->curstarttime == 0)) ? te->period : te->curstarttime);
        // should not be zero. time_left not used for abs mode
        
        /* handle case-2, case-5 
           - note that we've already checked above whether globaltime is available */
        #ifdef GLOBAL_TIME
        if (te->abs == 1) {

            if (te->curstarttime == 0) {   // case-7: put NOW + period
                te->curstarttime = curr_time + call LocalTimeInfo.msToTicks(te->period);
            }

            /* push to to-process list */
            call List.push(&m_timer_list, tc);

            /* We don't handle "alarm time has already passed" case 
               since abs time could have wrapped-around */

            if ((m_next_alarm_time == 0) ||   // if no timer was previously running, OR
                ((te->curstarttime - curr_time) < (m_next_alarm_time - curr_time))) { // earilier than earliest alarm,
                // Possibility of globaltime wrap-around is not handled here.
                // Assume that when the application had set the first 'starttime' value,
                // this starttime is arithmatically greater than the current globaltime.
                if (call AbsoluteTimer.set(te->curstarttime) == SUCCESS) {
                    m_next_alarm_time = te->curstarttime;
                } else { // failed to set the alarm... proceed
                    set_next_alarm_time();
                }
            }
        } else
        #endif

        /* handle case-1, case-3, and case-4 
            - all of them are interval timers */
        if (te->abs == 0) { // interval timer

            /* must update interval timer list before pushing a new one */
            update_interval_timers();

            /* add this active task to the issueing list */
            call List.push(&m_timer_list, tc);
            
            /* set the next timer to fire. note that we already filtered out 'first-period == 0' case */
            set_next_itimer();
        }

        // successfully waiting for on a timer for issueing the task.
        return SCHED_STOP;
    }


    /* remove all instances of element (and element_items) for the task
       that has just been deleted (suicided) */
    list_action_t remove_task(void *item, void *meta) {
        issue_item_t *c = (issue_item_t *)item;
        task_t *t = (task_t *)meta;
        if (c->active_task->t == t) {
            call TenetTask.active_task_delete(c->active_task);
            call Memory.free(c);
            return LIST_REMOVE;
        }
        return LIST_CONT;
    }

    void issue_suicide(task_t *t, element_t *e) {
        call List.iterate(&m_timer_list, remove_task, t);
    }

    /* construct (at install) */
    command element_t *Element.construct(task_t *t, void *data, uint16_t length) {
        issue_element_t *e;
        issue_params_t *p;

        if (data == NULL || length < sizeof(issue_params_t)) {
            return NULL;
        }

        p = (issue_params_t *)data;

        /* check parameters - filter out case-6: "issue(0,0,*)" */
        if (((p->starttime == 0) && (p->period == 0)) || (p->abs > 1)) {
            call TaskError.kill(t, ERR_INVALID_TASK_PARAMETER, ELEMENT_ISSUE, 0);
            return NULL;
        }

        if ((e = (issue_element_t *)call Memory.malloc(sizeof(issue_element_t))) == NULL) {
            return NULL;
        }
        call TenetTask.element_construct(t, (element_t *)e,
                    ELEMENT_ISSUE, issue_run, issue_suicide);
        e->curstarttime = p->starttime;
        e->period = p->period;
        e->abs = p->abs;
        return (element_t *)e;
    }

    command result_t StdControl.init() {
        call List.init(&m_timer_list);
        return SUCCESS;
    }
    command result_t StdControl.start() {return SUCCESS;}
    command result_t StdControl.stop() {return SUCCESS;}

}

