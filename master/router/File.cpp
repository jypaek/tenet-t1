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
* File handling class
*
* Authors: Ki-Young Jang
* Embedded Networks Laboratory, University of Southern California
* Modified: 2/6/2007
*/

#include <stdio.h>  
#include <stdlib.h>  
#include <string.h>
#include <sys/types.h>  
#include <sys/stat.h>  

#include "File.h"
#include "TR_Common.h"

#define MAX_STRING_SIZE			256

CFile::CFile(char *pStrFileName, bool bRead)
{
	if(bRead)
		this->m_pFile=fopen(pStrFileName, "r");
	else
		this->m_pFile=fopen(pStrFileName, "w");
	
	if(this->m_pFile==NULL)
	{
		TR_ERROR("File open error : [%s]\n",pStrFileName);
		exit(1);
	}
}

CFile::~CFile(void)
{
	fclose(this->m_pFile);
}

int CFile::WriteLine(char *pStr)
{
	return fputs(pStr, this->m_pFile);
	fflush(this->m_pFile);
}

char* CFile::ReadLine(char *pStr)
{
	return fgets(pStr,MAX_STRING_SIZE,this->m_pFile);
}

char* CFile::Trim(char *pStr)
{
    char *pStrTemp=0;

    //  Set pointer to character before terminating NULL
    pStrTemp=pStr+strlen(pStr)-1;

    //  iterate backwards until non '_' is found 
    while((pStrTemp>=pStr)&&(*pStrTemp==' '))
        *pStrTemp--='\0';

    return pStr;
}

char* CFile::GetToken(char *pStrSrc, char *pStrToken, char c)
{
	strcpy(pStrToken,pStrSrc);
	for(int i=0 ; i< (int)strlen(pStrSrc) ; i++)
	{
		if(pStrSrc[i]==c)
		{
			pStrToken[i]='\0';
			strcpy(pStrSrc,pStrSrc+i+1);

			return pStrToken;
		}
	}

	return pStrToken;
}
