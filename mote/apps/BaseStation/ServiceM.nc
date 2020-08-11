/*
* "Copyright (c) 2006 University of Southern California.
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
*/

/**
 * Time Forwarder
 *
 * This component receives a query from the master through the UART
 * about the base station's current time and other time
 * synchronization-related information. It sends a reply to the
 * master through the UART.
 *
 * @author Jeongyeup Paek
 * @modified 3/1/2007
 **/


#include "BaseStation.h"

module ServiceM {
    provides {
        interface StdControl;
    }
    uses {
        interface SendMsg as ServiceResponseSend;
        interface ReceiveMsg as ServiceRequestReceive;

    #ifdef GLOBAL_TIME
        interface GlobalTime;
        interface LocalTime;
        interface LocalTimeInfo;
        interface TimeSyncInfo;
    #endif
    #if defined(PLATFORM_TELOSB) || defined(PLATFORM_MICAZ) || defined(PLATFORM_IMOTE2)
        interface CC2420Control as RadioControl;
    #elif defined(PLATFORM_MICA2) || defined(PLATFORM_MICA2DOT)
        interface CC1000Control as RadioControl;
    #endif
    }
}
implementation
{
    bool        sendbusy;
    TOS_Msg     myMsg;
    BaseStationServiceMsg *m_bsmsg;

    command result_t StdControl.init() {
        sendbusy = FALSE;
        myMsg.group = TOS_AM_GROUP;
        m_bsmsg = (BaseStationServiceMsg *) myMsg.data;
        m_bsmsg->tid = 0;
        m_bsmsg->type = 0;
        return SUCCESS;
    }
    command result_t StdControl.start() { return SUCCESS; }
    command result_t StdControl.stop() { return SUCCESS; }

    task void ServiceResponseSendTask() {
        uint8_t length = offsetof(BaseStationServiceMsg, data);
        if (!sendbusy) return;
        
        if (m_bsmsg->type == BS_SERVICE_TIME)
            length += sizeof(bs_timeResponseMsg);
        else if (m_bsmsg->type == BS_SERVICE_ID)
            length += sizeof(bs_idMsg);
        else if (m_bsmsg->type == BS_SERVICE_POWER)
            length += sizeof(bs_powerMsg);

        if (!call ServiceResponseSend.send(TOS_LOCAL_ADDRESS, length, &myMsg)) {
            post ServiceResponseSendTask();
        }
    }

    event result_t ServiceResponseSend.sendDone(TOS_MsgPtr msg, result_t success) {
        if (success) sendbusy = FALSE;
        else post ServiceResponseSendTask();
        return SUCCESS;
    }

    event TOS_MsgPtr ServiceRequestReceive.receive(TOS_MsgPtr msg) {
        BaseStationServiceMsg *r_bssmsg = (BaseStationServiceMsg *) msg->data;
        if(!sendbusy) {
        
            m_bsmsg->tid = r_bssmsg->tid;
            m_bsmsg->type = r_bssmsg->type;

            if (r_bssmsg->type == BS_SERVICE_TIME) {
                bs_timeResponseMsg *tmsg = (bs_timeResponseMsg *) m_bsmsg->data;
            #ifdef GLOBAL_TIME
                bs_timeRequestMsg *reqmsg = (bs_timeRequestMsg *) r_bssmsg->data;
                uint32_t gtime, offset;
                gtime = call LocalTime.read();
                offset = call LocalTimeInfo.msToTicks(reqmsg->time * 1000); //sec->ms
                gtime += offset;    // requested time, in local ticks
                if (!call GlobalTime.local2Global(&gtime))
                    gtime = 0;

                tmsg->time = gtime;
                tmsg->localfreq = call LocalTimeInfo.getClockFreq();
                tmsg->root = call TimeSyncInfo.getRootID();
                tmsg->skew = call TimeSyncInfo.getSkew();
            #else
                tmsg->time = 0;
                tmsg->localfreq = 0;
                tmsg->root = 0;
                tmsg->skew = 0;
            #endif
                
                sendbusy = TRUE;
            }
            else if (r_bssmsg->type == BS_SERVICE_ID) {
                bs_idMsg *imsg = (bs_idMsg *) m_bsmsg->data;
                imsg->base_id = TOS_LOCAL_ADDRESS;

                sendbusy = TRUE;
            }
            else if (r_bssmsg->type == BS_SERVICE_POWER) {
                bs_powerMsg *reqmsg = (bs_powerMsg *) r_bssmsg->data;
                bs_powerMsg *pmsg = (bs_powerMsg *) m_bsmsg->data;
               
            #if defined(PLATFORM_TELOSB) || defined(PLATFORM_MICAZ) || defined(PLATFORM_IMOTE2) 
                if ((reqmsg->base_power >= 3) && (reqmsg->base_power <= 31))
            #elif defined(PLATFORM_MICA2) || defined(PLATFORM_MICA2DOT)
                if ((reqmsg->base_power >= 1) && (reqmsg->base_power <= 0xff))
            #endif
                    call RadioControl.SetRFPower(reqmsg->base_power);
                pmsg->base_power = (uint16_t) call RadioControl.GetRFPower();

                sendbusy = TRUE;
            }

            if (sendbusy)
                post ServiceResponseSendTask();
        }
        return msg;
    }
}   

