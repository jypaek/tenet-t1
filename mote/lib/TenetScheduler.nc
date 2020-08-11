/**
 * Tenet Task Scheduler
 *
 * Execute a task. Runs each tasklet of the task by calling the run
 * function implemented by each tasklet.  Once the run function
 * returns, it schedules the execution of the run function of the next
 * tasklet in the chain and so on until all the tasklets are executed.
 *
 * @author Ben Greenstein
 **/

#include "tenet_task.h"

module TenetScheduler {
    provides {
        interface StdControl;
        interface Schedule;
    }
    uses {
        interface List;
        interface TenetTask;
        interface TaskDelete;
        interface Leds;
    }
}
implementation {
#include "../lib/tenet_debug.h"

    list_t m_list; // list of active_tasks that are scheduled to run
    bool pending;

    task void run();

    /* let's do Deluge-like bootup led flashing !! (function from deluge) */
    void startupLeds() {
        uint8_t a = 0x7;
        int i, j, k;
        for (i = 3; i; i--, a >>= 1 ) {
            for (j = 1536; j > 0; j -= 4) {
                call Leds.set(a);
                for (k = j; k > 0; k--);
                call Leds.set(a >> 1);
                for (k = 1536-j; k > 0; k--);
            }
        }
    }
  
    command result_t StdControl.init() {
        call List.init(&m_list);
        pending = FALSE;
        call Leds.init();
        startupLeds();
        return SUCCESS;
    }
    command result_t StdControl.start() { return SUCCESS; }
    command result_t StdControl.stop() { return SUCCESS; }

    void schedule(active_task_t *at) {
        tlog(LOG_DEBUG, "calling List.push\n");
        call List.push(&m_list, at);
        if (pending == FALSE) {
            if (post run() == SUCCESS) {
                pending = TRUE;
            }
        }
    }

    /* schedule the first element of this active_task to run */
    command void Schedule.first(active_task_t *active_task) {
        if (active_task == NULL) {
            tlog(LOG_ERR,"null active task\n");
            return;
        }
        active_task->element_index = 0;
        schedule(active_task);
    }
  
    /* schedule the next element of this active_task to run */
    command void Schedule.next(active_task_t *active_task) {
        if (active_task == NULL) {
            tlog(LOG_ERR,"null active task\n");
            return;
        }
        active_task->element_index++; // goto next element
        if (active_task->element_index < active_task->t->num_elements) {
            // have not yet reached the end of task chain
            schedule(active_task);
        } else {
            // reached the end of task chain, and we delete task here.
            // there is not *natural* loop in the task chain
            if (active_task->t->num_atasks == 1) {
                call TaskDelete.destroy(active_task->t);
                active_task->t = NULL;
            }
            call TenetTask.active_task_delete(active_task);
        }
    }
  
    list_action_t remove_task(void *item, void *meta) {
        // assumes that *item is active_task ptr and *meta is task ptr
        active_task_t *a = (active_task_t *)item;
        task_t *t = (task_t *)meta;

        if (a->t == t) {
            call  TenetTask.active_task_delete(a);
            tlog(LOG_DEBUG, "calling LIST_REMOVE\n");
            return LIST_REMOVE;
        }
        return LIST_CONT;
    }

    command void Schedule.remove(task_t *t) {
        if (t != NULL)
            call List.iterate(&m_list, remove_task, t);
    }

    task void run() {
        active_task_t *active_task;
        element_t *n;
        sched_action_t action;

        tlog(LOG_DEBUG, "Scheduler.run: calling List.pop\n");
        /* get the next active task to run */
        active_task = (active_task_t *) call List.pop(&m_list);
        
        if (active_task == NULL) {
            //last active task could have been deleted before run is called
            tlog(LOG_DEBUG, "active task was deleted\n");
            pending = FALSE;
            return;
        }

        n = active_task->t->elements[active_task->element_index];

        action = n->run(active_task, n);

        switch (action) {
            case SCHED_STOP:
                // this active_task has stopped for now
                //  - ex> wait for timer fired event, etc.
                break;
            case SCHED_NEXT:
                // TODO: call List.push(&m_list,active_task) instead!!!
                // go to the next element in the task chain
                call Schedule.next(active_task);
                break;
            case SCHED_TERMINATE:
                call TenetTask.active_task_delete(active_task);
                break;
            case SCHED_TKILL:
                call TaskDelete.destroy(active_task->t);
                active_task->t = NULL;
                call TenetTask.active_task_delete(active_task);
                break;
            default:
                break;
        }
        if (!call List.empty(&m_list)) {
            tlog(LOG_DEBUG, "more active tasks\n");
            post run();
        }
        else {
            tlog(LOG_DEBUG, "no more active tasks\n");
            pending = FALSE;
        }
    }

}

