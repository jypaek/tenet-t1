////////////////////////////////////////////////////////////////////////////
//
// CENS
//
// Copyright (c) 2003 The Regents of the University of California.  All 
// rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions
// are met:
//
// - Redistributions of source code must retain the above copyright
//   notice, this list of conditions and the following disclaimer.
//
// - Neither the name of the University nor the names of its
//   contributors may be used to endorse or promote products derived
//   from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS''
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
// THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
// PARTICULAR  PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE REGENTS OR
// CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
// EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
// PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
// PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
// OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
//
// Purpose: The purpose of this functionality is keep all protocol-related 
//          declarations in a single header file.
//
////////////////////////////////////////////////////////////////////////////

#ifndef _PROTOCOLS_H
#define _PROTOCOLS_H

#ifndef TOSH_DATA_LENGTH
#define TOSH_DATA_LENGTH 120
#endif

enum {
  TASK_TYPE=1,
  DATA_TYPE,
};


typedef struct DseHeader_s
{
  uint16_t   m_uiSeq;
  uint16_t   m_uiSrcAddr;
  uint8_t    m_uiType;
  uint8_t    m_uiLen;
  uint16_t   m_resetcount;
  int64_t    m_timestamp;
  char       m_pData[0];
} __attribute__ ((packed)) DseHeader_t;

typedef struct DsePacket_s
{
  DseHeader_t hdr;
  char data[TOSH_DATA_LENGTH - sizeof(DseHeader_t)];
} __attribute__ ((packed)) DsePacket_t;


/*
 * end of general dse definitions
 *
* the following definitions are specific to applications that use dse
*/

// maintain backwards compatibility with names used in ess application
// should really fix ess application to use the definitions provided by the
// dse component
typedef DseHeader_t EssHeader_t;
typedef DsePacket_t EssPacket_t;

// extra configuration specific ESS application
typedef enum {
  SENSOR_DATA,
  TOPO_DATA,
  CONFIG_DATA 
} sourcedata_t;

//define multiplex/demux types for multihop 0-256 (8 bit field)
typedef enum {
  TEST_1 = 0x01,
  TEST_2,
  TEST_3,
  TIMESYNC_APP,
  MULTIHOP_DSE,
  MULTIHOP_SYMPATHY
} app_types_t;

#endif
