/* 
 * Author:		Josh Herbach
 * Revision:	1.0
 * Date:		09/02/2005
 */

/*------------------------------------------------------------------*/
/* dynqueue.c                                                       */
/*------------------------------------------------------------------*/

#include "PXA27Xdynqueue.h"

#define MIN_PHYS_LENGTH 2

struct DynQueue_T
{
   int iLength;
   int iPhysLength;
   int index;
   const void **ppvQueue;
};

/*------------------------------------------------------------------*/

DynQueue DynQueue_new()

/* Return a new DynQueue. */

{
   DynQueue oDynQueue;

   oDynQueue = (DynQueue)malloc(sizeof(struct DynQueue_T));
   //assert(oDynQueue != NULL);
   if(oDynQueue == NULL)
	   return NULL;
   
   oDynQueue->iLength = 0;
   oDynQueue->iPhysLength = MIN_PHYS_LENGTH;
   oDynQueue->ppvQueue = 
      (const void**)calloc(oDynQueue->iPhysLength, sizeof(void*));
   //assert(oDynQueue->ppvQueue != NULL);
   if(oDynQueue->ppvQueue == NULL)
	   return NULL;

   oDynQueue->index = 0;
   return oDynQueue;
}

/*------------------------------------------------------------------*/

void DynQueue_free(DynQueue oDynQueue)

/* Free oDynQueue. */

{
   if (oDynQueue == NULL)
      return;
   
   free(oDynQueue->ppvQueue);
   free(oDynQueue);
}

/*------------------------------------------------------------------*/

int DynQueue_getLength(DynQueue oDynQueue)

/* Return the length of oDynQueue.*/

{
   //assert(oDynQueue != NULL);
   if(oDynQueue == NULL)
	   return 0;
   return oDynQueue->iLength;
}

/*------------------------------------------------------------------*/

void *DynQueue_peek(DynQueue oDynQueue)
/* Returns the first element of oDynQueue without removing it.*/
{
	//assert(oDynQueue != NULL);
	//assert(oDynQueue->iLength > 0);
	if(oDynQueue == NULL || oDynQueue->iLength <= 0)
		return NULL;
	return (void*)(oDynQueue->ppvQueue)[oDynQueue->index];
}

/*------------------------------------------------------------------*/

static void DynQueue_shiftgrow(DynQueue oDynQueue)

/* Shift the elements to the start of the array
	or double the physical length of oDynQueue. */

{
	//assert(oDynQueue != NULL);
	if(oDynQueue == NULL)
		return;
   //choosing to waste space over wasting time by not always shifting
	if(oDynQueue->index > 2 && oDynQueue->index > oDynQueue->iPhysLength / 8){
	   memmove((void *)oDynQueue->ppvQueue, (void *)(oDynQueue->ppvQueue + oDynQueue->index), sizeof(void *) * oDynQueue->iLength);
	   oDynQueue->index = 0;
	}
   else{
	   oDynQueue->iPhysLength *= 2;
	   oDynQueue->ppvQueue =  (const void**)realloc(oDynQueue->ppvQueue, 
		   sizeof(void*) * oDynQueue->iPhysLength);
	   //assert(oDynQueue->ppvQueue != NULL);
   }
}

/*------------------------------------------------------------------*/

static void DynQueue_shiftshrink(DynQueue oDynQueue)

/* Shift the elements to the start of the array
	and halves the physical length of oDynQueue.*/
{
	//assert(oDynQueue != NULL);
	if(oDynQueue == NULL)
		return;
   //choosing to waste space over wasting time by not always shifting
	if(oDynQueue->index > 0){
	   memmove((void *)oDynQueue->ppvQueue, (void *)(oDynQueue->ppvQueue + oDynQueue->index), sizeof(void *) * oDynQueue->iLength);
	   oDynQueue->index = 0;
	}
    oDynQueue->iPhysLength /= 2;
	oDynQueue->ppvQueue = (const void**)realloc(oDynQueue->ppvQueue, 
		sizeof(void*) * oDynQueue->iPhysLength);
	   //assert(oDynQueue->ppvQueue != NULL);
}

/*------------------------------------------------------------------*/

int DynQueue_enqueue(DynQueue oDynQueue, const void *pvItem)
/* Adds pvItem to oDynQueue.*/
{
   //assert(oDynQueue != NULL);
	if(oDynQueue == NULL)
	  return 0;

   if (oDynQueue->iLength + oDynQueue->index == oDynQueue->iPhysLength)
      DynQueue_shiftgrow(oDynQueue);
   
   oDynQueue->ppvQueue[oDynQueue->index + oDynQueue->iLength] = pvItem;
   oDynQueue->iLength++;

   return oDynQueue->iLength;
}

/*------------------------------------------------------------------*/

void *DynQueue_dequeue(DynQueue oDynQueue)
/* Dequeues the first element of oDynQueue.*/
{
   const void *pvItem;

   //assert(oDynQueue != NULL);
   //assert(oDynQueue->iLength > 0);
	if(oDynQueue == NULL || oDynQueue->iLength <= 0)
		return NULL;

   pvItem = oDynQueue->ppvQueue[oDynQueue->index];
   oDynQueue->ppvQueue[oDynQueue->index] = NULL;
   
   oDynQueue->iLength--;
   oDynQueue->index++;

   if(oDynQueue->iLength + 5 < oDynQueue->iPhysLength / 2)
	   DynQueue_shiftshrink(oDynQueue);
   return (void*)pvItem;
}

/*------------------------------------------------------------------*/

void DynQueue_push(DynQueue oDynQueue, const void *pvItem){
	//assert(oDynQueue != NULL);
	if(oDynQueue == NULL)
		return;

	if(oDynQueue->iLength == oDynQueue->iPhysLength) //if <- is true, then index == 0
		DynQueue_shiftgrow(oDynQueue);

	if(oDynQueue->index > 0)
		oDynQueue->index--;
	else//assumed index == 0
		memmove((void *)(oDynQueue->ppvQueue + 1), (void *)oDynQueue->ppvQueue, sizeof(void *) * oDynQueue->iLength);
	oDynQueue->iLength++;
	oDynQueue->ppvQueue[oDynQueue->index] = pvItem;
}
