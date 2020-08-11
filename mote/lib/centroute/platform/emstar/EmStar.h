/*
 *
 * Copyright (c) 2003 The Regents of the University of California.  All 
 * rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 *
 * - Neither the name of the University nor the names of its
 *   contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS''
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
 * PARTICULAR  PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE REGENTS OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 */

#ifndef __EMSTAR_H__
#define __EMSTAR_H__

/*
 *  EmStar.h
 *
 *  Include this file from any NesC module that needs to use EmStar
 *  services, EmTOS related components, or be compatible with EmStar
 *  structure standards 
 *
 */

/* struct timeval, time_t, etc */
#ifdef PLATFORM_PC
# include <sys/time.h>
#else
typedef uint32_t time_t;
typedef uint32_t pid_t;
struct timeval { char pad[0]; };
#endif


/*
 *  Emstar Structure Include Files
 *  Add additional files as needed
 */

#include "local_types.h"
//#include "link/include/neighbor_structs.h"
#include "routing_table.h"
//#include "routing/include/routing_flags.h"
//#include "tos-contrib/hostmote/tos/system/h_types.h"
#include "sync_structs.h"
#include "link_structs.h"

/*
 *  get_my_node_id and get_my_if_id.. 32 bit node and interface ID, 
 *   on emstar maps to my_node_id and the link interface ID,
 *   on real motes maps to 32 bit cast of LOCAL_ADDRESS
 */

#ifdef PLATFORM_PC
node_id_t get_my_node_id();
if_id_t get_my_if_id();
#else
static inline node_id_t get_my_node_id() { return (node_id_t)TOS_LOCAL_ADDRESS; }
static inline if_id_t get_my_if_id() { return (if_id_t)TOS_LOCAL_ADDRESS; }
#endif

#ifdef PLATFORM_PC

static inline uint32_t tv_usec(struct timeval *tv) { return tv->tv_usec; }
static inline uint32_t tv_sec(struct timeval *tv) { return tv->tv_sec; }

static inline long ms_since(struct timeval *gTv) {
  struct timeval tv;
  long tmptime;
  gettimeofday(&tv,NULL);    
  tmptime = (tv_sec(&tv) - tv_sec(gTv)) * MILLION_I;
  tmptime += (tv_usec(&tv) - tv_usec(gTv));
  tmptime /= 1000;
  return tmptime;
}

#endif


#ifdef PLATFORM_EMSTAR
char *emtos_name_nosim(char *suffix, char *appname);
#else
#define emtos_name_nosim(x,y) (x) 
#endif

/*
 * buf_t 
 */



#ifdef PLATFORM_EMSTAR
#ifndef EMSTAR_NO_KERNEL

// buf_t required definitions etc
typedef struct buf buf_t;

buf_t* buf_new();
void buf_free(buf_t* buf);

void bufprintf(buf_t *b, const char *fmt, ...)
	     __attribute__ ((format (printf, 2, 3)));

void bufcpy(buf_t *b, const void *src, int len);

char *buf_get(buf_t *buf);
int buf_len(buf_t *buf);

#endif
#endif

/*
 *  parser
 */


typedef struct parser_state {
  char *input; /**< input string */
  int input_len;

  /* options */
  char *pair_delimit_set;
  char *pair_assign_set;
  int skip_whitespace:1;
  char escape_char;

  /* latest result */
  char *key;
  char *value;
  uint8_t pair_delimit;
  uint8_t pair_assign;

  /* internal variables */
  int consumed;
  char *_input;
} parser_state_t;


enum MISC_PARSE_ENUM {
 MISC_PARSE_COLON_SCHEME=1,
 MISC_PARSE_COMMA_SCHEME=2,
 MISC_PARSE_LF_SCHEME=3
};


#ifdef PLATFORM_EMSTAR

/* Parser Prototypes */
parser_state_t * misc_parse_init(char *input, int scheme);
void misc_parse_cleanup(parser_state_t *state);
int misc_parse_next_kvp(parser_state_t *state);
#ifndef EMSTAR_NO_KERNEL
void misc_parse_dump_curr_to_buf(buf_t *buf, parser_state_t *state);
#endif
int misc_parse_n_args(parser_state_t *state, char **keys, char **args, int n);
void misc_free_n_args(char **args, int n);
char *main_parse_get_raw_value(parser_state_t *state, int *remain);
void misc_parse_reset(parser_state_t *state);
void misc_parse_unescape(char *str, char esc);

#endif



/*
 *  Counts of EmTOS structures
 */

enum {
  EMSTATUSSERVERCLIENTS = uniqueCount("EmStatusServerI")
};
enum {
  EMLINKSERVERS = uniqueCount("EmLinkServerI")
};
enum {
  EMPDCLIENTS = uniqueCount("EmPdClientI")
};
enum {
  EMPDSERVERS = uniqueCount("EmPdServerI")
};
enum {
  EMSOCKETSERVERS = uniqueCount("EmSocketServerI")
};

#endif

