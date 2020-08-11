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
 * Reports task/tasklet related error back to the master that issued the
 * corresponding task, and safely kills/deletes the task if requested.
 *
 * Call to 'kill' command will kill the task and report the error.
 * Call to 'report' command will only report the error back to the master.
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 2/5/2007
 **/

#include "tenet_task.h"

module ErrorHandler {
    provides {
        interface TaskError;
    }
    uses {
        interface TaskDelete;
        interface TenetTask;
        interface TransportSend as Send;
    #ifdef BACK_CHANNEL
        interface SendMsg;
    #endif
    }
}
implementation {

    uint8_t buf[offsetof(attr_t, value) + sizeof(error_report_t)];
    uint8_t report_busy = 0;
#ifdef BACK_CHANNEL
    TOS_Msg m_msg;
#endif
    task_t *to_kill_task = NULL;

    
    /**
     * Report task/tasklet related error with (error_code, error_location1, and 2)
     * back to the master that issued the corresponding task.
     *
     * @param error_code is defined as error_code_t in tenet_task.h,
     *                   and describes the type of error.
     * @param error_loc should describes where(which file) the error happend.
     * @param error_loc2 should further describe where the error happend, 
     *                   usually contains the tasklet number within a task.
     **/
    command void TaskError.report(task_t *t, uint16_t error_code, 
                                  uint16_t error_loc, uint16_t error_loc2) {
        attr_t *err_attr;
        error_report_t *err_report;
        uint8_t len = 0;
        uint16_t tid, dst;

        if (t == NULL) return;
        if (report_busy) return;
     
        tid = call TenetTask.get_tid(t);
        dst = call TenetTask.get_src(t);
        
        err_attr = (attr_t *)buf;
        err_report = (error_report_t *)&buf[offsetof(attr_t, value)];
        
        err_attr->type = ERROR_ATTRIBUTE;
        err_attr->length = sizeof(error_report_t);
        err_report->err_code = error_code;
        err_report->err_loc = error_loc;
        err_report->err_loc2 = error_loc2;

        len = offsetof(attr_t, value) + err_attr->length;

    #ifdef BACK_CHANNEL
        memcpy(m_msg.data, &err_attr, len);
        if (call SendMsg.send(TOS_UART_ADDRESS, len, &m_msg)) {
    #else
        if (call Send.send(tid, dst, len, (void *)buf)) {
    #endif
            report_busy = 1;
        }
    }

/* WARNING (... when using this kill command)
    - This TaskError.kill command will kill the task 't', which includes
        - deleting all active tasks in the scheduler associated with task 't',
        - deleting all elements that belongs to task 't', and
        - deleting 't' it self.
    - This means that if you are calling this command within any function that
      has reference binding (function pointer, task pointer, active task pointer, etc)
      with the task 't', then you might generate a 'seg fault'.
    - So, here is the RULE when calling kill:
        - if you are in '*construct*', return 'NULL' after calling kill.
        - if you are in '*run*', return 'SCHED_TERMINATE' after calling kill.
        - if you are in any 'List.iterate' function, return 'LIST_BREAK' after calling kill.
        - you shouldn't need to call this in '*suicide*' function.
    - KEEP THIS IN MIND!!

 - Jeongyeup.
*/

    task void kill_it() {
        if (to_kill_task)
            call TaskDelete.destroy(to_kill_task);
        to_kill_task = NULL;
    }
    
    /**
     * Report task/tasklet related error with (error_code, error_location1, and 2)
     * back to the master that issued the corresponding task, AND kill the task.
     *
     * @param error_code is defined as error_code_t in tenet_task.h,
     *                   and describes the type of error.
     * @param error_loc should describes where(which file) the error happend.
     * @param error_loc2 should further describe where the error happend, 
     *                   usually contains the tasklet number within a task.
     **/
    command void TaskError.kill(task_t *t, uint16_t error_code, uint16_t error_loc, uint16_t error_loc2) {
        if (t == NULL)
            return;
        call TaskError.report(t, error_code, error_loc, error_loc2);
        if (to_kill_task == NULL) {
            to_kill_task = t;
            post kill_it();
        }
    }
        
    event void Send.sendDone(uint16_t tid, void *data, result_t success) {
        report_busy = 0;
    }

#ifdef BACK_CHANNEL
    event result_t SendMsg.sendDone(TOS_MsgPtr msg, result_t success) {
        report_busy = 0;
    }
#endif
}

