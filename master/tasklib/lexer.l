/**
 * This file is part of Tenet parse system.
 * It has the Tenet Lexicographic Rules.
 */
%{
#include <stdio.h>
#include <limits.h>
#include "y.tab.h"
#include "tp.h"
#include "tenet_task.h"

/* Scan the task description one character at a time */
/* task_description and taskpos are defined in parser.y */

#define YY_INPUT(buf,result,max_size) \
    { \
    char c = tp_taskdesc[tp_taskpos++]; \
    if (c == 0) { result = YY_NULL; } \
    else {buf[0] = c; result = 1; } \
    }
%}

%%
"&&"        {yylval.val=LAND;return number;}
"||"        {yylval.val=LOR;return number;}
"<<"        {yylval.val=SHL;return number;}
">>"        {yylval.val=SHR;return number;}
"+"         {yylval.val=A_ADD;return number;}
"-"         {yylval.val=A_SUB;return number;}
"*"         {yylval.val=A_MULT;return number;}
"/"         {yylval.val=A_DIV;return number;}
"%"         {yylval.val=A_MOD;return number;}
"^"         {yylval.val=A_POW;return number;}
"<="        {yylval.val=LEQ;return number;}
">="        {yylval.val=GEQ;return number;}
"!="        {yylval.val=NEQ;return number;}
">"         {yylval.val=GT;return number;}
"<"         {yylval.val=LT;return number;}
"=="        {yylval.val=EQ;return number;}
"&"         {yylval.val=AND;return number;}
"|"         {yylval.val=OR;return number;}
"!"         {yylval.val=NOT;return number;}
"node"		 return node;
"'" 		 return quote;
[0-9]+			{if(atoll(yytext)<=ULONG_MAX){yylval.val = atoll(yytext); return number;}else{strcpy (yylval.string, yytext);return byteString;}}
[0-9a-fA-F]+			{strcpy(yylval.string, yytext); return byteString;}
0x[0-9a-fA-F]+			{(void) sscanf(yytext, "%x", &yylval.val); return number;}
[A-Za-z][A-Za-z_0-9.]*	{strcpy (yylval.string, yytext); return identifier;}
[(),]			return yytext[0];
"->"			return rightarrow;
[ \t\n]			;
.			{ECHO; yyerror ("unexpected character");}

%%

int yywrap ()
{
  return 1;
}
