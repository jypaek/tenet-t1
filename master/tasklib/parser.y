/**
 * This file is part of Tenet parse system.
 * It has the Tenet Grammatic Parse.
 *
 * A task chain is a collection of task separated by '->'
 * A task may contain parameter (number, number,..)
 * A quote defines a constant number
 */
%{
#include "tp.h"
int yylex(void);

%}

%union {
    int val;
    char string[50];
}
%start task_chain
%token <string> identifier
%token <val> number
%token <string> byteString 
%token rightarrow
%token node
%token quote 
%%

/* Arguments: currently only integers */
arglist: /* empty */
	| number
	{
#if TP_DEBUG            
            fprintf(stderr, "In arg_list rule: %d\n", $1);
#endif            
            tp_add_arg($1);
        }
	| quote number quote
	{
#if TP_DEBUG            
            fprintf(stderr, "In arg_list constant rule: %d\n", $2);
#endif            
            tp_add_arg($2);
			tp_set_constant();
        }
    | byteString
    {
#if TP_DEBUG
            fprintf(stderr, "In arg_list byteString rule: %s\n", $1);
#endif
            tp_add_byteString($1);
        }
	| arglist ',' quote number quote
	{
#if TP_DEBUG            
            fprintf(stderr, "In arg_list constant rule: %d\n", $4);
#endif            
            tp_add_arg($4);
			tp_set_constant();
        }
	| arglist ',' byteString 
	{
#if TP_DEBUG            
            fprintf(stderr, "In arg_list byteString rule: %d\n", $3);
#endif            
            tp_add_byteString($3);
        }
	| arglist ',' number
	{
#if TP_DEBUG            
            fprintf(stderr, "In arg_list rule: %d\n", $3);
#endif            
            tp_add_arg($3);
        };

/* Task chain must have at least one element */
task_chain: task_element
	| task_chain rightarrow task_element;

task_element: identifier '(' arglist ')'
	{
#if TP_DEBUG            
            fprintf(stderr, "In task_element rule\n");
#endif            
            tp_call_constructor($1);
        }
//below is an example of High Level Task 
	| node '(' number ')'
	{
#if TP_DEBUG
		fprintf(stderr,"In node_element(number)\n");
#endif
		tp_init_args();
		//tp_add_arg(getAddress("TOS_LOCAL_ADDRESS"));
		tp_add_arg(4352);
		tp_add_arg(2);
		tp_add_arg(0);
		tp_add_arg(113);
		tp_call_constructor("memoryop");
		tp_init_args();
		tp_add_arg($3);
		tp_add_arg(1);
		tp_add_arg(113);
		tp_add_arg(0);
		tp_add_arg(3);
		tp_call_constructor("classify_amplitude");
		tp_init_args();
        tp_add_arg($3);
        tp_add_arg(1);
        tp_add_arg(113);
        tp_add_arg(1);
        tp_add_arg(3);
        tp_call_constructor("classify_amplitude");
    };
%%


