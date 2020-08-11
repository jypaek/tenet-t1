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
* TCP Server class
*
* Authors: Ki-Young Jang
* Embedded Networks Laboratory, University of Southern California
* Modified: 2/6/2007
*/

#include "TCP_Socket.h"

unsigned long	CTCP_Server::s_nMyIP;

CTCP_Server::CTCP_Server(void (*OnReceive)(CTCP_Client *, char*, int), int nPort)
: CNetwork()
{
	this->OnReceive=OnReceive;
	this->m_nPort=nPort;
	this->s_nMyIP=GetMyIP();

	m_fdSocket=-1;
	m_bStart=false;
}

CTCP_Server::~CTCP_Server(void)
{
	close(this->m_fdSocket);

	// Delete All Client
	CTCP_Server::DestoryAll( this );
}

bool CTCP_Server::StartServer(void)
{
	// Create socket for incoming connections 
	if ((this->m_fdSocket=socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)) < 0)
	{
		TR_ERROR("Creating socket failed");
		exit(1);
	}

	// Construct local address structure 
	memset(&m_addr, 0, sizeof(m_addr));			// Zero out structure 
	m_addr.sin_family = AF_INET;				// Internet address family 
	m_addr.sin_addr.s_addr = htonl(INADDR_ANY);	// Any incoming interface 
	m_addr.sin_port = htons(this->m_nPort);		// Local port 

	// Bind to the local address 
	if (bind(m_fdSocket, (struct sockaddr *) &m_addr, sizeof(m_addr)) < 0)
	{
		TR_ERROR("CTCP_Server::StartServer()// Binding failed");
		exit(1);
	}

	int nLen=sizeof(struct  sockaddr);
	getsockname(m_fdSocket, (struct sockaddr*) &m_addr,(socklen_t*) &nLen);

	this->m_nPort=ntohs(m_addr.sin_port);

	Listen();

#ifdef DEBUG_MODE
	TRACE("Server Module Started.\n\tTCP Server Port : %d\n", this->m_nPort);
#endif

	m_bStart=true;

	return true;
}

bool CTCP_Server::Terminate(void)
{
	m_bStart=false;

	return true;
}

bool CTCP_Server::Listen(void)
{
	// Mark the socket so it will listen for incoming connections 
	if (listen(m_fdSocket, 1) < 0)
	{
		TR_ERROR("listen() failed\n");
		exit(1);
	}
	return true;
}

bool CTCP_Server::IsThereAnyNewClient()
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

CTCP_Client* CTCP_Server::Accept()
{
	socklen_t		nAddrLen;
	CTCP_Client	*pClient=new CTCP_Client(this->OnReceive);

	nAddrLen=sizeof(*(pClient->GetClientAddr()));

	if(pClient->SetClientSocket
		(accept(this->m_fdSocket,(struct sockaddr *) pClient->GetClientAddr(),&nAddrLen))>= 0)
	{
		pClient->SetOwner(this);
		pClient->SetValid(true);

#ifdef DEBUG_MODE
		TRACE("a Client is accepted.\n");
#endif
		return pClient;
	}
	else
	{
		pClient->SetValid(false);
		return NULL;
	}
}

void CTCP_Server::SendToAll(char* pData, int nLen)
{
	CTCP_Client	*pClient;
	list <CTCP_Client*>::iterator	iter;


	for(iter=CTCP_Client::s_listClient.begin();iter!=CTCP_Client::s_listClient.end();iter++)
	{
		pClient=(CTCP_Client *)*iter;

		if( pClient->GetOwner() == this )
		{
			pClient->Send(pData, nLen);
		}
	}
}

void CTCP_Server::ReceiveFromAll()
{
	CTCP_Client	*pClient;
	list <CTCP_Client*>::iterator	iter;


	for(iter=CTCP_Client::s_listClient.begin();iter!=CTCP_Client::s_listClient.end();iter++)
	{
		pClient=(CTCP_Client *)*iter;

		if( pClient->GetOwner() == this && pClient->IsThereAnyNewPacket())
			pClient->Receive();
	}
}

void CTCP_Server::DestoryAll(CTCP_Server* pOwner)
{
	CTCP_Client	*pClient=NULL;
	list <CTCP_Client*>::iterator	iter;

	for(iter=CTCP_Client::s_listClient.begin();iter!=CTCP_Client::s_listClient.end();iter++)
	{
		if(pClient && 
			pOwner == pClient->GetOwner() )
			delete pClient;

		pClient=(CTCP_Client *)*iter;
	}

	if(pClient)
		delete pClient;
}

void CTCP_Server::DestoryInvalidSocket(CTCP_Server* pOwner)
{
	CTCP_Client	*pClient=NULL;
	list <CTCP_Client*>::iterator	iter;
	list <CTCP_Client*>::iterator	iterTemp;

	for(iter=CTCP_Client::s_listClient.begin();iter!=CTCP_Client::s_listClient.end();iter++)
	{
		pClient=(CTCP_Client *)*iter;
		if(NULL!=pClient)
		{
			if(!pClient->GetValid() &&
				pOwner == pClient->GetOwner())
			{
				iterTemp=iter;
				iterTemp++;

				CTCP_Client::s_listClient.remove(*iter);

				delete pClient;

				iter=iterTemp;
				
				return;

			}
		}
	}
}

void CTCP_Server::Process()
{
	if( this->IsStart() )
	{
		this->Accept();
	}
}
