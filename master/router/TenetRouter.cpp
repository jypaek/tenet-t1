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

#include "TenetTransport.h"
#include "TenetRouter.h"
#include "TenetSFClient.h"
#include "File.h"
#include "TR_Common.h"

#include "routinglayer.h"
#include "trd.h"

CTenetRouter*    CTenetRouter::s_pTenetRouter = NULL;
AddrMote        CTenetRouter::s_nTenetLocalAddr = 0;

//pthread_mutex_t CTenetRouter::s_lockDispatchPacket;

struct Debug TR_Debug;

extern struct Arg TR_Arg;

CTenetRouter::CTenetRouter(void)
    : CUDP_Server(CTenetRouter::OnReceive, atoi(getenv("TENET_ROUTER_PORT_FOR_OTHER_ROUTER")))
{
    s_pTenetRouter = this;
    s_nTenetLocalAddr = atoi(getenv("TENET_LOCAL_ADDRESS"));

    MSG("[ENV] TENET_ROUTER_INTERFACE : %s\n", getenv("TENET_ROUTER_INTERFACE"));
    MSG("[ENV] TENET_ROUTER_PORT_FOR_OTHER_ROUTER : %s\n", getenv("TENET_ROUTER_PORT_FOR_OTHER_ROUTER"));
    MSG("[ENV] TENET_LOCAL_ADDRESS : %s\n", getenv("TENET_LOCAL_ADDRESS"));

    if( 0 == strcmp ( getenv("TENET_ROUTER_STANDALONE_MODE"), "FALSE" ))
    {
        m_pSF = new CTenetSFClient();
    }
    else
    {
        m_pSF = NULL;
    }

    m_pTransport = new CTenetTransportInterface();
}

CTenetRouter::~CTenetRouter(void)
{
    if(m_pSF)
        delete m_pSF;

    if(m_pTransport)
    {
        m_pTransport->Terminate();
        //delete m_pTransport;
    }
}

// just for debugging
int CTenetRouter::Beacon(int nType)
{
    struct TR_Packet packet;

    packet.header.type = TR_PACKET_TYPE_BEACON;

#ifdef BEACON_WITH_MRT
    packet.header.nDataLength = CMRT_Manager::MakeMRT_Packet(packet.pData);
#else
    memcpy(packet.pData,"Beacon!!",8);
    packet.header.nDataLength=8; 
#endif
    return 0;
}

AddrMote CTenetRouter::GetSrcMoteID(TOS_Msg* pMsg)
{
    switch( pMsg->type )
    {
        case AM_TENET_ROUTING :
            return ( (RoutingHdr*) pMsg->data )->srcAddr;

        case AM_TRD_MSG:
            return ( (TRD_Msg*) pMsg->data )->sender;

        case AM_TRD_CONTROL:
            return ( (TRD_ControlMsg*) pMsg->data )->sender;
        
    }

    return 0;
}

AddrMote CTenetRouter::GetDstMoteID(TOS_Msg* pMsg)
{
    switch( pMsg->type )
    {
        case AM_TENET_ROUTING :
            return ( (RoutingHdr*) pMsg->data )->dstAddr;
    }

    return pMsg->addr;
}

AddrMote CTenetRouter::GetNextHopMoteID(TOS_Msg* pMsg)
{
    switch( pMsg->type )
    {
        case AM_TENET_ROUTING :
            return ( (RoutingHdr*) pMsg->data )->prevhop;

        case AM_TRD_MSG:
            return ( (TRD_Msg*) pMsg->data )->sender;

        case AM_TRD_CONTROL:
            return ( (TRD_ControlMsg*) pMsg->data )->sender;
    }

    return 0;
}

AddrMote CTenetRouter::IPtoMoteID(AddrMaster masterID)
{
    AddrMote addrMote = 0;

    return addrMote;
}

AddrMaster    CTenetRouter::MoteIDtoIP(AddrMote moteID)
{
    AddrMaster addrMaster = 
        ( 0xFF00 & moteID ) << 8
        | ( 0x00FF & moteID ) << 24
        | ( 0x0000FF00 & CTenetRouter::s_nMyIP )
        | ( 0x000000FF & CTenetRouter::s_nMyIP );

    return addrMaster;
}

