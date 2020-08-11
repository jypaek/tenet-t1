/* -*- Mode: C; tab-width: 8;c-basic-indent: 4; indent-tabs-mode: nil -*- */
/* ex: set tabstop=4 expandtab shiftwidth=4 softtabstop=4: */


/*
 * Copyright (c) 2003, Vanderbilt University
 * All rights reserved.
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose, without fee, and without written agreement is
 * hereby granted, provided that the above copyright notice, the following
 * two paragraphs and the author appear in all copies of this software.
 * 
 * IN NO EVENT SHALL THE VANDERBILT UNIVERSITY BE LIABLE TO ANY PARTY FOR
 * DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES ARISING OUT
 * OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN IF THE VANDERBILT
 * UNIVERSITY HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 * 
 * THE VANDERBILT UNIVERSITY SPECIFICALLY DISCLAIMS ANY WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE.  THE SOFTWARE PROVIDED HEREUNDER IS
 * ON AN "AS IS" BASIS, AND THE VANDERBILT UNIVERSITY HAS NO OBLIGATION TO
 * PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS.
 *
 * Author: Miklos Maroti
 * Date last modified: 12/07/03
 */

/**
 * This module provides a 921.6 KHz timer on the MICA2 platform,
 * and 500 KHz timer on the MICA2DOT platform. We use 1/8 prescaling.
 */

includes tos_emstar;

module SysTimeM
{
	provides 
	{
		interface StdControl;
		interface SysTime;
	}
}

implementation
{
#include <sys/time.h>

	async command uint16_t SysTime.getTime16()
	{
		return -1;  // not implemented
	}

	async command uint32_t SysTime.getTime32()
	{

        return emtos_gettimeofday();
	}

	async command uint32_t SysTime.castTime16(uint16_t time16)
	{
        return -1; // not implemented

	}

	command result_t StdControl.init()
	{
		return SUCCESS;
	}

	command result_t StdControl.start()
	{
		return SUCCESS;
	}

	command result_t StdControl.stop()
	{
		return SUCCESS;
	}
}
