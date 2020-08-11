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
 * Calculate the shortest path from a source to all nodes
 * Input: read adjacent matrix in input file
 * Output shortest path and cost
 * Based on algorithm matrixpfs() of Algorithms in C, Robert Sedgewick, pp466
 */

/*
 * Need to use position 0 of vector for flags
 * Thus, node i is label i+1 in the program
 */
#include "planning.h"
//#define DEBUG

int *dad;
double *val;

void shortestDistance(int V,int source,double **a){
/*Shortest Path*/
/* Priority Queue is implemented directly at val*/
/*Signal at val means the node is at the tree or priority queue*/
/*dad represents tree*/
  double priority=0;
  int k,t,min=0;
  for (k=0;k<=V;k++){
    val[k]=-UNSEEN;
    dad[k]=0;
  }


  val[0]=-(UNSEEN+1);//flag

  for (k=source;k!=0;k=min,min=0){
    val[k]=-val[k];
    if (val[k]==UNSEEN) val[k]=0;
    for (t=1;t<=V;t++)
      if (val[t]<0){
        priority=a[k][t]+val[k];
        if (a[k][t]&&(val[t]<-priority)){
          val[t]=-priority;dad[t]=k;

          #ifdef DEBUG
          /*Visiting edge*/
            printf("visit edge: %d %d \n",k,t);
          #endif
        }

        if (val[t]>val[min]) min=t;
      }

  }
}


void printMatrix(double **matrix,int size){
  int i,j;

  printf("Adjacent Matrix\n");

  for(i=0;i<=size;i++){
    for(j=0;j<=size;j++){
      printf("%lf ",matrix[i][j]);
     }
  printf("\n");
  }

}

vector_t getPath(int i){
  int j;
  vector_t result;
  result.size=0;

  j=i+1;//node j was label j+1
  while (j>0){
    result.vector[result.size]=(j-1);//minus 1 because we label node i i+1
    result.size++;
    j=dad[j];
  }

  return result;
}

void printPath(vector_t input){
  int indx;
  for (indx =input.size-1;indx>=0; indx--){
    printf("%d ",input.vector[indx]);// Write out vector item
  } 
  printf("\n");

}

vector_t plan(int source,int destination,double**a,int nVertex){
  shortestDistance(nVertex,source+1,a);//source=source+1 due to label
  return getPath(destination);
}

void loadTopology(char* configFileName,double ***distance_t,node_t** nodes,int *nvertices){
  /* Read config file to get number of vertex and edges*/
  FILE* configFile;
  int nVertex,nEdges;
  int i,j;

  #ifdef DEBUG
    printf("Input File Name:%s\n"configFileName);
  #endif

  configFile=fopen(configFileName,"r");

  if(configFile==NULL){
    printf("\nFile Error\nTrying to open:%s\n",configFileName);
    exit (1);
  }

  fscanf(configFile,"%d %d",&nVertex,&nEdges);

  *nvertices=nVertex;

  /* create Adjacent Matrix*/
  //(*distance_t)=new double*[nVertex+1];
 (*distance_t)=(double**)malloc(sizeof(double*[nVertex+1]));

 for(i=0;i<=nVertex;i++)
   //(*distance_t)[i]=new double[nVertex+1];
   (*distance_t)[i]=(double*)malloc(sizeof(double[nVertex+1]));


  for( i=0;i<=nVertex;i++){
    for( j=0;j<=nVertex;j++){
      (*distance_t)[i][j]=0.0;
    }
  }

  //dad=new int[nVertex+1];
  dad=(int*)malloc(sizeof(int[nVertex+1]));
  for( i=0;i<=nVertex;i++){
    dad[i]=0;
  }

  //val=new double[nVertex+1];
  val=(double*)malloc(sizeof(double[nVertex+1]));

  //(*nodes)=new node_t[nVertex+1];
  (*nodes)=(node_t*)malloc(sizeof(node_t[nVertex+1]));
 
 /*read input file*/
  /*NodeID1 X Y*/
  int id;
  double x1,y1;
  for( i=0;i<nVertex;i++){
      fscanf(configFile,"%d %lf %lf",&id,&x1,&y1);

      (*nodes)[id].x=x1;
      (*nodes)[id].y=y1;

      #ifdef DEBUG
        printf("%d %d \n",x1,y1);
      #endif

  }


  /*read input file*/
  /*NodeID1 NodeID2 weight*/
  int n1,n2;
  double dx,dy;
  while(fscanf(configFile,"%d %d",&n1,&n2)==2){

      dx=(*nodes)[n1].x-(*nodes)[n2].x;
      dy=(*nodes)[n1].y-(*nodes)[n2].y;

      (*distance_t)[n1+1][n2+1]= sqrt(dx*dx+dy*dy);
      (*distance_t)[n2+1][n1+1]= (*distance_t)[n1+1][n2+1];

      #ifdef DEBUG
        printf("%d %d %d \n",n1,n2,(*distance_t)[n1+1][n2+1]);
      #endif

  }

  fclose(configFile);
}
