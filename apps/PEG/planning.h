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
#ifndef PLAN_H
#define PLAN_H
#include <stdio.h>
#include <stdlib.h>
#include <math.h>

#define UNSEEN    32000 //flag: big number but not the biggest
#define MAXVECTOR 1000 //maximum number of elements in vector

typedef struct {
  double x;
  double y;
}node_t;

typedef struct {
 int size;
 int vector[MAXVECTOR];
}vector_t;

void loadTopology(char* configFileName,double ***distance_t,node_t** nodes,int *nvertices);
vector_t plan(int source,int destination,double**a,int nVertex);
vector_t getPath(int i);
void shortestDistance(int V,int source,double **a);
void printMatrix(double **matrix,int size);
void printPath(vector_t input);

#endif
