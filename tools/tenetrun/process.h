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
 $Id: process.h,v 1.4 2007-12-15 16:28:49 naik Exp $
*/

#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <signal.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/stat.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>

#define MAX_ARGS 200
#define MAX_CHILDREN 200
#define MAX_ID_LENGTH 10
#define MAX_COMMAND_LENGTH 100
#define TENETRUN_OUTPUT_FILENAME "tenetrun_output.txt"
#define MAX_ARG_LENGTH 1000

extern int errno;     /* system error number */
extern int isdaemon;
extern int log_fid;
int child_processid[MAX_CHILDREN];	
char child_process_command_name[MAX_CHILDREN][MAX_COMMAND_LENGTH];
char child_process_arg[MAX_CHILDREN][MAX_COMMAND_LENGTH];
int child_process_isdaemon[MAX_CHILDREN];
int child_index;

void syserr(char * msg)
{
   	fprintf(stderr,"%s: %s", strerror(errno), msg);
   	exit(errno);
}

void sigproc()
{
	printf("Tenetrun terminated.\n");
	while(child_index - 1 >= 0)
	{
		//printf("To be killed %d at %d.\n",child_processid[child_index-1],child_index-1);	
		kill(child_processid[child_index-1], SIGINT);
		child_index--;
	}
	if(isdaemon)
		close(log_fid);	
	exit(1);
}

void sigsegv()
{
	int child_pid, return_code;

	printf("Received segmentation fault.\n");
	child_pid = waitpid(P_ALL,&return_code,WNOHANG);        
        //child_pid = wait(&return_code);       
        if(child_pid != -1)
        {
        	printf("Child PID %d exited with return code %d.\n",child_pid,WEXITSTATUS(return_code));
                printf("Exit status = %d\n",WIFEXITED(return_code));
                //recreate_child(child_pid);
        }
	exit(1);
}

void recreate_child(int child_pid)
{
	int index = 0;

	while(index < child_index)
	{
		if(child_pid == child_processid[index])
			break;
		else
			index++;
	}

	if(index == child_index)
	{	
		printf("Child PID %d not found.\n",child_pid);
		return;
	}
	//printf("Dead child's command name is %s with arg %s and is daemon %d.\n",child_process_command_name[index],
        //      child_process_arg[index],child_process_isdaemon[index]);
	exec_process(child_process_command_name[index],child_process_arg[index],child_process_isdaemon[index],1,index);
}

/*void sigchild()
{
	printf("Child is dead.\n");
}	*/
int exec_process(char *command_name, char *arg, int isdaemon, int numberofnodes, int index)
{
	int child_pid;
	static char *argarray[MAX_ARGS];
	char *temp_arg , *temp_arg_dup;
	//I do not whether not freeing temp_arg and temp_arg_dup in child will cause memory leak.	
	int i,nodeindex;
	char nodeID[MAX_ID_LENGTH];

	//printf("Will execute %s as with arguments %s isdaemon %d with index %d.\n",command_name,arg,isdaemon,index);
	argarray[0] = command_name;
	i = 1;
	if(arg != NULL && *arg != '\0')
	{
		temp_arg = (char *)malloc(strlen(arg));
		temp_arg_dup = (char *)malloc(strlen(arg));
		memcpy(temp_arg,arg,strlen(arg));
		memcpy(temp_arg_dup,arg,strlen(arg));
		//printf("temp_arg_dup = %s\n",temp_arg);
	}
	else
	{
		temp_arg = NULL;	
		temp_arg_dup = NULL;
	}
	//printf("arg = %s\n",arg);	
	argarray[i] = strtok(temp_arg_dup, " ");
    	while (argarray[i] != NULL) {
      		if (i >= MAX_ARGS) {
        	printf("Can't run %s: argument list too long", arg);
        	exit(251);
      		}
      		argarray[++i] = strtok(NULL, " ");
    	}
	int j = 0;
	//free(temp_arg_dup);

	for(nodeindex=0;nodeindex<numberofnodes;nodeindex++)
	{
		child_pid = fork();
		if(child_pid > 0)
		{//parent
				/*j = 0;
				while (argarray[j] != NULL) 
					printf("%s ",argarray[j++]);
				printf("\n");*/
				if(index == -1)
				{
					//Create a new index
					strcpy(child_process_command_name[child_index],command_name);
					if(temp_arg != NULL)
					{
						//strcpy(child_process_arg[child_index],arg);
						memcpy(child_process_arg[child_index],temp_arg,strlen(temp_arg));
						//printf("Copied arg %s.\n",child_process_arg[child_index]);
						free(temp_arg);
					}
					else 
						child_process_arg[child_index][0] = '\0';
					child_process_isdaemon[child_index] = isdaemon;
					child_processid[child_index] = child_pid;
					//printf("Added child %d at %d.\n",child_processid[child_index],child_index);
					child_index++;
				}
				else
				{
					//Reuse the provided index
					child_processid[index] = child_pid;	
					//printf("Added child %d with arg %s at %d.\n",child_processid[index],
					//	child_process_arg[index],index);
				}
				free(temp_arg_dup);
		}
		switch(child_pid)
		{
			case -1: syserr("fork");
        	                 break;
	                case 0:	
				/*j = 0;
				while (argarray[j] != NULL) 
					printf("%s ",argarray[j++]);
				printf("\n");*/
				setpgid(0,0);
				if(isdaemon)
				{
					dup2(log_fid, 1);
                                        dup2(log_fid, 2);
					close(0);
        				//close(1);
        				//close(2);	
				}
				if(numberofnodes > 1)
				{
					argarray[i+2] = argarray[i];
					argarray[i] = "-N";
					sprintf(nodeID,"%d",nodeindex);
					argarray[i+1] = nodeID;
				}
				//free(temp_arg);
				//free(temp_arg_dup);
				execvp(command_name,argarray);		
				exit(1);
				break;
		}
	}
}		
