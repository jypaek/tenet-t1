/* 
 * Edits:		Josh Herbach
 * Revision:	1.1
 * Date:		09/02/2005
 */
#ifndef USE_USB
#define USE_USB 1
#endif

#ifndef ENABLE_TRACE
#define ENABLE_TRACE 1
#endif

includes trace;

module BluSHM {
  provides
    {
      interface StdControl;
    }
  
  uses
    {
      interface StdControl as UartControl;
      interface SendData as UartSend;
      interface ReceiveData as UartReceive;
      
#if USE_USB
      interface SendJTPacket as USBSend;
      interface ReceiveData as USBReceive;
#endif      
      
      interface BluSH_AppI[uint8_t id];
    }
}

implementation
{
#include "cmdlinetools.c"
#include "BluSH_types.h"
#include <stdarg.h>
    
#include "PXA27Xdynqueue.c"
  
#if USE_USB
#include "PXA27XUSBClient.h"
#endif
  
#define BLUSH_PROMPT_LENGTH 32
#define BLUSH_HISTORY_LENGTH 4
#define BLUSH_CMDLINE_LENGTH 80
#define MAX_RETURN_STRING 50
#define MAX_PRINTF_LEN 200
  
  void generalSend(uint8_t *buf, uint32_t buflen) __attribute__ ((C));
  task void processIn();
  void clearOut();
  void clearIn();
  void clearBluSHdata(BluSHdata data);
  
  char blush_prompt[ BLUSH_PROMPT_LENGTH ];
  // Index 0 is the current command line.
  char blush_history[BLUSH_HISTORY_LENGTH][BLUSH_CMDLINE_LENGTH];
  char blush_cur_line[BLUSH_CMDLINE_LENGTH];
  
  uint8_t InTaskCount = 0;
  DynQueue InQueue;
  DynQueue OutQueue;
  
  TOS_dbg_mode trace_modes;
  // Internal commands: help, ls, prompt, readmem, writemem.  
  
  void trace(TOS_dbg_mode mode, const char *format, ...) __attribute ((C, spontaneous)){
    if (trace_active(mode)) {
      char buf[MAX_PRINTF_LEN+1];
      uint16_t buflen=0;
      va_list args;
      
      va_start(args, format);
      if (!(mode & DBG_SIM)) {
	buflen=vsnprintf(buf,MAX_PRINTF_LEN,format,args);
	//make sure that we're properly terminating our string...
	buflen = (buflen>=MAX_PRINTF_LEN) ? MAX_PRINTF_LEN:buflen;
	buf[MAX_PRINTF_LEN] = 0;
	generalSend(buf,buflen);
      }
    }
  }

  unsigned char trace_active(TOS_dbg_mode mode) __attribute__((C, spontaneous)){
    unsigned char result;
    atomic result = (trace_modes & mode) != 0; 
    return result;
  }
  
  void trace_unset() __attribute__ ((C,spontaneous)){
    atomic trace_modes = 0;
  }
  
  void trace_set(TOS_dbg_mode mode) __attribute__ ((C, spontaneous)){
    atomic trace_modes = mode;
  }


  void generalSend(uint8_t *buf, uint32_t buflen) __attribute__ ((C)){
    DynQueue QueueTemp;
#if USE_USB    
    uint8_t *tempBuf;
    BluSHdata temp;
#endif    

    atomic QueueTemp = OutQueue;
    //call UartSend.send(buf, buflen);
#ifdef USE_UARTDBG
   call UartSend.send(buf, buflen);
#endif
#if USE_USB
    temp = (BluSHdata)malloc(sizeof(BluSHdata_t));
    tempBuf = (uint8_t *)malloc(buflen);
    memcpy(tempBuf, buf, buflen);
    temp->src = tempBuf;
    temp->len = buflen;
    if(call USBSend.send(tempBuf, buflen, IMOTE_HID_TYPE_CL_BLUSH) == SUCCESS){
      temp->state = 0;//sommat
      DynQueue_enqueue(QueueTemp,temp);
    }
    else{
      free(tempBuf);
      free(temp);
    }
#endif
  }
  
  task void processIn(){
    uint16_t hist_idx;
    BluSHdata data;
    
    if(DynQueue_getLength(InQueue) < 1){
      atomic InTaskCount--;
      return;
    }
    data = (BluSHdata)DynQueue_dequeue(InQueue);

    strcpy(blush_history[0], data->src);
    if(0 == strncmp("help", data->src, strlen("help"))){
      generalSend("Blue Shell v1.1 (BluSH)\r\n\
help - Display this list\r\n\
ls - Display all application commands\r\n\
history - Display the command history\r\n\
prompt - Allows you to change the prompt\r\n",
		  strlen("Blue Shell v1.1 (BluSH)\r\n\
help - Display this list\r\n\
ls - Display all application commands\r\n\
history - Display the command history\r\n\
prompt - Allows you to change the prompt\r\n"));
      generalSend(blush_prompt, strlen(blush_prompt));
    }
    else if(0 == strncmp("history", data->src, strlen("history"))){
      for(hist_idx = BLUSH_HISTORY_LENGTH - 1; 1; hist_idx--){
	if(blush_history[hist_idx][0] != '\0'){
	  generalSend(blush_history[hist_idx], strlen(blush_history[hist_idx]));
	  generalSend("\r\n", strlen("\r\n"));
	}
	if(hist_idx == 0)
	  break;
      }
      generalSend(blush_prompt, strlen(blush_prompt));
    }
    else if(0 == strncmp("prompt", data->src, strlen("prompt"))){
      uint8_t frstSpc = firstSpace(data->src, 0);
      if(frstSpc == 0)
	generalSend("prompt <new prompt string>\r\n", strlen("prompt <new prompt string>\r\n"));
      else
	strncpy(blush_prompt, data->src + frstSpc + 1, BLUSH_PROMPT_LENGTH);
      generalSend(blush_prompt, strlen(blush_prompt));
    }
    else if(0 == strncmp("ls", data->src, strlen("ls"))){
      unsigned int i;
      char temp[ BLUSH_CMDLINE_LENGTH ];
      
      for(i = 0; i < BLUSH_APP_COUNT; i++){
	call BluSH_AppI.getName[i]( temp, BLUSH_CMDLINE_LENGTH );
	generalSend(temp, strlen(temp));
	generalSend("\r\n", 2);
      }
      generalSend(blush_prompt, strlen(blush_prompt));
    }
    else{//not a built-in
      // Loop through app commands.
      uint32_t j;
      char retStr[MAX_RETURN_STRING];
      char temp[BLUSH_CMDLINE_LENGTH];
      for(j = 0; j < BLUSH_APP_COUNT; j++){
	call BluSH_AppI.getName[j](temp, BLUSH_CMDLINE_LENGTH);
	if((strncmp(temp,data->src,strlen(temp)) == 0) &&
	   ((data->src[strlen(temp)] == ' ') || (data->src[strlen(temp)] == '\0'))){
	  *retStr=0;
	  call BluSH_AppI.callApp[j](data->src, BLUSH_CMDLINE_LENGTH, retStr, MAX_RETURN_STRING);
	  // Watch out for buffer overflow.
	  retStr[MAX_RETURN_STRING - 1] = '\0';
	  generalSend(retStr, strlen(retStr));   
	  break;
	}
      }
      if(j == BLUSH_APP_COUNT)
	generalSend("Bad command\r\n", strlen("Bad command\r\n"));
      /*
	else{
	generalSend("Shell Busy\r\n",
	strlen("Shell Busy\r\n"));
	}
      */
      generalSend(blush_prompt, strlen(blush_prompt));
    }

    //Shift history...could probably be done more efficiently
    for(hist_idx = BLUSH_HISTORY_LENGTH - 1; hist_idx > 0; hist_idx--)
      strcpy(blush_history[hist_idx], blush_history[hist_idx - 1]);
    blush_history[0][0] = '\0';
    
    if(InTaskCount <= 5 && DynQueue_getLength(InQueue) > 0)
      post processIn();
    else
      atomic InTaskCount--;
    
    free(data->src);
    free(data);
    
  }
  
  command result_t StdControl.init(){
    uint16_t i;
    
    // Clear history.
    for(i = 0; i < BLUSH_HISTORY_LENGTH; i++)
      blush_history[i][0] = '\0';
    
#if ENABLE_TRACE
    trace_set(DBG_USR1|DBG_USR2|DBG_USR3|DBG_TEMP);
#else
    //disable all trace messages
    trace_set(DBG_TEMP);
#endif
    
    call UartControl.init();
    strncpy( blush_prompt, "BluSH>", BLUSH_PROMPT_LENGTH );
   
    atomic{
      InQueue = DynQueue_new();
      OutQueue = DynQueue_new();
    }
    return SUCCESS;
  }
  
  command result_t StdControl.start()
  {
    call UartControl.start();
    generalSend("\r\n", 2);
    generalSend(blush_prompt, strlen(blush_prompt));
    return SUCCESS;
  }
  
  command result_t StdControl.stop()
  {
    atomic{
      DynQueue_free(InQueue);
      DynQueue_free(OutQueue);
    }
    call UartControl.stop();
    return SUCCESS;
  }
  
 default command BluSH_result_t BluSH_AppI.getName[uint8_t id](char* buff, uint8_t len){
   buff[0] = '\0';
   return BLUSH_SUCCESS_DONE;
 }
 
 default command BluSH_result_t BluSH_AppI.callApp[uint8_t id](char* cmdBuff, uint8_t cmdLen,
							       char* resBuff, uint8_t resLen){
   resBuff[0] = '\0';
   return BLUSH_SUCCESS_DONE;
 }
 
#define UP_ARROW 0x41
#define DOWN_ARROW 0x42
 
 void queueInput(uint8_t *buff, uint32_t numBytesRead){
   uint32_t i;
   BluSHdata data;
   char temp[BLUSH_CMDLINE_LENGTH];
   static uint8_t uSpecialChar = 0;
   static uint16_t blush_cmdline_idx = 0;
   static uint16_t blush_history_idx = 0;
   
   for(i = 0; i < numBytesRead; i++)
     switch(buff[i]){
     case 0x0a:
       //drop newlines on the floor
       break;
     case 0x0d: //ENTER
       blush_history_idx = 0;
       generalSend("\r\n", 2);
       blush_cur_line[blush_cmdline_idx] = '\0';
       blush_cmdline_idx = 0;
       if(blush_cur_line[0] != '\0'){
	 killWhiteSpace(blush_cur_line);
	 data = (BluSHdata)malloc(sizeof(BluSHdata_t));
	 data->len = strlen(blush_cur_line) + 1; //include '\0'
	 data->src = (uint8_t *)malloc(data->len);
	 memcpy(data->src, blush_cur_line, data->len);
	 DynQueue_enqueue(InQueue, data);
	 if(InTaskCount < 5){
	   atomic InTaskCount++;
	   post processIn();
	 }
       }
       else
	 generalSend(blush_prompt, strlen(blush_prompt));
       if(i + 1 < numBytesRead && buff[i + 1] == '\n')
	 i++;
       blush_cur_line[0] = '\0';
       break;
     case 0x03: //CTRL-C
       //clear history and tasks and print newline / prompt
       blush_history_idx = 0;
       blush_cmdline_idx = 0;
       blush_cur_line[0] = '\0';
       clearIn();
       generalSend("\r\n", 2);
       generalSend(blush_prompt, strlen(blush_prompt));
       break;
     case 0x09: //TAB
       for( i = 0; i < BLUSH_APP_COUNT; i++ ){
	 call BluSH_AppI.getName[i](temp, BLUSH_CMDLINE_LENGTH);
	 if(strncmp(blush_cur_line, temp, strlen(blush_cur_line)) == 0){
	   generalSend(temp+strlen(blush_cur_line),
		       strlen(temp)-strlen(blush_cur_line));
	   generalSend(" ", 1);
	   strcat(blush_cur_line, temp+strlen(blush_cur_line));
	   strcat(blush_cur_line, " ");
	   blush_cmdline_idx = strlen(temp)+1;
	   break;
	 }
       }
       if(i >= BLUSH_APP_COUNT){
	 // No match found.  Send beep.
	 generalSend("\a", 1);
       }
       break;
     case '\b': //backspace
       if(blush_cmdline_idx > 0){
	 // backspace space backspace
	 generalSend("\b \b", 3);
	 blush_cmdline_idx--;
	 blush_cur_line[blush_cmdline_idx] = '\0';
       }
       else
	 generalSend( "\a", 1 );         
       break;
     default: // normal character or escape sequence
       if(buff[i] == 0x1b || uSpecialChar != 0){//escape seq
	 static int special_i=0;
	 //check to see if the current char is part of the escape sequence
	 switch(special_i){
	 case 0:
	   uSpecialChar=1;
	   special_i++;
	   continue;
	 case 1:
	   if(buff[i]!=0x5b){
	     uSpecialChar=0;
	     special_i=0;
	     /*at this point, we know that our escape sequence was invalid, 
	       so we should treat the current character as a normal char...
	       need to fall through on the outer loop at the moment, I'm 
	       happy with losing a character if the escape key is pressed*/
	     //	     queueInput(buff + i, 1); could catch this key...dunno if that's right to do
	     continue;
	   }
	   special_i++;
	   continue;
	 case 2:
	   uSpecialChar=buff[i];
	   special_i = 0;
	   if(uSpecialChar == UP_ARROW){
	     if(blush_history_idx < BLUSH_HISTORY_LENGTH - 1){
	       if(blush_history_idx == 0)
		 strcpy(blush_history[0],blush_cur_line);
	       blush_history_idx++;
	       
	       for( i = 0; i < blush_cmdline_idx; i++ )
		 // send backspace space backspace sequenence
		 generalSend("\b \b", 3 );
	       
	       // Copy history index.
	       strcpy(blush_cur_line, blush_history[blush_history_idx]);
	       generalSend(blush_cur_line, strlen(blush_cur_line));
	       blush_cmdline_idx = strlen(blush_cur_line);
	     }
	     else{
	       generalSend( "\a", 1 );
	     }
	     uSpecialChar = 0;
	     continue;
	   }
	   else if(uSpecialChar == DOWN_ARROW){
	     if(blush_history_idx > 0){

	       // Erase what's currently there.
	       for( i = 0; i < blush_cmdline_idx; i++ ){
		 // send backspace space backspace sequence
		 generalSend("\b \b", 3 );         
	       }

	       blush_history_idx--;
	       // Copy history index.
	       strcpy(blush_cur_line, blush_history[blush_history_idx]);
	       generalSend(blush_cur_line, strlen(blush_cur_line));
	       blush_cmdline_idx = strlen(blush_cur_line);
	     }
	     else
	       generalSend("\a", 1);
	     
	     uSpecialChar = 0;
	     continue;
	   }
	   else{
	     uSpecialChar = 0;
	     continue;
	   }
	 }
       }
       //normal character
       if(blush_cmdline_idx < BLUSH_CMDLINE_LENGTH - 1){
	 blush_cur_line[blush_cmdline_idx] = buff[i];
	 blush_cmdline_idx++;
	 // Put a \0 on the end for safety.
	 blush_cur_line[blush_cmdline_idx] = '\0';	       
	 // Echo the character back.
	 generalSend(buff + i, 1);
       }
       else // Send bell back, avoid buffer overflow.
	 generalSend("\a", 1);
       break;
     }
 }
 
 event result_t UartReceive.receive(uint8_t* buff, uint32_t numBytesRead){
   queueInput(buff, numBytesRead);
   return SUCCESS;
 }
 
#if USE_USB
 event result_t USBReceive.receive(uint8_t* buff, uint32_t numBytesRead){
   queueInput(buff, numBytesRead);
   return SUCCESS;
 }
#endif
 
 event result_t UartSend.sendDone(uint8_t* packet, uint32_t numBytes, result_t success)
 {
   // This function does nothing.
   return SUCCESS;
 }
 
#if USE_USB
 event result_t USBSend.sendDone(uint8_t* packet, uint8_t type, result_t success)
 {
   BluSHdata temp;
   atomic {
     temp = (BluSHdata)DynQueue_peek(OutQueue);
   }
   if(temp->src == packet){
     free(packet);
     free(temp);
     atomic{
       DynQueue_dequeue(OutQueue);
     }
   }
   return SUCCESS;
 }
#endif
 
 void clearOut(){
   DynQueue QueueTemp;
   atomic QueueTemp = OutQueue;
   while(DynQueue_getLength(QueueTemp) > 0)
     clearBluSHdata((BluSHdata)DynQueue_dequeue(QueueTemp));
 }
 
 void clearIn(){
   DynQueue QueueTemp;
   atomic QueueTemp = InQueue;
   while(DynQueue_getLength(QueueTemp) > 0)
     clearBluSHdata((BluSHdata)DynQueue_dequeue(QueueTemp));
 }
 
 void clearBluSHdata(BluSHdata data){
   free(data->src);
   free(data);
 } 
}
