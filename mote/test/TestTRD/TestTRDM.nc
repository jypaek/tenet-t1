/**
 * "Copyright (c) 2006-2009 University of Southern California.
 * All rights reserved.
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose, without fee, and without written
 * agreement is hereby granted, provided that the above copyright
 * notice, the following two paragraphs and the author appear in all
 * copies of this software.
 *
 * IN NO EVENT SHALL THE UNIVERSITY OF SOUTHERN CALIFORNIA BE LIABLE TO
 * ANY PARTY FOR DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL
 * DAMAGES ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS
 * DOCUMENTATION, EVEN IF THE UNIVERSITY OF SOUTHERN CALIFORNIA HAS BEEN
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * THE UNIVERSITY OF SOUTHERN CALIFORNIA SPECIFICALLY DISCLAIMS ANY
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.  THE SOFTWARE
 * PROVIDED HEREUNDER IS ON AN "AS IS" BASIS, AND THE UNIVERSITY OF
 * SOUTHERN CALIFORNIA HAS NO OBLIGATION TO PROVIDE MAINTENANCE,
 * SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS."
 *
 **/

/**
 * TestTRD application module for testing TRD (Tiered Reliable Dissemination)
 * - when this node receives a disseminated TRD message packet, 
 *   it sends the packet to UART.
 * - ifdef TRD_SEND_ENABLED
 *   - this node sends out (originates) a TRD message dissemination
 * - this supports TOSSIM
 *
 * @date Nov/17/2007
 * @author Jeongyeup Paek (jpaek@usc.edu)
 **/

module TestTRDM {
    provides interface StdControl;
    uses {
        interface Timer;
        interface SendMsg as UartSendMsg;
        interface TRD;
    #ifdef TRD_SEND_ENABLED
        interface TRD_Send;
    #endif
    }
}
implementation {

    uint16_t state;
    TOS_Msg myMsgBuf;
    TOS_MsgPtr myMsg;
    uint8_t mylen;
    bool sendBusy;
    uint16_t recvcnt;

    command result_t StdControl.init(){
        state = 0;
        sendBusy = FALSE;
        myMsg = &myMsgBuf;
        recvcnt = 0;
        return SUCCESS;
    }
    command result_t StdControl.start(){
    #ifdef TRD_SEND_ENABLED
        if (TOS_LOCAL_ADDRESS == 1) {
            call Timer.start(TIMER_REPEAT, 10000);
        } else if (TOS_LOCAL_ADDRESS == 3) {
            call Timer.start(TIMER_REPEAT, 10000);
        }
    #endif
        return SUCCESS;
    }
    command result_t StdControl.stop(){return SUCCESS;}

#ifdef TRD_SEND_ENABLED
    task void send_packet() {
        uint8_t len = 0;
        uint8_t *dataptr;

        if (sendBusy) return;

        dataptr = (uint8_t *)call TRD_Send.getBuffer(myMsg, &len);
        dataptr[0] = state;
        dataptr[1] = state;
        len = 2;

        dbg(DBG_USR1, "APP Sending Packet: %d\n\n", state);
        if (call TRD_Send.send(myMsg, len)) {
            sendBusy = TRUE;
            state++;
        } else {
            dbg(DBG_USR1, "radio busy: \n");
            myMsg = NULL;
        }
        return;
    }
#endif

    event result_t Timer.fired() {
    #ifdef TRD_SEND_ENABLED
        if ((TOS_LOCAL_ADDRESS == 1) &&
            (state < 10)) {
            post send_packet();
        }
        else if ((TOS_LOCAL_ADDRESS == 3) &&
            ((state > 10) && (state < 20))) {
            post send_packet();
        }
        else
            state++;
    #endif
        return SUCCESS;
    }

#ifdef TRD_SEND_ENABLED
    event result_t TRD_Send.sendDone(TOS_MsgPtr msg, result_t success) {
        sendBusy = FALSE;
        return SUCCESS;
    }
#endif

    task void send_to_uart() {
        if (!call UartSendMsg.send(TOS_UART_ADDR, mylen, myMsg)) {
            post send_to_uart();
        }
    }

    event void TRD.receive(uint16_t origin, uint8_t* data, uint16_t len) {
    #ifndef PLATFORM_PC 
        struct TestTRD_UartMsg *umsg;
    #endif
        dbg(DBG_USR1, "APP Received packet %d: from %d\n\n", ((uint8_t *)data)[0], origin);
        recvcnt++;
    #ifndef PLATFORM_PC 
        if (sendBusy) return;
        sendBusy = TRUE;
        
        umsg = (struct TestTRD_UartMsg *)myMsg->data;
        umsg->id = TOS_LOCAL_ADDRESS;
        umsg->recvcnt = recvcnt;
        umsg->origin = origin;
        memcpy(umsg->data, data, len);
        mylen = len + offsetof(struct TestTRD_UartMsg, data);
        post send_to_uart();
    #endif
        return;
    }

    event result_t UartSendMsg.sendDone(TOS_MsgPtr msg, result_t success) {
        sendBusy = FALSE;
        return SUCCESS;
    }
}
    
