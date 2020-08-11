#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/time.h>
#include <stdint.h>
#include "sfsource.h"
#include "serialsource.h"
#include "nx.h"
#include "tosmsg.h"
#include "testtrd.h"

static char *msgs[] = { 
  "unknown_packet_type",
  "ack_timeout" ,
  "sync"        ,
  "too_long"    ,   
  "too_short"   ,   
  "bad_sync"    ,   
  "bad_crc"     ,   
  "closed"      ,   
  "no_memory"   ,   
  "unix_error"
};

void stderr_msg(serial_source_msg problem) {
    fprintf(stderr, "Note: %s\n", msgs[problem]);
}


int fromsf = 0;
int use_sf_time = 0;

int main(int argc, char **argv)
{
    int fd = 0;
    serial_source src = 0;

    if (argc != 4)
    {
        fprintf(stderr, "\n=== listen to TestTRD received packets from a sf on UART ===\n\n");
        fprintf(stderr, "Usage:  %s sf     <host> <port>    // read from sf\n", argv[0]);
        fprintf(stderr, "        %s serial <device> <rate>  // read serial port\n", argv[0]);
        fprintf(stderr, "        %s sftime <host> <port>  // read from sftime\n", argv[0]);
        fprintf(stderr, "\n");
        exit(2);
    }
    if (strncmp(argv[1], "sf", 2) == 0) {
        fd = open_sf_source(argv[2], atoi(argv[3]));
        if (fd < 0) {
            fprintf(stderr, "Couldn't open serial forwarder at %s:%s\n", argv[2], argv[3]);
            exit(1);
        }
        fromsf = 1;
        if (strncmp(argv[1], "sftime", 6) == 0)
            use_sf_time = 1;
    }
    else {
        src = open_serial_source(argv[2], atoi(argv[3]), 0, stderr_msg);
        if (!src) {   
            fprintf(stderr, "Couldn't open serial port at %s:%s\n", argv[2], argv[3]);
            exit(1);
        }   
    }

    for (;;) {
        int len, paylen;
        const unsigned char *packet;
        TOS_Msg *tosmsg;
        struct TestTRD_UartMsg *testmsg;
        uint16_t rx_origin, rx_recvcnt, rx_id;
        long int sec, msec;
        struct timeval *tv;

        if (fromsf == 1) {
            packet = read_sf_packet(fd, &len);
        } else {
            packet = read_serial_packet(src, &len);
        }

        if (!packet) exit(0);

        if (use_sf_time) {
            tv = (struct timeval *)packet;
            tosmsg = (TOS_Msg *) &packet[sizeof(struct timeval)];
        } else {
            struct timeval tvb;
            tv = &tvb;
            gettimeofday(tv, NULL);
            tosmsg = (TOS_Msg *) packet;
        }
        sec = tv->tv_sec;
        msec = tv->tv_usec / (1000);
        
        testmsg = (TestTRD_UartMsg *)tosmsg->data;
        rx_origin = nxs(testmsg->origin);
        rx_recvcnt = nxs(testmsg->recvcnt);
        rx_id = nxs(testmsg->id);
        paylen = len - offsetof(TOS_Msg, data) - offsetof(TestTRD_UartMsg, data);
        
        fprintf(stdout, "%06ld.%03ld node %d origin %d rx_cnt %d data ", sec, msec, rx_id, rx_origin, rx_recvcnt);
        fdump_packet(stdout, (void *)testmsg->data, paylen);

        fflush(stdout);
        free((void *)packet);
    }
}

