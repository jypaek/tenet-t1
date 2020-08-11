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
 * Authors: Lama Nachman
 */
configuration SettingsC{

  provides{
    interface StdControl;
    command uint8_t ReadResetCause();
  }
}
implementation{
  components SettingsM, BluSHC, UIDC, CC2420ControlM, SleepC, TimerC, ResetC;

  StdControl = SettingsM;
  ReadResetCause = SettingsM.ReadResetCause;

  SettingsM.UID->UIDC;
  SettingsM.Reset->ResetC;
#ifdef RADIO_DEBUG
  SettingsM.CC2420Control->CC2420ControlM;
#endif
  SettingsM.StackCheckTimer->TimerC.Timer[unique("Timer")];
#ifdef TASK_QUEUE_DEBUG
  SettingsM.Timer->TimerC.Timer[unique("Timer")];
#endif
  SettingsM.Sleep->SleepC;
  BluSHC.BluSH_AppI[unique("BluSH")] -> SettingsM.NodeID;
  BluSHC.BluSH_AppI[unique("BluSH")] -> SettingsM.ResetNode;
  BluSHC.BluSH_AppI[unique("BluSH")] -> SettingsM.TestTaskQueue;
#ifdef RADIO_DEBUG
  BluSHC.BluSH_AppI[unique("BluSH")] -> SettingsM.SetRadioChannel;
  BluSHC.BluSH_AppI[unique("BluSH")] -> SettingsM.GetRadioChannel;
#endif
  BluSHC.BluSH_AppI[unique("BluSH")] -> SettingsM.GoToSleep;
  BluSHC.BluSH_AppI[unique("BluSH")] -> SettingsM.GetResetCause;
}
