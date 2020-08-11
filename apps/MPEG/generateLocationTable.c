#include <stdio.h>
#include <stdlib.h>

#define NMOTES 56
#define POSITIONS 14 //sensor position

int moteLocation[NMOTES+1][POSITIONS];

int map(int a){
 switch(a){
  case 0:
    return 0;
  case 2:
    return 1;
  case 4:
    return 2;
  case 5:
    return 3;
  case 7:
    return 4;
  case 8:
    return 5;
  case 9:
    return 6;
  case 11:
    return 7;
  case 13:
    return 8;
  default:
    return -1;
  }
}

int main(void){

  FILE *fin;
  int nodeId,position,rssi;
  int i,j;
  char line[255];

  if((fin=fopen("myTable.dat","r")) == NULL){
  //if((fin=fopen("superLogFilterRSSI164.dat","r")) == NULL){
    printf("Opening file: superLogFilterRSSI164.dat failed\n");
    exit(0);
  }

  for(i=0;i<(NMOTES+1);i++)
    for(j=0;j<POSITIONS;j++)
      moteLocation[i][j]=-1;

  fgets(line,255,fin);
  //printf("%s\n",line);

  //while(fscanf(fin,"%d %d %d",&nodeId,&position,&rssi)==3){
  while(fscanf(fin,"%d %d",&nodeId,&position)==2){
      //printf("nodeId %d position %d\n",nodeId,position);
      if((position!=1)&&(position!=3)&&(position!=6)&&(position!=10)&&(position!=12)){
          moteLocation[nodeId][position]=position;
     }
  }
  fclose(fin);
  
  //if((fin=fopen("myTable.dat","r")) == NULL){
  if((fin=fopen("superLogFilterRSSI164.dat","r")) == NULL){
    printf("Opening file: superLogFilterRSSI164.dat failed\n");
    exit(0);
  }
  fgets(line,255,fin);

  while(fscanf(fin,"%d %d %d",&nodeId,&position,&rssi)==3){
      //printf("nodeId %d position %d\n",nodeId,position);
      if((position!=1)&&(position!=3)&&(position!=6)&&(position!=10)&&(position!=12)){
          moteLocation[nodeId][position]=position;
     }
  }

  for(i=0;i<(NMOTES+1);i++){
    printf("{");
    for(j=0;j<POSITIONS;j++){
      if((j==1)||(j==3)||(j==6)||(j==10)||(j==12)){
        continue;
      }

      if(j){printf(",");}
      printf("%2d",map(moteLocation[i][j]));
    }
    printf("},\n");
  }

  fclose(fin);

return 0;
}

