/*
 * Authors: Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 */

/**
 * @author Jeongyeup Paek
 * @modified 3/28/2005
 */


// Any component/module that uses this interface 
// must include "VBSRControl.h".

interface VBSRControl { 

	// SUSPEND
	command result_t suspendSending();
	async event void suspendSendingDone(result_t success);
	
	// RESUME
	command result_t resumeSending();
	async event void resumeSendingDone(result_t success);

}

