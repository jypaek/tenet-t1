
#include "systemUtil.h"
#include "pxa27x_registers_def.h"
#include "frequency.h"
#include <string.h>
#include "queue.h"
#include "bufferManagement.h"
#include "arm_defs.h"
#include <stdarg.h>

#define RESET_DELAY 10000  // delay in 1/3.25 MHz increments = ~3 ms

const char csFatalError[] = "FATAL ERROR at ";
const char csRebootMsg[] = "Rebooting...";

void _malloc_stats_r(void *reent){
  return;
}

void disable_interrupts(void){
  uint32_t result = 0;
  uint32_t temp = 0;

  asm volatile (
		"mrs %0,CPSR\n\t"
		"orr %1,%2,%4\n\t"
		"msr CPSR_cf,%3"
		: "=r" (result) , "=r" (temp)
		: "0" (result) , "1" (temp) , "i" (ARM_CPSR_INT_MASK)
		);
  return;
}

static void configureUART(){
  
  GPIO_SET_ALT_FUNC(46,2,GPIO_IN);
  GPIO_SET_ALT_FUNC(47,1,GPIO_OUT);
  
  //turn on the port's clock
  CKEN |= (CKEN_CKEN5);

  STIER = IER_UUE; //disable all interrupts on the port and enable
  
  STLCR |=LCR_DLAB; //turn on DLAB so we can change the divisor
  STDLL = 8;  //configure to 115200;
  STDLH = 0;
  STLCR &= ~(LCR_DLAB);  //turn off DLAB
    
  STLCR |= 0x3; //configure to 8 bits

  STFCR = FCR_ITL(0) | FCR_TIL | FCR_RESETTF | FCR_TRFIFOE;
  STMCR &= ~MCR_LOOP;
  STMCR |= MCR_OUT2;
}

static void printChar(char data){
  STTHR = data;
  while((STLSR & LSR_TEMT) == 0);
}

static void printString(const char *str,uint32_t strlen){
  uint32_t i;
  
  for(i=0; i<strlen; i++){
    printChar(str[i]);
  }
}

static void printStringZ(const char *str){
  uint32_t len = strlen(str);
  printString(str,len);
}

// print one byte in hex
static void printHex(uint8_t num){
  
  switch(num & 0xF){
    case 0:
      printChar('0');
      break;
    case 1:
      printChar('1');
      break;
    case 2:
      printChar('2');
      break;
    case 3:
      printChar('3');
      break;
    case 4:
      printChar('4');
      break;
    case 5:
      printChar('5');
      break;
    case 6:
      printChar('6');
      break;
    case 7:
      printChar('7');
      break;
    case 8:
      printChar('8');
      break;
    case 9:
      printChar('9');
      break;
    case 10:
      printChar('A');
      break;
    case 11:
      printChar('B');
      break;
    case 12:
      printChar('C');
      break;
    case 13:
      printChar('D');
      break;
    case 14:
      printChar('E');
      break;
    case 15:
      printChar('F');
      break;
  }
}


static void printHex32(uint32_t num){
  int i;
  
  printChar('0');
  printChar('x');
  
  for(i=7; i>=0; i--){
    printHex(num>>(4*i));
  }
}

static void printDecimal(uint32_t num){
  int i,numDigits =1;
  char buf[10];

  for(i=0;i<10;i++){
    buf[9-i] = '0' + (num % 10);
    if(buf[9-i] != '0'){
      numDigits = i+1;
    }
    num = num/10;
  }
  printString((const char *)(buf+10-numDigits),numDigits);
}


static void reportSystemFrequency(){
  
   //print out the system specs at the time of failure
  printStringZ("System Frequency [CORE:BUS] was ");
  printDecimal(getSystemFrequency());
  printChar(':');
  printDecimal(getSystemBusFrequency());
  printChar('\r');
  printChar('\n');
  
  return;
}
extern uint32_t sys_max_tasks, sys_task_bitmask; 
extern uint8_t TOSH_sched_full;

static void dumpTaskQueue(){
  int i;
  uint8_t entry;
  extern uint32_t TOSH_queue;
  uint32_t *queue = &TOSH_queue;
  
  printStringZ("\r\ntask queue dump\r\n");
  
  entry = TOSH_sched_full;
  for (i = 0; i < sys_max_tasks; i++){
#if 0
    if(queue[entry*3] == NULL){
      printStringZ("TotalNumber of used taskQueue entries = ");
      printDecimal(i);
      printStringZ("\r\n");
    }

#endif//    else{
    printStringZ("task ");
    printHex32(queue[entry*4]);
    printStringZ(" posted by ");
    printHex32(queue[entry*4 + 1]);
    printStringZ(" at ");
    printDecimal(queue[entry*4 + 2]);
    printStringZ(" ran for ");
    printDecimal(queue[entry*4 + 3]);
    printStringZ("\r\n");
    // }
    entry = (entry + 1) & sys_task_bitmask;
  }
}