bool CTenetRouter::StartServer(void)
{
    ((CUDP_Server*)this)->StartServer();

    this->m_pTransport->StartServer();

    if(this->m_pSF)
        this->m_pSF->Connect();

    return true;
}

void CTenetRouter::Send(char *pAddr, TOS_Msg* pMsg, unsigned long lMasterIP, bool bBroadcast)
{
    struct TR_Packet packet;

    packet.header.type = TR_PACKET_TYPE_TOSMSG;
    packet.header.lMasterIP = lMasterIP;
    packet.header.nDataLength = pMsg->length + offsetof(TOS_Msg, data);
    memcpy(packet.pData, pMsg, packet.header.nDataLength );

    ((CUDP_Server*) this)->Send(pAddr, (char*)&packet, packet.GetTotalPacketLength(), bBroadcast);
}

void CTenetRouter::OnReceive(struct sockaddr_in* pAddr, char* pData, int nLen)
{
    CTenetRouter* pRouter=CTenetRouter::GetTenetRouter();

    TR_Packet*    pPacket=(TR_Packet*)pData;
    TOS_Msg* pMsg  = (TOS_Msg*) pPacket->pData;

    if( (unsigned long) pAddr->sin_addr.s_addr == CTenetRouter::s_nMyIP)
        return;

    switch(pPacket->header.type)
    {
        case TR_PACKET_TYPE_BEACON:
            //CMRT_Manager::Update( 
            //    (((uint32_t&) pAddr->sin_addr) & 0xFF000000) >> 24 | (((uint32_t&) pAddr->sin_addr) & 0x00FF0000) >> 16,  
            //    (uint32_t&) pAddr->sin_addr);

            //CIPRT_Manager::Update( (uint32_t&) pAddr->sin_addr, (uint32_t&) pAddr->sin_addr);

            break;

        case TR_PACKET_TYPE_CTRL_REQ:
            MSG("Remote Command : %s \n", pPacket->pData);
            CTenetRouter::ParseTR_Command( pPacket, false );
            break;

        case TR_PACKET_TYPE_TOSMSG:
            // Update MRT
            if( 0 != pRouter->GetSrcMoteID(pMsg) )
            {
                if( pRouter->GetDstMoteID(pMsg) != 0xFFFF )
                {
                    CMRT_Manager::Update(
                            CTenetRouter::GetSrcMoteID(pMsg),
                            CTenetRouter::GetSrcMoteID(pMsg),
                            (uint32_t &) pPacket->header.lMasterIP
                            );
                }
                else
                {
                    CMRT_Manager::Update(
                            CTenetRouter::GetSrcMoteID(pMsg),
                            CTenetRouter::GetSrcMoteID(pMsg),
                            CTenetRouter::MoteIDtoIP( CTenetRouter::GetSrcMoteID(pMsg) )
                            );
                }
            }

            if( 0 == CIPRT_Manager::LookUpNextHop((uint32_t&) pAddr->sin_addr) )
            {
                CIPRT_Manager::Update( (uint32_t&) pAddr->sin_addr, (uint32_t&) pAddr->sin_addr);
            }

            CTenetRouter::DispatchPacket(pMsg, PACKET_FROM_MY_NEIGHBOR, pPacket->header.lMasterIP, (uint32_t&) pAddr->sin_addr);
            break;

        case TR_PACKET_TYPE_ACK:
            break;
    }
}

