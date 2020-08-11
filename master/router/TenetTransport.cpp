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
* This class is used for communication between Tenet Transport and
* Tenet Router
*
* Authors: Ki-Young Jang
* Embedded Networks Laboratory, University of Southern California
* Modified: 2/6/2007
*/

#include "TenetTransport.h"
#include "TenetRouter.h"
#include "SFClient.h"
#include "TR_Common.h"


#include "sfsource.h"

CTenetTransportInterface*	CTenetTransportInterface::s_pTenetTransport = NULL;

CTenetTransportInterface::CTenetTransportInterface(void)
:CTCP_Server(CTenetTransportInterface::OnReceive, atoi(getenv("TENET_ROUTER_PORT_FOR_TRANSPORT")))
{
	MSG("[ENV] TENET_ROUTER_PORT_FOR_TRANSPORT : %s\n", getenv("TENET_ROUTER_PORT_FOR_TRANSPORT"));

	s_pTenetTransport = this;
}

CTenetTransportInterface::~CTenetTransportInterface(void)
{
		printf("HERE!3-3\n");
}

bool CTenetTransportInterface::StartServer(void)
{
	((CTCP_Server*)this)->StartServer();

	return true;
}

CTCP_Client* CTenetTransportInterface::Accept()
{
	socklen_t	nAddrLen;
	CSFClient*	pClient=new CSFClient();

	nAddrLen=sizeof(*(pClient->GetClientAddr()));

	if(pClient->SetClientSocket
		(accept(this->m_fdSocket,(struct sockaddr *) pClient->GetClientAddr(),&nAddrLen))>= 0)
	{
		pClient->SetOwner(this);
		pClient->SetValid(true);
		pClient->OnReceive = CTenetTransportInterface::OnReceive;

#ifdef DEBUG_MODE
		TRACE("a Transport is connected.\n");
#endif
		if ( init_sf_source( pClient->GetClientSocket() ) < 0)
			pClient->SetValid( false );

		return pClient;
	}
	else
	{
		pClient->SetValid(false);
		return NULL;
	}
}

void CTenetTransportInterface::SendToAll(TOS_Msg* pMsg)
{
	CSFClient*	pClient;
	list <CTCP_Client*>::iterator	iter;


	for(iter=CTCP_Client::s_listClient.begin();iter!=CTCP_Client::s_listClient.end();iter++)
	{
		pClient=(CSFClient *)*iter;

		if( pClient->GetOwner() == this )
		{
			pClient->Send(pMsg);
		}
	}
}

void CTenetTransportInterface::ReceiveFromAll()
{
	CSFClient	*pClient;
	list <CTCP_Client*>::iterator	iter;


	for(iter=CTCP_Client::s_listClient.begin();iter!=CTCP_Client::s_listClient.end();iter++)
	{
		pClient=(CSFClient *)*iter;

		if( pClient->GetOwner() == this && pClient->IsThereAnyNewPacket())
			pClient->Receive();
	}
}

void CTenetTransportInterface::OnReceive(CTCP_Client *pClient, char* pData, int nLen)
{
	CTenetRouter* pRouter = CTenetRouter::GetTenetRouter();
	pRouter->DispatchPacket( (TOS_Msg*)pData, PACKET_FROM_MY_TRANSPORT, CTenetTransportInterface::s_nMyIP);
}

//void* CTenetTransportInterface::TransportThread(void* arg)
//{
//	CTenetTransportInterface* pTransport = (CTenetTransportInterface*) arg;
//
//	while( pTransport->IsStart() )
//	{
//		if(pTransport->IsThereAnyNewClient())
//		{
//			pTransport->Accept();
//		}
//
//		pTransport->ReceiveFromAll();
//
//		usleep(1);
//	}
//
//	pTransport->Terminate();
//
//	return NULL;
//}

void CTenetTransportInterface::Process()
{
	if( this->IsStart() )
	{
		this->Accept();
	}
}
