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

#include "IPRT_Manager.h"
#include "File.h"
#include "Network.h"
#include "TR_Common.h"

#define MAX_STRING_SIZE			256

IPRT CIPRT_Manager::s_IPRT;  // IP routing table
int CIPRT_Manager::s_nTimer;

extern struct Debug TR_Debug;

CIPRT_Manager::CIPRT_Manager(void)
{
}

CIPRT_Manager::~CIPRT_Manager(void)
{
}

void CIPRT_Manager::Initialize(void)
{
}

void CIPRT_Manager::Finalize(void)
{
}

AddrMaster CIPRT_Manager::LookUpNextHop(AddrMaster destIP)
{
	IPRTiter iter;

	iter = CIPRT_Manager::s_IPRT.find(destIP);

	if (iter == s_IPRT.end())
		return 0;

	IPRT_Entry* pIPRT_Entry = (IPRT_Entry*) iter->second;
	pIPRT_Entry->bUsed = true;

	return pIPRT_Entry->nextHopIP;
}

IPRT_Entry* CIPRT_Manager::LookUpEntry(AddrMaster destIP)
{
	IPRTiter iter;
	IPRT_Entry* pIPRT_Entry;

	iter = CIPRT_Manager::s_IPRT.find(destIP);

	if (iter == s_IPRT.end())
		return NULL;

	pIPRT_Entry = (IPRT_Entry*) iter->second;
	pIPRT_Entry->bUsed = true;

	return pIPRT_Entry;
}

void CIPRT_Manager::Update(AddrMaster destIP, AddrMaster nextHopIP)
{
	IPRT_Entry* pIPRT_Entry = CIPRT_Manager::LookUpEntry(destIP);

	if(NULL == pIPRT_Entry)
	{
		CIPRT_Manager::Insert(destIP, nextHopIP);
	}
	else
	{
		pIPRT_Entry->nextHopIP = nextHopIP;
		pIPRT_Entry->bUsed = true;
	}
}


void CIPRT_Manager::Insert(AddrMaster destIP, AddrMaster nextHopIP)
{
	typedef pair <AddrMaster, IPRT_Entry*> IPRT_Entry_Pair;

	IPRT_Entry* pIPRT_Entry = new IPRT_Entry;

	pIPRT_Entry->destIP = destIP;
	pIPRT_Entry->nextHopIP = nextHopIP;
	pIPRT_Entry->bUsed = true;

	CONDITIONAL_DEBUG( TR_Debug.bTraceIPRT, "DestIP(%s) : NextHopIP(%s) is added to IPRT \n",
		inet_ntoa((in_addr&)pIPRT_Entry->destIP),
		inet_ntoa((in_addr&)pIPRT_Entry->nextHopIP)
		);

	CIPRT_Manager::s_IPRT.insert(IPRT_Entry_Pair(destIP, pIPRT_Entry));
}

void CIPRT_Manager::Erase(AddrMaster destIP)
{
	IPRTiter iter;

	iter = CIPRT_Manager::s_IPRT.find(destIP);

	if (iter == s_IPRT.end())
		return;

	CONDITIONAL_DEBUG(TR_Debug.bTraceIPRT, "destIP(%d) is deleted from IPRT \n", destIP);

	CIPRT_Manager::s_IPRT.erase(iter);
}

