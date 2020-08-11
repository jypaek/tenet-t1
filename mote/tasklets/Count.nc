/*
 * count(attr, init_value, rate)
 *
 * Provides a monotonically increasing value as a data attribute each time it
 * is run in an active task.
 *
 * Attr is the attribute to store result
 * init_value is the initial value of counter
 * Rate is the number to add.
 *
 * @author August Joki
*/

#include "tenet_task.h"

module Count {
    provides {
        interface Element;
    }
    uses {
        interface TenetTask;
        interface Memory;
    }
}
implementation {

    typedef struct count_element_s {
        element_t e;
        tag_t type;
        uint16_t count;
        int16_t rate;
    } __attribute__((packed)) count_element_t;

    sched_action_t count_run(active_task_t *active_task, element_t *e);
    void count_suicide(task_t *t, element_t *e) {} // nothing to do

    command element_t *Element.construct(task_t *t, void *data, uint16_t length) {
        count_element_t *e = NULL;
        count_params_t *p = (count_params_t *)data;

        if (data == NULL || length < sizeof(count_params_t)) {
            return NULL;
        }
        if ((e = (count_element_t *)call Memory.malloc(sizeof(count_element_t))) == NULL) {
            return NULL;
        } 

        call TenetTask.element_construct(t, (element_t *)e,
                                        ELEMENT_COUNT,
                                        count_run,
                                        count_suicide);
        e->count = p->count;
        e->rate = p->rate;
        e->type = p->type;
        return (element_t *)e;
    }

    sched_action_t count_run(active_task_t *active_task, element_t *e) {
        count_element_t *ce = (count_element_t *)e;

        ce->count = ce->count + ce->rate; /* the only actual operation */

        call TenetTask.data_push(active_task,
                call TenetTask.data_new_copy(ce->type, sizeof(uint16_t), &(ce->count)));

        return SCHED_NEXT;
    }

}

