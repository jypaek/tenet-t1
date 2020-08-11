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
* Socket base class of UdpServer/UdpClient and TcpServer/TcpClient classes
*
* Authors: Ki-Young Jang
* Embedded Networks Laboratory, University of Southern California
* Modified: 2/6/2007
*/

#ifndef _NETWORK_H_
#define _NETWORK_H_

#include <sys/types.h>
#include <netinet/in.h> 
#include <sys/socket.h> 
#include <arpa/inet.h>	//inet_addr()
#include <unistd.h>		//close()
#include <map>
using namespace std;

#define	REGULAR_PACKET		0
#define WITH_ACK_REQUEST	1
#define	ACK					2

// This structure is used for finding network interface or IP address
enum ADDRESS_TYPE
{
	ALL_INFO,
	IP_ADDRESS,
	BROADCAST_ADDRESS,
	CHECK
};

uint32_t GetAddress(char* pName, int nType, uint32_t nIsMyAddr = 0);
bool GetDefaultNetworkInterface(char* pStr);
uint32_t GetMyIP(void);
uint32_t GetMyBroadcastAddr(void);
bool IsInTheSameMachine( uint32_t nAddr );

class CNetwork;

typedef map <CNetwork*, int> NetworkSocketMap;
typedef map <CNetwork*, int>::iterator NetworkSocketMapIter;
typedef pair <CNetwork*, int> NetworkSocketPair;

// Socket base class
class CNetwork
{
public:
	CNetwork(void);
	virtual ~CNetwork(void);

	static void CheckAllSocket(void);

protected:
	int		m_fdSocket;				// Socket descriptor for server 

	static NetworkSocketMap	m_NetworkSocketMap;

	static void Add(CNetwork* pNetwork);
	static void Remove(CNetwork* pNetwork);

	virtual void Process(void);
};

#endif

