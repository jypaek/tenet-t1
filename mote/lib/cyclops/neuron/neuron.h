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
// Contents: To enable dumping a location of memory into serial port
//           
//           
//          
//
////////////////////////////////////////////////////////////////////////////
//
// $Header: /home/public_repository/root/tenet/mote/lib/cyclops/neuron/neuron.h,v 1.2 2007-08-06 05:06:50 jpaek Exp $
//
// Authors : 
//           Mohammad Rahimi mhr@cens.ucla.edu
//
////////////////////////////////////////////////////////////////////////////

/**
 * @modified 6/29/2007
 * @author Jeongyeup Paek
 **/

#ifndef NEURON_H
#define NEURON_H

#define CYCLOPS_NEURON_ADDRESS 100

//Structure that defines the packets for communication over Neuron.
typedef struct NEURON_Signal {
    uint8_t type;       // neuron module type
    uint8_t length;     // length of data[]. (8bit should be enough)
    char data[0];
} NEURON_Signal;

typedef NEURON_Signal *NEURON_SignalPtr;

#define NEURON_HEADER offsetof(NEURON_Signal, data)

// look in neuron_map.h for enumeration of modules used with neuron.    
    
#endif

