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
//
////////////////////////////////////////////////////////////////////////////
// Authors : 
//           Ning Xu  nxu@cens.ucla.edu
//           Mohammad Rahimi mhr@cens.ucla.edu
//
// Note:  modify the UCB i2c interface to accommodate the master wait state
//        now slave can force master into wait state by pulling the clock low
////////////////////////////////////////////////////////////////////////////

/**
 * @modified 6/28/2007
 * @author Jeongyeup Paek
 *
 * - no need to pass around NEURON_SignalPtr's.
 * - make use of the return values. otherwise, make them void
 * - should signalWrite return len?
 **/

#include "neuron.h"

//Interface that links all of the modules (activeEye, snap, ect...) to Neuron.
//This allows for communication between the host (mote) and each of those modules.
interface neuronC
{
    //This event occurs when the cyclops is written to by the host (mote)
    //write_packet is a pointer to the packet.
    event void neuronSignalWrite(uint8_t len, char *data);
    
    //This event is signaled when the host (mote) requests a read from a module in the cyclops.
    event void neuronSignalReadReady();

    //This command allows the cyclops to provide data for the host to read.
    //read_buffer is the buffer to be read from
    //length is the number of bytes to be read
    command result_t neuronSignalRead(uint8_t len, char *read_buffer);

    //This event is signaled when the host has read the data from the cyclops.
    //success is true if all of the bytes have been transferred
    event void neuronSignalReadDone(result_t success);
}

