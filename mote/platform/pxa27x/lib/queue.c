#include "queue.h"

int pushqueue(queue_t *queue, uint32_t val){
    //check to see if there is room in the queue
  uint16_t availableslots = (queue->head <= queue->tail) ? queue->size - queue->tail + queue->head: queue->head - queue->tail;
  //available entries in the queue is really size-1 since we need to guard against aliasing
  if(availableslots > 1 ){
    queue->entries[queue->tail] = val;
    queue->tail++;
    if(queue->tail >= queue->size){
      queue->tail = 0;
    }
    return 1;
    }
  else{
    return 0;
  }
}

int pushptrqueue(ptrqueue_t *queue, void *val){
    //check to see if there is room in the queue
  uint16_t availableslots = (queue->head <= queue->tail) ? queue->size - queue->tail + queue->head: queue->head - queue->tail;
  //available entries in the queue is really size-1 since we need to guard against aliasing
  if(availableslots > 1 ){
    queue->entries[queue->tail] = val;
    queue->tail++;
    if(queue->tail >= queue->size){
      queue->tail = 0;
    }
    return 1;
    }
  else{
    return 0;
  }
}

//get the value without removing it from the queue
int peekqueue(queue_t *queue, uint32_t *val) {
  if(queue->head != queue->tail){
    *val = queue->entries[queue->head];
    return 1;
  }
  else{
    *val = 0;
    //queue is empty
    return 0;
  }
}

void *peekptrqueue(ptrqueue_t *queue, int *status) {
  
  if(queue->head != queue->tail){
    *status = 1;
    return queue->entries[queue->head];
  }
  else{
    *status = 0;
    //queue is empty
    return 0;
  }
}

int getCurrentQueueSize(queue_t *queue){
  
  return (queue->head <= queue->tail) ? queue->size - queue->tail + queue->head: queue->head - queue->tail;

}

int getCurrentPtrQueueSize(ptrqueue_t *queue){
  
  return (queue->head <= queue->tail) ? queue->size - queue->tail + queue->head: queue->head - queue->tail;

}

int popqueue(queue_t *queue, uint32_t *val) {
  if(queue->head != queue->tail){
    *val = queue->entries[queue->head];
    queue->head++;
    if(queue->head >= queue->size){
      queue->head = 0;
    }
    return 1;
  }
  else{
    *val = 0;
    //queue is empty
    return 0;
  }
}

void *popptrqueue(ptrqueue_t *queue, int *status) {
  void *ret;
  
  if(queue->head != queue->tail){
    ret = queue->entries[queue->head];
    *status = 1;
    queue->head++;
    if(queue->head >= queue->size){
      queue->head = 0;
    }
    return ret;
  }
  else{
    *status = 0;
    //queue is empty
    return 0;
  }
}

void initqueue(queue_t *queue, uint32_t size) {
  queue->head = 0;
  queue->tail = 0;
  queue->size = size;
}

void initptrqueue(ptrqueue_t *queue, uint32_t size) {
  queue->head = 0;
  queue->tail = 0;
  queue->size = size;
}
