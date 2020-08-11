// $Id: hardware.h,v 1.1 2007-09-10 21:45:26 karenyc Exp $

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
 */
#ifndef __HARDWARE_H__
#define __HARDWARE_H__

#ifdef EMSTAR_NO_KERNEL
#include <emtos_i.h> 
#endif

// work around nesc automatic platform definition
#ifndef PLATFORM_PC
#define PLATFORM_PC
#endif

#undef STATUS_DBG

// Allow use of atomic in C code
#undef atomic

#include <stdio.h>
#include <string.h>
//#include <time.h>
#include <signal.h>
#ifdef __HAVE_GCC_4
#include </usr/include/linux/stddef.h>
#endif
//#include "nido.h"


//#include "events.h"
#include <local_types.h>
#include <sync_structs.h>
#include <link_structs.h>


#include "tos_emstar.h"
#include "hardware.nido.h"

// We need norace for tossim to declare tossim's state variables
// as norace (they are in "async" handlers, but tossim has no true
// concurrency)
#undef norace

#define TOS_INTERRUPT_HANDLER(name, params) \
void name##_interrupt params __attribute__((C))

#define TOS_SIGNAL_HANDLER(signame, params) \
void signame##_signal params __attribute__((C))

#define TOS_ISSUE_INTERRUPT(name) \
name##_interrupt

#define TOS_ISSUE_SIGNAL(signame) \
signame##_signal

#ifndef EMSTAR_NO_KERNEL
#include "dbg.h"
extern norace TOS_dbg_mode dbg_modes;
#endif


norace TOS_state_t tos_state;

void TOSH_wait_250ns()
{
}

void TOSH_uwait(int u_sec)
{
}

void TOSH_sleep()
{
}

// atomic statement runtime support
// For nido, nothing needs to be done...

typedef uint8_t __nesc_atomic_t;

inline __nesc_atomic_t __nesc_atomic_start(void) __attribute__((spontaneous))
{
  return 0;
}

inline void __nesc_atomic_end(__nesc_atomic_t oldSreg) __attribute__((spontaneous))
{
}

inline void __nesc_enable_interrupt() 
{
}

enum {
  TOSH_ADC_PORTMAPSIZE = 255,
};

//".c" files needed for the simulator

#include "hpl.c"
#include "hardware.c"
#include "fplist.c"

//variable needed for avr/pgmspace.h to init/load inst rom
char* memcpy_filename;

#endif /* __HARDWARE_H__ */
