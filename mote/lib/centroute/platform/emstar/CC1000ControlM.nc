/* -*- Mode: C; c-basic-indent: 2; indent-tabs-mode: nil -*- */
/* ex: set tabstop=4 expandtab shiftwidth=2 softtabstop=2: */


/*									tab:4
 *
 *
 * "Copyright (c) 2000-2002 The Regents of the University  of California.  
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
 */
/*									tab:4
 *  IMPORTANT: READ BEFORE DOWNLOADING, COPYING, INSTALLING OR USING.  By
 *  downloading, copying, installing or using the software you agree to
 *  this license.  If you do not agree to this license, do not download,
 *  install, copy or use the software.
 *
 *  Intel Open Source License 
 *
 *  Copyright (c) 2002 Intel Corporation 
 *  All rights reserved. 
 *  Redistribution and use in source and binary forms, with or without
 *  modification, are permitted provided that the following conditions are
 *  met:
 * 
 *	Redistributions of source code must retain the above copyright
 *  notice, this list of conditions and the following disclaimer.
 *	Redistributions in binary form must reproduce the above copyright
 *  notice, this list of conditions and the following disclaimer in the
 *  documentation and/or other materials provided with the distribution.
 *      Neither the name of the Intel Corporation nor the names of its
 *  contributors may be used to endorse or promote products derived from
 *  this software without specific prior written permission.
 *  
 *  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 *  ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 *  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
 *  PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE INTEL OR ITS
 *  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 *  EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 *  PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 *  PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 *  LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 *  NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 *  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 * 
 * 
 */
/*
 *
 * Authors:		Jaein Jeong, Phil Buonadonna
 * Date last modified:  $Revision: 1.1 $
 *
 * This module provides the CONTROL functionality for the Chipcon1000 series radio.
 * It exports both a standard control interface and a custom interface to control
 * CC1000 operation.
 */

module CC1000ControlM {
  provides {
    interface StdControl;
    interface CC1000Control;
  }
}
implementation
{
// For now, all commands return success. Eventually they will be hooked
// to link_ioctl with the right power setting	

  command result_t StdControl.init() {
    return SUCCESS;
  }


  command result_t CC1000Control.TunePreset(uint8_t freq) {

    return SUCCESS;
  }

  command uint32_t CC1000Control.TuneManual(uint32_t DesiredFreq) {
    return DesiredFreq;
  }

  async command result_t CC1000Control.TxMode() {
    return SUCCESS;
  }

  async command result_t CC1000Control.RxMode() {
    return SUCCESS;
  }

  command result_t CC1000Control.BIASOff() {
    return SUCCESS;
  }

  command result_t CC1000Control.BIASOn() {
    return SUCCESS;
  }


  command result_t StdControl.stop() {
    return SUCCESS;
  }

  command result_t StdControl.start() {

    return SUCCESS;
  }


  command result_t CC1000Control.SetRFPower(uint8_t power) {
    return emtos_link_set_power(power);
  }

  command uint8_t CC1000Control.GetRFPower() {
	  return emtos_link_get_power();
  }

  command result_t CC1000Control.SelectLock(uint8_t Value) {
	  return SUCCESS;
  }

  command uint8_t CC1000Control.GetLock() {
    return 0;
  }

  command bool CC1000Control.GetLOStatus() {

    return 0;

  }

}