int CIPRT_Manager::Refresh(int nType)
{
	char pStr[MAX_STRING_SIZE];
	char pStrToken[MAX_STRING_SIZE];

	AddrMaster	destIP;
	AddrMaster	gatewayIP;
	AddrMaster	maskIP;

	// This code reads IP routing table and store it as /proc/net/route in LINUX
#ifdef __CYGWIN__
	system("route print > /tmp/route");
#endif
#ifdef __APPLE__
        system("netstat -nr -f inet > /tmp/route");
#endif
	CFile file(ROUTE_FILE);

	IPRTiter iter;
	IPRTiter iterTemp;

	iter = CIPRT_Manager::s_IPRT.begin();

	while( iter != CIPRT_Manager::s_IPRT.end() )
	{
		IPRT_Entry* pIPRT_Entry = (IPRT_Entry*) iter->second;

		iterTemp=iter;
		iter++;

		if ( pIPRT_Entry->bUsed )
		{
			pIPRT_Entry->bUsed = false;
		}
		else
		{
			CIPRT_Manager::s_IPRT.erase(iterTemp);
		}
	}

	if(NULL == file.ReadLine(pStr))
		return 0;

#ifdef __CYGWIN__
	while(NULL != file.ReadLine(pStr))
	{
		if ( 0 == memcmp ( "Network Destination", pStr, 19 ) )
			break;
	}

	while(NULL != file.ReadLine(pStr))
	{
		unsigned char	dest[4];
		unsigned char	gateway[4];
		unsigned char	mask[4];

		if ( 0 == memcmp ( "Default Gateway:", pStr, 16 ) )
			break;

		//          0.0.0.0          0.0.0.0      192.168.1.1   192.168.1.107       25
		sscanf ( pStr, "%d.%d.%d.%d    %d.%d.%d.%d  %d.%d.%d.%d  %s",
			(int*)&dest[0], (int*)&dest[1], (int*)&dest[2], (int*)&dest[3],
			(int*)&mask[0], (int*)&mask[1], (int*)&mask[2], (int*)&mask[3],
			(int*)&gateway[0], (int*)&gateway[1], (int*)&gateway[2], (int*)&gateway[3],
			pStrToken );

		memcpy ( &destIP, dest, sizeof(AddrMaster) );
		memcpy ( &gatewayIP, gateway, sizeof(AddrMaster) );
		memcpy ( &maskIP, mask, sizeof(AddrMaster) );

		if ( IsInTheSameMachine( gatewayIP ) )
			continue;

		if( maskIP == 0xFFFFFFFF )
		{
			CIPRT_Manager::Update(destIP, gatewayIP);
		}
	}
#else
#ifdef __APPLE__
        unsigned char	dest[4];
	unsigned char	gateway[4];
        char pStrTemp[3][256];

        file.ReadLine(pStr);
        file.ReadLine(pStr);
        file.ReadLine(pStr);
        file.ReadLine(pStr);

	while(NULL != file.ReadLine(pStr))
	{

           memset( pStrTemp[0], 0, 256 );
           int n[4];

           n[0] = -1;
           n[1] = -1;
           n[2] = -1;
           n[3] = -1;

           sscanf ( pStr, "%s %s %s", pStrTemp[0], pStrTemp[1], pStrTemp[2] );
           //printf(">>> %s / %s  / %s\n", pStrTemp[0], pStrTemp[1], pStrTemp[2] );

           sscanf( pStrTemp[0], "%d.%d.%d.%d",
			&n[0], &n[1], &n[2], &n[3]);

           for( int i = 0; i < 4 ; i++ )
           {
               if ( n[i] < 0 || n[i] > 255 )
                   goto SKIP;

               dest[i] = (unsigned char) n[i];
           }


           n[0] = -1;
           n[1] = -1;
           n[2] = -1;
           n[3] = -1;
           sscanf( pStrTemp[1], "%d.%d.%d.%d",
			&n[0], &n[1], &n[2], &n[3]);

           for( int i = 0; i < 4 ; i++ )
           {
               if ( n[i] < 0 || n[i] > 255 )
                   goto SKIP;

               gateway[i] = (unsigned char) n[i];
           }
/*   
           printf ( "%d.%d.%d.%d    %d.%d.%d.%d \n",
			dest[0], dest[1], dest[2], dest[3],
			gateway[0], gateway[1], gateway[2], gateway[3] );
*/

  	   memcpy ( &destIP, dest, sizeof(AddrMaster) );
	   memcpy ( &gatewayIP, gateway, sizeof(AddrMaster) );

	   if ( IsInTheSameMachine( gatewayIP ) )
		continue;

  	   CIPRT_Manager::Update(destIP, gatewayIP);

SKIP:
            continue;
        }
#else
	while(NULL != file.ReadLine(pStr))
	{
		// /proc/net/route file format example
		// Iface   Destination     Gateway         Flags   RefCnt  Use     Metric  Mask            MTU     Window  IRTT                                                       
		// eth1    0000000A        00000000        0001    0       0       0       00FFFFFF        40      0       0                                                                              

		// Iface
		CFile::GetToken(pStr, pStrToken, '\t');

		// Destination
		CFile::GetToken(pStr, pStrToken, '\t');
		sscanf(pStrToken, "%x", (unsigned int*)&destIP);

		// Gateway
		CFile::GetToken(pStr, pStrToken, '\t');
		sscanf(pStrToken, "%x", (unsigned int*)&gatewayIP);

		if ( IsInTheSameMachine( gatewayIP ) )
			continue;

		CFile::GetToken(pStr, pStrToken, '\t');		//Flags
		CFile::GetToken(pStr, pStrToken, '\t');		//RefCnt
		CFile::GetToken(pStr, pStrToken, '\t');		//Use
		CFile::GetToken(pStr, pStrToken, '\t');		//Metric
		CFile::GetToken(pStr, pStrToken, '\t');		//Mask
		sscanf(pStrToken, "%x", (unsigned int*)&maskIP);

		if( maskIP == 0xFFFFFFFF )
		{
			CIPRT_Manager::Update(destIP, gatewayIP);
		}
	}
#endif
#endif
	return 0;
}

