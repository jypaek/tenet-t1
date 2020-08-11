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
* Authors: Marcos Vieira
* Embedded Networks Laboratory, University of Southern California
*/

#include <sys/socket.h>
#include <signal.h>
#include <unistd.h>
#include "client.h"
#include "locationServer.h"
#include "sfsource.h"
#include "localization.h"
#include "queue.h"
#include "log.h"
#include "tenet.h"

#define MAX_QUEUE_SIZE 10
#define MIN_PACKET_2_PROCESS 7 //minimum number of packet to estimate localization

//FILE *fptr;//log file
int verbosemode = 0;
int tid = 0;
int evader_position[MAX_EVADER];
int current_node[MAX_EVADER];
int counter[MAX_EVADER];
//store evaderId
int nelementsEvader=0;
int vectorEvaderId[MAX_EVADER];
int windowSize=3;

extern struct client_list *clients; /* list of client applications
                                       - which connected to this program.
                                       - it is maintained by the files client.c */


void print_usage() {
    printf("   Evader Localization Program \n");
    printf(" - Send command to a mote, and receive data whenever mote hear Evader \n");
    printf(" - It is a server that inform current Evader position.\n");
    printf(" - Write to file packet.log the Evader location.\n\n");

    printf("Usage: ls [-vh] [-n host] [-p port] [-s port] [-w windowSize] \n");
    printf("  h : display this help message.\n");
    printf("  v : verbose mode. Display all traffic messages.\n");
    printf("  n : host on which transport is running.Default is localhost\n");
    printf("  p : port on which transport is listening for connection.Default is 9998.\n");
    printf("  s : set port on which to accept connections.Default is 9997.\n");
    printf("  w : window size to filter. Default logfile is 5.\n");
}



void sig_int_handler(int signo) {
    fprintf(stderr, "Location server terminating... (closing all tasks/tid/clients)\n");
    rem_client_list();
    if (tid) delete_task(tid);
    //close log file
    closeLog();
    exit(1);
}

void construct_task_string(char *a,int threshold){
  sprintf(a,"wait(500,1)->sample_rssi(0xAA)->comparison(0xBB,0xAA,<,'%d')->deleteattributeif(0xBB,0xAA)->deleteattribute(0xBB)->send()",threshold);
}

int adapt_threshold(int tid,int newThreshold, char*string){
    /*retask*/
    if(tid) delete_task(tid);
    tid=0;
    construct_task_string(string,newThreshold);
    if (verbosemode)printf("%s\n",string);
    tid = send_task(string);
    if (tid < 0) exit(1);
    return tid;
}


int find(int index){
    int i;

    for(i=0;i<nelementsEvader;i++)
        if(vectorEvaderId[i]==index) return i;

    //did not find it; add it
    vectorEvaderId[nelementsEvader++]=index;
    return nelementsEvader-1;
}

/*get id from response packet*/
int getId(int *sensorId,int *evaderId){
    struct response *list;
    struct attr_node* valueNode;
    char log_message[255];
    int id;
    int rssi;
    int evader=-1;

    *sensorId=-1;
    *evaderId=-1;
 
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
                sig_int_handler(0);//exit(0);
            break;
            }
        }
    //response_print(list);
    /*extract data*/
    id = response_mote_addr(list);
    valueNode = response_find(list, 0xAA);
    if (valueNode!=NULL){
        rssi = valueNode->value[0];
        evader=valueNode->value[1];

        *sensorId=id;
        *evaderId=evader;

        if(verbosemode){
            sprintf(log_message, "%d\t%d\t%d\n", id, evader, rssi);
            printToLog(log_message,0);
        }
    }

    response_delete(list);

    return id;
}

int get_rssi_readings(QUEUE_t queue[]){
  int id;
  int evader;
  int evaderIndex=-1;
//  do{
    //id=getId();
    getId(&id,&evader);

    if((id>=0)&&(evader>=0)){
      evaderIndex=find(evader);
    //  printf("evaderIndex%d id%d evader%d\n",evaderIndex,id,evader);
    //  fflush(stdout);
      enqueue(id,queue[evaderIndex]);
      //printf("id=%d\n",id);
    }
    //if(queue_size(queue)>0.6*MAX_QUEUE_SIZE)break;//need to check
  //}while( (queue_size(queue)<MIN_PACKET_2_PROCESS)&&(id>=0) );
//  }while( queue_size(queue)<MIN_PACKET_2_PROCESS );

   
    return evaderIndex;
}

void initialize_server(int server_port) {
    if (signal(SIGPIPE, SIG_IGN) == SIG_ERR)
        fprintf(stderr, "Warning: failed to ignore SIGPIPE.\n");
    if(signal(SIGINT, sig_int_handler) == SIG_ERR)
        fprintf(stderr, "Warning: failed to set SINGINT handler");

    open_server_socket(server_port);

    printf("[ENV] SERVER_PORT (FOR APPLICATION) : %d\n", server_port);

}

