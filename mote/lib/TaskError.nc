/*
* "Copyright (c) 2006~7 University of Southern California.
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
 * Interface for task/tasklet error handling.
 *
 * Call to 'kill' command will kill the task and report the error.
 * Call to 'report' command will only report the error back to the master.
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 2/5/2007
 **/
 
#include "tenet_task.h"

interface TaskError {

	/**
	 * Report task/tasklet related error with (error_code, error_location1, and 2)
     * back to the master that issued the corresponding task.
     *
     * @param t : task that had error.
     * @param error_code is defined as error_code_t in tenet_task.h,
     *                   and describes the type of error.
     * @param error_loc should describes where(which file) the error happend.
     * @param error_loc2 should further describe where the error happend, 
     *                   usually contains the tasklet number within a task.
     **/
    command void report(task_t *t, uint16_t error_code, uint16_t error_loc, uint16_t error_loc2);

	/**
	 * Report task/tasklet related error with (error_code, error_location1, and 2)
     * back to the master that issued the corresponding task, AND kill the task.
     *
     * @param same as report();
     **/
    command void kill(task_t *t, uint16_t error_code, uint16_t error_loc, uint16_t error_loc2);

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

}

