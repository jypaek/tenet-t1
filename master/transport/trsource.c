#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h>
#include <unistd.h>
#include <errno.h>
#include <stdlib.h>
#include <string.h>
#ifdef __APPLE__
#include <stdint.h>
#endif

#include "trsource.h"

uint32_t platform;

int saferead2(int fd, void *buffer, int count)
{
  unsigned char *buf = (unsigned char *)buffer;
  int actual = 0;

  while (count > 0)
    {
      int n = read(fd, buf, count);

      if (n == -1 && errno == EINTR)
	continue;

#ifdef __CYGWIN__
      if (n == -1 && errno == EAGAIN)
        continue;
#endif
      if (n == -1)
	return -1;
      if (n == 0)
	return actual;

      count -= n;
      actual += n;
      buf += n;
    }
  return actual;
}

int safewrite2(int fd, const void *buffer, int count)
{
  unsigned char *buf = (unsigned char *)buffer;
  int actual = 0;

  while (count > 0)
    {
      int n = write(fd, buf, count);

      if (n == -1 && errno == EINTR)
	continue;
      if (n == -1)
	return -1;

      count -= n;
      actual += n;
      buf += n;
    }
  return actual;
}

int open_tr_source(const char *host, int port)
/* Returns: file descriptor for serial forwarder at host:port
 */
{
  int fd = socket(AF_INET, SOCK_STREAM, 0);
  struct hostent *entry;
  struct sockaddr_in addr;

  if (fd < 0)
    return fd;

  entry = gethostbyname(host);
  if (!entry)
    {
      close(fd);
      return -1;
    }      

  addr.sin_family = entry->h_addrtype;
  memcpy(&addr.sin_addr, entry->h_addr, entry->h_length);
  addr.sin_port = htons(port);
  if (connect(fd, (struct sockaddr *)&addr, sizeof addr) < 0)
    {
      close(fd);
      return -1;
    }

  if (init_tr_source(fd) < 0)
    {
      close(fd);
      return -1;
    }

  return fd;
}

extern uint32_t platform; 

int init_tr_source(int fd)
/* Effects: Checks that fd is following the serial forwarder protocol
     Sends 'platform' for protocol version '!', and sets 'platform' to
     the received platform value.
   Modifies: platform
   Returns: 0 if it is, -1 otherwise
 */
{
  char check[2], us[2];
  int version;
  unsigned char nonce[4];
  /* Indicate version and check if serial forwarder on the other end */
  us[0] = 'T'; us[1] = '!';
  if (safewrite2(fd, us, 2) != 2 ||
      saferead2(fd, check, 2) != 2 ||
      check[0] != 'T' || check[1] < ' ')
    return -1;

  version = check[1];
  if (us[1] < version)
    version = us[1];

  switch (version)
    {
    case ' ': break;
    case '!': 
      nonce[0] = platform;
      nonce[1] = platform >>  8;
      nonce[2] = platform >> 16;
      nonce[3] = platform >> 24;
      if (safewrite2(fd, nonce, 4) != 4)
	return -1;
      if (saferead2(fd, nonce, 4) != 4)
	return -1;
      //Unlike the more general SFProtocol.java this piece of code always knows what platform it is connected to; just   drop the preferred platform from the client
//platform = nonce[0] | nonce[1] << 8 | nonce[2] << 16 | nonce[3] << 24;
      break;
    }

  return 0;
}

void *read_tr_packet(int fd, int *len)
/* Effects: reads packet from serial forwarder on file descriptor fd
   Returns: the packet read (in newly allocated memory), and *len is
     set to the packet length, or NULL for failure
*/
{
  int l2;
  unsigned char l;
  void *packet;

  if (saferead2(fd, &l, 1) != 1)
    return NULL;

  l2 = (l<<8);

  if (saferead2(fd, &l, 1) != 1)
    return NULL;

  l2 += l;

  packet = malloc(l2);
  if (!packet)
    return NULL;

  if (saferead2(fd, packet, l2) != l2)
    {
      free(packet);
      return NULL;
    }
  *len = l2;
  
  return packet;
}

int write_tr_packet(int fd, const void *packet, int len)
/* Effects: writes len byte packet to serial forwarder on file descriptor
     fd
   Returns: 0 if packet successfully written, -1 otherwise
*/
{
  unsigned char l = (len>>8);
  unsigned char l2 = len;

  if (safewrite2(fd, &l, 1) != 1 ||
      safewrite2(fd, &l2, 1) != 1 ||
      safewrite2(fd, packet, len) != len)
    return -1;

  return 0;
}
