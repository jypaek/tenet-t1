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
 * Reboots the node when called.
 * Ment to be used only as a last resort.
 * All tasks are lost.
 *
 * @author August Joki
 *
 * IMPORTANT NOTE:
 * Should be used with 'wait()' prepended in a task (eg. 'wait(3000,0)->reboot()')
 * so that reboot task can be disseminated before nodes reboot.
 *
 * @author Jeongyeup Paek (jpaek@usc.edu)
 * @modified Oct/9/2009
 **/

#include "tenet_task.h"

module Reboot {
    provides {
        interface Element;
    }
    uses {
        interface TenetTask;
        interface Memory;
    #if defined (PLATFORM_IMOTE2)
        interface Reset;
    #endif
    }
}
implementation {
  
    typedef struct reboot_element_s {
        element_t e;
    } __attribute__((packed)) reboot_element_t;

    void real_reboot() {
        #if defined(PLATFORM_TELOS) || defined(PLATFORM_TELOSB)
            WDTCTL = 0;
        #elif defined(PLATFORM_MICAZ) || defined(PLATFORM_MICA2)  || defined(PLATFORM_MICA2DOT)
            cli(); 
            wdt_enable(0);
            while(1) {
                __asm__ __volatile__("nop" "\n\t" ::);
            }
        #elif defined (PLATFORM_IMOTE2)
            //resetNode();///tinyos-1.x/beta/platform/pxa27x/lib/systemUtil.c
	    call Reset.reset();
        #endif
    }
    
    sched_action_t reboot_run(active_task_t *active_task, element_t *e) {
        real_reboot();
        return SCHED_STOP;
    } 

    void reboot_suicide(task_t *t, element_t *e) {}

    command element_t *Element.construct(task_t *t, void *data, uint16_t length) {
        reboot_element_t *e;
        if ((e = (reboot_element_t *)call Memory.malloc(sizeof(reboot_element_t))) == NULL) {
            real_reboot();
            return NULL;
        }
        call TenetTask.element_construct(t, (element_t *)e,
                ELEMENT_REBOOT,
                reboot_run,
                reboot_suicide);
        return (element_t *)e;
    }

}

