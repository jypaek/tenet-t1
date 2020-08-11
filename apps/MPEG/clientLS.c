#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "locationServer.h"
#include "sfsource.h"

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
    msg->nEvaders=1;
    msg->evaderId[0]=2;
    msg->topologicalId[0]=3;

    int ok = write_sf_packet(c_fd, msg, sizeof(*msg));   // write to the serial forwarder

    if (ok > 0) fprintf(stderr, "Note: write failed\n");

    free((void *)msg);
}



int main(){
    char host_name[200];
    int ls_port;
    int server_fd;
    char keyboard;
    unsigned char *packet;
    int len;
    int i;
    LS_Msg_t *msg;

    /*default values*/
    strcpy(host_name, "127.0.0.1");
    ls_port = 9997;

    server_fd=open_port(host_name,ls_port);
    while(1){
      scanf("%c",&keyboard);
      send_packet(server_fd);
      packet = read_sf_packet(server_fd, &len);
      msg = (LS_Msg_t *)packet;
      for(i=0;i<msg->nEvaders;i++)
      printf("protocol=%d nEvaders %d evaderId=%d topologicalId=%d\n",msg->protocol,msg->nEvaders,msg->evaderId[i],msg->topologicalId[i]);

      printf("\n");
      free((void *)packet);
    }

    return 0;
}
