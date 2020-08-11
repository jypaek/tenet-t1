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
*  Pursuer Evader Game using Tenet
*
*
* Task all motes to receive Evader Beacon and if above some threshold, send it back.
* Motes should be programed with TenetBasic.
* Evader needs to send radio beacon. Radio packets simulate Sensor behavior.
* After receiving at least N number of mote reports, calculate probably Evader position.
* Plan Pursuer Robot to reach Evader. 
* Move Robot to catch Evader.
* Keep doing that indefinitely.
*
*/
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>
#include <signal.h>
#include <time.h>
#include <unistd.h>
//#include "transportAPI.h"
//#include "taskingAPI.h"
#include "tenet.h"
#include "querytime.h"
#include "localization.h"
#include "queue.h"
#include "plan_vfh.h"
#include "playerc.h"
#include "planning.h"
#include "setposition.h"

/*If GET_MOTE_TIME defined:
  Need a mote nodeId 57 running timesyncr
  Need ./sf 9002 <device> 57600 <platform>
*/
//#define GET_MOTE_TIME

#define MAX_QUEUE_SIZE 250
#define MIN_PACKET_2_PROCESS 8 //minimum number of packet to estimate localization

//graph topology
double **matrix;
node_t* nodes;
int nVertex;

FILE *fptr;//log file

//char *task_string = "wait(500,0,1)->global_time(0xaa)->sample_rssi(0x321)->thresh(160,0x321,1)->send()";
char task_string[200];
int isRobot=0;

void bye(){
  printf("Bye\n");
  fflush(stdout);
  //close log file
  fflush(fptr);
  fclose(fptr);
  //dispose_queue(queue);//free queue
  //close planning
  free(matrix);
  free(nodes);
  //close robot
  if(isRobot){
        closeRobotSystem();
/*      playerc_position_unsubscribe(position);
        playerc_position_destroy(position);
        playerc_client_disconnect(client);
        playerc_client_destroy(client);*/
  }
    exit(0);
}

/* signal handler for Ctrl-C */
void handler_C(int sig_num){
  bye();
}

void create_task(int *tid,char *task_string){

    *tid = send_task(task_string);// send the task
    if (*tid > 0) {                  
        printf("\ntasking packet has been sent with tid %d!!\n", *tid);
    } else {
        printf("\nfailed to create task\n");
    }
}


void printTime(int count){
    struct timeval tv;
    char buffer[30];
    time_t curtime;

    gettimeofday(&tv,0);
    curtime=tv.tv_sec;
    strftime(buffer,30,"%T.",localtime(&curtime));
    fprintf(fptr, " ComputerTime %s%ld ",buffer,tv.tv_usec);

    /*get attached mote time*/
    #ifdef GET_MOTE_TIME
    if(count>100){
	fprintf(fptr,"CurrentTime %ld ",current_time());
        count=0;
    }else{
        fprintf(fptr, "CurrentTime 0 ");
    }
    #endif
    fprintf(fptr,"\n");

}

/*get id from response packet*/
int getId(){
    struct response *list;
    int id;

    /* receive response packets */
    list = read_response(100);
    if (list == NULL) {//did not get any response.
        switch(get_error_code()){
            case TIMEOUT://timeout which means we received all messages
                return -1;
            case MOTE_ERROR://mote error, keep receiving other messages
                return -1;
            break;
            default://transport is probably broken
                fprintf(stderr,"error code %d\n",get_error_code());
                bye();//exit(0);
            break;
            }
        }

    /*extract data*/
    id = response_mote_addr(list);

    response_delete(list);

    return id;
}

void construct_string(char *a,int threshold){
  sprintf(a,"wait(1000,1)->sample_rssi(0xAA)->comparison(0xBB,0xAA,<,'%d')->deleteattributeif(0xBB,0xAA)->deleteattribute(0xBB)->send()",threshold);
}

//did not test it yet
void adapt_threshold(int *tid,int newThreshold, char*string){
    /*retask*/
    if(*tid) delete_task(*tid);
    *tid=0;//need to set to zero
    construct_string(string,newThreshold);
    printf("%s\n",string);
    create_task(tid,string);
}

