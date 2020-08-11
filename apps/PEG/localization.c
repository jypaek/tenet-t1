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
 * Given multiset of mote id, calculate which is the best position to have received them.
 * Use voting system. 
 */
#include <stdio.h>
#include <sys/types.h>
#include <time.h>
#include "queue.h"
#include "localization.h"

#define NMOTES 56
#define POSITIONS 14 //sensor position

int moteLocation[NMOTES+1][POSITIONS]={
{-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1},
{-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1},
{-1,-1,-1,-1,-1,-1,-1, 7,-1,-1,-1,-1,-1,-1},
{-1,-1,-1,-1,-1,-1, 6, 7,-1,-1,-1,-1,-1,-1},
{-1,-1,-1,-1,-1,-1, 6, 7,-1,-1,-1,-1,-1,-1},
{-1,-1,-1,-1,-1,-1, 6, 7,-1,-1,-1,-1,-1,-1},
{-1,-1,-1,-1,-1,-1, 6, 7,-1,-1,-1,-1,-1,-1},
{-1,-1,-1,-1,-1,-1, 6, 7,-1,-1,-1,-1,-1,-1},
{-1,-1,-1,-1,-1,-1,-1, 7,-1,-1,-1,-1,-1,-1},
{-1,-1,-1,-1,-1,-1,-1, 7,-1,-1,-1,-1,-1,-1},
{-1,-1,-1,-1,-1,-1, 6, 7,-1,-1,-1,-1,-1,-1},
{-1,-1,-1,-1,-1,-1, 6,-1,-1,-1,-1,-1,-1,-1},
{-1,-1,-1,-1,-1, 5, 6,-1,-1,-1,-1,-1,-1,-1},
{-1,-1,-1,-1,-1, 5, 6,-1,-1,-1,-1,-1,-1,-1},
{-1,-1,-1,-1,-1, 5,-1,-1,-1,-1,-1,-1,-1,-1},
{-1,-1,-1,-1, 4, 5, 6,-1,-1,-1,-1,-1,-1,-1},
{-1,-1,-1,-1, 4, 5,-1,-1, 8,-1,-1,-1,-1,-1},
{-1,-1,-1,-1, 4, 5,-1,-1,-1,-1,-1,-1,-1,-1},
{-1,-1,-1,-1, 4,-1,-1,-1,-1,-1,-1,-1,-1,-1},
{-1,-1,-1, 3,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1},
{-1,-1,-1,-1, 4,-1,-1,-1, 8,-1,-1,-1,-1,-1},
{-1,-1,-1,-1,-1,-1,-1,-1, 8,-1,-1,-1,-1,-1},
{-1, 1, 2, 3,-1,-1,-1,-1, 8,-1,-1,-1,-1,-1},
{-1,-1, 2,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1},
{ 0, 1, 2, 3,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1},
{-1, 1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1},
{ 0, 1, 2,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1},
{ 0, 1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1},
{ 0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1},
{-1,-1,-1,-1,-1,-1,-1,-1, 8, 9,-1,-1,-1,-1},
{-1,-1,-1,-1,-1,-1,-1,-1, 8, 9,-1,-1,-1,-1},
{-1,-1,-1,-1,-1,-1,-1,-1, 8, 9,-1,-1,-1,-1},
{-1,-1,-1,-1,-1,-1,-1,-1, 8, 9,-1,-1,-1,-1},
{-1,-1,-1,-1,-1,-1,-1,-1,-1, 9,-1,-1,-1,-1},
{-1,-1,-1,-1,-1,-1,-1,-1,-1, 9,10,-1,-1,-1},
{-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,10,-1,-1,-1},
{-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,10,11,12,-1},
{-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,11,-1,-1},
{-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,10,11,12,13},
{-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,12,-1},
{-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,12,13},
{-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,12,13},
{-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,13},
{-1,-1,-1, 3,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1},
{-1,-1,-1, 3,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1},
{-1,-1, 2, 3,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1},
{-1,-1, 2,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1},
{-1, 1, 2, 3,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1},
{-1,-1, 2, 3,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1},
{-1, 1, 2,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1},
{-1, 1, 2,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1},
{ 0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1},
{ 0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1},
{ 0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1},
{ 0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1},
{ 0, 1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1},
{ 0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1}
};

int compute_evader_position(QUEUE_t queue,FILE* fptr){

  int npackets;
  int i,indxMax,max;
  int element=0;
  int moteBitVector[POSITIONS+1];

  for(i=0;i<=POSITIONS;i++)moteBitVector[i]=0;
  npackets=0;

  while(!is_empty(queue)){
    element=dequeue(queue);
    npackets++;
    for(i=0;i<POSITIONS;i++)
      moteBitVector[(moteLocation[element][i])+1]++;
  }

  //calculate mode
  //0 is position flag means no packet received
  indxMax=1;
  max=moteBitVector[indxMax];
  for(i=2;i<=POSITIONS;i++){
    if(moteBitVector[i]>max){
      indxMax=i;
      max=moteBitVector[indxMax];
    }
  }

  fprintf(fptr,"#Position %d Npackets %d\n",indxMax-1,npackets);
  return indxMax-1;
}

#ifdef TEST
#define MAXPACKETS 15
int main(){
  QUEUE_t queue;
  int i;
  int id;
  int npackets;
  time_t t1;

  (void) time(&t1);
   srand48((long) t1); /* use time in seconds to set seed */

  queue = create_queue(200);
  
  while(1){
    //enqueue positions
    printf("PacketsId: ");
    npackets=lrand48()%MAXPACKETS;
    for(i=0;i<npackets;i++){
      id=lrand48()%(NMOTES+1);
      enqueue(id,queue);
      printf("%02d ",id);
    }
    //for(i=npackets;i<MAXPACKETS;i++)printf("   ");

    compute_evader_position(queue,stdout);
  }

  // lrand48() returns non-negative  long  integers
  // uniformly distributed over the interval (0, ~2**31)

}
#endif
