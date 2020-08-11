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
* Socket base class of UdpServer/UdpClient and TcpServer/TcpClient classes
* Also here are some utility functions for accessing network interface info
*
* Authors: Ki-Young Jang
* Embedded Networks Laboratory, University of Southern California
* Modified: 2/6/2007
*/

#include "Network.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <net/if.h>
#include <netdb.h>
//#include <netinet/in.h>
#include <arpa/inet.h>
#include <sys/time.h>

#include "TR_Common.h"

// this function retrieves addresses of network adpators in the system
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
		MSG( "                     : %10s %16s %16s\n", "Inf", "IP_ADDR", "BCAST_ADDR");

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
#ifdef __APPLE__
                if( !( 'l' == ifr->ifr_name[0] && 'o' == ifr->ifr_name[1] ) &&
                    !( 'e' == ifr->ifr_name[0] && 'n' == ifr->ifr_name[1] ) )
                {
                    goto CONTINUE;
                }
#endif
		return_val = ioctl(fd,SIOCGIFADDR, ifr);

		if (return_val == 0 
			&& ifr->ifr_broadaddr.sa_family == AF_INET) 
                {
			ip_addr = (uint32_t) ((struct sockaddr_in *)&ifr->ifr_addr)->sin_addr.s_addr;
                }
		else
                {
			perror ("ioctl()");
                }

		// Get the BROADCAST address
		return_val = ioctl(fd,SIOCGIFBRDADDR, ifr);

		if (return_val == 0 
			&& ifr->ifr_broadaddr.sa_family == AF_INET) 
		{
			bcast_addr = (uint32_t) ((struct sockaddr_in *)&ifr->ifr_broadaddr)->sin_addr.s_addr;
		}
		else
                { 
#ifdef __APPLE__
                        if( 0 == strcmp ( "lo0", ifr->ifr_name ) )
                            bcast_addr = 0x7fffffff;
                        else
#endif
			perror ("ioctl()");
                }

		switch ( nType )
		{
		case ALL_INFO:
			{
				in.sin_addr.s_addr = ip_addr;
				MSG( "                     : %10s %16s", ifr->ifr_name, inet_ntoa(in.sin_addr) );

				in.sin_addr.s_addr = bcast_addr;
				MSG( "%16s\n", inet_ntoa(in.sin_addr));
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
#ifdef __APPLE__
CONTINUE:
#endif

		ifr++;
	}

RETURN:
	free (ifc.ifc_buf);
	close (fd);

	return return_val;
}

bool GetDefaultNetworkInterface(char* pStr)
{
	struct ifconf ifc;
	struct ifreq *ifr;

	uint32_t	return_val = 0;
	uint32_t	ip_addr = 0;
	uint32_t	bcast_addr = 0;

	int	fd = -1;
	int	numreqs = 30;
	int	n;

	bool bResult = false;

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
#ifdef __APPLE__
                if( !( 'l' == ifr->ifr_name[0] && 'o' == ifr->ifr_name[1] ) &&
                    !( 'e' == ifr->ifr_name[0] && 'n' == ifr->ifr_name[1] ) )
                {
                    ifr++;
                    continue;
                }
#endif
		return_val = ioctl(fd,SIOCGIFADDR, ifr);

		if (return_val == 0 
			&& ifr->ifr_broadaddr.sa_family == AF_INET) 
			ip_addr = (uint32_t) ((struct sockaddr_in *)&ifr->ifr_addr)->sin_addr.s_addr;
		else 
                {
			perror ("ioctl()");
                }

		// Get the BROADCAST address
		return_val = ioctl(fd,SIOCGIFBRDADDR, ifr);

		if (return_val == 0 
			&& ifr->ifr_broadaddr.sa_family == AF_INET) 
		{
			bcast_addr = (uint32_t) ((struct sockaddr_in *)&ifr->ifr_broadaddr)->sin_addr.s_addr;
		}
		else
                { 
#ifdef __APPLE__
                        if( 0 == strcmp ( "lo0", ifr->ifr_name ) )
                            bcast_addr = 0x7fffffff;
                        else
#endif
			perror ("ioctl()");
                }
#ifdef __APPLE__
		if ( 0 == strcmp("lo0", ifr->ifr_name ) )
#else
		if ( 0 == strcmp("lo", ifr->ifr_name ) )
#endif
		{
			ifr++;
			continue;
		}

		strcpy( pStr, ifr->ifr_name );
		bResult = true;

		break;
	}

	free (ifc.ifc_buf);
	close (fd);

	return bResult;
}

