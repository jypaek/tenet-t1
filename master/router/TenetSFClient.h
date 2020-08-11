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
* SFClient wrapper class. This class is used for communication 
* between a basestation mote and Tenet Router
*
* Authors: Ki-Young Jang
* Embedded Networks Laboratory, University of Southern California
* Modified: 2/6/2007
*/

#ifndef _TENETSFCLIENT_H_
#define _TENETSFCLIENT_H_

#include <pthread.h>

#include "SFClient.h"

class CTenetSFClient
	: public CSFClient
{
public:
	CTenetSFClient(void);
	~CTenetSFClient(void);

private:
	static 	void	OnSFReceive(CTCP_Client *pClient, char* pData, int nLen);
	//static 	void*	SFThread(void *arg);

public:
	bool	Connect(void);
	static 	void	ShowPacket(char *pData, int nLen);
	void	Process();

private:
	//pthread_t		m_thread;

};

#endif
