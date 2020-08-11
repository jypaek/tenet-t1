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
* This class handles mote routing tables
*
* Authors: Ki-Young Jang
* Embedded Networks Laboratory, University of Southern California
* Modified: 2/6/2007
*/

#ifndef _MRT_MGR_H_
#define _MRT_MGR_H_

#include "tosmsg.h"
#include <map>
using namespace std;

#define AddrMote	uint16_t
#define AddrMaster	uint32_t
#define MAX_BUFFFER_SIZE	1000

#define MRT_REFRESH_TIMER_ID	10001
#define MRT_REFRESH_TIMEOUT		120		// sec
#define MAX_MRT_ENTRIES			110

// Mote routing table entry
struct MRT_Entry
{
	AddrMote	moteID;
	AddrMote	nextMoteID;
	AddrMaster	masterIP;
	bool		bUsed;
}__attribute__((packed));

struct MRT_Packet
{
	unsigned char nEntries;
	struct MRT_Entry	pEntries[MAX_MRT_ENTRIES];

	int GetMRT_PacketLength()
	{
		return nEntries * sizeof(MRT_Entry) + sizeof(unsigned char);
	}
}__attribute__((packed)); // just for debugging purpose

typedef map <AddrMote, MRT_Entry*> MRT;
typedef map <AddrMote, MRT_Entry*> :: iterator MRTiter;

// Mote routing table manager
class CMRT_Manager
{
public:
	CMRT_Manager(void);
	~CMRT_Manager(void);

private:
	static MRT s_MRT;
	static int	s_nTimer;
	static void			Insert(AddrMote moteID, AddrMote nextHopMoteID, AddrMaster masterIP);

public:
	static void			Initialize(void);
	static void			Finalize(void);
	static void			SetUsed(AddrMote moteID, bool bUsed);
	static void			Update(AddrMote moteID, AddrMote nextHopMoteID, AddrMaster masterIP);
	static void			Erase(AddrMote moteID);
	static AddrMaster	LookUpNextHopMaster(AddrMote moteID);
	static AddrMote		LookUpNextHopMote(AddrMote moteID);
	static MRT_Entry*	LookUpEntry(AddrMote moteID);
	static int			Refresh(int nType);
	static void			Show(void);
	static void			Show(MRT_Packet* pPacket);
	static int			MakeMRT_Packet(MRT_Packet* pPacket);
};

#endif
