/**
 * Schedule Interface
 *
 * Defines functions to control the execution of the tasklets of a
 * task. Calling first() will trigger the execution of all the
 * tasklets starting the first tasklet of the task.
 * 
 * @author Ben Greenstein
 **/


includes tenet_task;

interface Schedule {
    command void first(active_task_t *active_task);
    command void next(active_task_t *active_task);
    command void remove(task_t *t);  // remove all active_task of task 't' from the scheduler
}

