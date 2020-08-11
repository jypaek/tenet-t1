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
 * Interface which the Scheduler should use to safely delete a task
 * within the task list of TaskInstaller.
 *
 * When you want to delete a task, you should do it safely and cleanly.
 * States of an installed task are in, 1) TaskInstaller, and 2) either
 * Scheduler or a currently running task. State in the TaskInstaller is
 * used to delete the task upon reception of a 'Delete' task. When a 
 * task is running, the control is either at the Scheduler or the 
 * currently active tasklet. So, when it is required to delete(destroy)
 * a task during the execution of that task due to some error or something,
 * then the control will reside at either the tasklet or the Scheduler,
 * and will move to the Scheduler. So, the Scheduler should finally
 * tell the TaskInstaller to remove the task state.
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified 2/5/2007
 **/

#include "tenet_task.h"

interface TaskDelete {
    command void destroy(task_t *t);
}

