#ifndef __QUEUE_H__
#define __QUEUE_H__

#include "inttypes.h"

#define QUEUE_SIZE 256

enum{
  defaultQueueSize = QUEUE_SIZE
    };

typedef struct{
  uint32_t entries[QUEUE_SIZE];
  uint16_t head, tail;
  uint16_t size;
} queue_t;

typedef struct{
  void *entries[QUEUE_SIZE];
  uint16_t head, tail;
  uint16_t size;
} ptrqueue_t;


/**********
 *function to push an argument into a queue
 *
 *queue is a pointer to a previously initialized queue_t structure
 *val is the value that should be pushed
 *
 *returns 1 if successful, 0 otherwise
 ***********/
int pushqueue(queue_t *queue, uint32_t val);
int pushptrqueue(ptrqueue_t *queue, void *val);

/**********
 *function to pop a value from the queue
 *
 *queue is a pointer to a previously initialized queue_t structure
 *val is a pointer to storage for the value that will get popped
 *
 *returns 1 if successful, 0 otherwise
 ***********/
int popqueue(queue_t *queue, uint32_t *val);
void *popptrqueue(ptrqueue_t *queue, int *status);

/**********
 *function to peek a value from the queue.  This function will not remove
 *the item from the queue
 *
 *queue is a pointer to a previously initialized queue_t structure
 *val is a pointer to storage for the value that will get popped
 *
 *returns 1 if successful, 0 otherwise
 ***********/
int peekqueue(queue_t *queue, uint32_t *val);
void *peekptrqueue(ptrqueue_t *queue, int *status);

/**********
 *function to initialize a queue_t structure
 *
 *queue is a pointer to a previously initialized queue_t structure
 *size is the size of the queue that is getting initialized
 *
 *
 ***********/
void initqueue(queue_t *queue, uint32_t size);
void initptrqueue(ptrqueue_t *queue, uint32_t size);

int getCurrentQueueSize(queue_t *queue);
int getCurrentPtrQueueSize(ptrqueue_t *queue);

#endif
