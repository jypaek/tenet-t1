#include "criticalSection.h"
#include "queue.h"
#include "pxa27x_registers_def.h"
#include "systemUtil.h"

/*
 * TOS_parampost (thread_pointer, argument)
 *  
 * Put the task pointer into the next free slot.
 * Return 1 if successful, 0 if there is no free slot.
 *
 * This function uses a critical section to protect TOSH_sched_free.
 * As tasks can be posted in both interrupt and non-interrupt context,
 * this is necessary.
 */
extern uint32_t sys_max_tasks, sys_task_bitmask; 
extern uint8_t TOSH_sched_full, TOSH_sched_free;
extern queue_t paramtaskQueue;

typedef struct {
  void (*tp) ();
  void *postingFunction;
  uint32_t timestamp;
  uint32_t executeTime;
} TOSH_sched_entry_T;

extern TOSH_sched_entry_T TOSH_queue[];


unsigned char TOS_parampost(void (*tp) (), uint32_t arg) {

  DECLARE_CRITICAL_SECTION();
  uint8_t tmp;
  
  //  dbg(DBG_SCHED, ("TOSH_post: %d 0x%x\n", TOSH_sched_free, (int)tp));
  
  CRITICAL_SECTION_BEGIN();

  tmp = TOSH_sched_free;
  
  if (TOSH_queue[tmp].tp == 0x0) {
#ifdef TASK_QUEUE_DEBUG
    occupancy++;
    if (occupancy > max_occupancy) {
       max_occupancy = occupancy;
    }
#endif
    if(pushqueue(&paramtaskQueue, arg)){
    
      TOSH_sched_free = (tmp + 1) & sys_task_bitmask;
      TOSH_queue[tmp].tp = tp;
      TOSH_queue[tmp].postingFunction = (void *)__builtin_return_address(0);
      TOSH_queue[tmp].timestamp = OSCR0;
      TOSH_queue[tmp].executeTime = 0;
    }
    else{
      printFatalErrorMsg("paramtaskqueue full",0);
    }
      
    CRITICAL_SECTION_END();

    return 0x1;
  }
  else {	
#ifdef TASK_QUEUE_DEBUG
    failed_post++;
#endif
    CRITICAL_SECTION_END();
    printFatalErrorMsg("TaskQueue Full.  Size = ", 1,sys_max_tasks);
    return 0x0;
  }
}
