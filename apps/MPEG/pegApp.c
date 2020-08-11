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
*  Multiple Pursuer Evader Game using Tenet
*
* Task all motes to receive Evader Beacon and if above some threshold, send it back.
* Motes should be programed with TenetBasic.
* Evader needs to send radio beacon. Radio packets simulate Sensor behavior.
* Write to file possible evader localization.
* Keep doing that indefinitely.
*
*/
#include <stdio.h>
#include <stdlib.h>
#include <sys/time.h>
#include <signal.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include "transportAPI.h"
#include "taskingAPI.h"
#include "localization.h"
#include "queue.h"
#include "playerc.h"
#include "planning.h"


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
  exit(0);
}

/* signal handler for Ctrl-C */
void handler_C(int sig_num){
  bye();
}

void create_task(int *tid,char *task_string){
    unsigned char b[200];
    int l;

    l = construct_task(b, task_string);  // construct a task packet
    if (l < 0) {
        printf("task description error!! \n");
        exit(1);
    }

    *tid = send_task((uint16_t)*tid, l, b);// send the task
    if (*tid > 0) {                  
        printf("\ntasking packet has been sent with tid %d!!\n", *tid);
        printf("tasking packet payload >> "); dump_packet(b,l);
    } else {
        exit(1);
    }
}

int getPacket(int tid){
    uint16_t r_tid, r_addr;
    int l;

//    unsigned char *packet = receive_packet(&r_tid, &r_addr, &l);
    unsigned char *packet = receive_packet_non_blocking(&r_tid, &r_addr, &l);

    if ((packet) && (tid == r_tid)) {
        
        int offset = 0;
        unsigned char *nextptr = packet;
        uint32_t timestamp = 0;
        uint16_t rssi = 0;

        while (offset < l) {
            attr_t *attr = (attr_t *)nextptr;
                
            if (attr->type == 0xaa) {
                memcpy(&timestamp, attr->value, attr->length);
            } 
            else if (attr->type == 0x321) {
                //rssi = *((uint16_t *)attr->value);
                memcpy(&rssi, attr->value, attr->length);
            }
            else 
                printf("Unidentified attr type? check task string\n");
            offset += offsetof(attr_t, value) + attr->length;
            nextptr = packet + offset;
        }

        fprintf(stdout, "[tid %d] node %d >> time %u, rssi %d", r_tid, r_addr, timestamp, rssi);
        fflush(stdout);
        free((void *)packet);

	return r_addr;
    }

    return -1;
}

void construct_string(char *a,int threshold){
  sprintf(a,"wait(500,0,1)->global_time(0xaa)->sample_rssi(0x321)->thresh(%d,0x321,1)->send()",threshold);
}

void adapt_threshold(int *tid,int newThreshold, char*string){
    /*retask*/
    if(*tid) close_task(*tid);
    *tid=0;//need to set to zero
    construct_string(string,newThreshold);
    printf("%s\n",string);
    create_task(tid,string);
}

void get_rssi_readings(int tid,int *count,QUEUE_t queue){
  int id;
  do{
    id=getPacket(tid);
    if(id>=0){
      enqueue(id,queue);
      //printf("id=%d\n",id);
    }
    if(queue_size(queue)>0.6*MAX_QUEUE_SIZE)break;//need to check
  }while( (queue_size(queue)<MIN_PACKET_2_PROCESS)||(id>=0) );

}

void usage(void){
  printf("---< Pursuer Evader Game Application Program >----\n");
  printf(" - Send command to a mote, and receive data whenever mote hear Evader \n");
  printf(" - Write to file packet.log where Evader is.\n");
  printf("usage:\n");
  printf("\t [-h <hostname>]\n");
  printf("\t [-p <port number>]\n");
  printf("\t [-t <topology file>]\n");
}

int main(int argc, char **argv){
    int tid=0;

    int count=0;

    int isNewTransport=0;
    int isTopologyOn=0;
    char topologyFilename[255];
    char tr_host[255];
    int tr_port=9998;
    int c;
    QUEUE_t queue;
    int evader_position;

    /* set the INT (Ctrl-C) signal handler to function handler_C */
    signal(SIGINT, handler_C);

  while ((c = getopt(argc, argv, "h:p:t:")) != -1)
    switch(c){
      case 'h':
        strcpy(tr_host,optarg);
        isNewTransport++;
        break;
      case 'p':
        tr_port=atoi(optarg);
        isNewTransport++;
        break;
      case 't':
        strcpy(topologyFilename,optarg);
        isTopologyOn=1;
        break;
      case '?':
      default:
        usage();
        exit(1);
    }

    //transport
    if (isNewTransport== 2) {
	set_transport_host_n_port(tr_host, tr_port);
    }else if(isNewTransport==1){
        printf("Incomplete information for Transport connection.\n");
    }

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

    queue = create_queue(MAX_QUEUE_SIZE);

    /*start taks*/
    adapt_threshold(&tid,100,task_string);
    //construct_string(task_string,160);
    //create_task(&tid,task_string);
    
    /* receive response packets */
    while(1) {

        get_rssi_readings(tid,&count,queue);
        evader_position=compute_evader_position(queue,fptr);
        fprintf(fptr, "Evader position %d x=%lf y=%lf\n",evader_position,nodes[evader_position].x,nodes[evader_position].y);

    }//end while


    close_task(tid);                                                           
    return 0;
}
