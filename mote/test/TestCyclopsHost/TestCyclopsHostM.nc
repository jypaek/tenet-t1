/*
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
 *          David Zats dzats@ucla.edu
 *          Mohammad Rahimi mhr@cens.ucla.edu
 * History: created 08/10/05
 *
 */
 

/**
 * @modified Feb/16/2008
 * @author Jeongyeup Paek (jpaek@enl.usc.edu)
 *
 * - Simple Test-Cyclops Application for Mica2/Micaz
 **/

#include "neuron.h"
#include "cyclops_query.h"
#include "TestCyclopsMsg.h"

module TestCyclopsHostM {
    provides {
        interface StdControl;
    }
    uses {
        interface Leds;
        
        interface neuronH;
        interface StdControl as neuronControl;

        interface SendMsg;
        interface ReceiveMsg;
    }
}
implementation {
#include "cyclops_query.c"
    
    TOS_Msg msgBuf;         //Message that sends out answers to queries
    TestCyclopsMsg_t* m_tcm;

    //Variables for maintaining state
    uint8_t  m_queryID;     //The id of the query in the struct (0 = no query)
    uint8_t  m_nModule;     //Neuron module (snapN, activeN, etc)
    uint8_t  slaveQueryBuf[TOSH_DATA_LENGTH];
    
    bool sendMore;            //Specifies whether more fragments exist
    task void requestSegmentTask();
    
    /***************************************************************
     ****************Initialization and Termination*****************
     ***************************************************************/
    command result_t StdControl.init() {
        call Leds.init();
        m_queryID = 0;
        m_tcm = (TestCyclopsMsg_t *) msgBuf.data;
        m_tcm->sender = TOS_LOCAL_ADDRESS;
        m_tcm->type = TEST_CYCLOPS_MSG_TYPE_RESPONSE;
        call Leds.yellowOn(); 
        call neuronControl.init();
        return SUCCESS;
    }
    
    command result_t StdControl.start() {
        return call neuronControl.start();
    }
    
    command result_t StdControl.stop() {
        return call neuronControl.stop();
    }
    
    //This task requests a new segment of data
    task void requestSegmentTask() {
        if (m_queryID == 0)
            return;
        if (call neuronH.neuronSignalRead(m_nModule, (char *)m_tcm->data) == FAIL)
            call Leds.redOn();
    }

    event result_t SendMsg.sendDone(TOS_MsgPtr sent, result_t success) {
        if (!success) { //If message was a failure then turn on the red led
            call Leds.redOn();
        } else {        //We are done sending a packet; turn off the green led.
            call Leds.greenOff();
            call Leds.yellowOn();
        }
        //If more data to be sent and query is active request more data and return.       
        if (sendMore && m_queryID)
            post requestSegmentTask();
        else
            m_queryID = 0;
        return SUCCESS;
    }        
 
    //Neuron read done event, pass it to higher layer
    event result_t neuronH.neuronSignalReadDone(uint8_t type, uint8_t len, char *data) {
        cyclops_response_t *cr = (cyclops_response_t *)(data);

        //If something is wrong with message, the total fragment count is 0, or
        //query is inactive, set SendMore to false and go to SendComplete and return
        if ((m_queryID == 0) || (data != (char *)m_tcm->data)) {
            sendMore = FALSE;
            m_queryID = 0;
            return SUCCESS;
        }
//        if (type != cr->type)
  //          call Leds.redOn();

        //Otherwise check to see if there are more packets to be sent
        if (cr->more_left == 1)
            sendMore = TRUE;
        else
            sendMore = FALSE;

        //Turn on the green led to indicate that we are sending a packet
        call Leds.greenOn();
        
        if (call SendMsg.send(0xffff, offsetof(TestCyclopsMsg_t, data) + len, &msgBuf) == FAIL) {
            call Leds.redOn();
        }
        return SUCCESS;
    } 

    //Neuron write done event, pass it to higher layer
    event result_t neuronH.neuronSignalWriteDone(result_t result) {
        if (result == FAIL) {
            call Leds.redOn();
            m_queryID = 0;
        }
        //If we are successful and the query is active, we request the first segment.
        else if (m_queryID)
            post requestSegmentTask();
        return SUCCESS;
    }


    /* This event is signaled when packets are received from the PC/stargate */
    event TOS_MsgPtr ReceiveMsg.receive(TOS_MsgPtr msg) {
        TestCyclopsMsg_t* tmsg = (TestCyclopsMsg_t*)msg->data;

        /* received a query message */
        if (tmsg->type == TEST_CYCLOPS_MSG_TYPE_QUERY) {
            cyclops_query_t *qmsg = (cyclops_query_t *)tmsg->data;

            if (m_queryID != 0) {   // we are busy
                call Leds.redOn();
                return msg;
            }
            if (is_neuron_valid(qmsg->nSignal) == 0) {  // unknown neuron
                // unknown to the host mote....
                call Leds.redOn();
                // but it might still works if cyclops knows about it...
            }

            /* information from TestCyclopsMsg */
            m_queryID = tmsg->qid;
            m_tcm->qid = m_queryID;

            /* information from cyclops_query_t */
            m_nModule = qmsg->nSignal;
            memcpy(slaveQueryBuf, qmsg->data, qmsg->length);

            if (call neuronH.neuronSignalWrite(m_nModule, qmsg->length, slaveQueryBuf) == SUCCESS) {
                call Leds.greenOn();
                call Leds.yellowOff();
            } else {
                m_queryID = 0;
                call Leds.redOn();
            }
        }
        else if (tmsg->type == TEST_CYCLOPS_MSG_TYPE_CANCEL) {
            if (m_queryID == tmsg->qid)
                m_queryID = 0;
            else
                call Leds.redOn();
        }         
        else {
            call Leds.redOn();
        }
        return msg;
    }
}