void CTenetRouter::Unicast(TOS_Msg* pMsg, unsigned long lMasterIP)
{
    CTenetRouter* pRouter = CTenetRouter::GetTenetRouter();
    AddrMote addr = CTenetRouter::GetDstMoteID(pMsg);
    uint32_t  nNextHopIP = CMRT_Manager::LookUpNextHopMaster(addr);

    if( nNextHopIP ) // I know the Destination
    {
        if( nNextHopIP == pRouter->s_nMyIP)
        {
            CONDITIONAL_DEBUG( 
                    TR_Debug.bTracePacket, 
                    " [ %8s  (%5d)] -> through(%5d)","Child", 
                    addr, 
                    CMRT_Manager::LookUpNextHopMote(addr));

            // the destination is one of my children
            if( pRouter->m_pSF )
            {
                pMsg->addr = CMRT_Manager::LookUpNextHopMote(addr);

                if( pMsg->type == AM_TENET_ROUTING )
                    ( (RoutingHdr*) pMsg->data )->prevhop = s_nTenetLocalAddr;

                pRouter->m_pSF->Send(pMsg);
            }
        }
        else
        {
            CONDITIONAL_DEBUG( TR_Debug.bTracePacket, " [ %16s (%16s) ] -> %5d","Known Neighbor", inet_ntoa((in_addr&)nNextHopIP), addr);
            // the destination can be reached by forwarding the packet to one of my neighbors
            pRouter->Send(inet_ntoa((in_addr&)nNextHopIP), pMsg, lMasterIP);
        }
    }
    else // I don't know the Destination (No matching entry on MRT)
    {
        // If MyIP is loopback, ignore
        if( ( (int)(CTenetRouter::s_nMyIP & 0x000000FF) == 0x7F )
            && ( (int)(CTenetRouter::s_nMyIP & 0x0000FF00) >> 8 ) == 0x00 )
            return;

        /*

        // TRD control packet from Transport ==================================================
        // pMsg->type == AM_TRD_CONTROL && unicast

        if ( nFrom == PACKET_FROM_MY_TRANSPORT && AM_TRD_CONTROL == pMsg->type )
        {
        CONDITIONAL_DEBUG( 
        (addr != 0xFFED) && TR_Debug.bTracePacket, 
        " [ %16s (%16s) ] -> %5d","Unknown Child", "TRD Control", addr);
        pRouter->m_pSF->Send(pMsg);                
        }
        else
         */

        {
            // So, send it IP
            char pAddr[MAX_STRING_SIZE];

            sprintf( pAddr, "%d.%d.%d.%d", 
                    (int)(CTenetRouter::s_nMyIP & 0x000000FF),
                    (int)(CTenetRouter::s_nMyIP & 0x0000FF00) >> 8,
                    (int)(addr & 0xFF00) >> 8,
                    (int)(addr & 0x00FF)
                   );

            CONDITIONAL_DEBUG( 
                    (addr != 0xFFED) && TR_Debug.bTracePacket, 
                    " [ %16s (%16s) ] -> %5d","Unknown Neighbor", pAddr, addr);
            CONDITIONAL_DEBUG( 
                    (addr == 0xFFED) && TR_Debug.bTracePacket, 
                    " [Routing beacon]");

            if( addr != 0xFFED )
            {
                // Foward the packet directly to a possible master
                pRouter->Send(pAddr, pMsg, lMasterIP);
            }
        }
    }
}

