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
* UDP Client class
*
* Authors: Ki-Young Jang
* Embedded Networks Laboratory, University of Southern California
* Modified: 2/6/2007
*/

#include "UDP_Socket.h"

unsigned long	CUDP_Client::s_nMyIP;

CUDP_Client::CUDP_Client(void)
: CNetwork()
{
	this->s_nMyIP=GetMyIP();
}

CUDP_Client::~CUDP_Client(void)
{
}

void CUDP_Client::DirectSend(char *pAddr, unsigned int nPort, char* pData, int nLen, bool bBroadcast)
{
	int		fdSocket;
	int		nBroadcast = 1;
	struct	sockaddr_in	addr;
	struct	hostent*	he;
	int		nSent = 0 ;

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
	addr.sin_port = htons(nPort);
	addr.sin_addr = *((struct in_addr *)he->h_addr);
	bzero(&(addr.sin_zero), 8);

	if(bBroadcast
		&&setsockopt(fdSocket, SOL_SOCKET, SO_BROADCAST, &nBroadcast,
		sizeof(nBroadcast)) == -1) 
	{
		TR_ERROR("setsockopt(SO_BROADCAST) failed");
		exit(1);
	}

	if ((nSent=sendto(fdSocket, (char*) pData, nLen, 0,
		(struct sockaddr *)&addr, sizeof(struct sockaddr))) == -1) 
	{
		TR_ERROR("sendto() failed");
//		exit(1);
	}

	close(fdSocket);
}

void CUDP_Client::Process()
{
	return;
}
