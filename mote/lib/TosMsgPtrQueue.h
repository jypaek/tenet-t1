/*
* "Copyright (c) 2006 University of Southern California.
* All rights reserved.
*
* Permission to use, copy, modify, and distribute this software and its
* documentation for any purpose, without fee, and without written
* agreement is hereby granted, provided that the above copyright
* notice, the following two paragraphs and the author appear in all
* copies of this software.
*
* IN NO EVENT SHALL THE UNIVERSITY OF SOUTHERN CALIFORNIA BE LIABLE TO
* ANY PARTY FOR DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL
* DAMAGES ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS
* DOCUMENTATION, EVEN IF THE UNIVERSITY OF SOUTHERN CALIFORNIA HAS BEEN
* ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*
* THE UNIVERSITY OF SOUTHERN CALIFORNIA SPECIFICALLY DISCLAIMS ANY
* WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
* MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.  THE SOFTWARE
* PROVIDED HEREUNDER IS ON AN "AS IS" BASIS, AND THE UNIVERSITY OF
* SOUTHERN CALIFORNIA HAS NO OBLIGATION TO PROVIDE MAINTENANCE,
* SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS."
*
*/

/**
 * Defines necessary structures/functions for using a queue of TOS_Msg pointers.
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 1/11/2006
 **/


#ifndef _TOS_MSG_PTR_QUEUE_H_
#define _TOS_MSG_PTR_QUEUE_H_

#include "AM.h"
// To use this queue, you must do the following.
//	- 1. Declare pointer buffer: "TOS_MsgPtr buf[size];"
//	- 2. Declare queue head	: "TosMsgPtrQueue queue;"
//	- 3. Initiallize queue	: "queueInit(&queue, buf, size);"

	struct TosMsgPtrQueue {
		uint8_t enqueueNext;
		uint8_t dequeueNext;
		uint8_t queueSize;
		uint8_t queueMaxLength;
		TOS_MsgPtr *bufferPtr;
	};

	void TosMsgPtrQueue_init(struct TosMsgPtrQueue *queue, TOS_MsgPtr *buffer, uint8_t size) {
		queue->bufferPtr = buffer;
		queue->enqueueNext = 0;
		queue->dequeueNext = 0;
		queue->queueSize = 0;
		queue->queueMaxLength = size;
	}

	bool TosMsgPtrQueue_isEmpty(struct TosMsgPtrQueue *queue) {
		if (queue->queueSize == 0)
			return TRUE;
		else
			return FALSE;
	}

	bool TosMsgPtrQueue_isFull(struct TosMsgPtrQueue *queue) {
		if (queue->queueSize == queue->queueMaxLength)
			return TRUE;
		else
			return FALSE;
	}

	result_t TosMsgPtrQueue_enqueue(struct TosMsgPtrQueue *queue, TOS_MsgPtr msg) {
		if (TosMsgPtrQueue_isFull(queue))
			return FAIL;
		queue->bufferPtr[queue->enqueueNext] = msg;
		queue->enqueueNext++;
		queue->enqueueNext %= queue->queueMaxLength;
		queue->queueSize++;
		return SUCCESS;
	}

	TOS_MsgPtr TosMsgPtrQueue_dequeue(struct TosMsgPtrQueue *queue) {
		TOS_MsgPtr returnMsg = queue->bufferPtr[queue->dequeueNext];
		if (TosMsgPtrQueue_isEmpty(queue))
			return NULL;
		queue->bufferPtr[queue->dequeueNext] = NULL;
		queue->dequeueNext++;
		queue->dequeueNext %= queue->queueMaxLength;
		queue->queueSize--;
		return returnMsg;
	}

	TOS_MsgPtr TosMsgPtrQueue_delete_ith(struct TosMsgPtrQueue *queue, uint8_t i) {
		TOS_MsgPtr deleteMsg;
		if (TosMsgPtrQueue_isEmpty(queue))
			return NULL;
		deleteMsg = queue->bufferPtr[(queue->dequeueNext + i - 1) % queue->queueMaxLength];
		queue->bufferPtr[(queue->dequeueNext + i - 1) % queue->queueMaxLength] = queue->bufferPtr[queue->dequeueNext];
		TosMsgPtrQueue_dequeue(queue);
		return deleteMsg;
	}

	TOS_MsgPtr TosMsgPtrQueue_getFirst(struct TosMsgPtrQueue *queue) {
		return queue->bufferPtr[queue->dequeueNext];
	}

	 TOS_MsgPtr TosMsgPtrQueue_get_ith(struct TosMsgPtrQueue *queue, uint8_t i) {
		return queue->bufferPtr[(queue->dequeueNext + i - 1) % queue->queueMaxLength];
	}

#endif // _TOS_MSG_PTR_QUEUE_H_