void send_packet(int c_fd){
    int i;

    LS_Msg_t *msg = (LS_Msg_t *) malloc(sizeof(LS_Msg_t));
    msg->protocol= LS_REQUEST;
    msg->nEvaders=nelementsEvader;

    for(i=0;i<nelementsEvader;i++){
        msg->evaderId[i]=vectorEvaderId[i];
        //msg->topologicalId[i]=evader_position[i];
        msg->topologicalId[i]=current_node[i];
    }

/*    printf("\nsendpacket: nEvaders=%d ",nelementsEvader);
    for(i=0;i<nelementsEvader;i++){
        printf("evaderId=%d ",msg->evaderId[i]=vectorEvaderId[i]);
        printf("position=%d     ",msg->topologicalId[i]=evader_position[i]);
    }
    printf("\n");
*/

    //msg->x=4;
    //msg->y=3;

    int ok = write_sf_packet(c_fd, msg, sizeof(*msg));   // write to the serial forwarder

    if (ok > 0) fprintf(stderr, "Note: write failed\n");

    free((void *)msg);
}


/* We have received a packet from a client application */
void check_clients(fd_set *fds) {
    int len;
    struct client_list **c;
    unsigned char *packet;

    for (c = &clients; *c; ) {
        int next = 1;

        if (FD_ISSET((*c)->fd, fds)) {

            packet =(unsigned char *) read_sf_packet((*c)->fd, &len);// read from client

            if (packet) {

                send_packet((*c)->fd);

                free((void *)packet);
            } else {
                rem_client(c);
                next = 0;
            }
        }
        if (next)
            c = &(*c)->next;
    }
}


void filter_data(int position,int evaderIndex){

    //start condition
    if(current_node[evaderIndex] == -1){
        current_node[evaderIndex] = position;
    }

    if(current_node[evaderIndex] != position && counter[evaderIndex] < windowSize){
        #ifdef DEBUG
            printf("#ignoring change: %d\n",counter);
        #endif
        counter[evaderIndex]++;
    }else{
        counter[evaderIndex] = 0;
        current_node[evaderIndex] = position;
    }
    //writeToFile(current_node);
    //#ifdef DEBUG
    //    printf("#current node: %d\n",current_node[evaderIndex]);
    //#else
    //    printf("%d\n",current_node[evaderIndex]);
    //#endif

}

int main(int argc, char **argv){

    char host_name[200];
    int tr_port;
    int c;
    int i;
    char task_string[200];
    char log_message[255];
    QUEUE_t queue[MAX_EVADER];
    int evaderIndex;

    //int isLog=0;

    int server_port; /* this server port number
                       - that this program will open, and
                       - other applications will connect to. */

    //parse_argv(argc, argv); /* parse command-line arguments/options */

    if(signal(SIGINT, sig_int_handler) == SIG_ERR)
        fprintf(stderr, "Warning: failed to set SINGINT handler");

    /*default values*/
    strcpy(host_name, "127.0.0.1");
    //strcpy(host_name, "flipflop.usc.edu");
    tr_port = 9998;
    server_port=9997;

/*parse option line*/
    while ((c = getopt(argc, argv, "n:w:p:s:vh")) != -1)
        switch(c){
            case 'n':
                strcpy(host_name, optarg);
                break;
            case 'w':
                windowSize= atoi(optarg);
                break;
            case 'p':
                tr_port = atoi(optarg);
                break;
            case 's':
                server_port = atoi(optarg);
                break;
            case 'v':
                setVerbose();
                verbosemode = 1;
                break;
            case 'h':
            case '?':
            default:
                print_usage();
                exit(1);
        }

    config_transport(host_name, tr_port);
    fprintf(stdout, "Server initialized...\n");
    fflush(stdout);

    //log
    openLog();
    printToLog("#node\tevaderId\trssi\n",0);

    initialize_server(server_port); /* initialize transport (socket, etc) */

    fprintf(stdout, "Server initialized...\n");
    fflush(stdout);

    for(i=0;i<MAX_EVADER;i++){
        queue[i] = create_queue(MAX_QUEUE_SIZE);
        evader_position[i]=-1;
        current_node[i]=-1;
        counter[i]=-1;
    }

    fprintf(stdout, "\nNetwork was tasked...\n");
    fflush(stdout);

    /*start task*/
    tid=adapt_threshold(tid,164,task_string);

    for (;;){
        fd_set rfds;
        int maxfd = -1;
        int ret;
        struct timeval tv;

        FD_ZERO(&rfds);
        //fd_wait(&rfds, &maxfd, rt_fd);
        fd_wait(&rfds, &maxfd, server_socket);
        wait_clients(&rfds, &maxfd);

        tv.tv_sec = 0;
        tv.tv_usec = 50000; // poll for timer events every 90ms

        ret = select(maxfd + 1, &rfds, NULL, NULL, &tv);   // block
//        ret = select(maxfd + 1, &rfds, NULL, NULL, NULL);   //

        evaderIndex=get_rssi_readings(queue);
        if(evaderIndex>=0){
    //         printf("evaderIndex=%dn",evaderIndex);
             if (queue_size(queue[evaderIndex])>=MIN_PACKET_2_PROCESS){
                  evader_position[evaderIndex]=compute_evader_position(queue[evaderIndex]);
                  filter_data(evader_position[evaderIndex],evaderIndex);
                  sprintf(log_message,"#Filtered Position %d robotId %d ",current_node[evaderIndex],vectorEvaderId[evaderIndex]);
                  printToLog(log_message,0);
             }
        }

        if (ret > 0) {
            //if (FD_ISSET(rt_fd, &rfds))
            //    check_router();     /* received a packet from router (or sf) */

            if (FD_ISSET(server_socket, &rfds))
                check_new_client(); /* received new connection request from a client */

            check_clients(&rfds);   /* received a packet from a client. */
        }
//        else  if (ret == 0) {
//            check_timer();    // if polling is used
//            check_init();
//        }
    }
}
