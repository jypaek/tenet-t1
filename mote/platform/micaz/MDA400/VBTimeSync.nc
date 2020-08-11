
/*
 * Authors: Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 */

/**
 * @author Jeongyeup Paek
 * @modified 7/10/2005
 */


interface VBTimeSync { 

	command result_t sendTimeSyncMsg(uint32_t currentTime);

	async event void sendDone(result_t success);
	
}

