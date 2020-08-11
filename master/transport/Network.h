
#ifndef _NETWORK_H_
#define _NETWORK_H_

#include <netinet/in.h> 
#include <sys/socket.h> 
#include <arpa/inet.h>	//inet_addr()
#include <unistd.h>		//close()
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <net/if.h>
#include <netdb.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <sys/time.h>

enum ADDRESS_TYPE
{
	ALL_INFO = 0,
	IP_ADDRESS = 1,
	BROADCAST_ADDRESS = 2 ,
	CHECK = 3
};

uint32_t GetAddress(char* pName, int nType, uint32_t nIsMyAddr)
{
	struct ifconf ifc;
	struct ifreq *ifr;
	struct sockaddr_in in;

	uint32_t	return_val = 0;
	uint32_t	ip_addr = 0;
	uint32_t	bcast_addr = 0;

	int	fd = -1;
	int	numreqs = 30;
	int	n;

	fd = socket (PF_INET, SOCK_DGRAM, 0);

	if (fd < 0) 
	{
		perror("socket()");
		exit(1);
	}

	memset (&ifc, 0, sizeof(ifc));

	ifc.ifc_buf = NULL;
	ifc.ifc_len =  sizeof(struct ifreq) * numreqs;
	ifc.ifc_buf = (char*)malloc((size_t)ifc.ifc_len);

	if( nType == ALL_INFO )
		printf( "                     : %10s %16s %16s\n", "Inf", "IP_ADDR", "BCAST_ADDR");

	while (1) 
	{
		ifc.ifc_len = sizeof(struct ifreq) * numreqs;
		ifc.ifc_buf = (char*)realloc(ifc.ifc_buf, ifc.ifc_len);

		if ((return_val = ioctl(fd, SIOCGIFCONF, &ifc)) < 0) 
		{
			perror("ioctl()");
			break;
		}

		if (ifc.ifc_len == (int) sizeof(struct ifreq) * numreqs) 
		{
			// assume it overflowed and try again
			numreqs += 10;
			continue;
		}
		break;
	}

	if (return_val < 0) {
		perror("ioctl()");
		exit(1);
	}

	// loop through interfaces returned from SIOCGIFCONF
	ifr=ifc.ifc_req;

	for ( n=0; n < ifc.ifc_len; n+=sizeof(struct ifreq) ) 
	{
		// Get the Destination Address for this interface
		return_val = ioctl(fd,SIOCGIFADDR, ifr);

		if (return_val == 0 
			&& ifr->ifr_broadaddr.sa_family == AF_INET) 
			ip_addr = (uint32_t) ((struct sockaddr_in *)&ifr->ifr_addr)->sin_addr.s_addr;
		else 
			perror ("ioctl()");

		// Get the BROADCAST address
		return_val = ioctl(fd,SIOCGIFBRDADDR, ifr);

		if (return_val == 0 
			&& ifr->ifr_broadaddr.sa_family == AF_INET) 
		{
			bcast_addr = (uint32_t) ((struct sockaddr_in *)&ifr->ifr_broadaddr)->sin_addr.s_addr;
		}
		else 
			perror ("ioctl()");

		switch ( nType )
		{
		case ALL_INFO:
			{
				in.sin_addr.s_addr = ip_addr;
				printf( "                     : %10s %16s", ifr->ifr_name, inet_ntoa(in.sin_addr) );

				in.sin_addr.s_addr = bcast_addr;
				printf( "%16s\n", inet_ntoa(in.sin_addr));
			}
			break;
		case IP_ADDRESS:
			{
				if ( 0 == strcmp( pName, ifr->ifr_name ) )
				{
					return_val = ip_addr;
					goto RETURN;
				}
			}
			break;
		case BROADCAST_ADDRESS:
			{
				if ( 0 == strcmp( pName, ifr->ifr_name ) )
				{
					return_val = bcast_addr;
					goto RETURN;
				}
			}
			break;
		case CHECK:
			{
				if ( nIsMyAddr == ip_addr)
				{
					return_val = ip_addr;
					goto RETURN;
				}
			}
			break;
		}

		ifr++;
	}

RETURN:
	free (ifc.ifc_buf);
	close (fd);

	return return_val;
}

int GetDefaultNetworkInterface(char* pStr)
{
	struct ifconf ifc;
	struct ifreq *ifr;

	uint32_t	return_val = 0;
	uint32_t	ip_addr = 0;
	uint32_t	bcast_addr = 0;

	int	fd = -1;
	int	numreqs = 30;
	int	n;

	int bResult = 0;

	strcpy( pStr, "" );

	fd = socket (PF_INET, SOCK_DGRAM, 0);

	if (fd < 0) 
	{
		perror("socket()");
		exit(1);
	}

	memset (&ifc, 0, sizeof(ifc));

	ifc.ifc_buf = NULL;
	ifc.ifc_len =  sizeof(struct ifreq) * numreqs;
	ifc.ifc_buf = (char*)malloc((size_t)ifc.ifc_len);

	while (1) 
	{
		ifc.ifc_len = sizeof(struct ifreq) * numreqs;
		ifc.ifc_buf = (char*)realloc(ifc.ifc_buf, ifc.ifc_len);

		if ((return_val = ioctl(fd, SIOCGIFCONF, &ifc)) < 0) 
		{
			perror("ioctl()");
			break;
		}

		if (ifc.ifc_len == (int) sizeof(struct ifreq) * numreqs) 
		{
			// assume it overflowed and try again
			numreqs += 10;
			continue;
		}
		break;
	}

	if (return_val < 0) {
		perror("ioctl()");
		exit(1);
	}

	// loop through interfaces returned from SIOCGIFCONF
	ifr=ifc.ifc_req;

	for ( n=0; n < ifc.ifc_len; n+=sizeof(struct ifreq) ) 
	{
		// Get the Destination Address for this interface
		return_val = ioctl(fd,SIOCGIFADDR, ifr);

		if (return_val == 0 
			&& ifr->ifr_broadaddr.sa_family == AF_INET) 
			ip_addr = (uint32_t) ((struct sockaddr_in *)&ifr->ifr_addr)->sin_addr.s_addr;
		else 
			perror ("ioctl()");

		// Get the BROADCAST address
		return_val = ioctl(fd,SIOCGIFBRDADDR, ifr);

		if (return_val == 0 
			&& ifr->ifr_broadaddr.sa_family == AF_INET) 
		{
			bcast_addr = (uint32_t) ((struct sockaddr_in *)&ifr->ifr_broadaddr)->sin_addr.s_addr;
		}
		else 
			perror ("ioctl()");

		if ( 0 == strcmp("lo", ifr->ifr_name ) )
		{
			ifr++;
			continue;
		}

		strcpy( pStr, ifr->ifr_name );
		bResult = 1;

		break;
	}

	free (ifc.ifc_buf);
	close (fd);

	return bResult;
}

uint32_t GetMyIP(void)
{
	return GetAddress( getenv("TENET_ROUTER_INTERFACE"), IP_ADDRESS, 0 );
}

uint32_t GetMyBroadcastAddr(void)
{
	return GetAddress( getenv("TENET_ROUTER_INTERFACE"), BROADCAST_ADDRESS, 0 );
}

int IsInTheSameMachine( uint32_t nAddr )
{
	if ( GetAddress( "", CHECK, nAddr ) == nAddr )
		return 0;

	return 1;
}

#endif
