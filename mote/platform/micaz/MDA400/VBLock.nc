/*
 * Authors: Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 */

/**
 * @author Jeongyeup Paek
 * @modified 3/28/2005
 */

interface VBLock { 

	// LOCK
	command result_t lock();
	event void lockDone();
	
	// UNLOCK
	command void unlock();
}

