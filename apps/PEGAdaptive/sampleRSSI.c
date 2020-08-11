#include <stdio.h>
#include <stdlib.h>
#include <sys/time.h>
#include <time.h>
#include "transportAPI.h"
#include "task_construct.h"
#include "querytime.h"
/*If GET_MOTE_TIME defined:
  Need a mote nodeId 17 running timesyncr
  Need ./sf 10003 <device> 57600 <platform>
*/
#define GET_MOTE_TIME

#define NVALUES 10 //store exactly nvalues unique values 
#define KVALUE 5 //pick the kvalue value from vector

extern char *tr_host;
extern int tr_port;

//char *task_string = "wait(500,0,1)->global_time(0xaa)->sample_rssi(0x321)->thresh(160,0x321,1)->send()";
char task_string[200];

/*sort increasing*/
int compNum(int *num1,int *num2){
  if (*num1<*num2) return -1;
  if (*num1==*num2)return 0;
  else return 1;
}

int find(int *a,int nel,int element){
  int i;
  for(i=0;i<nel;i++)
    if(a[i]==element)return 1;
  return 0;
}

void create_task(int *tid,int *l,char *task_string){
    unsigned char b[200];
    
    *l = construct_task(b, task_string);  // construct a task packet
    if (*l < 0) {
        printf("task description error!! \n");
        exit(1);
    }

    *tid = send_task((uint16_t)*tid, *l, b);// send the task
    if (*tid > 0) {                  
        printf("\ntasking packet has been sent with tid %d!!\n", *tid);
        printf("tasking packet payload >> "); dump_packet(b,*l);
    } else {
        exit(1);
    }
}


void printTime(int count){
    struct timeval tv;
    char buffer[30];
    time_t curtime;

    gettimeofday(&tv,0);
    curtime=tv.tv_sec;
    strftime(buffer,30,"%T.",localtime(&curtime));
    printf(" ComputerTime %s%ld ",buffer,tv.tv_usec);

    /*get attached mote time*/
    #ifdef GET_MOTE_TIME
    if((count%10)==0){
	printf("CurrentTime %u ",current_time());
        count=0;
    }else{
        printf("CurrentTime 0 ");
    }
    #endif
    printf("\n");

}

int getPacket(int tid,int l){
    uint16_t r_tid, r_addr;

    unsigned char *packet = receive_packet(&r_tid, &r_addr, &l);

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

        printf("[tid %d] node %d >> time %u, rssi %d", r_tid, r_addr, timestamp, rssi);
        fflush(stdout);
        free((void *)packet);

	return rssi;
    }

    return -1;
}

void construct_string(char *a,int threshold){
  sprintf(a,"wait(500,0,1)->global_time(0xaa)->sample_rssi(0x321)->thresh(%d,0x321,1)->send()",threshold);
}

int main(int argc, char **argv)
{
    int tid=0;
    int l=0;

    int count=0;
    int rssiValues[NVALUES];
    int nrssi=0;
    int rssi=0;
    int i;

    if (argc == 3) {
        tr_host = argv[1];
        tr_port = atoi(argv[2]);
    }

    /*to get pursuer mote time*/
    #ifdef GET_MOTE_TIME
    setup_serial_connection("localhost", "10003", 17);
    #endif

    /*start taks*/
    construct_string(task_string,10);
    create_task(&tid,&l,task_string);
    
    /* receive response packets */
    while(nrssi<NVALUES) {

	count++;
        rssi=getPacket(tid,l);

        if(!find(rssiValues,nrssi,rssi)){
            rssiValues[nrssi]=rssi;
            nrssi++;
        }
        printTime(count);

    }//end while

    qsort(rssiValues,NVALUES,sizeof(int),(void*)compNum);
    for(i=0;i<NVALUES;i++)printf("%d\n",rssiValues[i]);

    /*retask*/
    close_task(tid);
    tid=0;l=0;
    construct_string(task_string,rssiValues[KVALUE]);
    printf("%s\n",task_string);
    create_task(&tid,&l,task_string);

    while(1){
        rssi=getPacket(tid,l);
        printTime(count++);
    }

                                                           
    return 0;
}


