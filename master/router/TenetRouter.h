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
* Tenet router main class
*
* Authors: Ki-Young Jang
* Embedded Networks Laboratory, University of Southern California
* Modified: 2/6/2007
*/

#ifndef _TENETROUTER_H_
#define _TENETROUTER_H_

#include <pthread.h>

#include "UDP_Socket.h"
#include "MRT_Manager.h"
#include "IPRT_Manager.h"


#include "tosmsg.h"

#define AddrMote	uint16_t
#define AddrMaster	uint32_t

#define BEACON_TIMER_ID		10000
#define BEACON_INTERVAL		3		//sec

class	CTenetSFClient;
class	CTenetTransportInterface;

enum
{
	PACKET_FROM_MY_MOTE = 0x00,
	PACKET_FROM_MY_NEIGHBOR = 0x01,
	PACKET_FROM_MY_TRANSPORT = 0x02
};

enum
{
	TR_PACKET_TYPE_BEACON = 0x00,
	TR_PACKET_TYPE_TOSMSG = 0x01,
	TR_PACKET_TYPE_ACK = 0x05,

	TR_PACKET_TYPE_CTRL_REQ = 0x10,

	TR_PACKET_TYPE_CTRL_RES = 0x20,
	TR_PACKET_TYPE_CTRL_RES_MRT = 0x21,
	TR_PACKET_TYPE_CTRL_RES_IPRT = 0x22
};

typedef struct TR_PacketHeader
{
	unsigned char	type;
	AddrMaster		lMasterIP;
	unsigned short	nDataLength;
};

// Just for debugging in interactive mode
typedef struct TR_Ctrl_Req
{
	char	pStrCommand[MAX_STRING_SIZE];
};

typedef struct TR_Ctrl_Res
{
};

typedef struct TR_Packet
{
	struct	TR_PacketHeader header;

	char	pData[MAX_BUFFFER_SIZE];

	int		GetTotalPacketLength()
	{
		return header.nDataLength + sizeof(TR_PacketHeader);
	}
};

//Tenet router main class
class CTenetRouter
	: public CUDP_Server
{
public:
	CTenetRouter(void);
	~CTenetRouter(void);

private:
	static	CTenetRouter*	s_pTenetRouter;
	static	AddrMote		s_nTenetLocalAddr;

	int				m_nBeaconTimer;
	CTenetSFClient*	m_pSF; // this instance communicates with basestation mote
	CTenetTransportInterface* m_pTransport; // this instance communicate with Tenet transport

	static	AddrMote	IPtoMoteID(AddrMaster masterID);
	static	AddrMaster	MoteIDtoIP(AddrMote moteID);
	static	AddrMote	GetSrcMoteID(TOS_Msg* pMsg);
	static	AddrMote	GetDstMoteID(TOS_Msg* pMsg);
	static	AddrMote	GetNextHopMoteID(TOS_Msg* pMsg);
	static	void		OnReceive(struct sockaddr_in* pAddr, char* pData, int nLen);

public:
void		Timer();

public:
	bool	StartServer(void);
	void	Send(char *pAddr, TOS_Msg* pMsg, unsigned long lMasterIP, bool bBroadcast = false);

	static	int		Beacon(int nType);
    static  void    Unicast(TOS_Msg* pMsg, unsigned long lMasterIP);
	static	void	DispatchPacket(TOS_Msg* pMsg, unsigned int nFrom, unsigned long lMasterIP, unsigned long nFromNeighborIP = 0);

	virtual void Process(void);

	static CTenetRouter* GetTenetRouter()
	{
        return s_pTenetRouter;
	}

    static AddrMote GetTenetLocalAddr()
    {
        return s_nTenetLocalAddr;
    }

	static bool ParseTR_Command(TR_Packet *pPacket, bool bConsole = true);
};

#endif
