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

#include "MRT_Manager.h"
#include "IPRT_Manager.h"
#include "Network.h"
#include "TR_Common.h"
#include "TenetRouter.h"

MRT CMRT_Manager::s_MRT;  // Mote routing table
int CMRT_Manager::s_nTimer;

extern struct Debug TR_Debug;

CMRT_Manager::CMRT_Manager(void)
{
}

CMRT_Manager::~CMRT_Manager(void)
{
}

void CMRT_Manager::Initialize(void)
{
}

void CMRT_Manager::Finalize(void)
{
}

// this info is used for Refresh()
void CMRT_Manager::SetUsed(AddrMote moteID, bool bUsed)
{
	MRT_Entry* pMRT_Entry = CMRT_Manager::LookUpEntry(moteID);

	if(pMRT_Entry)
		pMRT_Entry->bUsed = bUsed;
}

AddrMaster CMRT_Manager::LookUpNextHopMaster(AddrMote moteID)
{
	MRTiter iter;
	iter = CMRT_Manager::s_MRT.find(moteID);

	if (iter == s_MRT.end())
		return 0;

	MRT_Entry* pMRT_Entry = (MRT_Entry*) iter->second;
	uint32_t addrNextHopMaster = CIPRT_Manager::LookUpNextHop(pMRT_Entry->masterIP);

	if ( GetMyIP() == pMRT_Entry->masterIP || !addrNextHopMaster )
		return pMRT_Entry->masterIP;
	else
		return addrNextHopMaster;
}

AddrMote CMRT_Manager::LookUpNextHopMote(AddrMote moteID)
{
	MRTiter iter;

	iter = CMRT_Manager::s_MRT.find(moteID);

	if (iter == s_MRT.end())
		return 0;

	MRT_Entry* pMRT_Entry = (MRT_Entry*) iter->second;

	if ( GetMyIP() == pMRT_Entry->masterIP )
		return pMRT_Entry->nextMoteID;
	else
		return CIPRT_Manager::LookUpNextHop(pMRT_Entry->masterIP);
}

MRT_Entry* CMRT_Manager::LookUpEntry(AddrMote moteID)
{
	MRTiter iter;

	iter = CMRT_Manager::s_MRT.find(moteID);

	if (iter == s_MRT.end())
		return NULL;

	MRT_Entry* pMRT_Entry = (MRT_Entry*) iter->second;

	return pMRT_Entry;
}

void CMRT_Manager::Update(AddrMote moteID, AddrMote nextHopMoteID, AddrMaster masterIP)
{
	MRT_Entry* pMRT_Entry = CMRT_Manager::LookUpEntry(moteID);

	if(NULL == pMRT_Entry)
	{
		CMRT_Manager::Insert(moteID, nextHopMoteID, masterIP);
	}
	else
	{
		if( nextHopMoteID )
		{
			pMRT_Entry->masterIP = masterIP;
			pMRT_Entry->nextMoteID = nextHopMoteID;
		}

		pMRT_Entry->bUsed = true;
	}
}


void CMRT_Manager::Insert(AddrMote moteID, AddrMote nextHopMoteID, AddrMaster masterIP)
{
/*
	if( moteID == 
		( ( 0xFF000000 & GetMyIP() ) >> 24 | 
		( 0x00FF0000 & GetMyIP() ) >> 8 )
		)
		return;
*/
    if( moteID == CTenetRouter::GetTenetLocalAddr() )
        return;

	typedef pair <AddrMote, MRT_Entry*> MRT_Entry_Pair;

	MRT_Entry* pMRT_Entry = new MRT_Entry;

	pMRT_Entry->moteID = moteID;
	pMRT_Entry->masterIP = masterIP;
	pMRT_Entry->nextMoteID = nextHopMoteID;
	pMRT_Entry->bUsed = true;

	CMRT_Manager::s_MRT.insert(MRT_Entry_Pair(moteID, pMRT_Entry));

	CONDITIONAL_DEBUG( TR_Debug.bTraceMRT, "CMRT_Manager::Insert()// MoteID(%d) masterIP(%s) is added to MRT \n", 
		pMRT_Entry->moteID,
		inet_ntoa((in_addr&)pMRT_Entry->masterIP)
		);
}

