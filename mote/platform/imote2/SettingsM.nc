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
 * Authors:  Lama Nachman
 */


/*
 * A module to apply generic settings.  For now, all we need is the tos 
 * local address
 */
includes trace;

module SettingsM{
  provides{
    interface StdControl;
    interface BluSH_AppI as NodeID;
    interface BluSH_AppI as TestTaskQueue;
#ifdef RADIO_DEBUG
    interface BluSH_AppI as SetRadioChannel;
    interface BluSH_AppI as GetRadioChannel;
#endif
    interface BluSH_AppI as ResetNode;
    interface BluSH_AppI as GoToSleep;
    interface BluSH_AppI as GetResetCause;
    command uint8_t ReadResetCause();
  }
  uses {
    interface UID;
    interface Reset;
#ifdef RADIO_DEBUG
    interface CC2420Control;
#endif
    interface Sleep;
    interface Timer as StackCheckTimer;
#ifdef TASK_QUEUE_DEBUG
    interface Timer;
#endif
  }
}

implementation {
  
#include "assert.h"
  
  uint32_t ResetCause;

  command result_t StdControl.init(){
    return SUCCESS;
  }

  command result_t StdControl.start(){
/*
#ifdef MY_ADDRESS
    TOS_LOCAL_ADDRESS = MY_ADDRESS;
#else
    TOS_LOCAL_ADDRESS = (uint16_t) (call UID.getUID() & 0xff);
#endif
*/
    call StackCheckTimer.start(TIMER_REPEAT, 5000);
#ifdef TASK_QUEUE_DEBUG
    call Timer.start(TIMER_REPEAT, 10000);
#endif

    // Figure out the cause of reset, store the info and clear the register
    ResetCause = RCSR;
    RCSR = 0xf;

    return SUCCESS;
  }
  
  command result_t StdControl.stop(){
    call StackCheckTimer.stop();
#ifdef TASK_QUEUE_DEBUG
    call Timer.stop();
#endif
    return SUCCESS;
  }

  task void testQueue() {
     trace(DBG_USR1,"Task Executed\r\n");
  }

  task void doReset() {
     call Reset.reset();
  }

  command BluSH_result_t NodeID.getName(char *buff, uint8_t len) {
     const char name[] = "NodeID";
     strcpy(buff, name);
     return BLUSH_SUCCESS_DONE;
  }

  command BluSH_result_t NodeID.callApp(char *cmdBuff, uint8_t cmdLen,
                                        char *resBuff, uint8_t resLen) {
     trace(DBG_USR1,"0x%x\r\n", TOS_LOCAL_ADDRESS);
     return BLUSH_SUCCESS_DONE;
  }

  command BluSH_result_t TestTaskQueue.getName(char *buff, uint8_t len) {
     const char name[] = "TestTaskQueue";
     strcpy(buff, name);
     return BLUSH_SUCCESS_DONE;
  }

  command BluSH_result_t TestTaskQueue.callApp(char *cmdBuff, uint8_t cmdLen,
                                        char *resBuff, uint8_t resLen) {
     post testQueue();
     return BLUSH_SUCCESS_DONE;
  }

#if 0
  command BluSH_result_t SetDebugMode.getName(char *buff, uint8_t len) {
     const char name[] = "SetDebugMode";
     strcpy(buff, name);
     return BLUSH_SUCCESS_DONE;
  }

  command BluSH_result_t SetDebugMode.callApp(char *cmdBuff, uint8_t cmdLen,
                                        char *resBuff, uint8_t resLen) {
     return BLUSH_SUCCESS_DONE;
  }
#endif

#ifdef RADIO_DEBUG
  command BluSH_result_t SetRadioChannel.getName(char *buff, uint8_t len) {
     const char name[] = "SetRadioChannel";
     strcpy(buff, name);
     return BLUSH_SUCCESS_DONE;
  }

  command BluSH_result_t SetRadioChannel.callApp(char *cmdBuff, uint8_t cmdLen,
                                        char *resBuff, uint8_t resLen) {
     uint32_t radio_channel;
    
      if(strlen(cmdBuff) <17) {
         sprintf(resBuff,"SetRadioChannel <channel number>\r\n");
      } else {
         sscanf(cmdBuff,"SetRadioChannel %d", &radio_channel);
         call CC2420Control.TunePreset((uint16_t) radio_channel);
      }
     
     return BLUSH_SUCCESS_DONE;
  }

  command BluSH_result_t GetRadioChannel.getName(char *buff, uint8_t len) {
     const char name[] = "GetRadioChannel";
     strcpy(buff, name);
     return BLUSH_SUCCESS_DONE;
  }

  command BluSH_result_t GetRadioChannel.callApp(char *cmdBuff, uint8_t cmdLen,
                                        char *resBuff, uint8_t resLen) {
     uint32_t radio_channel;
    
     radio_channel = (uint32_t) call CC2420Control.GetPreset();
     trace(DBG_USR1,"Channel is %d\r\n", radio_channel);
     
     return BLUSH_SUCCESS_DONE;
  }
#endif

  command BluSH_result_t GoToSleep.getName(char *buff, uint8_t len) {
     const char name[] = "GoToSleep";
     strcpy(buff, name);
     return BLUSH_SUCCESS_DONE;
  }

  command BluSH_result_t GoToSleep.callApp(char *cmdBuff, uint8_t cmdLen,
                                        char *resBuff, uint8_t resLen) {
     uint32_t sleep_time;
    
      if(strlen(cmdBuff) < 11) {
         sprintf(resBuff,"GoToSleep <Sleep time in seconds>\r\n");
      } else {
         sscanf(cmdBuff,"GoToSleep %d", &sleep_time);
         call Sleep.goToDeepSleep(sleep_time);
      }
     
     return BLUSH_SUCCESS_DONE;
  }

  command BluSH_result_t ResetNode.getName(char *buff, uint8_t len) {
     const char name[] = "ResetNode";
     strcpy(buff, name);
     return BLUSH_SUCCESS_DONE;
  }

  command BluSH_result_t ResetNode.callApp(char *cmdBuff, uint8_t cmdLen,
                                        char *resBuff, uint8_t resLen) {
     trace(DBG_USR1,"Resetting\r\n");
     post doReset();
     return BLUSH_SUCCESS_DONE;
  }

  command BluSH_result_t GetResetCause.getName(char *buff, uint8_t len) {
     const char name[] = "GetResetCause";
     strcpy(buff, name);
     return BLUSH_SUCCESS_DONE;
  }

  command BluSH_result_t GetResetCause.callApp(char *cmdBuff, uint8_t cmdLen,
                                        char *resBuff, uint8_t resLen) {
     uint8_t gpio_rst, sleep_rst, wdt_rst, hw_rst;
     gpio_rst = (ResetCause & RCSR_GPR) == RCSR_GPR;
     sleep_rst = (ResetCause & RCSR_SMR) == RCSR_SMR;
     wdt_rst = (ResetCause & RCSR_WDR) == RCSR_WDR;
     hw_rst = (ResetCause & RCSR_HWR) == RCSR_HWR;
     trace(DBG_USR1, "GPIO %d, Sleep %d, WDT %d, Power On %d\r\n", 
           gpio_rst, sleep_rst, wdt_rst, hw_rst);
     return BLUSH_SUCCESS_DONE;
  }

#ifdef PROFILE_IRQ_TIME
  extern uint32_t IRQTimeInfo1[] __attribute__((C));
  extern uint32_t IRQTimeInfo2[] __attribute__((C));
  extern uint32_t *pCurrentIRQTimeInfo __attribute__((C));
#endif


  event result_t StackCheckTimer.fired(){
#ifdef PROFILE_IRQ_TIME
    int i;
    uint32_t *infoToPrint;
#endif
    
    
    extern uint32_t _SVC_MODE_STACK, _IRQ_MODE_STACK, _FIQ_MODE_STACK, _UND_MODE_STACK, _ABT_MODE_STACK;
    assert(_SVC_MODE_STACK  == 0xDEADBEEF);
    assert(_IRQ_MODE_STACK  == 0xDEADBEEF);
    assert(_FIQ_MODE_STACK  == 0xDEADBEEF);
    assert(_UND_MODE_STACK  == 0xDEADBEEF);
    assert(_ABT_MODE_STACK  == 0xDEADBEEF);

#ifdef PROFILE_IRQ_TIME
    atomic{
      if(pCurrentIRQTimeInfo == IRQTimeInfo1){
	infoToPrint = IRQTimeInfo1;
	pCurrentIRQTimeInfo = IRQTimeInfo2;
      }
      else if(pCurrentIRQTimeInfo == IRQTimeInfo2){
	infoToPrint = IRQTimeInfo2;
	pCurrentIRQTimeInfo = IRQTimeInfo1;
      }
      else{
	infoToPrint = NULL;
	printFatalErrorMsg("SettingM found unknown IRQTimeInfo structure\r\n",0);
      }
    }
    trace(DBG_TEMP,"\r\nIRQ Time Profile Table\r\n");
    for(i=0; i<3; i++){
      trace(DBG_TEMP,"%u\t%u\t%u\t%u\t%u\t%u\t%u\t%u\t%u\t%u\r\n",
	    infoToPrint[10*i],
	    infoToPrint[10*i + 1],
	    infoToPrint[10*i + 2],
	    infoToPrint[10*i + 3],
	    infoToPrint[10*i + 4],
	    infoToPrint[10*i + 5],
	    infoToPrint[10*i + 6],
	    infoToPrint[10*i + 7],
	    infoToPrint[10*i + 8],
	    infoToPrint[10*i + 9]);
    }
    trace(DBG_TEMP,"%u\t%u\r\n",infoToPrint[30], infoToPrint[31]);
    memset(infoToPrint, 0, 4*32);
#endif

    return SUCCESS;
  }
  

#ifdef TASK_QUEUE_DEBUG
  event result_t Timer.fired() {
     uint8_t mo;
     uint32_t fp;
     TOSH_get_debug_counters(&mo, &fp);
     trace(DBG_USR1, "Task Queue : Max Occ = %d, Failed Post = %d\r\n", mo, fp);
     TOSH_reset_debug_counters();
     return SUCCESS;
  }
#endif
  
  command uint8_t ReadResetCause() {
     return ResetCause;
  }

}
