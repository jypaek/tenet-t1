/*                                    tab:4
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
 * Authors: Jason Hill, David Gay, Philip Levis, Chris Karlof
 * Date last modified:  6/25/02
 *
 */

// Message format


/**
 * @author Jason Hill
 * @author David Gay
 * @author Philip Levis
 * @author Chris Karlof
 */

/* Minor modifications by Jeongyeup Paek to include prototypes and
 * other constants for Tenet
 */


#ifndef _TOSMSG_H_
#define _TOSMSG_H_

#include <stdio.h>
#include <sys/types.h>
#include <stddef.h>

#ifdef __CYGWIN__
#include <windows.h>
#include <io.h>
#else
#include <stdint.h>
#endif


//#define DEBUG_SEND_TOS_MSG 1

#ifndef TOS_BCAST_ADDR
#define TOS_BCAST_ADDR 0xffff
#endif
#ifndef TOS_UART_ADDR
#define TOS_UART_ADDR 0x007e
#endif
#ifndef TOS_DEFAULT_GROUP
#define TOS_DEFAULT_GROUP 0x7d
#endif
#ifndef TOSH_DATA_LENGTH
#define TOSH_DATA_LENGTH 114
#endif

#ifdef OLD_TOS_MSG_FORMAT
typedef struct TOS_Msg {
    uint16_t addr;
    uint8_t  type;
    uint8_t  group;
    uint8_t  length;
    uint8_t  data[TOSH_DATA_LENGTH];
} __attribute__ ((packed)) TOS_Msg;
#else
typedef struct TOS_Msg
{
  uint8_t length;
  uint8_t fcfhi;
  uint8_t fcflo;
  uint8_t dsn;
  uint16_t destpan;
  uint16_t addr;
  uint8_t type;
  uint8_t group;
  int8_t data[TOSH_DATA_LENGTH];
} __attribute__ ((packed)) TOS_Msg;
#endif

 
/* dump the packet in hex */
void fdump_packet(FILE *fptr, unsigned char *packet, int len);


/* send_TOS_Msg :
    - given the payload data *msg, constructs a TOS_Msg
      and sends the packet to the socket id given by "fd". */
void send_TOS_Msg(int fd, const void *msg, int len, uint8_t type, 
                  uint16_t addr, uint8_t group);

#endif