void CTenetRouter::DispatchPacket(TOS_Msg* pMsg, unsigned int nFrom, unsigned long lMasterIP, unsigned long nFromNeighborIP)
{
    CTenetTransportInterface* pTenetTransport = CTenetTransportInterface::GetTenetTransport();
    CTenetRouter* pRouter = CTenetRouter::GetTenetRouter();
    AddrMote addr = CTenetRouter::GetDstMoteID(pMsg);

    // the packet was sent by me
    if ( PACKET_FROM_MY_NEIGHBOR == nFrom
            && nFromNeighborIP == GetMyIP() )
        return;


    switch( pMsg->type )
    {
        case AM_TENET_ROUTING:
            switch(nFrom)
            {
                case PACKET_FROM_MY_MOTE:
                case PACKET_FROM_MY_NEIGHBOR:
                    // TTL expired.&& TCMP
                    if( 0 == ( ( (RoutingHdr*) pMsg->data )->ttl-- ) )
                    {
                        if ( ( ( (RoutingHdr*) pMsg->data )->protocol & PROTOCOL_MASK) == PROTOCOL_TCMP )
                        {
                            // To Transport
                            pTenetTransport->SendToAll(pMsg);
                            MSG("TCMP && (TTL=0)\n");
                            CTenetSFClient::ShowPacket( (char*)pMsg, pMsg->length + offsetof(TOS_Msg, data) );
                        }
                        else
                        {
                            MSG("Packet dropped. (TTL=0)\n");
                            CTenetSFClient::ShowPacket( (char*)pMsg, pMsg->length + offsetof(TOS_Msg, data) );
                        }

                        return;
                    } else if ( ( (RoutingHdr*) pMsg->data )->srcAddr == s_nTenetLocalAddr ) {
                        MSG("Packet dropped. (Loop, SRC=LocalAddr)\n");
                        CTenetSFClient::ShowPacket( (char*)pMsg, pMsg->length + offsetof(TOS_Msg, data) );

                        return;
                    }
                    break;
            }

            break;

            // Add some other AM types to here        
    }

    CMRT_Manager::SetUsed(GetSrcMoteID(pMsg), true);

#ifdef DEBUG_MODE
    if(TR_Debug.bTracePacket)
    {
        DEBUG(" %5d ->", GetSrcMoteID(pMsg));

        switch(nFrom)
        {
            case PACKET_FROM_MY_MOTE:
                DEBUG(" [ %16s ] ->","Mote");
                break;
            case PACKET_FROM_MY_NEIGHBOR:
                DEBUG(" [ %8s (%5d) ] ->", 
                        "Neighbor", 
                        (int)( ( 0xFF000000 & nFromNeighborIP ) >> 24 | ( 0x00FF0000 & nFromNeighborIP ) >> 8 ));
                break;
            case PACKET_FROM_MY_TRANSPORT:
                DEBUG(" [ %16s ] ->","Transport");
                break;
        }
    }
#endif

    if ( 0xFFFF != addr )
    {
        switch(nFrom)
        {
            case PACKET_FROM_MY_MOTE:

                // Update MRT
                if( 0 != CTenetRouter::GetSrcMoteID(pMsg) )
                {
                    CMRT_Manager::Update(
                            CTenetRouter::GetSrcMoteID(pMsg),    // Sender MoteID 
                            CTenetRouter::GetNextHopMoteID(pMsg),
                            CTenetRouter::s_nMyIP                // I'm the master of this mote
                            );    
                }

                if( addr == s_nTenetLocalAddr || addr == RT_ANY_MASTER_ADDR || addr == TOS_UART_ADDR )
                {
                    CONDITIONAL_DEBUG( TR_Debug.bTracePacket, " [ %16s ] ","Transport");

                    // To Transport
                    pTenetTransport->SendToAll(pMsg);
                }
                else
                {
                    CTenetRouter::Unicast(pMsg, lMasterIP);
                }

                break;

            case PACKET_FROM_MY_NEIGHBOR:

                if( addr == s_nTenetLocalAddr || addr == RT_ANY_MASTER_ADDR )
                {
                    CONDITIONAL_DEBUG( TR_Debug.bTracePacket, " [ %16s ] ","Transport");

                    // To Transport
                    pTenetTransport->SendToAll(pMsg);
                }
                else
                {
                    CTenetRouter::Unicast(pMsg, lMasterIP);
                }
                break;

            case PACKET_FROM_MY_TRANSPORT:
                if( addr == s_nTenetLocalAddr || addr == RT_ANY_MASTER_ADDR )
                {
                    CONDITIONAL_DEBUG(TR_Debug.bTracePacket, " [ %16s ] ","Mote");
                    // To Mote
                    // the destination is one of my children
                    if(pRouter->m_pSF)
                    {
                        if( pMsg->type == AM_TENET_ROUTING )
                            ( (RoutingHdr*) pMsg->data )->prevhop = s_nTenetLocalAddr;

                        pRouter->m_pSF->Send(pMsg);
                    }
                }
                else
                {
                    CTenetRouter::Unicast(pMsg,lMasterIP);

                }
                break;
        }
    }
    else
    {
        switch(nFrom)
        {
            case PACKET_FROM_MY_MOTE:
            case PACKET_FROM_MY_NEIGHBOR:
                CONDITIONAL_DEBUG( TR_Debug.bTracePacket, " [ %16s ]","Transport(bcast)");

                // To Transport
                pTenetTransport->SendToAll(pMsg);

                break;
            case PACKET_FROM_MY_TRANSPORT:
                {
                    CONDITIONAL_DEBUG( TR_Debug.bTracePacket, " [ %16s ] &","Mote(bcast)");
                    CONDITIONAL_DEBUG( TR_Debug.bTracePacket, " [ %16s ]","Neighbor(bcast)");

                    // To Mote
                    // the destination is one of my children
                    if(pRouter->m_pSF)
                    {
                        if( pMsg->type == AM_TENET_ROUTING )
                            ( (RoutingHdr*) pMsg->data )->prevhop = s_nTenetLocalAddr;

                        pRouter->m_pSF->Send(pMsg);
                    }

                    // If MyIP is loopback, ignore
                    if( ( (int)(CTenetRouter::s_nMyIP & 0x000000FF) == 0x7F )
                            && ( (int)(CTenetRouter::s_nMyIP & 0x0000FF00) >> 8 ) == 0x00 )
                    {
                        break;
                    }
                    else
                    {
                        pRouter->Send( getenv("TENET_BROADCAST_ADDRESS"), pMsg, lMasterIP, true);
                    }
                }
                break;
        }
    }

    {
        CONDITIONAL_DEBUG( TR_Debug.bTracePacket, "\n");

        if( TR_Debug.bShowPacket )
            CTenetSFClient::ShowPacket( (char*)pMsg, pMsg->length + offsetof(TOS_Msg, data) );

        if ( TR_Arg.pLogFile )
        {
            char pStr[MAX_STRING_SIZE];

            sprintf( pStr, "%02d ", ( nFrom == 2 ? 1:0 ));
            TR_Arg.pLogFile->WriteLine( pStr );
            CTenetSFClient::WritePacketToFile( TR_Arg.pLogFile, (char*)pMsg, pMsg->length + offsetof(TOS_Msg, data) );

        }
    }

}

