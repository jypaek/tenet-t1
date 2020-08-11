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

//This interface allows the host mote to communicate with the cyclops over Neuron.

/**
 * @modified 6/29/2007
 * @author Jeongyeup Paek (jpaek@enl.usc.edu)
 *
 * - neuronSignalWrite command modified so that it takes 'type', 'len', and 'data'
 *   instead of 'NEURON_SignalPtr' as the argument.
 *   This is done so that any upper layer does not need to know the communication
 *   details of neuron. This interface should abstract the neuron, and the users
 *   of this interface should not need to know 'NEURON_SignalPtr' structure.
 * - changed all 'length' fields from uint16_t to uint8_t.
 *   limit data length to 128 bytes.
 **/
 
interface neuronH
{
    //This command requests a segment of code to be read from the appropriate module in
    //the cyclops.
    //type specifies the module 
    //read_buffer is a pointer to the buffer to be filled  
    command result_t neuronSignalRead(uint8_t type, char *read_buffer);
   
    //This event is signaled when the read request has completed. 
    //type is the module from which the requested segment was read
    //read_buffer is a pointer to the buffer where the requested segment was stored.
    event result_t neuronSignalReadDone(uint8_t type, uint8_t len, char *read_buffer);

    //This command allows the host (mote) to write to a cyclops module over Neuron. 
    //command result_t neuronSignalWrite(NEURON_SignalPtr write_packet);
    /**
     * @arg type  is the cyclops module (snapN, activeN, etc)
     * @arg data  contains data that the host mote is writing to the module 'type'.
     * @arg len   is the length of data
     **/
    command result_t neuronSignalWrite(uint8_t type, uint8_t len, char *data);

    //This event is signaled when the host has written to the cyclops. 
    //result specifies whether or not write was successful.
    event result_t neuronSignalWriteDone(result_t result);
}

