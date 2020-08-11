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

#ifndef _TENETTRANSPORT_H_
#define _TENETTRANSPORT_H_

#include <pthread.h>

#include "TCP_Socket.h"

#include "tosmsg.h"

#define	PACKET_FROM_TRANSPORT		102

// this class is used for communication with Tenet transport
class CTenetTransportInterface
	: public CTCP_Server
{
public:
	CTenetTransportInterface(void);
	~CTenetTransportInterface(void);

private:
	static	CTenetTransportInterface*	s_pTenetTransport;
	static	void	OnReceive(CTCP_Client *pClient, char* pData, int nLen);

protected:
	CTCP_Client* Accept();

public:
	static	CTenetTransportInterface* GetTenetTransport()
	{
        return s_pTenetTransport;
	}

	bool	StartServer(void);
	void	SendToAll(TOS_Msg* pMsg);
	void	ReceiveFromAll();

	virtual void Process(void);
};

#endif