void CMRT_Manager::Erase(AddrMote moteID)
{
	MRTiter iter;

	iter = CMRT_Manager::s_MRT.find(moteID);

	if (iter == s_MRT.end())
		return;

	CONDITIONAL_DEBUG( TR_Debug.bTraceMRT, "CMRT_Manager::Erase()// MoteID(%d) is deleted from MRT \n", moteID);

	CMRT_Manager::s_MRT.erase(iter);
}

int CMRT_Manager::Refresh(int nType)
{
	MRTiter iter;
	MRTiter iterTemp;

	iter = CMRT_Manager::s_MRT.begin();

	while( iter != CMRT_Manager::s_MRT.end() )
	{
		MRT_Entry* pMRT_Entry = (MRT_Entry*) iter->second;

		iterTemp=iter;
		iter++;

		if ( pMRT_Entry->bUsed )
		{
			pMRT_Entry->bUsed = false;

			if( CIPRT_Manager::LookUpNextHop(
					( 0xFF00 & pMRT_Entry->moteID ) << 8
					| ( 0x00FF & pMRT_Entry->moteID ) << 24
					| ( 0x0000FF00 & GetMyIP() )
					| ( 0x000000FF & GetMyIP() )
					)
					!= 0 )
			{
				pMRT_Entry->bUsed = true;
			}

		}
		else
		{
			CMRT_Manager::s_MRT.erase(iterTemp);
		}
	}

	return 0;
}

void CMRT_Manager::Show(void)
{
	MRTiter iter;
	MRT_Entry*	pEntry;
	struct in_addr in;
	in.s_addr = GetMyIP();

	MSG ("--------------------------------------------------\n");
	MSG (" I am %s\n", inet_ntoa( in ) );
	MSG ("--------------------------------------------------\n");
	MSG (" Mote ID               NextHopMoteID masterIP Used             \n");
	MSG ("--------------------------------------------------\n");

	if( CMRT_Manager::s_MRT.size() !=  0 )
	{
		iter = CMRT_Manager::s_MRT.begin();

		while(iter != CMRT_Manager::s_MRT.end())
		{
			pEntry = (MRT_Entry*) iter->second;

			MSG(" %4d(%3d.%3d) %14d %16s %s\n", 
				pEntry->moteID,
				((0xFF00) & pEntry->moteID) >> 8,
				((0x00FF) & pEntry->moteID),
				pEntry->nextMoteID,
				inet_ntoa((in_addr&)pEntry->masterIP),
				pEntry->bUsed == true ? "TRUE" : "FALSE");

			iter++;
		}
	}
	MSG ("--------------------------------------------------\n");
	MSG (" %d entries in MRT \n", CMRT_Manager::s_MRT.size() );
	MSG ("--------------------------------------------------\n");
}

void CMRT_Manager::Show(MRT_Packet* pPacket)
{
	MRT_Entry*	pEntry;

	MSG (" Mote ID               NextHopMoteID masterIP Used             \n");
	MSG ("--------------------------------------------------\n");

	for( int i = 0 ; i < pPacket->nEntries ; i++ )
	{
		pEntry = &pPacket->pEntries[i];

		MSG(" %4d(%3d.%3d) %14d %16s %s\n", 
			pEntry->moteID,
			((0xFF00) & pEntry->moteID) >> 8,
			((0x00FF) & pEntry->moteID),
			pEntry->nextMoteID,
			inet_ntoa((in_addr&)pEntry->masterIP),
			pEntry->bUsed == true ? "TRUE" : "FALSE");
	}

	MSG ("--------------------------------------------------\n");
	MSG (" %d entries in MRT \n", pPacket->nEntries );
	MSG ("--------------------------------------------------\n");
}

int CMRT_Manager::MakeMRT_Packet(MRT_Packet* pPacket)
{
	MRTiter iter;

	pPacket->nEntries = 0;

	if( CMRT_Manager::s_MRT.size() !=  0 )
	{
		iter = CMRT_Manager::s_MRT.begin();

		while(iter != CMRT_Manager::s_MRT.end())
		{
			memcpy( &pPacket->pEntries[ pPacket->nEntries++ ], ((MRT_Entry*) iter->second), sizeof(MRT_Entry)); 
			iter++;
		}
	}

	return pPacket->GetMRT_PacketLength();
}
