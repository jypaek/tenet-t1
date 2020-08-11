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
* This class is used for IP routing table access for communications
* among Masters
*
* Authors: Ki-Young Jang
* Embedded Networks Laboratory, University of Southern California
* Modified: 2/6/2007
*/

#ifndef _IPRT_MGR_H_
#define _IPRT_MGR_H_

#include "tosmsg.h"
#include <map>
using namespace std;

#define AddrMote	uint16_t
#define AddrMaster	uint32_t

#define MAX_BUFFFER_SIZE	1000
#ifdef __CYGWIN__
	#define ROUTE_FILE	"/tmp/route"
#else
#ifdef __APPLE__
	#define ROUTE_FILE	"/tmp/route"
#else 
	#define ROUTE_FILE	"/proc/net/route"
#endif
#endif

#define IPRT_REFRESH_TIMER_ID	10002
#define IPRT_REFRESH_TIMEOUT	30		// sec
#define MAX_IPRT_ENTRIES		110


// IP Routing Table entry
struct IPRT_Entry
{
	AddrMaster	destIP;
	AddrMaster	nextHopIP;
	bool	bUsed;
}__attribute__((packed));


struct IPRT_Packet
{
	unsigned char nEntries;
	struct IPRT_Entry	pEntries[MAX_IPRT_ENTRIES];

	int GetIPRT_PacketLength()
	{
		return nEntries * sizeof(IPRT_Entry) + sizeof(unsigned char);
	}
}__attribute__((packed));// just for debugging purpose

typedef map <AddrMaster, IPRT_Entry*> IPRT;
typedef map <AddrMaster, IPRT_Entry*> :: iterator IPRTiter;

// IP Routing table is accessed through this class
class CIPRT_Manager
{
public:
	CIPRT_Manager(void);
	~CIPRT_Manager(void);

private:
	static IPRT s_IPRT;
	static int	s_nTimer;

public:
	static void			Initialize(void);
	static void			Finalize(void);
	static void			Update(AddrMaster DestIP, AddrMaster nextHopIP);
	static void			Insert(AddrMaster DestIP, AddrMaster nextHopIP);
	static void			Erase(AddrMaster DestIP);
	static AddrMaster	LookUpNextHop(AddrMaster DestIP);
	static IPRT_Entry*	LookUpEntry(AddrMaster DestIP);
	static int			Refresh(int nType);
	static void			Show(void);
	static void			Show(IPRT_Packet* pPacket);
	static int			MakeIPRT_Packet(IPRT_Packet* pPacket);

};

#endif
