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
* UDP Server class
*
* Authors: Ki-Young Jang
* Embedded Networks Laboratory, University of Southern California
* Modified: 2/6/2007
*/

#include "UDP_Socket.h"

unsigned long	CUDP_Server::s_nMyIP;

CUDP_Server::CUDP_Server(void (*OnReceive)(struct sockaddr_in* , char*, int ), int nPort)
: CNetwork()
{
	this->OnReceive=OnReceive;
	this->m_nPort=nPort;
	this->s_nMyIP=GetMyIP();

	m_fdSocket=-1;
	m_bStart=false;
}

CUDP_Server::~CUDP_Server(void)
{
	close(m_fdSocket);
}

bool CUDP_Server::StartServer(void)
{
	if ((this->m_fdSocket = socket(AF_INET, SOCK_DGRAM, 0)) == -1) 
	{
		TR_ERROR("Creating socket failed");
		exit(1);
	}

	m_addr.sin_family = AF_INET;         
	m_addr.sin_port = htons(this->m_nPort);     
	m_addr.sin_addr.s_addr = INADDR_ANY; 
	bzero(&(m_addr.sin_zero), 8);        

	if (bind(m_fdSocket, (struct sockaddr *)&m_addr, sizeof(struct sockaddr)) == -1) 
	{
		TR_ERROR("CUDP_Server::StartServer()// Binding failed");
		exit(1);
	}

	TRACE("Server Module Started.\n");
 
	m_bStart=true;

	return true;
}

bool CUDP_Server::Terminate(void)
{
	m_bStart=false;

	return true;
}

bool CUDP_Server::IsThereAnyNewPacket()
{
	fd_set			fds;
	struct timeval	tv;

	tv.tv_sec = 0;
	tv.tv_usec = 0;

	FD_ZERO(&fds);			
	FD_SET(this->m_fdSocket, &fds);	

	if (select(this->m_fdSocket+1, &fds, NULL, NULL, &tv) <= 0)
		return false;

	if (FD_ISSET (this->m_fdSocket, &fds))
		return true;

	return false;
}

void CUDP_Server::Send(char *pAddr, char* pData, int nLen, bool bBroadcast)
{
	int	fdSocket ;
	int		nBroadcast = 1;
	struct	sockaddr_in	addr;
	struct	hostent*	he;
	int		nSent = 0;

	if ((fdSocket = socket(AF_INET, SOCK_DGRAM, 0)) == -1) 
	{
		TR_ERROR("Creating socket failed");
		exit(1);
	}

	if ((he = gethostbyname(pAddr)) == NULL) 
	{
		TR_ERROR("gethostbyname() failed");
		exit(1);
	}
	
	addr.sin_family = AF_INET;
	addr.sin_port = htons(this->m_nPort);
	addr.sin_addr = *((struct in_addr *)he->h_addr);
	bzero(&(addr.sin_zero), 8);

	if(bBroadcast
		&&setsockopt(fdSocket, SOL_SOCKET, SO_BROADCAST, &nBroadcast,
		sizeof(nBroadcast)) == -1) 
	{
		TR_ERROR("setsockopt(SO_BROADCAST) failed");
		exit(1);
	}

	if ((nSent=sendto(fdSocket, pData, nLen, 0,
		(struct sockaddr *)&addr, sizeof(struct sockaddr))) == -1) 
	{
		TR_ERROR("sendto() failed");
		//exit(1);
	}

	close(fdSocket);
}

void CUDP_Server::Receive(void)
{
	struct	sockaddr_in	addr;
	int		nBytesRcvd = 0;
	char	pData[MAX_BUFFFER_SIZE];

	memset( pData, 0, MAX_BUFFFER_SIZE);

	int		nAddrSize = sizeof(struct sockaddr);

	if ((nBytesRcvd = 
		recvfrom(m_fdSocket, pData, MAX_BUFFFER_SIZE, 0, (struct sockaddr *)&addr,  
		(socklen_t*)&nAddrSize)) == -1) 
	{
		TR_ERROR("Receive() failed");
		exit(1);
	}

	OnReceive(&addr, pData, nBytesRcvd);
}

void CUDP_Server::Process()
{
	if( this->IsStart() )
		this->Receive();
}
