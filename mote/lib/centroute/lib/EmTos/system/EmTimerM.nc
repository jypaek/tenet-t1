// $Id: EmTimerM.nc,v 1.1 2007-09-10 21:45:26 karenyc Exp $

/*									tab:4
 * "Copyright (c) 2000-2003 The Regents of the University  of California.  
 * All rights reserved.
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose, without fee, and without written agreement is
 * hereby granted, provided that the above copyright notice, the following
 * two paragraphs and the author appear in all copies of this software.
 * 
 * IN NO EVENT SHALL THE UNIVERSITY OF CALIFORNIA BE LIABLE TO ANY PARTY FOR
 * DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES ARISING OUT
 * OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN IF THE UNIVERSITY OF
 * CALIFORNIA HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 * 
 * THE UNIVERSITY OF CALIFORNIA SPECIFICALLY DISCLAIMS ANY WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE.  THE SOFTWARE PROVIDED HEREUNDER IS
 * ON AN "AS IS" BASIS, AND THE UNIVERSITY OF CALIFORNIA HAS NO OBLIGATION TO
 * PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS."
 *
 * Copyright (c) 2002-2003 Intel Corporation
 * All rights reserved.
 *
 * This file is distributed under the terms in the attached INTEL-LICENSE     
 * file. If you do not find these files, copies can be found by writing to
 * Intel Research Berkeley, 2150 Shattuck Avenue, Suite 1300, Berkeley, CA, 
 * 94704.  Attention:  Intel License Inquiry.
 */

/*
 *
 * Authors:             Joe Polastre <polastre@cs.berkeley.edu>
 *                      Rob Szewczyk <szewczyk@cs.berkeley.edu>
 *                      David Gay <dgay@intel-research.net>
 *                      David Moore
 *
 * Revision:            $Id: EmTimerM.nc,v 1.1 2007-09-10 21:45:26 karenyc Exp $
 * This implementation assumes that DEFAULT_SCALE is 3.
 */

/**
 * @author Su Ping <sping@intel-research.net>
 */


module EmTimerM {
    provides interface EmTimerI[uint8_t id];
    provides interface StdControl;
}

implementation {
    
    int timer_callback(void *data)
    {
	uint8_t my_if = (int)data;

	return signal EmTimerI.fired[my_if]();
    }

    command result_t StdControl.init() {
        
        return SUCCESS;
    }

    command result_t StdControl.start() {
        return SUCCESS;
    }

    command result_t StdControl.stop() {
        
        return SUCCESS;
    }

    command result_t EmTimerI.start[uint8_t id](char type, 
				   uint32_t interval) {
	struct timeval timeout;
	emstar_timer_renew_t renew;
	int data_to_pass = id;

	// interval is in ms, convert to usec and seconds
	timeout.tv_sec = interval / 1000;
	timeout.tv_usec = (interval - (timeout.tv_sec * 1000)) * 1000; 

	if (type == TIMER_REPEAT)
	{
	    renew = TIMER_REFRESH;
	}
	else
	{
	   renew = TIMER_ONESHOT;
	}

	if (emstar_timer_add(timer_callback, timeout,
		             renew, (void *)data_to_pass) < 0)
	{
	    dbg(DBG_ERROR, "Unable to start timer!\n");
            return FAIL;
	}
        return SUCCESS;
    }

    

    command result_t EmTimerI.stop[uint8_t id]() {
	int timer_id;
	int data_to_pass = id;

	timer_id = emstar_timer_get_by_data((void *)data_to_pass);
	if (timer_id < 0)
	{
	    // timer doesn't exist, probably it's already deleted?
            dbg(DBG_ERROR, "Unable to find timer to delete!\n");
	    return FAIL;
 	}

        if (emstar_timer_delete(timer_id) == DELETE_FAIL)
	{
	    // unable to delete
            dbg(DBG_ERROR, "Failed to delete timer %d!\n", timer_id);
	    return FAIL;
	}
	else
	{
            dbg(DBG_USR3, "Deleted timer OK\n");
	    return SUCCESS;
	}
    }


    default event result_t EmTimerI.fired[uint8_t id]() {
        return SUCCESS;
    }
}

