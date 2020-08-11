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

#ifndef _TCP_SOCKET_H_
#define _TCP_SOCKET_H_

#include <sys/types.h>
#include <sys/socket.h>
#include <sys/types.h>	
#include <netinet/in.h>	
#include <arpa/inet.h>	
#include <netdb.h>		
#include <unistd.h>		
#include <stdlib.h>		
#include <string.h>		
#include <errno.h>
#include <signal.h>
#include <sys/wait.h>	
#include <pthread.h>
#include <utility>

#include <list>
using namespace std;

#include "TR_Common.h"
#include "Network.h"

class CTCP_Client;
typedef struct list <CTCP_Client *> ListTCP_Client;

// TCP Server class
class CTCP_Server
	: public CNetwork
{
public:
	CTCP_Server(void (*OnReceive)(CTCP_Client *, char* , int ), int nPort);
	~CTCP_Server(void);

	bool	StartServer(void);
	bool	Terminate(void);

	bool	IsStart(void)
	{
		return m_bStart;
	}

	void	SendToAll(char* pData, int nLen);
	void	ReceiveFromAll();

protected:
	static unsigned long	s_nMyIP;
	struct	sockaddr_in	m_addr;
	int		m_nPort;				// Port Number

	bool	m_bStart;

	virtual void Process(void);

protected:
	CTCP_Client* Accept();

	bool	Listen(void);
	bool	IsThereAnyNewClient();
	void	(*OnReceive)(CTCP_Client *pClient, char* pData, int nLen);

	static void DestoryAll(CTCP_Server* pOwner);
	static void DestoryInvalidSocket(CTCP_Server* pOwner);
};

// TCP client class
class CTCP_Client
	: public CNetwork
{
public:
	CTCP_Client(void	(*OnReceive)(CTCP_Client *, char* , int ));
	~CTCP_Client(void);

	bool	Connect(char *strIP, int nPort);
	bool	Close(void);

	bool	Send(char* pData, int nLen);
	int		Receive(void);

	int	SetClientSocket(int nSocket)
	{
		m_fdSocket=nSocket;
		return m_fdSocket;
	}

	int	GetClientSocket(void)
	{
		return m_fdSocket;
	}

	void SetValid(bool bValid)
	{
		this->m_bValid=bValid;
	}

	bool GetValid(void)
	{
		return this->m_bValid;
	}

	void SetOwner(CTCP_Server* pOwner)
	{
		this->m_pOwner = pOwner;
	}

	CTCP_Server* GetOwner()
	{
		return m_pOwner;
	}

	struct sockaddr_in* GetClientAddr()
	{
		return &m_addr;
	}

	bool	IsThereAnyNewPacket();

	void	(*OnReceive)(CTCP_Client *pClient, char* pData, int nLen);
	virtual void Process(void);

public:
	static int				s_nMaxSocket;
	static ListTCP_Client	s_listClient;

protected:
	static unsigned long	s_nMyIP;
	struct	sockaddr_in		m_addr;
	int		m_nPort;				// Port Number
	bool	m_bValid;

	CTCP_Server*	m_pOwner;
};

#endif
