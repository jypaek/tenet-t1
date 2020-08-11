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
 * Get
 *
 * - This tasklet gets the values of system variables, defined by value, 
 *   and assigns them to attr. Depending on value, attr may be a scalar 
 *   or a vector. 
 *
 *  1 (ROUTING_PARENT)
 *  2 (GLOBAL_TIME) 
 *  3 (LOCAL_TIME) 
 *  4 (MEMORY_STATS) 
 *  5 (NUM_TASKS)
 *  6 (NUM_ACTIVE_TASKS)
 *  7 (CHILDREN)
 *  8 (NEIGHBORS)
 *  9 (LEDS)
 * 10 (RF_POWER)
 * 11 (RF_CHANNEL)
 * 12 (IS_TIMESYNC)
 * 13 (TOS_LOCAL_ADDRESS)
 * 14 (GLOBAL_TIME_MS)
 * 15 (LOCAL_TIME_MS)
 * 16 (ROUTING_PARENT_LINKQUALITY)
 * 17 (PLATFORM)
 * 18 (CLOCL_FREQ)
 * 19 (ROUTING_MASTER)
 * 20 (ROUTING_HOPCOUNT)
 * 21 (ROUTING_PARENT_RSSI)
 *
 * @author Ki-Young Jang
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 6/28/2007
 **/

#include "tenet_task.h"

