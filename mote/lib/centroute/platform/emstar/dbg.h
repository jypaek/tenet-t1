// $Id: dbg.h,v 1.1 2007-11-17 00:55:24 karenyc Exp $

/*									tab:4
 * "Copyright (c) 2000-2003 The Regents of the University  of California.  
 * All rights reserved.
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose, without fee, and without written agreement is
 * hereby granted, provided that the above copyright notice, the following
 * two paragraphs and the author appear in all copies of this software.
 * 
 * IN NO EVENT SHALL THE UNIVERSITY OF CALIFORNIA BE LIABLE TO ANY PARTY FOR
 * DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES ARISING OUT
 * OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN IF THE UNIVERSITY OF
 * CALIFORNIA HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 * 
 * THE UNIVERSITY OF CALIFORNIA SPECIFICALLY DISCLAIMS ANY WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE.  THE SOFTWARE PROVIDED HEREUNDER IS
 * ON AN "AS IS" BASIS, AND THE UNIVERSITY OF CALIFORNIA HAS NO OBLIGATION TO
 * PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS."
 *
 * Copyright (c) 2002-2003 Intel Corporation
 * All rights reserved.
 *
 * This file is distributed under the terms in the attached INTEL-LICENSE     
 * file. If you do not find these files, copies can be found by writing to
 * Intel Research Berkeley, 2150 Shattuck Avenue, Suite 1300, Berkeley, CA, 
 * 94704.  Attention:  Intel License Inquiry.
 */
/*
 *
 * Authors:		David Gay, Philip Levis (from work by Mike Castelle), Nelson Lee
 * Date last modified:  6/25/02
 *
 */

 /*
 *   FILE: dbg.h
 * AUTHOR: pal
 *  DESCR: Run-time configuration of debug output in FULLPC mode. 
 *
 * Debug output determined by DBG environment variable. dbg_modes.h has
 * definitions of the settings possible. One can specify multiple debugging
 * outputs by comma-delimiting (e.g. DBG=sched,timer). Compiling with
 * NDEBUG defined (e.g. -DNDEBUG) will stop all of the debugging
 * output, will remove the debugging commands from the object file.
 *
 * example usage: dbg(DBG_TIMER, "timer went off at %d\n", time);
 *
 */

/**
 * @author David Gay
 * @author Philip Levis (from work by Mike Castelle)
 * @author Nelson Lee
 * @author pal
 */

#ifndef DBG_H
#define DBG_H

	#ifndef EMSTAR_NO_KERNEL

#include "dbg_modes.h"
/* We're in FULLPC mode, and debugging is not turned off */
		#if (defined(PLATFORM_EMSTAR) && !defined(NDEBUG))

#include <stdio.h>
#include <stdarg.h>
			#if !defined(PLATFORM_EMSTAR)
	#include "nido.h"
			#endif //!defined(PLATFORM_EMSTAR)

//#include "GuiMsg.h"

typedef struct dbg_mode {
	char* d_name;
	unsigned long long d_mode;
} __attribute__ ((packed)) TOS_dbg_mode_names;

TOS_dbg_mode dbg_modes = 0;

static bool dbg_active(TOS_dbg_mode mode) 
{ 
  return (dbg_modes & mode) != 0;
}

static void dbg_add_mode(const char *mode);
static void dbg_add_modes(const char *modes);
static void dbg_init(void);
static void dbg_help(void);

			#if defined(PLATFORM_EMSTAR)
#define dbg(lev, args...) \
   do { dbg_real((lev), __FUNCTION__, args); } while (0)
#define dbg_clear(lev, args...) \
   do { dbg_real((lev), __FUNCTION__, args); } while (0)

void dbg_real(int lev, const char *func, const char *format, ...) 
   __attribute__ ((format (printf, 3, 4))); 
			#else 
static void dbg(TOS_dbg_mode mode, const char *format, ...) 
{ 
	
  DebugMsgEvent ev;
  if (dbg_active(mode)) {
    va_list args;
    // XXX MDW - used to be printf 
    va_start(args, format); 
    if (!(mode & DBG_SIM)) {
      vsnprintf(ev.debugMessage, sizeof(ev.debugMessage), format, args);
      //sendTossimEvent(NODE_NUM, AM_DEBUGMSGEVENT, tos_state.tos_time, &ev);
    }
    // XXX MDW - used to be vprintf 
    vfprintf(stdout, format, args);
    va_end(args);
  }    
}

static void dbg_clear(TOS_dbg_mode mode, const char *format, ...) 
{
/*	
  DebugMsgEvent ev;
  if (dbg_active(mode)) {
    va_list args;
    va_start(args, format);
    if (!(mode & DBG_SIM)) {
      vsnprintf(ev.debugMessage, sizeof(ev.debugMessage), format, args);
      //sendTossimEvent(NODE_NUM, AM_DEBUGMSGEVENT, tos_state.tos_time, &ev);
    }
    // XXX MDW - used to be vprintf 
    vfprintf(stdout, format, args);
    va_end(args);
  }    
  */
}
			#endif 

		#else 
/* No debugging */

#define dbg(...) { }
#define dbg_clear(...) { }
#define dbg_add_mode(...) { }
#define dbg_add_modes(...) { }
#define dbg_init() { }
#define dbg_help() { }
#define dbg_active(x) (FALSE)

//static inline void dbg(TOS_dbg_mode mode, const char *format, ...) { }
//static inline void dbg_clear(TOS_dbg_mode mode, const char *format, ...) { }
//static inline bool dbg_active(TOS_dbg_mode mode) { return FALSE; }
//static inline void dbg_add_mode(const char *mode) { }
//static inline void dbg_add_modes(const char *modes) { }
//static inline void dbg_init(void) { }
//static inline void dbg_help(void) { }
		#endif
	#else
#define dbg_clear(...) { }
//#include <devel/emstar_sockets/emtos_i.h> 
	#endif
#endif /* DBG_H */
