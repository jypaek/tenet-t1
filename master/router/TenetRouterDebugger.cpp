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
* This class is used for debugging Tenet router running on a Master
*
* Authors: Ki-Young Jang
* Embedded Networks Laboratory, University of Southern California
* Modified: 2/6/2007
*/

#include "TR_Common.h"
#include "TenetRouter.h"
#include "File.h"
#include "Network.h"
#include "TenetRouterDebugger.h"

CTenetRouterDebugger*	CTenetRouterDebugger::s_pTenetRouterDebugger = NULL;

CTenetRouterDebugger::CTenetRouterDebugger(void)
: CUDP_Server(CTenetRouterDebugger::OnReceive, TENET_ROUTER_PORT_FOR_DEBUGGER )
{
	s_pTenetRouterDebugger = this;

	MSG("[ENV] TENET_ROUTER_PORT_FOR_OTHER_ROUTER : %s\n", getenv("TENET_ROUTER_PORT_FOR_OTHER_ROUTER"));
}

CTenetRouterDebugger::~CTenetRouterDebugger(void)
{
}

void CTenetRouterDebugger::OnReceive(struct sockaddr_in* pAddr, char* pData, int nLen)
{
	CTenetRouterDebugger* pRouterDebugger=CTenetRouterDebugger::GetTenetRouterDebugger();

	TR_Packet*	pPacket=(TR_Packet*)pData;

	MSG ("--------------------------------------------------\n");
	MSG (" Message received from %s\n", inet_ntoa( pAddr->sin_addr ) );
	MSG ("--------------------------------------------------\n");

	switch(pPacket->header.type)
	{
	case TR_PACKET_TYPE_CTRL_RES_MRT:
		CMRT_Manager::Show((MRT_Packet*)pPacket->pData);
		break;

	case TR_PACKET_TYPE_CTRL_RES_IPRT:
		CIPRT_Manager::Show((IPRT_Packet*)pPacket->pData);
		break;

	case TR_PACKET_TYPE_CTRL_RES:
		MSG(" %s\n", pPacket->pData);
		break;

	default:
		ERROR("I have got a wrong packet! \n");
	}
	MSG ("--------------------------------------------------\n");

	pRouterDebugger->Terminate();
}

void CTenetRouterDebugger::Process()
{
	this->Receive();
}

void ShowUsage(char* argv) 
{
    MSG("   - Usage: %s <tenet router addr> [options]\n",argv);
    MSG("   - [options] \n");
    MSG("       -h            : print this message\n");
	MSG("       -p <port>     : set the port for tenet router debugger\n");
    MSG("       -rp <tenet router port> : set the tenet router port\n");

	exit(1);
}

void ShowHelp()
{
	MSG("------------------------------------------------------------\n");
    MSG("  h                      : print this message\n");
    MSG("  show(s) packet(p)      : enable/disable to print raw packet \n");  
    MSG("  trace(t) packet(p)     : enable/disable to trace packet \n");  
    MSG("  trace(t) mrt(m)        : enable/disable to trace mrt \n");  
    MSG("  trace(t) iprt(i)       : enable/disable to trace iprt \n");  
	MSG("  mrt(m)                 : show mote routing table\n");
    MSG("  iprt(i)                : show ip routing table\n");
    MSG("  q                      : quit\n");
	MSG("------------------------------------------------------------\n");
}

void ParseArgv(int argc, char **argv)
{
	if( ! getenv("TENET_ROUTER_PORT_FOR_OTHER_ROUTER"))
		setenv("TENET_ROUTER_PORT_FOR_OTHER_ROUTER", _TENET_ROUTER_PORT_FOR_OTHER_ROUTER, 1);

	for( int i=1 ; i < argc ; i++ )
	{
		if( 0 == strcmp( "-p",  argv[i] ))
		{
			setenv("TENET_ROUTER_PORT_FOR_DEBUGGER", argv[++i], 1);
			continue;
		}

		if( 0 == strcmp( "-rp",  argv[i] ))
		{
			setenv("TENET_ROUTER_PORT_FOR_OTHER_ROUTER", argv[++i], 1);
			continue;
		}
	}
}

int main(int argc, char** argv)
{
	TR_Packet	packet;

	packet.header.lMasterIP = GetMyIP();

	//printf("------------------------------------------------------------\n");
	//printf(" Tenet Router Debugger\n");
	//printf("------------------------------------------------------------\n");
	//printf("\n");

	ParseArgv( argc, argv );

	CTenetRouterDebugger* pTR_Debugger = new CTenetRouterDebugger();

	//printf("TR > ");
	//fflush(stdout);

	//GetCommand(packet.pData);

	strcpy(packet.pData, argv[2]);

	if( strcmp ( "q", packet.pData ) != 0 )
	{
		pTR_Debugger->StartServer();

		packet.header.lMasterIP = GetMyIP();
		packet.header.nDataLength = strlen(packet.pData);
		packet.header.type = TR_PACKET_TYPE_CTRL_REQ;

		CUDP_Client::DirectSend( argv[1], 10000, (char*) &packet, packet.GetTotalPacketLength() );

		while ( pTR_Debugger->IsStart() )
		{
			while(pTR_Debugger->IsThereAnyNewPacket())
				pTR_Debugger->Receive();

			usleep(1);
		}
	}
}
