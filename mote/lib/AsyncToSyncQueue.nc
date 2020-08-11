/*
Author Ben Greenstein.

This provides queuing functionality for asynchronous events so you can
queue them up and service them at your leisure. It is useful in the
context of sensing and messaging.
I don't know if it's currently in use.
*/


includes tenet_task;

generic module AsyncToSyncQueue() {
  provides interface AsyncToSync;
  uses interface Memory;
#ifdef TESTINGQ
  uses interface Leds;
#endif  
}
implementation {
#include "tenet_debug.h"

  list_t list;
  bool popping;

  command void AsyncToSync.init() { 
    list.head = NULL;
    list.tail = NULL;
    popping = FALSE;
  }

  task void toSync() {
    list_item_t *item = NULL;
    void *data;
    bool gotIt = TRUE;
    bool again = FALSE;
    atomic {
      if (list.head != NULL) {
        item = list.head;
        list.head = item->next;
        /*
        if (list.head == NULL) list.tail = NULL;
        atomic {
          if (list.head) again = TRUE;
          else popping = FALSE;
        }
        */
        if (list.head != NULL) {
          again = TRUE;
        }
        else {
          list.tail = NULL;
          popping = FALSE;
        }
      }
      else {
        gotIt = FALSE;
      }
    }
    if (again) {
      post toSync();
    }
    if (gotIt) {
      data = item->data;
      call Memory.free(item);
      signal AsyncToSync.popped(data);
#ifdef TESTINGQ
      call Leds.yellowToggle();
#endif
    }
  }

  async command result_t AsyncToSync.push(void *data) {
    list_item_t *item;
    item = (list_item_t *)call Memory.malloc(sizeof(list_item_t));
    if (item == NULL) {
      tlog(LOG_ERR,"item alloc failed\n");
      return FALSE;
    }
    item->data = data;
    item->next = NULL;
    
    atomic {
      if (list.head == NULL) {
        list.head = item;
        list.tail = item;
      }
      else {
        list.tail->next = item;
        list.tail = item;
      }
      if (popping == FALSE) {
        if (post toSync()) {
          popping = TRUE;
        }
      }
    }
    return SUCCESS;
  }
}
