// $Id: dbg.c,v 1.1 2007-11-17 00:55:24 karenyc Exp $

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
 * Authors:		Phil Levis (derived from work by Mike Castelle)
 *
 *
 */

/*
 *   FILE: dbg.c
 * AUTHOR: pal
 *  DESCR: Variables and initialization of DBG routines.
 */

#if defined(PLATFORM_PC) && !defined(NDEBUG) && !defined(PLATFORM_EMSTAR)

static TOS_dbg_mode_names dbg_nametab[] = {
  DBG_NAMETAB
};

void dbg_add_mode(const char *name) {
  int cancel;
  TOS_dbg_mode_names *mode;
  
  if (*name == '-') {
    cancel = 1;
    name++;
  }
  else
    cancel = 0;
  
  for (mode = dbg_nametab; mode->d_name != NULL; mode++)
    if (strcmp(name, mode->d_name) == 0)
      break;
  if (mode->d_name == NULL) {
    fprintf(stderr, "Warning: Unknown debug option: "
	    "\"%s\"\n", name);
    return;
  }
  
  if (cancel)
    dbg_modes &= ~mode->d_mode;
  else
    dbg_modes |= mode->d_mode;
}

void dbg_add_modes(const char *modes) {
  char env[256];
  char *name;
  
  strncpy(env, modes, sizeof(env));
  for (name = strtok(env,","); name; name = strtok(NULL, ","))
    dbg_add_mode(name);
}

void dbg_init(void) {
  const char *dbg_env;

  dbg_modes = DBG_NONE;
  
  dbg_env = getenv(DBG_ENV);
  if (!dbg_env) {
    dbg_modes = DBG_DEFAULT;
    return;
  }
  
  dbg_add_modes(dbg_env);
}

void dbg_help(void) {
  int i = 0;
  printf("Known dbg modes: ");

  while (dbg_nametab[i].d_name != NULL) {
    printf("%s", dbg_nametab[i].d_name);
    if (dbg_nametab[i + 1].d_name != NULL) {
      printf(", ");
    }
    i++;
  }

  printf("\n");
}
#endif //PLATFORM_PC
