/* -*- Mode: C; tab-width: 4; c-basic-indent: 4; indent-tabs-mode: nil -*- */
/* ex: set tabstop=4 expandtab shiftwidth=4 softtabstop=4: */

/*
 *
 * Copyright (c) 2003 The Regents of the University of California.  All
 * rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 *
 * - Neither the name of the University nor the names of its
 *   contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS''
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,         
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
 * PARTICULAR  PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE REGENTS OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 */


// The main emstar module
// Author: Thanos Stathopoulos


includes tos_emstar;

module Emstar {
	provides {
		interface ReceiveMsg as Receive;
		interface ReceiveMsg as RadioReceiveMsg;
		interface ReceiveMsg as UARTReceiveMsg;
	}

	uses {
		interface StdControl;
	}
}

implementation {


#include "avr/pgmspace.h"
#include <string.h>


void start_mote(uint16_t moteID, uint8_t groupID)
{
    atomic {
      TOS_LOCAL_ADDRESS = moteID;
      if (groupID > 0)
        TOS_AM_GROUP = groupID;
    }
    //	__nesc_nido_initialise(0);
	call StdControl.init();
	call StdControl.start();
}


void stop_mote()
{
	call StdControl.stop();
}


void setID(uint16_t moteID)
{
    atomic {
    	TOS_LOCAL_ADDRESS = moteID;
    }
}

// Main function, everything gets initialized here
// the emstar main loop should start here too
int main(int argc, char **argv) __attribute__ ((C, spontaneous))
{
	fp_list_t *fplist=get_fplist();
	tos_state.current_node=0;

	// set the function pointers for start and stop
	fplist->start=start_mote;
	fplist->stop=stop_mote;
	fplist->setID=setID;
	
	/* fixme Set debug level, This is different then loglevel - so
    * Im not sure what the corollary should be. For now, set to verbose
	* */
	//dbg_add_mode("all");
	//dbg_add_mode(DBG_ALL);

	//RK initialize emtos instruction rom if specified
        emtos_init_inst_rom(argc,argv);

	// call the library init
	emtos_main(argc, argv, fplist);	
	return 0;
}


default event TOS_MsgPtr UARTReceiveMsg.receive(TOS_MsgPtr msg) 
{
	return msg;
}



}