static void reportSystemState(){
  
  uint32_t mode, oldmode;

  asm volatile (
		"mrs %0,CPSR\n\t"
		: "=r" (mode) 
		);

  printStringZ("Died while in ");
  switch(mode & 0x1F){
  case 0x10:
    //User
    printStringZ("USER");
    asm volatile (
		  "mrs %0,SPSR\n\t"
		  : "=r" (oldmode) 
		  );
      
    break;
  case 0x11:
    //FIQ
    printStringZ("FIQ");
    asm volatile (
		  "mrs %0,SPSR\n\t"
		  : "=r" (oldmode) 
		  );

    break;
  case 0x12:
    //IRQ
    printStringZ("IRQ");
    asm volatile (
		  "mrs %0,SPSR\n\t"
		  : "=r" (oldmode) 
		  );

    break;
  case 0x13:
    //Super
    printStringZ("SUPERVISOR");
    asm volatile (
		  "mrs %0,SPSR\n\t"
		  : "=r" (oldmode) 
		  );
    
    break;
  case 0x17:
    //abort
    printStringZ("ABORT");
    asm volatile (
		  "mrs %0,SPSR\n\t"
		  : "=r" (oldmode) 
		  );

    break;
  case 0x1b:
    //Undef
    printStringZ("UNDEF");
    asm volatile (
		  "mrs %0,SPSR\n\t"
		  : "=r" (oldmode) 
		  );
    
    break;
  case 0x1f:
    //System:
    printStringZ("SYSTEM");
    asm volatile (
		  "mrs %0,SPSR\n\t"
		  : "=r" (oldmode) 
		  );
    
    break;
  default:
    printStringZ("UNKNOWN");
    asm volatile (
		  "mrs %0,SPSR\n\t"
		  : "=r" (oldmode) 
		  );
    
    break;
  }
  printStringZ(" mode\r\n");
  
  printStringZ("OldMode was ");
  switch(oldmode & 0x1F){
  case 0x10:
    //User
    printStringZ("USER");
    
    break;
  case 0x11:
    //FIQ
    printStringZ("FIQ");
    
    break;
  case 0x12:
    //IRQ
    printStringZ("IRQ");
    
    break;
  case 0x13:
    //Super
    printStringZ("SUPERVISOR");
    
    break;
  case 0x17:
    //abort
    printStringZ("ABORT");
    
    break;
  case 0x1b:
    //Undef
    printStringZ("UNDEF");
    
    break;
  case 0x1f:
    //System:
    printStringZ("SYSTEM");
    
    break;
  default:
    printStringZ("UNKNOWN");
    
    break;
  }
  printStringZ(" mode\r\n");
}

/**
r11 = current stack frame
[r11] = current pc
[r11]-1 = current lr
[r11] -2 = previous sp
[r11] -3 = previous fp
  
  
  
 **/

static void flushDebugUart(){
  extern ptrqueue_t outgoingQueue;
  bufferInfo_t *pBI;
  int status;
  
  printStringZ("\r\nFlushing DebugUART\r\n");

  
  pBI = popptrqueue(&outgoingQueue, &status);
  while(status == 1){
    printString(pBI->pBuf,pBI->numBytes);
    pBI = popptrqueue(&outgoingQueue, &status);
  }
    
}

static void unwindStack(){
  uint32_t *fp, *sp, pc, lr;
  volatile uint32_t stackLimit;
  
  printStringZ("\r\nstack dump\r\n");
  stackLimit = 0x5c040000;
  asm volatile (
		"mov %0,R11\n\t"
		: "=r" (fp) 
		);
  
  while(fp < (uint32_t *)stackLimit){
    pc = *fp;
    lr = *(fp-1);
    sp = (uint32_t *)*(fp-2);
    fp = (uint32_t *)*(fp-3);
    
    printStringZ("function ");
    printHex32(pc);
    printStringZ(" called by ");
    printHex32(lr);
    printStringZ("\r\n");
  }
}

static void dumpCore(){
  
  reportSystemFrequency();
  reportSystemState();
  unwindStack();
  dumpTaskQueue();

  flushDebugUart();
}


void printAssertMsg(const char* file, uint32_t line, char *condition){
  uint32_t currentTime = OSCR0;
  
  disable_interrupts();
  configureUART();
  
  printStringZ(csFatalError);
  printDecimal(currentTime);
  printStringZ(": ");
  printStringZ(file);
  printChar(':');
  printDecimal(line);
  printStringZ(": Assertion failed: ");
  printStringZ(condition);
  printChar('\r');
  printChar('\n');
  
  dumpCore();
  
  resetNode();
}

void printFatalErrorMsgHex(const char *msg, uint32_t numArgs, ...){
  uint32_t currentTime= OSCR0;
  uint32_t i;
  va_list args;

  disable_interrupts();
  configureUART();
  
      
  va_start(args, numArgs);
  printStringZ(csFatalError);
  printDecimal(currentTime);
  printStringZ(": ");
  printStringZ(msg);
  
  for(i=0; i<numArgs; i++){
    printHex32(va_arg(args,uint32_t));
    printStringZ(" ");
  }  

  va_end(args);
  
  printChar('\r');
  printChar('\n');

  dumpCore();
  
  resetNode();
}

void printFatalErrorMsg(const char *msg, uint32_t numArgs, ...){
  uint32_t currentTime= OSCR0;
  uint32_t i;
  va_list args;

  disable_interrupts();
  configureUART();
  
      
  va_start(args, numArgs);
  printStringZ(csFatalError);
  printDecimal(currentTime);
  printStringZ(": ");
  printStringZ(msg);
  
  for(i=0; i<numArgs; i++){
    printDecimal(va_arg(args,uint32_t));
    printStringZ(" ");
  }  

  va_end(args);
  
  printChar('\r');
  printChar('\n');

  dumpCore();
  
  resetNode();
}

void resetNode(){
  
  configureUART();
  
  printStringZ(csRebootMsg);
  printChar('\r');
  printChar('\n');
  
  OSMR3 = OSCR0 + RESET_DELAY;
  OWER = 1;
  while(1);
}
