#include <stdio.h>
#include <stdlib.h>
#include <sys/time.h>
#include "querytime.h"
#include "sfsource.h"

int fd;
int moteid;
unsigned char packet[200];
char hexbuf[20];
unsigned int time;

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


unsigned int current_time() {
  int len;
  unsigned char* vp;
  int i;
    
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

  for(i=0;i<12;i++)printf("%02x ",packet[i]);
  printf("was packet sent.\n");

  vp = read_sf_packet(fd, &len);
    
  if (!packet)
    return 0;

  sprintf(hexbuf, "%02x%02x%02x%02x\n",
	 vp[13],
	 vp[12],
	 vp[11],
	 vp[10]);

  printf("vp:\n");
  for(i=0;i<len;i++)printf("%02x ",vp[i]); 
  printf("\n"); 
for(i=0;i<len;i++)printf("%02d ",vp[i]);

  printf("\nvp:%02x %02x %02x %02x\n", vp[13],vp[12],vp[11],vp[10]);
  printf("vp:%d %d %d %d\n", vp[13],vp[12],vp[11],vp[10]);


  printf("hexbuf %s",hexbuf);
  sscanf(hexbuf, "%xu\n", &time);
  return time;
}

#ifdef QUERY_MAIN
int main(int argc, char **argv)
{

  //setup_serial_connection("localhost", "9002", 200);
  setup_serial_connection("testbed.usc.edu", "10017", 17);
  printf("Current time: %u\n", current_time());
  return 0;
}
#endif
