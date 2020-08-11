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
 * Configuration file for wiring of non-multihop task installer.
 *
 * This is for testing purposes only.
 *
 * A mote receives tasking packet sent through GenericComm
 * link layer and passes it to the task installer.
 * TaskInstaller installs the task by instantiating tasklets (elements),
 * and schedules the task, if possible. If the task cannot be installed
 * for some reason or error, task installer deletes the task.
 *
 * @author Ben Greenstein
 * @author Jeongyeup Paek
 * @modified 2/5/2007
 **/
 
configuration TaskInstallerNoRouting {
  provides {
    interface StdControl;
    interface TaskDelete;
  }
  uses {
    interface Element as Element_u[uint8_t id];
    interface Schedule;
    interface TenetTask;
    interface TaskError;
    interface List;
    interface ReceiveMsg;
  }
}
implementation {
    components TaskInstallerM, 
               TaskRecvNoRoutingM
               ;

    StdControl = TaskInstallerM;
    Element_u = TaskInstallerM;
    Schedule = TaskInstallerM;
    TenetTask = TaskInstallerM;
    TaskError = TaskInstallerM;
    TaskDelete = TaskInstallerM;
    List = TaskInstallerM;
    ReceiveMsg = TaskRecvNoRoutingM;

    TaskInstallerM.TaskRecv -> TaskRecvNoRoutingM;

}

