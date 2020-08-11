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
* UdpServer/UdpClient classes
*
* Authors: Ki-Young Jang
* Embedded Networks Laboratory, University of Southern California
* Modified: 2/6/2007
*/

#ifndef _UDP_SOCKET_H_
#define _UDP_SOCKET_H_

#include <stdio.h> 
#include <stdlib.h> 
#include <errno.h> 
#include <string.h> 
#include <sys/types.h> 
#include <netdb.h> 
#include <errno.h>
#include <signal.h>
#include <sys/wait.h>	//waitpid()
#include <pthread.h>
#include <utility>

#include "TR_Common.h"
#include "Network.h"


class CUDP_Server
	: public CNetwork
{
public:
	CUDP_Server(void (*OnReceive)(struct sockaddr_in* , char* , int ), int nPort);
	~CUDP_Server(void);

	bool	StartServer(void);
	bool	Terminate(void);

	bool	IsStart(void)
	{
		return m_bStart;
	}

	bool	IsThereAnyNewPacket(void);
	void	Send(char *pAddr, char* pData, int nLen, bool bBroadcast = false);
	void	Receive(void);
	virtual void Process(void);

protected:
	static unsigned long	s_nMyIP;
	struct	sockaddr_in m_addr;
	int		m_nPort;			// Port Number

	bool	m_bStart;

protected:
	void	(*OnReceive)(struct sockaddr_in* addr, char* pData, int nLen);
};

class CUDP_Client
	: public CNetwork
{
public:
	CUDP_Client(void);
	~CUDP_Client(void);

	static void	DirectSend(char *pAddr, unsigned int nPort, char* pData, int nLen, bool bBroadcast = false);
	virtual void Process(void);

private:
	static unsigned long	s_nMyIP;
};

#endif
