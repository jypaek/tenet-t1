#include <time.h>
#include <sys/time.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include "log.h" 

FILE* fptrLog=NULL;

void openLog(){
/*Open Logfile*/
    char *filename;
    struct timeval tv;
    struct tm* ptm;
    char time_string[40];
    long milliseconds;

    filename = malloc(255);
    strcpy(filename,"packets");

    gettimeofday (&tv, NULL);
    ptm = localtime (&tv.tv_sec);
    /* Format the date and time, down to a single second. */
    strftime (time_string, sizeof (time_string), "_%Y-%m-%d_%H_%M", ptm);
    /* Compute milliseconds from microseconds. */
    milliseconds = tv.tv_usec / 1000;

    //filename = getdate(%y-%m-%d);
    strcat (filename, time_string);
    strcat (filename, ".log");

    printf("filename: %s\n",filename);
    fflush(stdout);
    fptrLog = fopen(filename,"w");

    if(fptrLog==NULL){
      printf("\nFile Error\n Trying to open:%s log file\n",filename);
    }

}

void printToLog(char *message,int isTime){
	char time_string[40];

    if(isTime){
	  memset(time_string, 0, sizeof(time_string));
	  getTime(time_string);
      strcat(time_string,"\n");
    }

    //stdout
    printf(message);
	if(isTime) printf(time_string);
    fflush(stdout);

    //log file
    if(fptrLog){
      fprintf(fptrLog, message);
      if (isTime) fprintf(fptrLog,time_string);//print time later	
      fflush(fptrLog);
    }
}

void getTime(char *time){
	
	char timeofday[40];
	
    struct timeval tv;
 	struct tm* ptm;
    //memset(timeofday, 0, sizeof(timeofday));
    
    gettimeofday (&tv, NULL);
 	ptm = localtime (&tv.tv_sec);
 	/* Format the date and time, down to a single second. */
 	strftime (timeofday, sizeof (timeofday), "%H:%M:%S ", ptm);
 	strcpy(time,timeofday);
 	
}

void closeLog(){
  fclose(fptrLog);
}

