includes element_map;
includes tenet_task;

module TenetMainM {
  provides {
    interface StdControl;
#ifdef TESTING
    interface ReceiveMsg;
#endif
  }
  uses {
    interface Schedule;
    interface TenetTask;
    interface Element[uint8_t id];
#ifdef TESTING
    interface Timer;
#endif
  }
}
implementation {
#include "../../lib/tenet_debug.h"

  command result_t StdControl.init(){ return SUCCESS; }
  command result_t StdControl.start(){
    recvFrom_params_t recvFrom;
    //install_params_t install;
    active_task_t *atask;
    task_t *t;
    if ((t = call TenetTask.task_new(2,INSTALL_TASK)) == NULL){
      tlog(LOG_ERR,"can't create new task\n");
      return FAIL;
    }
    recvFrom.repeat = 1;
    recvFrom.flags = 0;
    tlog(LOG_DEBUG,"constructing install task\n");
    if (t){
      t->elements[0] = call Element.construct[ELEMENT_RECVFROM](t,&recvFrom,sizeof(recvFrom));
      t->elements[1] = call Element.construct[ELEMENT_INSTALL](t,NULL,0);
    }
    tlog(LOG_DEBUG,"hello earth\n");
    tlog(LOG_DEBUG,"done constructing install task\n");
    if ((atask = call TenetTask.active_task_new(t)) == NULL){
      tlog(LOG_ERR,"can't create new active task\n");
      //TODO call TenetTask.task_delete(t);
      return FAIL;
    }
    tlog(LOG_DEBUG,"starting the scheduler...\n");
    call Schedule.first(atask);
    tlog(LOG_DEBUG,"scheduler started\n");
#ifdef TESTING
    call Timer.start(TIMER_ONE_SHOT, 1000);
#endif
    tlog(LOG_DEBUG,"exiting function\n");
    return SUCCESS; 
  }

#ifdef TESTING
  event result_t Timer.fired(){

#ifdef TEST_SLOWSEND
    {
    TOS_Msg m;
    tenet_old_msg_t *tmsg;
    install_msg_t *imsg;
    attr_t *attr;
    attr_t *attr2;
    slowSample_params_t *sample;
    sendTo_params_t *sendTo;

    tlog(LOG_DEBUG,"creating test task\n");
    tmsg = (tenet_old_msg_t *)(m.data);
    tmsg->src = 99;
    tmsg->task_id = INSTALL_TASK;
    tmsg->seqno = 1;
    imsg = (install_msg_t *)(tmsg->data);
    imsg->task_id = 5;
    imsg->num_elements = 2;
    imsg->type = INSTALL;

    attr = (attr_t *)(imsg->data);
    attr->type = ELEMENT_SLOWSAMPLE;
    attr->length = sizeof(slowSample_params_t);
    sample = (slowSample_params_t *)(attr->value);
    (sample->period).rate = 100; // ms
    (sample->period).unit = MILLI;
    sample->count = 1;
    sample->repeat = TRUE;
    sample->numChannels = 1;
    sample->channel[0] = 0;
    sample->outputName[0]  = 0x78;

    attr2 = (attr_t *)(attr->value + sizeof(slowSample_params_t));
    attr2->type = ELEMENT_SENDTO;
    attr2->length = sizeof(sendTo_params_t);
    sendTo = (sendTo_params_t *)(attr2->value);
    sendTo->dest = TOS_BCAST_ADDR;

    m.length = sizeof(tenet_old_msg_t) + sizeof(install_msg_t) 
      + sizeof(attr_t) + sizeof(slowSample_params_t) 
      + sizeof(attr_t) + sizeof(sendTo_params_t);
    tlog(LOG_DEBUG,"injecting task\n");
    signal ReceiveMsg.receive(&m);
    tlog(LOG_DEBUG,"task injected\n");
    }
#endif

#ifdef TEST_SLOW
    {
    TOS_Msg m;
    tenet_old_msg_t *tmsg;
    install_msg_t *imsg;
    attr_t *attr;
    slowSample_params_t *sample;

    tlog(LOG_DEBUG,"creating test task\n");
    tmsg = (tenet_old_msg_t *)(m.data);
    tmsg->src = 99;
    tmsg->task_id = INSTALL_TASK;
    tmsg->seqno = 1;
    imsg = (install_msg_t *)(tmsg->data);
    imsg->task_id = 5;
    imsg->num_elements = 1;
    imsg->type = INSTALL;

    attr = (attr_t *)(imsg->data);
    attr->type = ELEMENT_SLOWSAMPLE;
    attr->length = sizeof(slowSample_params_t);
    sample = (slowSample_params_t *)(attr->value);
    (sample->period).rate = 200; // ms
    (sample->period).unit = MILLI;
    sample->count = 1;
    sample->repeat = TRUE;
    sample->numChannels = 1;
    sample->channel[0] = 0;
    sample->outputName[0]  = 0x78;

    m.length = sizeof(tenet_old_msg_t) + sizeof(install_msg_t) 
      + sizeof(attr_t) + sizeof(slowSample_params_t);
    tlog(LOG_DEBUG,"injecting task\n");
    signal ReceiveMsg.receive(&m);
    tlog(LOG_DEBUG,"task injected\n");
    }
#endif

    return SUCCESS;
  }
#endif


  command result_t StdControl.stop(){ return SUCCESS; }

  default command element_t *Element.construct[uint8_t id](task_t *t,
                                                           void *data,
                                                           uint16_t length){
    return NULL;
  }
  
}
