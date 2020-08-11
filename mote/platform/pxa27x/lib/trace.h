#ifndef __TRACE_H__
#define __TRACE_H__
#include <stdio.h>
#include "dbg_modes.h"

#define TOS_dbg_mode long long
#define DBG_SIM (1ull <<21)

void trace(TOS_dbg_mode mode, const char *format, ...);

unsigned char trace_active(TOS_dbg_mode mode);

void trace_unset();

void trace_set(TOS_dbg_mode mode);

#endif
