
/**
 * Listen to 'TestTimeSync' (FTSP debug) messages
 *
 * Embedded Networks Laboratory, University of Southern California
 *
 * @modified Oct/31/2007
 *
 * @author Jeongyeup Paek
 **/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stddef.h>
#include <sys/types.h>
#include <stdint.h>
#include <arpa/inet.h>
#include <time.h>
#include "sfsource.h"
#include "serialsource.h"
#include "tosmsg.h"
#include "nx.h"
#include "TestTimeSyncMsg.h"
#include "TimeSyncMsg.h"

int fromsf = 0;
uint32_t last_gtime = 0;

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

void stderr_msg(serial_source_msg problem)
{
    fprintf(stderr, "Note: %s\n", msgs[problem]);
}

int main(int argc, char **argv)
{
    int fd = -1;
    serial_source src = 0;

    if (argc != 4)
    {
        fprintf(stderr, "\n=== Listen to FTSP debug pkts ===\n");
        fprintf(stderr, "Usage:  %s sf     <host> <port>    // read from a sf\n", argv[0]);
        fprintf(stderr, "        %s serial <device> <rate>  // read serial port\n", argv[0]);
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
    }
    else {
        src = open_serial_source(argv[2], atoi(argv[3]), 0, stderr_msg);
        if (!src) {   
            fprintf(stderr, "Couldn't open serial port at %s:%s\n", argv[2], argv[3]);
            exit(1);
        }   
    }

    for (;;)
    {
        int len;
        const unsigned char *packet;
        TOS_Msg *tosmsg;
        time_t m_time;
        struct tm *tt;

        if (fromsf == 1) {
            packet = read_sf_packet(fd, &len);
        } else {
            packet = read_serial_packet(src, &len);
        }

        if (!packet)
            exit(0);

        tosmsg = (TOS_Msg *) packet;
        m_time = time(NULL);
        tt = localtime(&m_time);

        if (tosmsg->type == AM_TIMESYNCPOLLREPLY) {
            TimeSyncPollReply *timemsg = (TimeSyncPollReply *) tosmsg->data;
            printf("%02d:%02d:%02d ", tt->tm_hour, tt->tm_min, tt->tm_sec);
            printf("[%d] ", nxs(timemsg->msgID));
            printf("node %2d ", nxs(timemsg->nodeID));
            printf("gtime %10u (%10u) ", nxl(timemsg->globalClock), nxl(timemsg->localClock));
            printf("sync %d ", timemsg->is_synced);
            if (timemsg->rootID == 0xffff) printf("root X ");
            else printf("root %d ", nxs(timemsg->rootID));
            printf("skew % f ", ((int32_t)nxl(timemsg->skew))/1000000.0);
            printf("seqNo %d ", timemsg->seqNum);
            printf("entries %d ", timemsg->numEntries);
            //printf("oavg %d lavg %u ", (int32_t)nxl(timemsg->offsetAvg), nxl(timemsg->localAvg));
            printf("xtra %d ", timemsg->not_used);
            if (last_gtime == 0) printf("diff       0 ");
            else printf("diff %7d ", (int32_t)(nxl(timemsg->globalClock) - last_gtime));
            last_gtime = nxl(timemsg->globalClock);
            putchar('\n');
        } else if (tosmsg->type == AM_TIMESYNCMSG) {
            TimeSyncMsg *beacon = (TimeSyncMsg *)tosmsg->data;
            printf("%02d:%02d:%02d ", tt->tm_hour, tt->tm_min, tt->tm_sec);
            printf("[FTSP Beacon] ");
            printf("node %2d ", nxs(beacon->nodeID));
            printf("gtime %10u ", nxl(beacon->sendingTime));
            if (beacon->rootID == 0xffff) printf("root  X ");
            else printf("root %d ", nxs(beacon->rootID));
            printf("seqNo %d ", beacon->seqNum);
            putchar('\n');
        }// else {
            //int i;
            //for (i = 0; i < len; i++)
            //    printf("%02x ", packet[i]);
        //}
        fflush(stdout);
        free((void *)packet);
    }
}

