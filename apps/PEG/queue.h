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

/*
* Authors: Marcos Augusto Menezes Vieira
* Embedded Networks Laboratory, University of Southern California
*/
#ifndef QUEUE_H
#define QUEUE_H
#include <stdio.h>
#include <stdlib.h>

typedef int element_type;
struct queue_record{
	unsigned int q_max_size; /* Maximum # of elements */
	/* until Q is full */
	unsigned int q_front;
	unsigned int q_rear;
	unsigned int q_size; /* Current # of elements in Q */
	element_type *q_array;
};

typedef struct queue_record * QUEUE_t;

int is_full( QUEUE_t Q);

int is_empty( QUEUE_t Q );

int queue_size( QUEUE_t Q);

void init( QUEUE_t Q );

unsigned int succ( unsigned int value, QUEUE_t Q );

void enqueue( element_type x, QUEUE_t Q );

element_type dequeue( QUEUE_t Q );

QUEUE_t create_queue( unsigned int max_elements );

void dispose_queue( QUEUE_t Q );

#endif
