
/**
 * Waits on a press of the User Button to schedule next element.
 * Optionally waits on all presses.
 *
 * @author August Joki
 **/

#include "tenet_task.h"

module UserButton {
  provides {
    interface StdControl;
    interface Element;
  }
  uses {
    interface MSP430Event as UserButton;
    interface Schedule;
    interface List;
    interface TenetTask;
    interface Memory;
  }
}
implementation {

  typedef struct userButton_element_s {
    element_t e;
    bool repeat;
  } __attribute__((packed)) userButton_element_t;

  sched_action_t userButton_run(active_task_t *active_task, element_t *e);
  void userButton_suicide(task_t *t, element_t *e);
  
  /* global data */
  list_t m_list;


  list_action_t remove_task(void *item, void *meta) {
      active_task_t *i = (active_task_t *)item;
      task_t *t = (task_t *)meta;
      if (i->t == t) {
          call TenetTask.active_task_delete(i);
          return LIST_REMOVE;
      }
      return LIST_CONT;
  }

  list_action_t userButton_fired(void *item, void *meta) {
      active_task_t *clone, *at; 
      userButton_element_t *be;

      if ((at = (active_task_t *)item) == NULL) {
          return LIST_REMOVE;
      }
      if ((be = (userButton_element_t *)call TenetTask.element_this(at)) == NULL) {
          call TenetTask.active_task_delete(at);
          return LIST_REMOVE;
      }

      if (!be->repeat) {
          call Schedule.next(at);
          return LIST_REMOVE;
      }
      clone = call TenetTask.active_task_clone(at);
      call Schedule.next(clone);
      return LIST_CONT;
  }

  command element_t *Element.construct(task_t *t, void *data, uint16_t length) {
      userButton_element_t *e;

      if (data == NULL || length < sizeof(userButton_params_t)) {
          return NULL;
      }
      if ((e = (userButton_element_t *)call Memory.malloc(sizeof(userButton_element_t))) == NULL) {
          return NULL;
      }
      call TenetTask.element_construct(t, (element_t *)e,
              ELEMENT_USERBUTTON,
              userButton_run,
              userButton_suicide);
      e->repeat = ((userButton_params_t *)data)->repeat;
      return (element_t *)e;
  }

  sched_action_t userButton_run(active_task_t *active_task, element_t *e) {
      call List.push(&m_list, active_task);
      return SCHED_STOP;
  }

  void userButton_suicide(task_t *t, element_t *e) {
      call List.iterate(&m_list, remove_task, t);
  }

  /* hooks to tinyos */
  command result_t StdControl.init() {
      call List.init(&m_list);
      return SUCCESS;
  }
  command result_t StdControl.start() {return SUCCESS;}
  command result_t StdControl.stop() {return SUCCESS;}

  task void iterate() {
      call List.iterate(&m_list, userButton_fired, NULL);    
  }

  async event void UserButton.fired() {
      post iterate();
  }

}

