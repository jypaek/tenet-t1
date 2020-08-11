/*
  * Author:		Josh Herbach
  * Revision:	1.0
  * Date:		09/02/2005
  */

/*------------------------------------------------------------------*/
/* dynqueue.h                                                       */
/*------------------------------------------------------------------*/

#ifndef __PXA27Xdynqueue_H__
#define __PXA27Xdynqueue_H__

typedef struct DynQueue_T *DynQueue;
/* A DynQueue is an fifo queue whose length can expand dynamically. */

DynQueue DynQueue_new();
/* Return a new DynQueue. */

void DynQueue_free(DynQueue oDynQueue);
/* Free oDynQueue. */

int DynQueue_getLength(DynQueue oDynQueue);
/* Return the length of oDynQueue.*/

void *DynQueue_dequeue(DynQueue oDynQueue);
/* Dequeues the first element of oDynQueue.*/

int DynQueue_enqueue(DynQueue oDynQueue, const void *pvItem);
/* Adds pvItem to oDynQueue.*/

void *DynQueue_peek(DynQueue oDynQueue);
/* Returns the first element of oDynQueue without removing it.*/

void DynQueue_push(DynQueue oDynQueue, const void *pvItem);
/* Puts an item at the head of oDynQueue the queue.*/

#endif //__PXA27Xdynqueue_H__