module Get {
    provides {
        interface Element;
    }
    uses {
        interface TenetTask;
        interface TaskError;
        interface RoutingTable;
    #ifndef USE_CENTROUTE
        interface ChildrenTable;
        interface NeighborTable;
    #endif
        interface Memory;
    #ifdef GLOBAL_TIME
        interface GlobalTime;
    #endif
        interface LocalTime;
        interface LocalTimeInfo;
        interface Leds;

    #if defined(PLATFORM_TELOSB) || defined(PLATFORM_MICAZ) || defined(PLATFORM_IMOTE2)
        interface CC2420Control;
    #elif defined(PLATFORM_MICA2)  || defined(PLATFORM_MICA2DOT)
        interface CC1000Control;
    #endif
    }
}
implementation {

    typedef struct get_element_s {
        element_t e;
        tag_t type;
        uint16_t value;
    } __attribute__((packed)) get_element_t;

    sched_action_t get_run(active_task_t *active_task, element_t *e);
    void get_suicide(task_t *t, element_t *e) {} // nothing to do

    command element_t *Element.construct(task_t *t, void *data, uint16_t length) {
        get_element_t *e;
        get_params_t *p;
        if (data == NULL || length < sizeof(get_params_t)) {
            return NULL;
        }
        if ((e = (get_element_t *)call Memory.malloc(sizeof(get_element_t))) == NULL) {
            return NULL;
        }
        p = (get_params_t *)data;
        call TenetTask.element_construct(t, (element_t *)e,
                ELEMENT_GET,
                get_run,
                get_suicide);
        e->type = p->type;
        e->value = p->value;
        return (element_t *)e;
    } 

    sched_action_t get_run(active_task_t *active_task, element_t *e) {
        get_element_t* ge;
        memory_stats_t* m;
        data_t* d;
        uint16_t data16;
        uint32_t data32;
        uint8_t *databuf;
        uint8_t dataType = 0;   // 0=16bit, 1=32bit, 2=else

        ge = (get_element_t *)e;
        
        data16 = 0;
        data32 = 0;
        databuf = NULL;

        switch ( ge->value )
        {
            case GET_TOS_LOCAL_ADDRESS:
                data16 = TOS_LOCAL_ADDRESS;
                break;
            case GET_PLATFORM:
            #ifdef PLATFORM_TELOSB
                data16 = TELOSB;
            #elif PLATFORM_MICAZ
                data16 = MICAZ;
            #elif PLATFORM_IMOTE2
                data16 = IMOTE2;
            #elif PLATFORM_MICA2
                data16 = MICA2;
            #elif PLATFORM_MICA2DOT
                data16 = MICA2DOT;
            #else
                data16 = 0;
            #endif
                break;
            case GET_NUM_TASKS:
                data16 = call TenetTask.get_task_count();
                break;
            case GET_NUM_ACTIVE_TASKS:
                data16 = call TenetTask.get_active_task_count();
                break;
            case GET_LEDS:
                atomic {
                    data16 = (uint16_t)call Leds.get();
                }
                break;
            case GET_LOCAL_TIME:
                data32 = call LocalTime.read();
                dataType = 1;
                break;
            case GET_CLOCK_FREQ:
                data16 = (uint16_t)call LocalTimeInfo.getClockFreq();
                break;
            case GET_LOCAL_TIME_MS:
                data32 = call LocalTime.read();
                data32 = call LocalTimeInfo.ticksToMs(data32);
                dataType = 1;
                break;
            case GET_RF_POWER:
            #if defined(PLATFORM_TELOSB) || defined(PLATFORM_MICAZ) || defined(PLATFORM_IMOTE2)
                data16 = (uint16_t)call CC2420Control.GetRFPower();
            #elif defined(PLATFORM_MICA2)  || defined(PLATFORM_MICA2DOT)
                data16 = (uint16_t)call CC1000Control.GetRFPower();
            #endif
                break;
            case GET_RF_CHANNEL:
            #if defined(PLATFORM_TELOSB) || defined(PLATFORM_MICAZ) || defined(PLATFORM_IMOTE2)
                data16 = (uint16_t)call CC2420Control.GetPreset();
            #elif defined(PLATFORM_MICA2)  || defined(PLATFORM_MICA2DOT)
                //CC1000Radio does not provide channel numbers
            #endif
                break;
            case GET_IS_TIMESYNC:
            #ifdef GLOBAL_TIME
                if (call GlobalTime.getGlobalTime(&data32) == SUCCESS)
                    data16 = 1;
            #endif
                break;
        #ifdef GLOBAL_TIME  // generate ERROR when FTSP disabled
            case GET_GLOBAL_TIME:
                call GlobalTime.getGlobalTime(&data32);
                dataType = 1;
                break;
            case GET_GLOBAL_TIME_MS:
                call GlobalTime.getGlobalTime(&data32);
                data32 = call LocalTimeInfo.ticksToMs(data32);
                dataType = 1;
                break;
        #endif
            case GET_ROUTING_PARENT:
                data16 = call RoutingTable.getParent();
                break;
            case GET_ROUTING_HOPCOUNT:
                data16 = call RoutingTable.getDepth();
                break;
            case GET_ROUTING_PARENT_LINKQUALITY:
            #ifndef USE_CENTROUTE
                data16 = call RoutingTable.getLinkEst();
            #endif
                break;
            case GET_ROUTING_PARENT_RSSI:
            #ifndef USE_CENTROUTE
                data16 = (uint16_t)call RoutingTable.getLinkRssi();
            #endif
                break;
            case GET_ROUTING_MASTER:
                data16 = call RoutingTable.getMaster();
                break;
            case GET_MEMORY_STATS:
            #ifdef INSTRUMENTED_MEMORY
                if ((m = call Memory.malloc(sizeof(memory_stats_t))) != NULL) {
                    if ((d = call TenetTask.data_new(ge->type, sizeof(memory_stats_t), m)) != NULL) {
                        m->bytesAllocated = call Memory.bytesAllocated();
                        m->ptrsAllocated = call Memory.ptrsAllocated();
                        m->maxBytesAllocated = call Memory.maxBytesAllocated();
                        m->maxPtrsAllocated = call Memory.maxPtrsAllocated();
                        call TenetTask.data_push(active_task, d);
                    } else {
                        call Memory.free(m);
                    }
                }
            #else
                m = NULL;
                d = NULL;
                call TaskError.report(active_task->t, ERR_NOT_SUPPORTED, ELEMENT_GET, 
                                    active_task->element_index);
            #endif
                dataType = 2;
                break;
        #ifndef USE_CENTROUTE   // generate ERROR if CentRoute is used
            case GET_ROUTING_CHILDREN:
                data16 = call ChildrenTable.getChildrenListSize();
                if ((databuf = call Memory.malloc(data16*sizeof(uint16_t))) != NULL) {
                    uint8_t listlen = call ChildrenTable.getChildrenList(databuf, data16);
                    if (listlen > 0) {
                        if ((d = call TenetTask.data_new_copy(ge->type, listlen*sizeof(uint16_t), databuf)) != NULL) {
                            call TenetTask.data_push(active_task, d);
                        }
                    }
                }
                call Memory.free(databuf);
                dataType = 2;
                break;
            case GET_NEIGHBORS:
                data16 = call NeighborTable.getNeighborsSize();
                if ((databuf = call Memory.malloc(data16*sizeof(uint16_t))) != NULL) {
                    uint8_t listlen = call NeighborTable.getNeighbors(databuf, data16);
                    if (listlen > 0) {
                        if ((d = call TenetTask.data_new_copy(ge->type, listlen*sizeof(uint16_t), databuf)) != NULL) {
                            call TenetTask.data_push(active_task, d);
                        }
                    }
                    call Memory.free(databuf);
                }
                dataType = 2;
                break;
        #endif
            default:
                call TaskError.report(active_task->t, ERR_INVALID_OPERATION, ELEMENT_GET, active_task->element_index);
                break;
        }
        if (dataType == 0) {
            call TenetTask.data_push(active_task,
                    call TenetTask.data_new_copy(ge->type, sizeof(uint16_t), &data16));
        } else if (dataType == 1) {
            call TenetTask.data_push(active_task,
                    call TenetTask.data_new_copy(ge->type, sizeof(uint32_t), &data32)); 
        }
        return SCHED_NEXT;
    }

}


