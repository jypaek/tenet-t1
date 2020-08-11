
#include "tenet_task.h"

module Vector {
    provides {
        interface Element;
    }
    uses {
        interface TenetTask;
        interface TaskError;
        interface Memory;
    }
}
implementation {

    typedef struct vector_element_s {
        element_t e;
        tag_t attr;
        uint16_t length;
        uint16_t pattern;
    } __attribute__((packed)) vector_element_t;

    void vector_suicide(task_t *t, element_t *e) {} // nothing to do

    sched_action_t vector_run(active_task_t *active_task, element_t *e) {
        vector_element_t *ve = (vector_element_t *)e;
        nx_uint16_t *pResult;
        uint16_t i;

        if ((pResult = (nx_uint16_t *)call Memory.malloc(sizeof(uint16_t)*ve->length)) == NULL) {
            call TaskError.kill(active_task->t, ERR_MALLOC_FAILURE, ELEMENT_RLE, ve->attr);
            return SCHED_TERMINATE;
        }
       
        for (i = 0; i < ve->length; i++)
            pResult[i] = i;

        call TenetTask.data_push(active_task,
                call TenetTask.data_new(ve->attr, sizeof(uint16_t)*ve->length, pResult));

        return SCHED_NEXT;
    }

    command element_t *Element.construct(task_t *t, void *data, uint16_t length) {
        vector_element_t *e = NULL;
        vector_params_t *p = (vector_params_t *)data;

        if (data == NULL || length < sizeof(vector_params_t)) {
            return NULL;
        }
        if ((e = (vector_element_t *)call Memory.malloc(sizeof(vector_element_t))) == NULL) {
            return NULL;
        } 

        call TenetTask.element_construct(t, (element_t *)e,
                                        ELEMENT_VECTOR, vector_run,
                                        vector_suicide);
        e->length = p->length;
        e->pattern = p->pattern;
        e->attr = p->attr;
        return (element_t *)e;
    }

}

