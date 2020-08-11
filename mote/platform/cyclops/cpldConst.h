////////////////////////////////////////////////////////////////////////////
// 
// CENS 
// Agilent
//
// Copyright (c) 2003 The Regents of the University of California.  All 
// rights reserved.
//
// Copyright (c) 2003 Agilent Corporation 
// rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions
// are met:
//
// - Redistributions of source code must retain the above copyright
//   notice, this list of conditions and the following disclaimer.
//
// - Neither the name of the University nor Agilent Corporation nor 
//   the names of its contributors may be used to endorse or promote 
//   products derived from this software without specific prior written 
//   permission.
//
// THIS SOFTWARE IS PROVIDED BY THE REGENTS , AGILENT CORPORATION AND 
// CONTRIBUTORS ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, 
// BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS 
// FOR A PARTICULAR  PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE REGENTS OR
// AGILENT CORPORATION OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, 
// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT 
// NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, 
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
// OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// Contents: This file contains the cpld basic definition
//           and communication. For CPLD detail contact rick below.
//
//          
//          
//
////////////////////////////////////////////////////////////////////////////
//
// $Header: /home/public_repository/root/tenet/mote/platform/cyclops/cpldConst.h,v 1.1 2007-07-03 00:57:48 jpaek Exp $
//
//
//
// Authors : 
//           Mohammad Rahimi mhr@cens.ucla.edu 
//           Rick Baer       rick_baer@agilent.com 
//
////////////////////////////////////////////////////////////////////////////

#ifndef CPLDCONST_H
#define CPLDCONST_H


//states
enum { 
  CPLD_STANDBY=0x35             ,     // standby
  CPLD_RUN_CAMERA               ,     // run camera
  CPLD_CAPTURE_IMAGE            ,     // capture image
  CPLD_CAPTURE_TEST_PATTERN     ,     // generate test image
  CPLD_MCU_ACCESS_SRAM          ,     // direct uP to SRAM access
  CPLD_MCU_ACCESS_FLASH         ,     // direct uP to Flash access
  CPLD_TRANSFER_SRAM_TO_FLASH   ,     // transfer SRAM to Flash
  CPLD_TRANSFER_FLASH_TO_SRAM   ,     // transfer Flash to SRAM
  CPLD_OFF
};

//CPLD opCode
//Defined by rick according to implementation of CPLD.
enum { 
  CPLD_OPCODE_STANDBY                  =0x0,     // standby
  CPLD_OPCODE_RESET                    =0x1,     // reset
  CPLD_OPCODE_RUN_CAMERA               =0x2,     // run camera
  CPLD_OPCODE_CAPTURE_IMAGE            =0x3,     // capture image
  CPLD_OPCODE_CAPTURE_TEST_PATTERN     =0x4,     // generate test image
  CPLD_OPCODE_MCU_ACCESS_SRAM          =0x5,     // direct uP to SRAM access
  CPLD_OPCODE_MCU_ACCESS_FLASH         =0x6,     // direct uP to Flash access
  CPLD_OPCODE_TRANSFER_SRAM_TO_FLASH   =0x7,     // transfer SRAM to Flash
  CPLD_OPCODE_TRANSFER_FLASH_TO_SRAM   =0x9,     // transfer Flash to SRAM
};

struct cpldCommand_s 
{
  uint8_t opcode;
  uint8_t sramBank:4;
  uint8_t flashBank:4;
  uint8_t startPageAddress;
  uint8_t endPageAddress;
}__attribute__((packed));

typedef struct cpldCommand_s cpldCommand_t;

#endif
