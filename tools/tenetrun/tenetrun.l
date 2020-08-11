%{
/*
 "Copyright (c) 2007 The Regents of the University of California.
 All rights reserved.

 Permission to use, copy, modify, and distribute this software and its
 documentation for any purpose, without fee, and without written
 agreement is hereby granted, provided that the above copyright
 notice, the following two paragraphs and the author appear in all
 copies of this software.

 IN NO EVENT SHALL THE REGENTS BE LIABLE TO
 ANY PARTY FOR DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL
 DAMAGES ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS
 DOCUMENTATION, EVEN IF THE REGENTS HAS BEEN
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

 THE REGENTS SPECIFICALLY DISCLAIMS ANY
 WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.  THE SOFTWARE
 PROVIDED HEREUNDER IS ON AN "AS IS" BASIS, AND THE UNIVERSITY OF
 SOUTHERN CALIFORNIA HAS NO OBLIGATION TO PROVIDE MAINTENANCE,
 SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS."


 Author: Vinayak Naik (naik@cens.ucla.edu)
 $Id: tenetrun.l,v 1.2 2007-12-15 02:29:20 naik Exp $
*/

#include "tenetrun.tab.h"
extern char *strdup(const char *s1);
//#define YYSTYPE char *
//extern YYSTYPE yylval;
%}
%%
\n                      /* ignore end of line */;
[ \t]+                  /* ignore whitespace */;
process 		return PROCESS;
command                 return COMMAND;
=			return EQUALS;
\{			return OBRACE;
\}			return CBRACE;
\"			return QUOTE;
;			return SEMICOLON;
arg			return ARG;
number_of_nodes		return NUMBEROFNODES;
[0-9]+			yylval = atoi(yytext); return NUMBER;	
[a-zA-Z0-9\/.\-][a-zA-Z0-9 \t\-\/.&\_]*   yylval=strdup(yytext); return WORD;
%%
