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
* SFClient wrapper class. This class is used for communication
* between a basestation mote and Tenet Router
*
* Authors: Ki-Young Jang
* Embedded Networks Laboratory, University of Southern California
* Modified: 2/6/2007
*/

#include "TenetSFClient.h"
#include "TenetRouter.h"

#include "tosmsg.h"

CTenetSFClient::CTenetSFClient(void)
{
	this->OnReceive = CTenetSFClient::OnSFReceive;

	MSG("[ENV] TENET_SF_HOST : %s\n", getenv("TENET_SF_HOST"));
	MSG("[ENV] TENET_SF_PORT : %s\n", getenv("TENET_SF_PORT"));
}

CTenetSFClient::~CTenetSFClient(void)
{
}

bool CTenetSFClient::Connect()
{
	((CSFClient*)this)->Connect( getenv("TENET_SF_HOST"), atoi(getenv("TENET_SF_PORT")) );
	//pthread_create(&m_thread, NULL, CTenetSFClient::SFThread, (void*)this);
	return true;
}


void CTenetSFClient::OnSFReceive(CTCP_Client* pClient, char* pData, int nLen)
{
	CTenetRouter* pTenetRouter=CTenetRouter::GetTenetRouter();

	pTenetRouter->DispatchPacket((TOS_Msg*) pData, PACKET_FROM_MY_MOTE, CTenetSFClient::s_nMyIP);
}

//void* CTenetSFClient::SFThread(void* arg)
//{
//	CTenetSFClient* pSF = (CTenetSFClient*) arg;
//	CTenetRouter* pTenetRouter = CTenetRouter::GetTenetRouter();
//
//	while( pTenetRouter->IsStart() )
//	{
//		if( !pSF->GetValid() )
//		{
//			TR_ERROR("CTenetSFClient::SFThread()//Connect Again\n");
//			((CSFClient*)pSF)->Connect( getenv("TENET_SF_HOST"), atoi(getenv("TENET_SF_PORT")) );
//			usleep(1000000);
//		}
//		else if( pSF->IsThereAnyNewPacket() )
//		{
//			pSF->Receive();
//		}
//
//		usleep(1);
//	}
//	return NULL;
//}

void CTenetSFClient::Process()
{
	CTenetRouter* pTenetRouter = CTenetRouter::GetTenetRouter();

	if( pTenetRouter->IsStart() )
	{
		if( !this->GetValid() )
		{
			TR_ERROR("CTenetSFClient::Process()//Connect Again\n");
			((CSFClient*)this)->Connect( getenv("TENET_SF_HOST"), atoi(getenv("TENET_SF_PORT")) );
			usleep(1000000);
		}
		else
		{
			this->Receive();
		}
	}
}

void CTenetSFClient::ShowPacket(char *pData, int nLen)
{
#ifdef DEBUG_MODE

	DEBUG("        >> ");

	for (int i = 0; i < nLen; i++)
	{
		if( i == 5 )
			DEBUG("// ");

		if( i== offsetof(TOS_Msg, type) )
			DEBUG("[");

		DEBUG("%02x", (unsigned char)pData[i]);

		if( i== offsetof(TOS_Msg, type) )
			DEBUG("]");

		DEBUG(" ");
	}

	putchar('\n');

	fflush(stdout);
#endif
}

