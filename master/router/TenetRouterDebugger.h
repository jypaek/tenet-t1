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

#ifndef _TENETROUTERDEBUGGER_H_
#define _TENETROUTERDEBUGGER_H_

#include "UDP_Socket.h"
#include "MRT_Manager.h"
#include "IPRT_Manager.h"

class CTenetRouterDebugger :
	public CUDP_Server
{
public:
	CTenetRouterDebugger(void);
	~CTenetRouterDebugger(void);

private:
	static	CTenetRouterDebugger*	s_pTenetRouterDebugger;

public:
	static	void		OnReceive(struct sockaddr_in* pAddr, char* pData, int nLen);
	virtual void Process(void);

	static CTenetRouterDebugger* GetTenetRouterDebugger()
	{
        return s_pTenetRouterDebugger;
	}

};

#endif
