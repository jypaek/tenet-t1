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
 * hostNeuronM is the implementation of hostNeuron. It provides the host (mote)
 * with the ability to send to the cyclops over Neuron.
 */

#include "I2C.h"
#include "neuron.h"

module hostNeuronM {
    provides {
        interface StdControl as neuronControl;
        //this interface allows the application on the mote to use neuron.
        interface neuronH;
    }

    uses {
        //this interface sends packets over I2C.
        interface I2CPacketMaster;
        interface StdControl as I2CStdControl; 
    }
}
implementation {
    //This enumeration provides all of the possible m_states of hostNeuronM
    enum {
        IDLE,
        SEND,
        RECEIVE,
        REPOSITION
    };

    //Variables used for reading
    char* m_rx_buf;               //pointer to buffer to store data from cyclops 
    uint8_t mtype = 0;            //last destination module

    NEURON_Signal *sig_msg;       //packet sent over Neuron for repositioning
    char buf[I2C_MAX_PACKETSIZE]; //buffer space for writing packets
    
    uint8_t m_state = IDLE;     //variable containing current m_state



    //*******************************************************************    
    //******************Initialization and Termination*******************
    //*******************************************************************    
    command result_t neuronControl.init() {
        //Initialize host-side of I2C
        call I2CStdControl.init();      
        
        sig_msg = (NEURON_Signal *)buf;
        return SUCCESS;
    }

    command result_t neuronControl.start() {
        //Start host-side of I2C
        call I2CStdControl.start();      
        return SUCCESS;
    }

    command result_t neuronControl.stop() {
        //Stop host-side of I2C
        call I2CStdControl.stop();      
        return SUCCESS;
    }

    //*******************************************************************    
    //********************************Neuron*****************************
    //*******************************************************************    

    //neuronH.neuronSignalRead
    //used to read data from a cyclops module. 
    //The module being snapN, activeEyeN, etc.
    command result_t neuronH.neuronSignalRead(uint8_t type, char *read_buffer) {
        //If neuron is busy, then fail.
        if (m_state!=IDLE) return FAIL;

        //Store variables
        m_rx_buf = read_buffer;

        //If we are not currently positioned to read from proper module, reposition
        if (mtype != type) {
            //update m_state
            m_state = REPOSITION;

            //store proper values in reposition packet
            sig_msg->type = type;
            sig_msg->length = 0; 

            //write reposition packet
            call I2CPacketMaster.writePacket(offsetof(NEURON_Signal, data), (char *)sig_msg);
        }
        else {
            //If we are already pointing to the right module, read data	
            m_state = RECEIVE;

            //Read packet from Neuron
            call I2CPacketMaster.readPacket(m_rx_buf);
        }
        return SUCCESS;
    }

    //neuronH.neuronSignalWrite
    //used to transmit a packet over Neuron from the mote to the appropriate
    //module in the cyclops. This is done over I2C.
    //command result_t neuronH.neuronSignalWrite(NEURON_SignalPtr write_packet) {
    command result_t neuronH.neuronSignalWrite(uint8_t type, uint8_t len, char *data) {
        uint8_t length;
        
        //If Neuron is busy, then fail.
        if (m_state != IDLE) return FAIL;

        //Otherwise set m_state to SEND
        m_state = SEND;

        //Store destination module
        mtype = type;

        //Construct the NEURON_Signal packet
        sig_msg->type = type;
        sig_msg->length = len;
        memcpy(sig_msg->data, data, len);
        
        // total length of the packet to write to I2C
        length = offsetof(NEURON_Signal, data) + len;
        
        //Send packet over Neuron
        call I2CPacketMaster.writePacket(length, (char *)sig_msg);
        return SUCCESS;
    }

    //*******************************************************************    
    //********************************I2C Part***************************
    //******************************************************************* 

    //When data has been read from the cyclops, send it to the application using hostNeuron.       
    //Remember that I2CPacketMaster does not know about mtype (snapN, activeN, etc)
    event result_t I2CPacketMaster.readPacketDone(char len, char *data) {        
        //set m_state to idle
        m_state = IDLE;

        //signal application using hostNeuron.
        return (signal neuronH.neuronSignalReadDone(mtype, len, data));
    }

    //When data has been written to the cyclops, take appropriate action
    //based upon current m_state.
    event result_t I2CPacketMaster.writePacketDone(result_t result) {
        //If failed to write     
        if (result == FAIL) {
            //If we were sending data, inform higher layer
            if (m_state == SEND)
                signal neuronH.neuronSignalWriteDone(FAIL);
            return FAIL;
        }

        //Action determined based upon the current m_state
        switch (m_state) {
            case SEND:      
                //If packet has been sent, signal the application using hostNeuron and set state to 
                //idle.
                m_state = IDLE;
                signal neuronH.neuronSignalWriteDone(SUCCESS);
                break;
            case REPOSITION:
                //If we just repositioned Neuron, update module, set the state to receive, and begin obtaining 
                //the data from the cyclops
                mtype = sig_msg->type;

                m_state = RECEIVE;
                call I2CPacketMaster.readPacket(m_rx_buf);
                break;
            default: 
                //realy should not be here
                return FAIL;
        }

        return SUCCESS;
    }
}

