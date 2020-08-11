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
* Serial forwarder client class
*
* Authors: Ki-Young Jang
* Embedded Networks Laboratory, University of Southern California
* Modified: 2/6/2007
*/

#include <stddef.h>

#include "TR_Common.h"
#include "sfsource.h"

#include "SFClient.h"
#include "File.h"
#include <sys/time.h>

CSFClient::CSFClient(void)
:CTCP_Client(CSFClient::OnSFReceive)
{
	this->OnReceive=CSFClient::OnSFReceive;
}

CSFClient::~CSFClient(void)
{
}

bool CSFClient::Connect(char *strIP, int nPort)
{
	this->m_fdSocket = open_sf_source(strIP, nPort);

	if (this->m_fdSocket < 0)
	{
		TR_ERROR("Connection Failed\n");
		return false;
	}

	this->SetValid(true);

	return true;
}

bool CSFClient::Send(TOS_Msg* pMsg)
{
	struct timeval t;
	gettimeofday(&t, NULL);

	if ( this->GetValid()
		&& -1 == write_sf_packet( this->m_fdSocket, (void*) pMsg, pMsg->length + offsetof(TOS_Msg, data)) )
	{
		TR_ERROR("send() sent a different number of bytes than expected\n");
		this->SetValid(false);
		return false;
	}

	return true;
}

void CSFClient::OnSFReceive(CTCP_Client *pClient, char* pData, int nLen)
{
#ifdef DEBUG_MODE
	for (int i = 0; i < nLen; i++)
		DEBUG("%02x ", pData[i]);

	putchar('\n');

	fflush(stdout);
#endif

}

int CSFClient::Receive(void)
{
	int		nBytesRcvd=0;
	char	pData[MAX_BUFFFER_SIZE];
	char*	pDataTemp;

	if(!this->GetValid())
		return -1;

	pDataTemp = (char*) read_sf_packet( this->m_fdSocket, &nBytesRcvd );

	if( NULL == pDataTemp )
	{
		TR_ERROR("CSFClient::Receive()// recv() error!\n");
		this->SetValid(false);
		return 0;
	}

	memcpy( pData, pDataTemp, nBytesRcvd );

	free(pDataTemp);

	this->OnReceive(this,pData, nBytesRcvd);

	return nBytesRcvd;
}

void CSFClient::ShowPacket(char *pData, int nLen)
{
#ifdef DEBUG_MODE
	DEBUG(" >> ");
	for (int i = 0; i < nLen; i++)
		DEBUG("%02x ", (unsigned char)pData[i]);

	putchar('\n');

	fflush(stdout);
#endif
}

void CSFClient::WritePacketToFile(CFile *pFile, char *pData, int nLen)
{
	char pStr[MAX_STRING_SIZE];

	for (int i = 0; i < nLen; i++)
	{
		sprintf( pStr, "%02x ", (unsigned char)pData[i]);
		pFile->WriteLine(pStr);
	}

	sprintf( pStr, "\n");
	pFile->WriteLine(pStr);
}

void CSFClient::Process()
{
	this->Receive();
}
