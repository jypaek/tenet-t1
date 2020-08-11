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
 * 	        David Zats dzats@ucla.edu
 *          Mohammad Rahimi mhr@cens.ucla.edu
 * History: created 08/01/05
 *
 * cyclopsNeuronM provides the implementation for the cyclopsNeuron component. This is
 * used to ensure that neuron works on the cyclops side.
 */

/**
 * @modified 6/28/2007
 * @author Jeongyeup Paek
 *
 * - disable UART0 here
 * - no need to pass around NEURON_SignalPtr's.
 * - make use of the return values. otherwise, make them void
 * - should signalWrite return len?
 * - hash include
 **/

#include "neuron.h"

module cyclopsNeuronM {
    provides {
        interface StdControl as neuronControl;
        //parameterized interfaces
        interface neuronC[uint8_t id];
    }
    uses {
        //communication over i2c
        interface I2CPacketSlave;
        interface StdControl as I2CStdControl;
    }
}
implementation {

    //The previous module that was written to
    uint8_t prevModule = 0;     // '0' is some dummy value

    //***********************************************************************************
    //****************************Initialization and Termination ************************
    //***********************************************************************************

    command result_t neuronControl.init() {
        //Initialize slave side of I2C
        call I2CStdControl.init();      
        call I2CPacketSlave.setAddress(CYCLOPS_NEURON_ADDRESS, TRUE);
        return SUCCESS;
    }

    command result_t neuronControl.start() {
        call I2CStdControl.start();      
        return SUCCESS;
    }

    command result_t neuronControl.stop() { 
        call I2CStdControl.stop();  
        return SUCCESS;
    }

    //*******************************************************************    
    //********************************Neurorn****************************
    //*******************************************************************    


    //Allows host to read data from cyclops
    command result_t neuronC.neuronSignalRead[uint8_t id](uint8_t len, char *read_buffer) {
        return call I2CPacketSlave.readBufReady(read_buffer, len);
    }

    //*******************************************************************    
    //********************************I2C Part***************************
    //*******************************************************************    

    //Occurs when host writes to the cyclops.
    //Write to the appropriate module, if there is data to be written
    event char *I2CPacketSlave.write(char *data, uint8_t len) {
        //type cast write as NEURON_SignalPtr
        NEURON_SignalPtr write_data = (NEURON_SignalPtr)data;

        //Store last module accessed 
        prevModule = write_data->type;

        //length = 0 packets are used to redirect Neuron, no further action is needed
        if (write_data->length > 0) {
            //Signal appropriate neuron module
            signal neuronC.neuronSignalWrite[prevModule](write_data->length, write_data->data);
        }
        return data;
    }

    //Signals appropriate neuron module when host issues read request
    event result_t I2CPacketSlave.readRequest() {
        //PrevModule contains the last module written to. 
        //The read will occur from that same module.
        signal neuronC.neuronSignalReadReady[prevModule]();
        return SUCCESS;
    }

    //Signals appropriate neuron module when the cyclops has finished reading
    event result_t I2CPacketSlave.readDone(bool success) {
        //PrevModule is the module that the host has finished reading from
        signal neuronC.neuronSignalReadDone[prevModule](success);
        return SUCCESS;
    }

    default event void neuronC.neuronSignalWrite[uint8_t id](uint8_t len, char *data) {}
    default event void neuronC.neuronSignalReadReady[uint8_t id]() {}
    default event void neuronC.neuronSignalReadDone[uint8_t id](result_t success) {}
}