//void* CTenetRouter::RouterThread(void* arg)
//{
//    CTenetRouter* pRouter = (CTenetRouter*) arg;
//
//    while( pRouter->IsStart() )
//    {
//        while(pRouter->IsThereAnyNewPacket())
//            pRouter->Receive();
//
//        usleep(1);
//    }
//
//    return NULL;
//}

void CTenetRouter::Process()
{
    if( this->IsStart() )
        this->Receive();
}

void CTenetRouter::Timer()
{
    static time_t  timeCur=0;
    static time_t  timerMRT=0;
    static time_t  timerIPRT=0;

    if( timeCur == 0 )
    {
        time(&timerMRT);
        time(&timerIPRT);
    }

    if( this->IsStart() )
    {
        time(&timeCur);

        if( (timeCur - timerMRT) > MRT_REFRESH_TIMEOUT )
        {
            time(&timerMRT);
            CMRT_Manager::Refresh(0);
            //CMRT_Manager::Show();
        }

        if( (timeCur - timerIPRT) > IPRT_REFRESH_TIMEOUT )
        {
            time(&timerIPRT);
            CIPRT_Manager::Refresh(0);
        }
    }
}

// this function is called when Tenet Router is running in interactive mode
bool CTenetRouter::ParseTR_Command(TR_Packet *pPacket, bool bConsole)
{
    char* pArg=pPacket->pData;
    char pStrToken[MAX_STRING_SIZE];
    TR_Packet packet;

    CFile::GetToken(pArg, pStrToken, ' ');

    if( strcmp ( "show" , pStrToken ) == 0 || strcmp ( "s" , pStrToken ) == 0 )
    {
        CFile::GetToken(pArg, pStrToken, ' ');

        if( strcmp ( "packet" , pStrToken ) == 0 || strcmp ( "p" , pStrToken ) == 0 )
        {
            TR_Debug.bShowPacket = !TR_Debug.bShowPacket;
            DEBUG(" > TR_Debug.bShowPacket is %s \n", TR_Debug.bShowPacket == true ? "Enabled" : "Disabled");
            goto DONE;
        }
    }
    else if( strcmp ( "trace" , pStrToken ) == 0 ||  strcmp ( "t" , pStrToken ) == 0 )
    {
        CFile::GetToken(pArg, pStrToken, ' ');

        if( strcmp ( "mrt" , pStrToken ) == 0 ||  strcmp ( "m" , pStrToken ) == 0 )
        {
            TR_Debug.bTraceMRT = !TR_Debug.bTraceMRT;
            DEBUG(" > TR_Debug.bTraceMRT is %s \n", TR_Debug.bTraceMRT == true ? "Enabled" : "Disabled");

            goto DONE;
        }
        else if( strcmp ( "iprt" , pStrToken ) == 0 || strcmp ( "i" , pStrToken ) == 0 )
        {
            TR_Debug.bTraceIPRT = !TR_Debug.bTraceIPRT;
            DEBUG(" > TR_Debug.bTraceIPRT is %s \n", TR_Debug.bTraceIPRT == true ? "Enabled" : "Disabled");

            goto DONE;
        }
        else if( strcmp ( "packet" , pStrToken ) == 0 ||  strcmp ( "p" , pStrToken ) == 0 )
        {
            TR_Debug.bTracePacket = !TR_Debug.bTracePacket;
            DEBUG(" > TR_Debug.bTracePacket is %s \n", TR_Debug.bTracePacket == true ? "Enabled" : "Disabled");

            goto DONE;
        }
    }
    else if( strcmp ( "add" , pStrToken ) == 0 )
    {
        uint16_t moteID;
        uint32_t nextHopIP;

        CFile::GetToken(pArg, pStrToken, ' ');
        moteID = (uint16_t) atoi(pStrToken);

        CFile::GetToken(pArg, pStrToken, ' ');
        nextHopIP = (uint32_t) inet_addr(pStrToken);

        CMRT_Manager::Update( moteID, moteID, nextHopIP );

        goto DONE;

    }else if( strcmp ( "mrt" , pStrToken ) == 0 || strcmp ( "m" , pStrToken ) == 0 )
    {
        CMRT_Manager::Show();

        goto SHOW_MRT;
    }
    else if( strcmp ( "iprt" , pStrToken ) == 0 || strcmp ( "i" , pStrToken ) == 0 )
    {
        CIPRT_Manager::Show();

        goto SHOW_IPRT;
    }
    else if( strcmp ( "h" , pStrToken ) == 0 )
    {
        ShowHelp();

        return true;
    }

    return false;


DONE:

    if(!bConsole)
    {
        strcpy(packet.pData, "Done");
        packet.header.lMasterIP = CTenetRouter::s_nMyIP;
        packet.header.type = TR_PACKET_TYPE_CTRL_RES;
        packet.header.nDataLength = strlen(packet.pData);
        DEBUG("Send %s\n",inet_ntoa((in_addr&) pPacket->header.lMasterIP));
        CUDP_Client::DirectSend( inet_ntoa((in_addr&) pPacket->header.lMasterIP), TENET_ROUTER_PORT_FOR_DEBUGGER, (char*) &packet, packet.GetTotalPacketLength() ); 
    }

    return true;

SHOW_MRT:

    if(!bConsole)
    {
        MRT_Packet* pMRT_Packet = (MRT_Packet*) packet.pData;

        CMRT_Manager::MakeMRT_Packet( pMRT_Packet );
        packet.header.lMasterIP = CTenetRouter::s_nMyIP;
        packet.header.type = TR_PACKET_TYPE_CTRL_RES_MRT;
        packet.header.nDataLength = pMRT_Packet->GetMRT_PacketLength();
        DEBUG("Send %s\n",inet_ntoa((in_addr&) pPacket->header.lMasterIP));
        CUDP_Client::DirectSend( inet_ntoa( (in_addr&) pPacket->header.lMasterIP ), TENET_ROUTER_PORT_FOR_DEBUGGER, (char*) &packet, packet.GetTotalPacketLength() ); 
    }

    return true;
SHOW_IPRT:

    if(!bConsole)
    {
        IPRT_Packet* pIPRT_Packet = (IPRT_Packet*) packet.pData;

        CIPRT_Manager::MakeIPRT_Packet( pIPRT_Packet );
        packet.header.lMasterIP = CTenetRouter::s_nMyIP;
        packet.header.type = TR_PACKET_TYPE_CTRL_RES_IPRT;
        packet.header.nDataLength = pIPRT_Packet->GetIPRT_PacketLength();
        DEBUG("Send %s\n",inet_ntoa((in_addr&) pPacket->header.lMasterIP));
        CUDP_Client::DirectSend( inet_ntoa( (in_addr&) pPacket->header.lMasterIP ), TENET_ROUTER_PORT_FOR_DEBUGGER,  (char*) &packet, packet.GetTotalPacketLength() ); 
    }

    return true;
}

