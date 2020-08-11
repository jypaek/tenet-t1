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
*          Omprakash Gnawali
* Embedded Networks Laboratory, University of Southern California
*/
/*
 * Get time from a mote that is running FTSP
 *
 */
#include <stdio.h>
#include <stdlib.h>
#include <sys/time.h>
#include "querytime.h"
#include "sfsource.h"

int fd;
int moteid;
unsigned char packet[200];
char hexbuf[20];
long unsigned int time;

void setup_serial_connection(char* sfhost, char* sfport, int mid) {
  fd = open_sf_source(sfhost, atoi(sfport));
  if (fd < 0)
    {
      fprintf(stderr, "Couldn't open serial forwarder at %s:%s\n",
	      sfhost, sfport);
      exit(1);
    }
  moteid = mid;
}


long int current_time() {
  int len;
  unsigned char* vp;
    
  packet[0] = 2;
  packet[1] = 2;
  packet[2] = 2;
  packet[3] = 2;
  packet[4] = 2;
  packet[5] = 2;
  packet[6] = moteid;
  packet[7] = 0;
  packet[8] = 3;
  packet[9] = 0x7e;

  write_sf_packet(fd, packet, 12);

  vp = (unsigned char *) read_sf_packet(fd, &len);
    
  if (!packet)
    return 0;

  sprintf(hexbuf, "%02x%02x%02x%02x\n",
	 vp[13],
	 vp[12],
	 vp[11],
	 vp[10]);

  sscanf(hexbuf, "%xlu\n", &time);
  return time;
}

/*
int main(int argc, char **argv)
{

  setup_serial_connection("localhost", "9002", 57);
  printf("Current time: %ld\n", current_time());
  return 0;
}*/
