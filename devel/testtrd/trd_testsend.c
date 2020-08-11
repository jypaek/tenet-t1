#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/time.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include "sfsource.h"
#include "timeval.h"
#include "nx.h"
#include "tosmsg.h"
#include "trd_interface.h"
#include "trd_misc.h"
#include "testtrd.h"


int sf_fd;
int use_sf_time = 0;

unsigned char *buffer;
uint32_t sendcnt = 0;

int sendReady = 0;
struct timeval testsend_alarm_time;

uint16_t LOCAL_ADDRESS;
int send_interval_ms = 1000;
int payload_size = 6;
int num_packets = 20;

int doneTest = 0;


void testsend_timer_start(unsigned long int interval_ms);
void testsend_timer_stop();
void polling_testsend_timer();
void check_timer();


int send_packet() {
    int seqno;

    *((uint16_t *)buffer) = hxs(LOCAL_ADDRESS);
    *((uint32_t *)&buffer[2]) = hxl(sendcnt);

    seqno = (int)trd_send(payload_size, buffer);
    if (seqno <= 0) {
        printf("# send_packet: failed.\n");
    } else {
        printf("\n# ");
        fdump_packet(stdout, buffer, payload_size);
        printf("# -> packet has been sent with trd seqno %d!!\n", seqno);
        sendcnt++;
    }
    fflush(stdout);
    return seqno;
}

void sig_int_handler(int signo) {
    free(buffer);
    exit(1);
}

void check_timer() {
    polling_trd_timer();
    polling_testsend_timer();
}

int main(int argc, char **argv)
{
    int ind;

    if (argc < 4) {
        printf(" Usage: %s  <host> <port> <LOCAL_ADDRESS> [options]\n", argv[0]);
        printf("   [options]  -i : send interval in ms\n");
        printf("              -s : packet(payload) size in bytes (min=6)\n");
        printf("              -n : number of packets to send\n");
        exit(2);
    }
    for (ind = 4; ind < argc; ind++) {
        if (argv[ind][0] == '-') {
            switch (argv[ind][1]) {
                case 'i':
                    send_interval_ms = atoi(argv[++ind]); break;
                case 's':
                    payload_size = atoi(argv[++ind]);
                    if (payload_size < 6) payload_size = 6;
                    break;
                case 'n':
                    num_packets = atoi(argv[++ind]); break;
                case 't':
                    use_sf_time = 1;
                    printf("# using sf time\n");
                    break;
                default : printf("# Unknown switch '%c'\n", argv[ind][1]);
                    break;
            }
        }
    }

    /* set Ctrl-C handler */
    if (signal(SIGINT, sig_int_handler) == SIG_ERR)
        fprintf(stderr, "Warning: failed to set SINGINT handler");

    sf_fd = open_sf_source(argv[1], atoi(argv[2]));
    if (sf_fd < 0) {
        fprintf(stderr, "Couldn't open serial forwarder at %s:%s\n", argv[1], argv[2]);
        exit(1);
    }

    LOCAL_ADDRESS = (uint16_t)atoi(argv[3]);
    buffer = (void *)malloc(payload_size);
    memset(buffer, 0, payload_size);

    printf("\n# Test TRD Send..........\n\n");
    printf("#   - connected-to %s:%d\n", argv[1], atoi(argv[2]));
    printf("#   - LOCAL_ADDRESS = %d\n", LOCAL_ADDRESS);
    printf("#   - payload_size = %d\n", payload_size);
    printf("#   - num_packets = %d\n", num_packets);
    printf("#   - listens to trd-related packets, \n");
    printf("#     participate in reliable broadcasting, \n");
    printf("#     and send packets into the network. \n\n");

    trd_init(sf_fd, LOCAL_ADDRESS);
    printf("# TRD initializing...\n");

    for (;;) {
        fd_set rfds;
        int ret;
        struct timeval tv;

        FD_ZERO(&rfds);
        FD_SET(sf_fd, &rfds);   // serial forwarder

        tv.tv_sec = 0;
        tv.tv_usec = 50000; // poll for timer events every 50ms

        ret = select(sf_fd + 1, &rfds, NULL, NULL, &tv);   // block

        if ((!sendReady) && (is_trd_sendReady())) {
            sendReady = 1;
            printf("# Ready to send!\n");
            testsend_timer_start(5000);
        } else if (sendcnt >= num_packets) {
            if (doneTest == 0) {
                testsend_timer_start(10000);
                doneTest = 1;
                printf("\n# Test TRD Send finished...\n");
            } else {
                testsend_timer_stop();
                sig_int_handler(0);
            }
        }
        //if (ret == 0)
            check_timer();    // if polling is used
        if (ret <= 0) continue;

        if (FD_ISSET(sf_fd, &rfds)) {   // received a packet from the serial forwarder
            int len;
            const unsigned char *packet, *real_packet;

            packet = read_sf_packet(sf_fd, &len);

            if (!packet)
                exit(0);

            if (use_sf_time) {
                real_packet = &packet[sizeof(struct timeval)];
                len = len - sizeof(struct timeval);
            } else {
                real_packet = packet;
            }

            if (is_trd_packet(len, (void *)real_packet)) {
                trd_receive(len, (void *)real_packet);
            }
            fflush(stdout);
            free((void *)packet);
        } 
    }
    return 0;
}

/////////////////////////////////////////////////////////////////////////

void receive_trd(int sender, int len, unsigned char *msg) {
    printf("# Should send this packet to application >>\n# ");
    fdump_packet(stdout, msg, len);
}

/////////////////////////////////////////////////////////////////////////

void testsend_timer_start(unsigned long int interval_ms) {
    struct timeval curr;
    gettimeofday(&curr, NULL);
    add_ms_to_timeval(&curr, interval_ms, &testsend_alarm_time);
}

void testsend_timer_stop() {
    testsend_alarm_time.tv_sec = 0;
    testsend_alarm_time.tv_usec = 0;
}

void polling_testsend_timer() {
    struct timeval curr;
    gettimeofday(&curr, NULL);
    if (((testsend_alarm_time.tv_sec > 0) || (testsend_alarm_time.tv_usec > 0))
                && (compare_timeval(&testsend_alarm_time, &curr) <= 0)) {
        if (send_packet() > 0) {
            long int sec = curr.tv_sec;
            long int msec = curr.tv_usec/(1000);
            printf("%06ld.%03ld origin %d sendcnt %d\n", sec, msec, LOCAL_ADDRESS, sendcnt);
            fflush(stdout);
        }
        testsend_timer_start(send_interval_ms);
    }
}


