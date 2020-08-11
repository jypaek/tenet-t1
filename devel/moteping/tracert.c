#include <stdio.h>
#include <stdlib.h>
#include "tenet.h"
#include "serviceAPI.h"

int main(int argc, char **argv)
{
    uint16_t dst_addr;

    if (argc == 4) {
        config_transport(argv[1], atoi(argv[2]));
        dst_addr = atoi(argv[3]);
    } else if (argc == 2)  {
        dst_addr = atoi(argv[1]);
    } else {
        fprintf(stderr, " Usage: %s [host] [port] mote_id\n", argv[0]);
        exit(1);
    }
    
    send_tracert(dst_addr);
    
    struct response *list;
    while(1) {
        list = read_response(5000);
        response_delete(list);
    }
}

