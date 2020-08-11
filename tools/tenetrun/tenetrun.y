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
 $Id: tenetrun.y,v 1.3 2007-12-15 02:28:49 naik Exp $
*/

#include "process.h"
int isdaemon;
int log_fid;
char command_name[MAX_COMMAND_LENGTH], arg[MAX_ARG_LENGTH];
int numberofnodes;
%}
%start processes
%token WORD EQUALS SEMICOLON NEWLINE COMMAND OBRACE CBRACE QUOTE ARG DAEMON ALPHANUMERIC PROCESS NUMBEROFNODES NUMBER
%% /* Grammar rules and actions follow */
processes: 
	NUMBEROFNODES EQUALS NUMBER SEMICOLON
		{numberofnodes = $3;}
        |        
        processes process
        ;
process:
	OBRACE statements CBRACE
		{if(command_name[0] == 0)  //if(command_name == NULL)
		 {
			yyerror("Command name is not given.\n");
			exit(0);
		 }
	 	//printf("command_name is %s %d\n",command_name,strlen(command_name));	
		exec_process(command_name,arg,isdaemon,numberofnodes,-1);
		memset(command_name,0,MAX_COMMAND_LENGTH); //free(command_name); command_name = NULL;
		memset(arg,0,MAX_ARG_LENGTH);//free(arg); arg=NULL;
		}
	;
statements:
	statement
	|
	statements statement
	;
statement:
	COMMAND equals_quoted_word_semicolon
		{//printf("command=%s\n",$2);
		//command_name = (char *)malloc(strlen((char *)$2));
		strcpy(command_name,(char *)$2);
                //printf("statement: command_name is %s %d\n",command_name,strlen(command_name));
		}	
	|
	ARG equals_quoted_word_semicolon
		{//printf("arguments=%s\n",$2);
		//arg= (char *)malloc(strlen((char *)$2));
		strcpy(arg,(char *)$2);}
	;
equals_quoted_word_semicolon:
	EQUALS QUOTE WORD QUOTE SEMICOLON		
		{$$=$3;}
;
%%

extern FILE *yyin;

int yyerror(char *s)  /* Called by yyparse on error */
{
	printf ("%s\n", s);
}

int yywrap()
{
        return 1;
}

int main (int argc, char **argv)
{
	memset(command_name,0,MAX_COMMAND_LENGTH);
	memset(arg,0,MAX_ARG_LENGTH);//command_name = arg = NULL;
	isdaemon = 0;	
	numberofnodes = 0;
       	FILE *file;
        int return_code, child_pid;
	
	signal(SIGINT, sigproc);
        signal(SIGTERM, sigproc);
	//signal(SIGSEGV, sigsegv);
        //signal(SIGCHLD, SIG_IGN);

	//printf("Number of arguments = %d\n",argc);
  	while(argc > 1) {
		switch(argc)
		{	
			case 3:
				if(strcmp(argv[argc-1],"daemon") == 0)
				{
					isdaemon = 1;
					int fork_retval = fork();
        				if (fork_retval < 0) {
                				printf("couldn't fork: %s",argv[0]);
                				exit(1);
        				}
        				if (fork_retval > 0) {
                 				//parent: just exit 
                				exit(0);
        				}
					printf("Please do not issue \"kill -9\" signal to tenetrun. Instead use just \"kill\".\n");
					log_fid = open(TENETRUN_OUTPUT_FILENAME, O_RDWR|O_CREAT); 
					fchmod(log_fid, S_IRUSR|S_IWUSR);
					dup2(log_fid, 1);
					dup2(log_fid, 2);
        				setpgrp();
        				close(0);
        				//close(1);
        				//close(2);
				}
				break;
			case 2:
    			        file = fopen(argv[argc-1], "r");
                		if (!file) {
                        		fprintf(stderr,"could not open %s\n",argv[1]);
                        		exit(1);
                		}
                		yyin = file;
				break;
			default:
				printf("Ignoring the argument %s.\n");
				break;
		}
		argc--;
        }
  	yyparse();
	fclose(yyin);
	while(1)
	{
		//child_pid = waitpid(P_ALL,&return_code,WNOHANG);	
		
		child_pid = wait(&return_code);	
			
		if(child_pid != -1)
		{
			printf("Child PID %d exited with return code %d.\n",child_pid,WEXITSTATUS(return_code));	
			if(WEXITSTATUS(return_code) < 1)
			{
			 	//if(WIFSIGNALED(return_code) == 1)
				//{
				//	printf("Child received %d signal.\n",WTERMSIG(return_code));
					recreate_child(child_pid);
				//	continue;
				//}
				//printf("Stopped %d\n",WIFSTOPPED(return_code));		
			}
		}
		else
		{
			printf("Unknown child returned.\n");
			break;
		}	
	}
}
