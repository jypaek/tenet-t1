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
*
* Authors: Ki-Young Jang
* Embedded Networks Laboratory, University of Southern California
* Modified: 2/6/2007
*/

#include <stdio.h>
#include <stdlib.h>
#include <signal.h>
#include <limits.h>

#include "TR_Common.h"
#include "TenetRouter.h"
#include "File.h"
#include "Network.h"

extern struct Debug TR_Debug;

extern struct Arg TR_Arg;

CTenetRouter* g_pTR;  // Tenet Router instance

bool	g_bInteractive = false;

void ShowUsage(char* argv) 
{
	MSG("   - Usage: %s [options]\n",argv);
	MSG("   - [options] \n");
	MSG("       -h            : print this message\n");
	MSG("       -s            : standalone mode (without BaseStation)\n");
	MSG("       -a            : set local address (16bit)\n");
	MSG("       -i            : Interactive Mode\n");
	MSG("       -l [Path]     : specify log path\n");
	MSG("       -n [Inf]      : name of network interface\n");
	
	GetAddress("", ALL_INFO);

	MSG("       -tp <port>    : set the port for transport\n");
	MSG("       -rp <port>    : set the port for other routers\n");
	MSG("       -sp <sf port> : set the serial forwarder port\n");
	MSG("       -sh <sf host> : set the serial forwarder host\n");

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

// just for debugging
void EnableInteractiveMode(int n)
{
	if( ! TR_Arg.bInteractive )
	{
		ShowHelp();
	}

	TR_Arg.bInteractive = true;
}

void ParseArgv(int argc, char **argv)
{
	char pStr[MAX_STRING_SIZE];

	if( ! getenv("TENET_ROUTER_PORT_FOR_TRANSPORT"))
		setenv("TENET_ROUTER_PORT_FOR_TRANSPORT", _TENET_ROUTER_PORT_FOR_TRANSPORT, 1);

	if( ! getenv("TENET_ROUTER_PORT_FOR_OTHER_ROUTER"))
		setenv("TENET_ROUTER_PORT_FOR_OTHER_ROUTER", _TENET_ROUTER_PORT_FOR_OTHER_ROUTER, 1);

	if( ! getenv("TENET_SF_HOST"))
		setenv("TENET_SF_HOST", _TENET_SF_HOST, 1);

	if( ! getenv("TENET_SF_PORT"))
		setenv("TENET_SF_PORT", _TENET_SF_PORT, 1);

	if( ! getenv("TENET_ROUTER_INTERFACE"))
	{
		if ( !GetDefaultNetworkInterface( pStr ) )
			TR_ERROR ( "No network interface found\n" );

		setenv("TENET_ROUTER_INTERFACE", pStr, 1);
	}

	setenv("TENET_ROUTER_STANDALONE_MODE", "FALSE", 1);

	for( int i=1 ; i < argc ; i++ )
	{
		if( 0 == strcmp( "-a",  argv[i] ))
		{
			setenv("TENET_LOCAL_ADDRESS", argv[++i], 1);
			continue;
		}

		if( 0 == strcmp( "-s",  argv[i] ))
		{
			setenv("TENET_ROUTER_STANDALONE_MODE", "TRUE", 1);
			continue;
		}

		if( 0 == strcmp( "-i",  argv[i] ))
		{
			TR_Debug.bInteractive = true;
			continue;
		}

		if( 0 == strcmp( "-l",  argv[i] ))
		{
			struct tm *t;
			char	pStrLog[MAX_STRING_SIZE];
			time_t  timeCur = time(NULL);
			t =localtime(&timeCur);

			sprintf( pStrLog, "%s/%d-%d-%d-%d-%d",
					argv[++i],
					t->tm_mon+1,
					t->tm_mday,
					t->tm_hour,
					t->tm_min,
					t->tm_sec);

			TR_Arg.pLogFile = new CFile( pStrLog, false );
			continue;
		}

		if( 0 == strcmp( "-tp",  argv[i] ))
		{
			setenv("TENET_ROUTER_PORT_FOR_TRANSPORT", argv[++i], 1);
			continue;
		}

		if( 0 == strcmp( "-rp",  argv[i] ))
		{
			setenv("TENET_ROUTER_PORT_FOR_OTHER_ROUTER", argv[++i], 1);
			continue;
		}

                if( 0 == strcmp( "-n",  argv[i] ))
                {
                        setenv("TENET_ROUTER_INTERFACE", argv[++i], 1);
                        continue;
                }

		if( 0 == strcmp( "-sh",  argv[i] ))
		{
			setenv("TENET_SF_HOST", argv[++i], 1);
			continue;
		}

		if( 0 == strcmp( "-sp",  argv[i] ))
		{
			setenv("TENET_SF_PORT", argv[++i], 1);
			continue;
		}

		ShowUsage(argv[0]);
	}
	

	if ( 0 == GetMyIP() )
	{
		TR_ERROR("Please specify network interface\n");
		ShowUsage( argv[0] );
	}

	sprintf( pStr, "%d", (unsigned int)( ( 0xFF000000 & GetMyIP() ) >> 24 | ( 0x00FF0000 & GetMyIP() ) >> 8 ) );

        if( ! getenv("TENET_LOCAL_ADDRESS"))
                setenv("TENET_LOCAL_ADDRESS", pStr, 1);

	struct in_addr in;
	in.s_addr = GetMyBroadcastAddr();

	setenv("TENET_BROADCAST_ADDRESS", inet_ntoa( in ), 1);
}

void EndTR(int n)
{
	g_pTR->Terminate();

	CMRT_Manager::Finalize();
	CIPRT_Manager::Finalize();

	usleep(1000000);

	delete g_pTR;

	exit(0);
}


int main(int argc, char** argv)
{
	TR_Packet	packet;
	int		pid = 0;

	TR_Debug.bInteractive = false;
	TR_Debug.bShowPacket = true;
	TR_Debug.bTracePacket = true;
	TR_Debug.bTraceMRT = false;
	TR_Debug.bTraceIPRT = false;

	TR_Arg.bInteractive = false;
	TR_Arg.pLogFile = NULL;

	//packet.header.lMasterIP = GetMyIP();

	MSG("------------------------------------------------------------\n");
	MSG(" Tenet Router\n");
	MSG("------------------------------------------------------------\n");

	ParseArgv( argc, argv );

	packet.header.lMasterIP = GetMyIP();

	if( TR_Debug.bInteractive )
	{
		MSG("Press 'Ctrl + C' for the command prompt. \n");

		if( signal(SIGINT, EnableInteractiveMode) == SIG_ERR) 
		{ 
			TR_ERROR("singal() error\n");
			exit(0);
		}
	}

	MSG("\n");

	CMRT_Manager::Initialize();
	CIPRT_Manager::Initialize();
	CIPRT_Manager::Refresh(0);

	g_pTR = new CTenetRouter();
	g_pTR->StartServer();


        if( ! TR_Debug.bInteractive )
	{
                pid = fork();

                if ( pid )
		{
                        char pStr[256];
			char pOut[256];
                        realpath( argv[0], pStr );
			sprintf( pOut, "echo %d > $(dirname %s)/router.pid", pid, pStr );
                        system( pOut );

			exit(0);
		}

                if( signal(SIGTERM, EndTR) == SIG_ERR)
                {
                        TR_ERROR("singal() error\n");
                        exit(0);
                }

                if( signal(SIGINT, EndTR) == SIG_ERR)
                {
                        TR_ERROR("singal() error\n");
                        exit(0);
                }
	}

	while ( true )
	{
		//if( TR_Arg.bInteractive )	
		//{
		//	MSG("TR > ");
		//	fflush(stdout);

		//	GetCommand(packet.pData);

		//	if( strcmp ( "q", packet.pData ) == 0 )
		//		break;

		//	if( ! CTenetRouter::ParseTR_Command(&packet) )
		//		TR_Arg.bInteractive = false;
		//}

		CNetwork::CheckAllSocket();
        g_pTR->Timer();
	}

	EndTR(0);
}
