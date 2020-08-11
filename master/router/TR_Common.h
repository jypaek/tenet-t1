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
* definitions that are commonly used are here
* 
* Authors: Ki-Young Jang
* Embedded Networks Laboratory, University of Southern California
* Modified: 2/6/2007
*/

#ifndef _TR_COMMON_H
#define _TR_COMMON_H

#include <time.h>
#include <stdio.h>
#include <stdlib.h>

#define MAX_STRING_SIZE		256
#define _TENET_ROUTER_PORT_FOR_OTHER_ROUTER	"10000"
#define _TENET_ROUTER_PORT_FOR_TRANSPORT	"9999"
#define _TENET_SF_HOST		"127.0.0.1"
#define _TENET_SF_PORT		"9000"
#define _TENET_ROUTER_INTERFACE	"wlan0"
#define TENET_ROUTER_PORT_FOR_DEBUGGER	19999
#define MAX_BUFFFER_SIZE		1000

#define MSG(fmt, args...) fprintf(stdout, fmt, ## args);
#define TR_ERROR(fmt, args...) { fprintf(stderr, "[ERROR] <%s>\n\t", __PRETTY_FUNCTION__); fprintf(stderr, fmt, ## args); }

#ifdef DEBUG_MODE
#define TRACE(fmt, args...) { fprintf(stderr, "[TRACE] <%s>\n\t", __PRETTY_FUNCTION__); fprintf(stderr, fmt, ## args); } 
#define DEBUG(fmt, args...) fprintf(stderr, fmt, ## args);
#define CONDITIONAL_DEBUG(condition, fmt, args...) if(condition) fprintf(stderr, fmt, ## args);
#else
#define TRACE(fmt, args...)
#define DEBUG(fmt, args...) 
#define CONDITIONAL_DEBUG(fmt, args...) 
#endif


class CFile;

typedef struct Debug
{
	bool bInteractive;
	bool bShowPacket;
	bool bTracePacket;
	bool bTraceMRT;
	bool bTraceIPRT;
};

typedef struct Arg
{
	char	pLogFilePath[MAX_STRING_SIZE];
        CFile*	pLogFile;
	bool	bInteractive;
        char    pNameOfNetworkInterface[MAX_STRING_SIZE];
};

void GetCommand(char* pStr);

void ShowUsage(char* argv); 
void ShowHelp();

#endif
