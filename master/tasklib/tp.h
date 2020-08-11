/*
* "Copyright (c) 2006-2007 University of Southern California.
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

/**
 * This file is part of Tenet parse system.
 * Given a string, it parse into tasklets and its parameters.
*/

#include <stdio.h>
#include <string.h>
#include <sys/file.h>
#include "common.h"

/* Set this to 1 for debugging */
#define TP_DEBUG 0 

/* Set this to 1 for standalone testing */
//#define TP_STANDALONE 1

#define TP_MAX_ARGS     20  /* Number of tasklet args */
#define TP_MAX_TASKLEN  300 /* Length of task string */

extern char tp_taskdesc[];      /* Task description: yylex uses this */
extern int tp_taskpos;          /* Current position: yylex uses this */
extern int tp_args[];           /* Function args scanned in: yyparse fills this */
extern char tp_byteString[][255];           /* Function args scanned in: yyparse fills this */
extern int tp_argpos;           /* Position of args: yyparse touches this */
extern int tp_arg_byteString;           /* Number of byteString args: yyparse touches this */
extern int tp_is_constant;     /*Indicates if it is a constant. yyparse touches this*/
extern unsigned char* tp_packetbuf; /* Packet buffer given by caller */

/* Exported functions, called by the parser */
extern void tp_init_args();
extern void tp_add_arg(int);
extern void tp_set_constant();
extern void tp_call_constructor(char* func);
extern void tp_add_byteString(char* string);

int yyerror (char *s);


int tp_parse_task(unsigned char* buf,   /* Pointer to packet buffer */
                  char* task);          /* Task description string */

//#ifdef __CYGWIN__
//long long atoll(char *str);
//#endif
