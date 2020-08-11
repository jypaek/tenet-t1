/**
 * Tenet Debugger
 *
 * Provides utilities to log debug messages in TOSSIM or EMSTAR
 *
 **/

#ifndef TENET_DEBUG_H
#define TENET_DEBUG_H

#if defined(PLATFORM_PC) || defined(PLATFORM_EMSTAR)

#include <stdio.h>
#include <stdarg.h>

#ifndef LOG_EMERG
#define LOG_EMERG       0       /**< system is unusable */
#define LOG_ALERT       1       /**< action must be taken immediately */
#define LOG_CRIT        2       /**< critical conditions */
#define LOG_ERR         3       /**< error conditions */
#define LOG_WARNING     4       /**< warning conditions */
#define LOG_NOTICE      5       /**< normal but significant condition */
#define LOG_INFO        6       /**< informational */
#define LOG_DEBUG       7       /**< debug */

// location @
#endif
//Karen suggested to move this from location @ for platform emstar to work
char *str[8] = {"EMERG","ALERT","CRIT ","ERR  ",
                "WARN ","NOTE ","INFO ","DEBUG"};

#ifndef LOGLEVEL
#define LOGLEVEL (LOG_DEBUG)
#endif

#define MAX_BUF_SIZE (1000)

static void tenet_log(const char *file, long line, const char *fn, int level, 
                      const char *format, ...){
  va_list args;
  va_start(args,format);
  fprintf(stdout,"%s %s:%ld %s(): ",str[level],file,line,fn);
  vfprintf(stdout,format,args);
  va_end(args);
}

static void buffer_log(const char *file, long line, const char *fn, int level, 
                       uint8_t *buf, uint16_t size){
  char s[MAX_BUF_SIZE];
  int i = 0, offset = 0;
  while (i < size && offset < MAX_BUF_SIZE){
    sprintf(&s[offset],"%2x ",buf[i]);
    i++;
    offset+=3;
  }
  s[offset]='\0';
  fprintf(stdout,"%s %s:%ld %s(): %s\n",str[level],file,line,fn, s);
}



#define tlog(level, args...) \
  do { if (LOGLEVEL>=(level)) tenet_log(__FILE__, __LINE__, __FUNCTION__, (level), args);\
}while (0)

#define buflog(level,buf,size) \
  do { if (LOGLEVEL>=(level)) buffer_log(__FILE__,__LINE__, __FUNCTION__, (level), (uint8_t *)buf, (uint16_t)size);\
} while (0)


#else
#define tlog(...)
#define buflog(...)

#endif


#endif
