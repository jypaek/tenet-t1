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
/*
 * Abstract Data Type Queue
 */

#include "queue.h"

void error(char *msg){
  printf("Error:%s\n",msg);
}

void fatal_error(char *msg){
  printf("Error:%s\n",msg);
  exit(1);
}

int is_full( QUEUE_t Q){
  return (Q->q_size == Q->q_max_size);
}

int is_empty( QUEUE_t Q ){
  return( Q->q_size == 0 );
}

int queue_size( QUEUE_t Q){
  return Q->q_size;
}

void init( QUEUE_t Q ){
  Q->q_size = 0;
  Q->q_front = 1;
  Q->q_rear = 0;
}

unsigned int succ( unsigned int value, QUEUE_t Q ){
  if( ++value == Q->q_max_size )
  value = 0;
  return value;
}

void enqueue( element_type x, QUEUE_t Q ){
  if( is_full( Q ) ) {
   dequeue(Q);//drop element
   enqueue(x,Q);
   //error("Full queue");
  }
  else {
    Q->q_size++;
    Q->q_rear = succ( Q->q_rear, Q );
    Q->q_array[ Q->q_rear ] = x;
  }
}

void getWindow( QUEUE_t Q, int size, element_type *x){
  int i;

  for(i=0;i<size;i++){
    //if( queue_size( Q )< size ) error("Empty queue");
    x[i] = Q->q_array[ (Q->q_front+i)%Q->q_max_size ];
  }
  
}

element_type dequeue( QUEUE_t Q ){
  element_type x;
  if( is_empty( Q ) ) error("Empty queue");
  x = Q->q_array[ Q->q_front ];
  Q->q_size--;
  Q->q_front = succ( Q->q_front, Q );
  return x;
}

QUEUE_t create_queue( unsigned int max_elements ){
  QUEUE_t Q;
  if( max_elements < 0 ) error("Stack size is too small");
  Q = (QUEUE_t) malloc( sizeof( struct queue_record ) );
  if( Q == NULL ) fatal_error("Out of space!!!");
  Q->q_array = (element_type *)malloc( sizeof( element_type ) * max_elements );
  if( Q->q_array == NULL ) fatal_error("Out of space!!!");
  Q->q_max_size = max_elements;
  init(Q);
  return( Q );
}

void dispose_queue( QUEUE_t Q ){
  if( Q != NULL ) {
    free( Q->q_array );
    free( Q );
  }
}
