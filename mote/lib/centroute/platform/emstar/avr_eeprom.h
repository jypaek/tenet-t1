/* Copyright (c) 2002, Marek Michalkiewicz
   All rights reserved.

   Redistribution and use in source and binary forms, with or without
   modification, are permitted provided that the following conditions are met:

   * Redistributions of source code must retain the above copyright
     notice, this list of conditions and the following disclaimer.
   * Redistributions in binary form must reproduce the above copyright
     notice, this list of conditions and the following disclaimer in
     the documentation and/or other materials provided with the
     distribution.

  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
  POSSIBILITY OF SUCH DAMAGE. */

/* $Id: avr_eeprom.h,v 1.1 2007-11-17 00:55:24 karenyc Exp $ */

/*
   eeprom.h

   Contributors:
     Created by Marek Michalkiewicz <marekm@linux.org.pl>

  EmTOS modifications: Thanos Stathopoulos
 */

#ifndef _INTERNAL_EEPROM_H_
#define _INTERNAL_EEPROM_H_ 1

#include <stddef.h>
#include <inttypes.h>
#include "tos_emstar.h"

// I am putting the implementation inside the header file...nasty...

/** \ingroup avr_eeprom
    Read one byte from EEPROM address \c addr. */

uint8_t eeprom_read_byte (uint8_t *addr)
{
    if (addr!=NULL) {
        return *addr;
    } else { 
        return 0;
    }
}


/** \ingroup avr_eeprom
    Read one 16-bit word (little endian) from EEPROM address \c addr. */

uint16_t eeprom_read_word (uint16_t *addr)
{
    if (addr!=NULL) {
       return *addr;
    } else {
       return 0;
    }
}

/** \ingroup avr_eeprom
    Write a byte \c val to EEPROM address \c addr. */

void eeprom_write_byte (uint8_t *addr, uint8_t val)
{
    if (addr!=NULL) {
      *addr=val;
    }
}

/** \ingroup avr_eeprom
    Read a block of \c n bytes from EEPROM address \c addr to
    \c buf. */

void eeprom_read_block (void *buf, void *addr, size_t n)
{
    if (buf!=NULL && addr!=NULL) {
        memcpy(addr, buf, n);
    }
}


#endif /* _INTERNAL_EEPROM_H_ */
