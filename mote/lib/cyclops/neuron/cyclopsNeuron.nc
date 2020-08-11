/*
 *
 * Copyright (c) 2005 The Regents of the University of California.  All 
 * rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 *
 * - Neither the name of the University nor the names of its
 *   contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS''
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
 * PARTICULAR  PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE REGENTS OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 *
 * Authors: Shaun Ahmadian
 *	        David Zats dzats@ucla.edu
 *          Mohammad Rahimi mhr@cens.ucla.edu
 * History: created 08/01/05
 *
 * cyclopsNeuron provides a parameterized interface to enable communication between
 * modules in the cyclops. These modules (activeEye, snap, ect..) are all linked to
 * cyclopsNeuron.
 */

configuration cyclopsNeuron {
    provides {
        interface StdControl as neuronControl;
        //parameterized interface that allows multiple modules to connect
        interface neuronC[uint8_t id];
    }
}
implementation {
    components cyclopsNeuronM, I2CPacketSlaveC;

    neuronC = cyclopsNeuronM;
    neuronControl = cyclopsNeuronM;

    //communication between cyclops and mote is doen over I2C
    cyclopsNeuronM.I2CPacketSlave -> I2CPacketSlaveC.I2CPacketSlave;
    cyclopsNeuronM.I2CStdControl -> I2CPacketSlaveC.StdControl;
}