uint32_t GetMyIP(void)
{
        if( getenv("TENET_ROUTER_DEFAULT_IP_ADDRESS") )
        {
             uint32_t nAddr;
             inet_aton( getenv("TENET_ROUTER_DEFAULT_IP_ADDRESS"), (in_addr*) &nAddr);
             //printf("TENET_ROUTER_DEFAULT_IP_ADDRESS %X\n", nAddr);
             return nAddr;
        }

        return GetAddress( getenv("TENET_ROUTER_INTERFACE"), IP_ADDRESS );}

uint32_t GetMyBroadcastAddr(void)
{
        if( getenv("TENET_ROUTER_DEFAULT_BROADCAST_ADDRESS") )
        {
             uint32_t nAddr;
             inet_aton( getenv("TENET_ROUTER_DEFAULT_BROADCAST_ADDRESS"), (in_addr*) &nAddr);
             //printf("TENET_ROUTER_DEFAULT_BROADCAST_ADDRESS %X\n", nAddr);
             return nAddr;
        }

        return GetAddress( getenv("TENET_ROUTER_INTERFACE"), BROADCAST_ADDRESS );}

bool IsInTheSameMachine( uint32_t nAddr )
{
	if ( GetAddress( "", CHECK, nAddr ) == nAddr )
		return true;

	return false;
}

NetworkSocketMap	CNetwork::m_NetworkSocketMap;

CNetwork::CNetwork(void)
{
	CNetwork::Add(this);
}

CNetwork::~CNetwork(void)
{
	CNetwork::Remove(this);
}


void CNetwork::Add(CNetwork* pNetwork)
{
	CNetwork::m_NetworkSocketMap.insert( NetworkSocketPair( pNetwork, pNetwork->m_fdSocket ) );
}

void CNetwork::Remove(CNetwork* pNetwork)
{
	CNetwork::m_NetworkSocketMap.erase( CNetwork::m_NetworkSocketMap.find( pNetwork ) );
}

void CNetwork::CheckAllSocket(void)
{
	CNetwork* pNetwork;

	NetworkSocketMapIter iter;

	int		nMaxFD = -1;
	fd_set	fds;
	struct timeval	tv;

	tv.tv_sec = 1;
	tv.tv_usec = 0;

	FD_ZERO(&fds);			

	if( 0 == CNetwork::m_NetworkSocketMap.size() )
		return;

	iter = CNetwork::m_NetworkSocketMap.begin();

	do
	{
		pNetwork = ( (CNetwork*)iter->first );

		if( NULL == pNetwork )
			break;

		if( -1 != pNetwork->m_fdSocket)
		{
			FD_SET(pNetwork->m_fdSocket, &fds);	

			if( nMaxFD < pNetwork->m_fdSocket )
				nMaxFD = pNetwork->m_fdSocket;
		}

		iter++;

		if( iter == CNetwork::m_NetworkSocketMap.end() )
			break;

	}while(1);


	if (select(nMaxFD+1, &fds, NULL, NULL, &tv) <= 0)
		return;

	iter = CNetwork::m_NetworkSocketMap.begin();

	do
	{
		pNetwork = ( (CNetwork*)iter->first );

		if( NULL == pNetwork )
			break;

		if (FD_ISSET (pNetwork->m_fdSocket, &fds))
			pNetwork->Process();

		iter++;

		if( iter == CNetwork::m_NetworkSocketMap.end() )
			break;
	}while(1);
}

void CNetwork::Process()
{
	return;
}
