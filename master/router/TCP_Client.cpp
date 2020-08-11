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
* TcpServer/TcpClient classes
*
* Authors: Ki-Young Jang
* Embedded Networks Laboratory, University of Southern California
* Modified: 2/6/2007
*/

#include <stdio.h>
#include <sys/time.h>
#include <sys/types.h>
#include <unistd.h>

#include "TCP_Socket.h"
#include "TR_Common.h"

int				CTCP_Client::s_nMaxSocket;
ListTCP_Client	CTCP_Client::s_listClient;
unsigned long	CTCP_Client::s_nMyIP;

CTCP_Client::CTCP_Client(void (*OnReceive)(CTCP_Client *, char*, int ))
: CNetwork()
{
	this->m_bValid = false;
	this->OnReceive = OnReceive;
	this->m_pOwner = NULL;

	this->s_nMyIP = GetMyIP();
	s_listClient.push_back(this);
}

CTCP_Client::~CTCP_Client(void)
{
	this->SetValid(false);
}

bool CTCP_Client::Connect(char *strIP, int nPort)
{
	// Create a reliable, stream socket using TCP 
	if ((this->m_fdSocket=socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)) < 0)
	{
		TR_ERROR("socket() failed");
		this->SetValid(false);
		return false;
	}

	// Construct the server address structure 
	memset(&this->m_addr, 0, sizeof(this->m_addr));	// Zero out structure 
	this->m_addr.sin_family = AF_INET;					// Internet address family 
	this->m_addr.sin_addr.s_addr = inet_addr(strIP);		// Server IP address 
	this->m_addr.sin_port = htons(nPort);					// Server port 

	// Establish the connection to the echo server 
	if (connect(this->m_fdSocket, (struct sockaddr *) &this->m_addr, sizeof(this->m_addr)) < 0)
	{
		TR_ERROR("connect() failed\n");
		this->SetValid(false);
		return false;
	}

	this->SetValid(true);

	s_nMaxSocket=this->m_fdSocket;

	return true;
}

bool CTCP_Client::Close(void)
{
	close(this->m_fdSocket);
	return false;
}

bool CTCP_Client::Send(char* pData, int nLen)
{
	int total = 0;	// how many bytes we've sent
	int bytesleft = nLen; // how many we have left to send
	int n = 0;

	if(!this->GetValid())
		return -1;

	while(0!=bytesleft) 
	{
		n=send(this->m_fdSocket, (char *) pData, bytesleft, 0);

		if(n==-1)
		{
			TR_ERROR("send() sent a different number of bytes than expected\n");
			this->SetValid(false);
			return false;
		}

		total+= n;
		bytesleft-=n;
	}

	return true;
}

bool CTCP_Client::IsThereAnyNewPacket()
{
	fd_set			fds;
	struct timeval	tv;

	tv.tv_sec = 0;
	tv.tv_usec = 0;

	if(!this->GetValid())
		return false;

	FD_ZERO(&fds);			
	FD_SET(this->m_fdSocket, &fds);	

	if (select(this->m_fdSocket+1, &fds, NULL, NULL, &tv) <= 0)
		return false;

	if (FD_ISSET (this->m_fdSocket, &fds))
		return true;

	return false;
}

int CTCP_Client::Receive(void)
{
	int		nBytesRcvd=0;
	char	pData[MAX_BUFFFER_SIZE];

	if(!this->GetValid())
		return -1;

	if ((nBytesRcvd=recv(this->m_fdSocket,pData,MAX_BUFFFER_SIZE, 0))<=0)
	{
		TR_ERROR("CTCP_Client::Receive()// recv() error!\n");
		this->SetValid(false);
		return 0;
	}

	this->OnReceive(this,pData, nBytesRcvd);

	return nBytesRcvd;
}

void CTCP_Client::Process()
{
	this->Receive();
}