void get_rssi_readings(int tid,int *count,QUEUE_t queue){
  int id;
  do{
    id=getId();
    if(id>=0){
      printTime(*count);(*count)++;
      enqueue(id,queue);
    }
    printf("id=%d\n",id);
    if(queue_size(queue)>0.6*MAX_QUEUE_SIZE)break;//need to check
  }while( (queue_size(queue)<MIN_PACKET_2_PROCESS)||(id>=0) );


}

int compute_path_and_move_pursuer(int pursuer_position,int evader_position){
  vector_t path;
  int new_position;

  if(evader_position<0)return pursuer_position;//do not move

  if (pursuer_position==evader_position){
     //target=1;
     return pursuer_position;//same position
  }

  path=plan(pursuer_position,evader_position,matrix,nVertex);
  printf("Moving from %d to %d\n",pursuer_position,evader_position);

  //need to start again
  //target=0;
  
  printf("Doing the plan:");printPath(path);

  new_position=path.vector[path.size-2];//-2 because the last position is the current position.
 
  printf("\nGoing to Pos x: %.2lf y: %.2lf id:%d\n",nodes[new_position].x,nodes[new_position].y,new_position);
  my_playerc_position_set_cmd_pose(nodes[new_position].x,nodes[new_position].y);

  return new_position;//new position
}

void usage(void){
  printf("---< Pursuer Evader Game Application Program >----\n");
  printf(" - Send command to a mote, and receive data whenever mote hear Evader \n");
  printf(" - Send robot to where hear Evader \n");
  printf("usage:\n");
  printf("\t [-h <hostname>]\n");
  printf("\t [-p <port number>]\n");
  printf("\t [-t <topology file>]\n");
  printf("\t [-r] Enable to execute with robot\n");
}

int main(int argc, char **argv){
    int tid=0;

    int count=0;
    int pursuer_position=0;

    int isTopologyOn=0;
    char topologyFilename[255];
    char tr_host[255];
    int tr_port;
    int c;
    QUEUE_t queue;
    int evader_position;

    /* set the INT (Ctrl-C) signal handler to function handler_C */
    signal(SIGINT, handler_C);
    /*default values*/
    strcpy(tr_host, "127.0.0.1");
    tr_port = 9998;

  while ((c = getopt(argc, argv, "h:p:t:r:")) != -1)
    switch(c){
      case 'h':
        strcpy(tr_host,optarg);
        break;
      case 'p':
        tr_port=atoi(optarg);
        break;
      case 't':
        strcpy(topologyFilename,optarg);
        isTopologyOn=1;
        break;
      case 'r':
        isRobot=1;
        break;
      case '?':
      default:
        usage();
        exit(1);
    }

    //transport
	config_transport(tr_host,tr_port);

    //log
    fptr = fopen("packets.log","w");
    if(fptr==NULL){
      printf("\nFile Error\n Trying to open:packets log file\n");
    }

    if(isTopologyOn){
      printf("Loading topology...\n");
      loadTopology(topologyFilename,&matrix,&nodes,&nVertex);
      printf("Topology loaded\n");
    }
    if(isRobot){
      printf("What is the initial position?\n");
      scanf("%d",&pursuer_position);
      initRobotSystem();
    }

    queue = create_queue(MAX_QUEUE_SIZE);

    /*to get pursuer mote time*/
    #ifdef GET_MOTE_TIME
    setup_serial_connection("localhost", "9002", 57);
    #endif

    /*start taks*/
    adapt_threshold(&tid,160,task_string);
    //construct_string(task_string,160);
    //create_task(&tid,task_string);
    
    /* receive response packets */
    while(1) {

        get_rssi_readings(tid,&count,queue);
        evader_position=compute_evader_position(queue,fptr);

        if(isRobot){
            pursuer_position=compute_path_and_move_pursuer(pursuer_position,evader_position);
            printf("Pursuer position %d\n",pursuer_position);
        }

    }//end while


    delete_task(tid);                                                           
    return 0;
}
