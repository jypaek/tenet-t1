/*
* "Copyright (c) 2006~2007 University of Southern California.
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
 * Test a task on the mote internally without disseminating the task 
 * from a master.
 *
 * TASK_TESTING must be defined to use this file.
 * For testing purposes, a predefined task can be automatically installed 
 * approximately one second after booting a mote. The task definition must 
 * appear in this file.
 *
 * @author Ben Greenstein
 * @author August Joki
 *
 * @author Jeongyeup Paek
 * @modified Mar/11/2008
 **/
 

#ifdef TASK_TESTING

#include "element_map.h"
#include "tenet_task.h"

module TenetTaskTestM {
    provides {
        interface StdControl;
        interface TRD_Transport;
    }
    uses {
        interface Timer;
    }
}
implementation {

    command result_t StdControl.init(){ return SUCCESS; }
    command result_t StdControl.start(){
        call Timer.start(TIMER_ONE_SHOT, 5000);
        return SUCCESS; 
    }
    
    TOS_Msg m;
    uint16_t tid = 6;
    uint16_t src = 1;

    void inject_task(TOS_MsgPtr mPtr){
        signal TRD_Transport.receive(tid, src, m.data, m.length);
    }

#include "element_construct.c"
#include "task_construct.c"

    event result_t Timer.fired(){
#ifdef TEST_BLINK
        tid++;
        m.length = blink_packet(m.data);
        inject_task(&m);
#elif TEST_CNT_TO_LEDS_AND_RFM
        tid++;
        m.length = cnt_to_leds_and_rfm_packet(m.data);
        inject_task(&m);
#elif TEST_SENSE_TO_RFM
        tid++;
        m.length = sense_to_rfm_packet(m.data);
        inject_task(&m);
#elif TEST_REBOOT
        tid++;
        m.length = reboot_packet(m.data);
        inject_task(&m);
#else
        tid++;
        m.length = blink_packet(m.data);
        inject_task(&m);
#endif
        return SUCCESS;
    }

    command result_t StdControl.stop(){ return SUCCESS; }

}

#endif  // TASK_TESTING