void CIPRT_Manager::Show(void)
{
	IPRTiter iter;
	IPRT_Entry*	pEntry;
	struct in_addr in;
	in.s_addr = GetMyIP();

	MSG ("--------------------------------------------------\n");
	MSG (" I am %s\n", inet_ntoa( in ) );
	MSG ("--------------------------------------------------\n");
	MSG ("            Dest          NextHop\n");
	MSG ("--------------------------------------------------\n");

	if( CIPRT_Manager::s_IPRT.size() !=  0 )
	{
		iter = CIPRT_Manager::s_IPRT.begin();

		while(iter != CIPRT_Manager::s_IPRT.end())
		{
			pEntry = (IPRT_Entry*) iter->second;

			MSG(" %16s",
				inet_ntoa((in_addr&)pEntry->destIP)
				);

			MSG(" %16s \n",
				inet_ntoa((in_addr&)pEntry->nextHopIP)
				);

			iter++;
		}

	}

	MSG ("--------------------------------------------------\n");
	MSG (" %d entries in IPRT \n", CIPRT_Manager::s_IPRT.size() );
	MSG ("--------------------------------------------------\n");

}

void CIPRT_Manager::Show(IPRT_Packet* pPacket)
{
	IPRT_Entry*	pEntry;

	MSG ("            Dest          NextHop\n");
	MSG ("--------------------------------------------------\n");

	for( int i = 0 ; i < pPacket->nEntries ; i++ )
	{
		pEntry = &pPacket->pEntries[i];

		MSG(" %16s",
			inet_ntoa((in_addr&)pEntry->destIP)
			);

		MSG(" %16s \n",
			inet_ntoa((in_addr&)pEntry->nextHopIP)
			);
	}

	MSG ("--------------------------------------------------\n");
	MSG (" %d entries in IPRT \n", pPacket->nEntries );
	MSG ("--------------------------------------------------\n");

}

// just for debugging purpose
int CIPRT_Manager::MakeIPRT_Packet(IPRT_Packet* pPacket)
{
	IPRTiter iter;

	pPacket->nEntries = 0;

	if( CIPRT_Manager::s_IPRT.size() !=  0 )
	{
		iter = CIPRT_Manager::s_IPRT.begin();

		while(iter != CIPRT_Manager::s_IPRT.end())
		{
			memcpy( &pPacket->pEntries[ pPacket->nEntries++ ], ((IPRT_Entry*) iter->second), sizeof(IPRT_Entry)); 
			iter++;
		}
	}

	return pPacket->GetIPRT_PacketLength();
}
