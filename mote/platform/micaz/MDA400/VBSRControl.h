
/*
 * Authors: Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 */

/**
 * @author Jeongyeup Paek
 * @modified 3/28/2005
 */

#ifndef _VB_SR_CONTROL_H_
#define _VB_SR_CONTROL_H_

enum {
	VB_SR_S_NORMAL = 11,		// Don't care/know state
	VB_SR_S_SUSDONE_WAIT = 12,	// waiting for suspendDone
	VB_SR_S_SUSDONE_NOW = 13,	// immediate suspendDone
	VB_SR_S_SUSPENDED = 14,		// it knows that VB is suspended
	VB_SR_S_RESDONE_WAIT = 15	// waiting for resumeDone... but doesn't really care.
};

#endif // _VB_SR_CONTROL_H_

