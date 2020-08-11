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
* Authors: Jeongyeup Paek
           Marcos Augusto Menezes Vieira
* Embedded Networks Laboratory, University of Southern California
*/

/*
* Task all motes to send Evader beacon radio signal above some thresold after t seconds
* Uses TenetBasic
* To test it, it is necessary an Evader to send beacons
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>
#include <time.h>
#include "transportAPI.h"
#include "taskingAPI.h"
#include "querytime.h"
/*Need a mote nodeId 57 running timesyncr
  Need ./sf 9002 <device> 57600 <platform>
*/
extern char *tr_host;
extern int tr_port;

char *task_string = "wait(500,0,1)->global_time(0xaa)->sample_rssi(0x321)->thresh(2,0x321,1)->send()";

int main(int argc, char **argv)
{
    unsigned char b[200];
    int l, tid = 0;
    uint16_t r_tid, r_addr;

    time_t curtime;
    struct timeval tv;
	char buffer[30];

    if (argc == 3) {
        tr_host = argv[1];
        tr_port = atoi(argv[2]);
    }

    /*to get pursuer mote time*/
    setup_serial_connection("localhost", "9002", 57);

    l = construct_task(b, task_string);  // construct a task packet
    if (l < 0) {
        printf("task description error!! \n");
        exit(1);
    }

    tid = send_task((uint16_t)tid, l, b);// send the task
    if (tid > 0) {                  
        printf("\ntasking packet has been sent with tid %d!!\n", tid);
        printf("tasking packet payload >> "); dump_packet(b,l);
    } else {
        exit(1);
    }
    
    /* receive response packets */
    while(1) {
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
			gettimeofday(&tv,0);
			curtime=tv.tv_sec;
			strftime(buffer,30,"%T.",localtime(&curtime));
			printf("%ld ",tv.tv_usec);
            printf("[tid %d] node %d >> time %u, rssi %d Current time: %ld\n", r_tid, r_addr, timestamp, rssi,current_time());
            fflush(stdout);
            free((void *)packet);
        }
    }
    return 0;
}


