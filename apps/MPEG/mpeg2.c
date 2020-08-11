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
*
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
#include <string.h>
#include <unistd.h>
#include <signal.h>
//#include "queue.h"
#include "playerc.h"
#include "planning.h"
#include "locationServer.h"
#include "sfsource.h"

//graph topology
double **matrix;
node_t* nodes;
int nVertex;

int isRobot=0;
int verbosemode = 0;

void print_usage() {
    printf("   Pursuer Evader Game Application Program \n");
    printf(" - Read Pursuer Robot Postion from Particle Filter. \n");
    printf(" - Read Evaded Position from Evader Location Server. \n");

    printf("Usage: mpeg [-vh] [-n host] [-p port] [-t <topology filename>]\n");
    printf("  h : display this help message.\n");
    printf("  v : verbose mode. Display all traffic messages.\n");
    printf("  n : host on which evaderLocationServer is running.Default is localhost\n");
    printf("  p : port on which evaderLocationServer is listening for connection.Default is 9997.\n");
    printf("  t : filename of topology.\n");

}


void sig_int_handler(int signo) {
    //printf("Bye\n");
    //fflush(stdout);
    //close log file
    //fflush(fptr);
    //fclose(fptr);
    //dispose_queue(queue);//free queue
    //close planning
    free(matrix);
    free(nodes);
    exit(0);
}

int open_port(const char *host, int port) {
    /* open a TCP socket to the router program using 'sf' protocol. */
    int server_fd;

    server_fd = open_sf_source(host, port);
    if (server_fd < 0) {
        fprintf(stderr, "Couldn't open router at %s:%d\n", host, port);
        exit(1);
    }

    return server_fd;
}


void send_packet(int c_fd){
    LS_Msg_t *msg = (LS_Msg_t *) malloc(sizeof(LS_Msg_t));
    msg->protocol= 1;
    //msg->evaderId=2;
    //msg->topologicalId=3;
    //msg->x=5;
    //msg->y=6;

    int ok = write_sf_packet(c_fd, msg, sizeof(*msg));   // write to the serial forwarder

    if (ok > 0) fprintf(stderr, "Note: write failed\n");

    free((void *)msg);
}

int requestEvaderPosition(int server_fd,int evaderPosition[]){
    unsigned char *packet;
    int len;
    int nEvaders;
    LS_Msg_t* msg;

    send_packet(server_fd);
    packet = read_sf_packet(server_fd, &len);
    msg = (LS_Msg_t *)packet;
    //printf("protocol=%d evaderId=%d topologicalId=%d x=%d y=%d\n",msg->protocol,msg->evaderId,msg->topologicalId,msg->x,msg->y);
    memcpy(evaderPosition,msg->topologicalId,MAX_EVADER*sizeof(int));
    nEvaders=msg->nEvaders;

    free((void *)packet);
    return nEvaders;
}

int main(int argc, char **argv){
    char host_name[200];
    int els_port;
    int c;
    int i;
    int isTopologyOn=0;
    char topologyFilename[255];
    int server_fd;
    int nEvaders;
    int evader_position[MAX_EVADER];


    if(signal(SIGINT, sig_int_handler) == SIG_ERR)
        fprintf(stderr, "Warning: failed to set SINGINT handler");

    /*default values*/
    strcpy(host_name, "127.0.0.1");
    els_port = 9997;

    /*parse option line*/
    while ((c = getopt(argc, argv, "t:n:p:vah")) != -1)
        switch(c){
            case 'n':
                strcpy(host_name, optarg);
                break;
            case 'p':
                els_port = atoi(optarg);
                break;
            case 'v':
                //setVerbose();
                verbosemode = 1;
                break;
            case 't':
                strcpy(topologyFilename,optarg);
                isTopologyOn=1;
                break;
            case 'h':
            case '?':
            default:
                print_usage();
                exit(1);
        }

    server_fd=open_port(host_name,els_port);

    if(isTopologyOn){
      printf("Loading topology...\n");
      loadTopology(topologyFilename,&matrix,&nodes,&nVertex);
      printf("Topology loaded\n");
    }



    while (1) {

        sleep(1);
        nEvaders=requestEvaderPosition(server_fd,evader_position);
        printf("\nnEvaders=%d ",nEvaders);
        for(i=0;i<nEvaders;i++){
            if(evader_position[i]>=0){
                //initially evader_position can be not determine yet, return -1
                printf("Evader position %d ",evader_position[i]);
                if(isTopologyOn)
                fprintf(stdout, "x=%lf y=%lf   ",nodes[evader_position[i]].x,nodes[evader_position[i]].y);
				fflush(stdout);
            }
        }

    }

    return 0;
}
