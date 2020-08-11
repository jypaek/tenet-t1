////////////////////////////////////////////////////////////////////////////
// 
// CENS 
// Agilent
//
// Copyright (c) 2003 The Regents of the University of California.  All 
// rights reserved.
//
// Copyright (c) 2003 Agilent Corporation 
// rights reserved.
//	  // call Leds.greenOff();

// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions
// are met:
//
// - Redistributions of source code must retain the above copyright
//   notice, this list of conditions and the following disclaimer.
//
// - Neither the name of the University nor Agilent Corporation nor 
//   the names of its contributors may be used to endorse or promote 
//   products derived from this software without specific prior written 
//   permission.
//
// THIS SOFTWARE IS PROVIDED BY THE REGENTS , AGILENT CORPORATION AND 
// CONTRIBUTORS ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, 
// BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS 
// FOR A PARTICULAR  PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE REGENTS OR
// AGILENT CORPORATION OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, 
// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT 
// NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, 
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
// OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// Contents: This file contains the implementaion of the CPLD command
//           and communication. For CPLD detail contact rick below.
//
// Purpose: The purpose of this functionality is to implement the protocl
//          that enables cpld to change its status
//          
//
////////////////////////////////////////////////////////////////////////////
//
// $Header: /home/public_repository/root/tenet/mote/platform/cyclops/cpldM.nc,v 1.1 2007-07-03 00:57:48 jpaek Exp $
//
// Authors : 
//           Mohammad Rahimi mhr@cens.ucla.edu 
//           Rick Baer       rick_baer@agilent.com 
//
////////////////////////////////////////////////////////////////////////////

includes cpldConst;

module cpldM {
  provides {
    interface StdControl as cpldControl;
    interface cpld[uint8_t id];
  }
  uses {
    interface Leds;
    interface Timer;
  }
}
implementation {

  /*
  Note: psedoCode for the behaviour of the component
  case OPCODE_STANDBY:
  case CPLD_OPCODE_RESET:
  download command to cpld and return success immidiately,signals cpld.setCpldModeDone immidiately.
  case CPLD_OPCODE_RUN_CAMERA:
  case CPLD_MCU_ACCESS_SRAM:
  cae CPLD_MCU_ACCESS_FLASH:  
  download command to cpld and return success immidiately,signals cpld.setCpldModeDone immidiately.
  user should call cpld.stdByCpld() when done so that other component can use cpld.
  case OPCODE_CAPTURE_IMAGE:
  case CPLD_OPCODE_CAPTURE_TEST_PATTERN:
  download command to cpld and return success immidiately.
  Later cpld Interrupt happens and this component signals cpld.setCpldModeDone and make cpld standby
  case CPLD_OPCODE_TRANSFER_SRAM_TO_FLASH:
  case CPLD_OPCODE_TRANSFER_FLASH_TO_SRAM:
  download command to cpld and return success immidiately.
  Later cpld Interrupt happens and this component signals cpld.setCpldModeDone and make cpld standby
  */
  
  /*
    start : turn the regulator on and set cpld in standby.
    stop  : set cpld in standby and turn the regulator off. 
  */
  uint8_t state;
  cpldCommand_t  *cpldCode;
  uint8_t calling_id;
  //  uint8_t writeDelay; 

  //****************************HS Lines Functionality************************
  //HS0 which is program/run mode pin and is connected to PORTE pin 5
  //HS1 which is clock pin is connected to PORTE pin 6
  //HS2 is cpld reply pin is connected to PORTE pin 7, it is also interrupt 7 and can be set in interrupt mode.
  //HS3 is MCLK control pin, connected to PORTE pin4

  //HS0 definition
#define MAKE_MODE_PIN_OUTPUT()  sbi(DDRE, 5)
    //#define MAKE_MODE_PIN_INPUT()   cbi(DDRE, 5)
#define SET_CPLD_PROGRAM_MODE() cbi(PORTE, 5)
#define SET_CPLD_RUN_MODE()     sbi(PORTE, 5)

  //HS1 definition
#define MAKE_CLOCK_PIN_OUTPUT() sbi(DDRE, 6)
    //#define MAKE_CLOCK_PIN_INPUT()  cbi(DDRE, 6)
#define SET_CLOCK()             sbi(PORTE, 6)
#define CLEAR_CLOCK()           cbi(PORTE, 6)

  //HS2 definition, it is input and it is interrupt pin
#define MAKE_STATUS_PIN_INPUT() cbi(DDRE, 7)
#define GET_CPLD_STATUS()   ((inp(PINE) >> 7) & 0x1)
#define INT_ENABLE()  sbi(EIMSK , 7)  //Interrupt definition.INT7 of MCU 
#define INT_DISABLE() cbi(EIMSK , 7)
#define INT_RISING_EDGE() {sbi(EICRB,ISC71);sbi(EICRB,ISC70);} //Note this is asynchronous INT.

 // HS3 definition
#define MAKE_MCLK_CTRL_PIN_OUTPUT() sbi(DDRE, 4)
    //#define MAKE_MCLK_CTRL_PIN_INPUT()  cbi(DDRE, 4)
#define TURN_MCLK_ON() sbi(PORTE, 4)
#define TURN_MCLK_OFF() cbi(PORTE, 4)

 // I2C monitoring pins
    // The I2C lines must not be configured as outputs when the memory system is shut down
#define MAKE_I2C_CLOCK_PIN_INPUT()  cbi(DDRD, 6)
#define MAKE_I2C_CLOCK_PIN_OUTPUT() sbi(DDRD, 6)
#define SET_I2C_CLOCK_OFF()         cbi(PORTD, 6)
#define MAKE_I2C_DATA_PIN_INPUT()   cbi(DDRD, 7)
#define MAKE_I2C_DATA_PIN_OUTPUT()  sbi(DDRD, 7)
#define SET_I2C_DATA_OFF()          cbi(PORTD, 7)

// CPLD clock control
#define MAKE_CPLD_CLOCK_PIN_OUTPUT() sbi(DDRB, 6)
#define TURN_CPLD_CLOCK_ON()  sbi(PORTB, 6)  // enable CPLD clock oscillator
#define TURN_CPLD_CLOCK_OFF() cbi(PORTB, 6)  // disable CPLD clock oscillator

  //****************************SRAM Functionality************************
  //NOTE: the fact that RD and most importatnly WR remains high during transion is extremely important for the
  //safe operation of peripherals not to write to them.

#define MAKE_WR_PIN_OUTPUT() sbi(DDRG, 0)
#define MAKE_RD_PIN_OUTPUT() sbi(DDRG, 1)                 
#define MAKE_WR_PIN_INPUT() cbi(DDRG, 0)                  //this pins should be alwas input not to fight with CPLD
#define MAKE_RD_PIN_INPUT() cbi(DDRG, 1)                  //this pins should be alwas input not to fight with CPLD

    //  SRW11   SRW10
    //    0       0       no wait states
    //    0       1       wait one cycle during R/W strobe
    //    1       0       wait two cycles during R/W strobe
    //    1       1       wait two cycles during R/W strobe, wait one cycle before driving new address
#define SET_SRAM_WAIT_STATES() sbi(XMCRA,SRW11); sbi(MCUCR,SRW10)      

    //NOTE: Bits 5..2 of the MCUCR register control the sleep mode. 
#define MAKE_SRAM_60K() outp(((0<<XMM2) | (0<<XMM1) | (0<<XMM0)),XMCRB)                //make memory space 60KB. 
    //#define SET_RAM_CONTROL_LINES_IN_SAFE_MODE() cbi(DDRG, 0); cbi(DDRG, 1); sbi(PORTG, 0); sbi(PORTG, 1); outp((1<<XMBK),XMCRB) //make RD,WR input pins and enable the bus keeper 
    // Pull-ups keep the memories off (*** may not be required ***)
#define SET_RAM_CONTROL_LINES_IN_SAFE_MODE() cbi(DDRG, 0); cbi(DDRG, 1); sbi(PORTG, 0); sbi(PORTG, 1); cbi(XMCRB,XMBK) //make RD,WR input pins and disable the bus keeper 
#define SET_RAM_CONTROL_LINES_ZERO() sbi(DDRG, 0);sbi(DDRG, 1);cbi(PORTG, 0);cbi(PORTG, 1);cbi(XMCRB,XMBK) //make RD,WR output-low pins and disable the bus keeper 
#define SET_RAM_CONTROL_LINES_ONE()  sbi(DDRG, 0);sbi(DDRG, 1);sbi(PORTG, 0);sbi(PORTG, 1);cbi(XMCRB,XMBK) //make RD,WR output-low pins and disable the bus keeper 
#define SET_RAM_LINES_PORT_MODE() cbi(MCUCR,SRE)           //behave like ordinary registers
#define SET_RAM_LINES_EXTERNAL_SRAM_MODE() sbi(MCUCR,SRE)  //Secondry external SRAM 
#define MAKE_PORTA_OUTPUT() outp(0xff,DDRA)
#define MAKE_PORTA_INPUT() outp(0x00,DDRA)
    // Pull-ups are required on PORTA because the address latch is on the same power
    // supply as the uP. If the PORTA lines float, the inputs of the latch will
    // draw excessive current. The address latch should be attached to the memory
    // system power supply (BVcc) in future revisions of Cyclops in order to avoid
    // wasting power. 
#define MAKE_PORTA_INPUT_PULL_UP() outp(0x00,DDRA);outp(0xFF,PORTA)
#define MAKE_PORTA_ZERO() outp(0x00,PORTA);outp(0xFF,DDRA)
#define MAKE_PORTC_OUTPUT() outp(0xff,DDRC) 
#define MAKE_PORTC_INPUT() outp(0x00,DDRC)
    // Pull-ups are NOT required on PORTC because the memory system is powered down.
    // Pull-ups waste power.
#define MAKE_PORTC_INPUT_NOT_PULL_UP() outp(0x00,DDRC);outp(0x00,PORTC)
#define MAKE_PORTC_INPUT_PULL_UP() outp(0x00,DDRC);outp(0xFF,PORTC)
#define MAKE_PORTC_ZERO() outp(0x00,PORTC);outp(0xFF,DDRC)

    // dives address latch
#define SET_ADDRESS_LATCH()   sbi(PORTG,2);sbi(DDRG,2)
#define CLEAR_ADDRESS_LATCH() cbi(PORTG,2);sbi(DDRG,2)

    // drives _OE input of address latch
#define MAKE_ALE_OE_OUTPUT() sbi(DDRE,2)
#define ADDRESS_LATCH_OUTPUT_ENABLE() cbi(PORTE,2)
#define ADDRESS_LATCH_OUTPUT_DISABLE() sbi(PORTE,2)

  //*******************cpld Voltage Regulator Functionality***************
#define MAKE_VOLTAGE_REGULATOR_PIN_OUTPUT() sbi(DDRB, 7)
#define TURN_VOLTAGE_REGULATOR_ON()         cbi(PORTB, 7)  //by making the pin low we turn on the P-Channel Mosfet
#define TURN_VOLTAGE_REGULATOR_OFF()        sbi(PORTB, 7)  //by making the pin high we turn off the P-Channel Mosfet


  //****************************Utility functions************************
  void delay() { asm volatile  ("nop" ::);}
  
  static inline void clk()
    {
      delay();
      CLEAR_CLOCK();
      delay();
      SET_CLOCK();
      delay();
      CLEAR_CLOCK();
    }
  
 
  static inline void downloadCpld(cpldCommand_t *myCpld)
      {
          // uP control of the address and data busses is released whenever a new CPLD command
          // is downloaded.
          uint8_t i;
          char buf[sizeof(cpldCommand_t)];
          //copy data structure to char memory so that outp does not complain about data mismatch.
          memcpy(buf,(char *) myCpld,sizeof(cpldCommand_t));
          //size of cpldCommand_t devide by eight (shift 3) is number of byte to put on bus

          SET_CPLD_PROGRAM_MODE();    // place CPLD in program mode
          SET_RAM_LINES_PORT_MODE();  // ... before taking control of data bus
          MAKE_PORTA_OUTPUT();   // use data lines for programming
          MAKE_PORTC_INPUT_PULL_UP();    // return high address lines to input mode (after direct memory access)
          for(i=0; i < ( sizeof(cpldCommand_t)) ;i++) 
              {
                  outp(buf[i],PORTA);
                  clk();
              }

          ADDRESS_LATCH_OUTPUT_DISABLE();	// release uP control of address bus, and
          MAKE_PORTA_INPUT_PULL_UP();		// release uP control of data bus
          SET_CPLD_RUN_MODE();      // ... before changing CPLD mode
      }
  
  static inline void setDirectMemAccess()
      {          
          cpldCommand_t myCpldCommand;
          myCpldCommand.opcode = CPLD_OPCODE_MCU_ACCESS_SRAM;
          myCpldCommand.sramBank=0;
          myCpldCommand.flashBank=0;
          myCpldCommand.startPageAddress=0x11;
          myCpldCommand.endPageAddress=0xff;          
          atomic { state = CPLD_MCU_ACCESS_SRAM; }
          downloadCpld(&myCpldCommand);
          ADDRESS_LATCH_OUTPUT_ENABLE();		// uP takes control of low address bus
          MAKE_PORTC_OUTPUT();                  // uP takes control of high address bus
          MAKE_PORTA_OUTPUT();		            // uP takes control of data bus
          SET_RAM_LINES_EXTERNAL_SRAM_MODE();
          atomic {TOSH_CYCLOPS_RESET_DIRECT_MEMORY_ACCESS();}
      }
  
  static inline void setCpldStanddBy()
      {
          cpldCommand_t myCpldCommand;
          myCpldCommand.opcode = CPLD_OPCODE_STANDBY;
          myCpldCommand.sramBank=0;
          myCpldCommand.flashBank=0;
          myCpldCommand.startPageAddress=0;
          myCpldCommand.endPageAddress=0;
          downloadCpld(&myCpldCommand);
          atomic {state = CPLD_STANDBY;}

          // Drive all of the address and data lines to zero in order to minimize power consumption
          // by avoiding floating lines without resorting to pull-up resistors.
          ADDRESS_LATCH_OUTPUT_ENABLE();		// uP takes control of low address bus
          MAKE_PORTA_ZERO();                    // uP takes control of high address bus
          MAKE_PORTC_ZERO();		            // uP takes control of data bus
          SET_ADDRESS_LATCH();
          TOSH_uwait(5);
          CLEAR_ADDRESS_LATCH();    
      }
  
  task void processSignal()
      {
          INT_DISABLE();                          // disable further interrupts
          signal cpld.setCpldModeDone[calling_id](cpldCode);
      }
 
  
  //****************************Initialization and Termination ************************
  command result_t cpldControl.init() { 

      //     writeDelay = 0;   // delay clock for transfers to Flash memory

      //be safe before things stable
      INT_DISABLE();
      INT_RISING_EDGE();

      TURN_CPLD_CLOCK_OFF();
      MAKE_CPLD_CLOCK_PIN_OUTPUT();

      //set direction of CPLD control pins
      SET_I2C_CLOCK_OFF();            // make I2C imager control pins output, with zero value
      MAKE_I2C_CLOCK_PIN_OUTPUT();
      SET_I2C_DATA_OFF();
      MAKE_I2C_DATA_PIN_OUTPUT();

      TURN_VOLTAGE_REGULATOR_OFF();
      MAKE_VOLTAGE_REGULATOR_PIN_OUTPUT();

      MAKE_STATUS_PIN_INPUT();
      CLEAR_CLOCK();
      MAKE_CLOCK_PIN_OUTPUT();
      TURN_MCLK_OFF();
      MAKE_MCLK_CTRL_PIN_OUTPUT();
      SET_CPLD_PROGRAM_MODE();
      MAKE_MODE_PIN_OUTPUT();

      //set direction of bus control pins
      MAKE_PORTA_OUTPUT();
      //SET_SRAM_WAIT_STATES();                 // add wait states to prevent contention during RAM access
      //make ram space 60KB.
      MAKE_SRAM_60K();
      //Note: the assumption below is that they keep being in safe state even when the 
      //SRAM mode is back to direct port mode since bus-keeper is enabled.
      SET_RAM_CONTROL_LINES_IN_SAFE_MODE();
      MAKE_ALE_OE_OUTPUT();             // drive low value 
      ADDRESS_LATCH_OUTPUT_DISABLE();
      TURN_VOLTAGE_REGULATOR_OFF();
      atomic {state = CPLD_OFF;}
      return SUCCESS;
  }
  
  command result_t cpldControl.start() {    
      // This if is here to avoid a component suddendy change the status of the device
      // if it has been already started and in bussiness by sombody else
      uint8_t s;
      atomic{s=state;}
      if( s == CPLD_OFF )
          {
              INT_DISABLE();

              SET_CPLD_RUN_MODE();          // start from run mode to ensure correct programming

              MAKE_PORTA_INPUT_PULL_UP();      
              MAKE_PORTC_INPUT_PULL_UP();

              // A 100 usec delay is required in order to allow the 1.8 V regulator to
              // reach steady state. 
              TURN_VOLTAGE_REGULATOR_ON();
              TOSH_uwait(100);

              SET_RAM_CONTROL_LINES_ONE();
              
              // A 500 usec delay is required to allow the clock to start.
              TURN_CPLD_CLOCK_ON();
              TOSH_uwait(500);

              //rlb: Capture can't be performed directly from standby mode because HS2 is already
              //     low. It causes subtle problems that interfere with the correct operation
              //     of the imager I2C interface.
              
              setDirectMemAccess();       //alternative: setCpldStanddBy();
          }

      return SUCCESS;
  }
  
  command result_t cpldControl.stop() {
      setCpldStanddBy();
      delay();

      SET_CPLD_PROGRAM_MODE();       // set all handshake lines low
      CLEAR_CLOCK();
      TURN_MCLK_OFF();

      TURN_CPLD_CLOCK_OFF();

      SET_I2C_CLOCK_OFF();          // prevent I2C lines from powering CPLD
      SET_I2C_DATA_OFF();

      ADDRESS_LATCH_OUTPUT_DISABLE();

      SET_RAM_LINES_PORT_MODE();             // prevent uP from driving unpowered CPLD
      SET_RAM_CONTROL_LINES_ZERO();          // prevent RD,WR from driving unpowered CPLD

      // Drive address and data ports low to keep inputs from floating (and consuming high current)
      MAKE_PORTA_ZERO();
      MAKE_PORTC_ZERO();

      TURN_VOLTAGE_REGULATOR_OFF();
      atomic { state = CPLD_OFF; }
      return SUCCESS;
  }
  
  // *** NOTE: 1) release control of the data and address busses BEFORE downloading a new CPLD command
  //           2) take control of the data and address busses AFTER downloading a new CPLD command
  
  //****************************Setting CPLD Status and such****************************
  command result_t cpld.setCpldMode[uint8_t id](cpldCommand_t *myCpld)
      {
          //if(state != CPLD_STANDBY) return FAIL;
          //     SET_RAM_LINES_PORT_MODE();
          cpldCode = myCpld;
          calling_id = id;
          //these cases the result are immidiate. The rest of the casese should wait for Interrupt.
          // ***************************************************************
          // ******* FIX THIS !!!   FIX THIS !!! ***************************
          // Unless interrupts are enabled at this point, an interrupt will 
          // occur when capture is intiated, regardless of the state of HS2. 
          // This could be caused by a glitch in HS2, which is not registered,
          // but I don't see it on the logic analyzer, or the scope.
          INT_ENABLE();   // enable interrupts first, or it doesn't work.   
          // ***************************************************************
          // ***************************************************************
          switch((cpldCode->opcode & 0x0f))  // RLB 7/21/05: filtered out repeat count
              {
              case CPLD_OPCODE_STANDBY:
              case CPLD_OPCODE_RESET:
                  downloadCpld(cpldCode);
                  // Drive all of the address and data lines to zero in order to minimize power consumption
                  // by avoiding floating lines without resorting to pull-up resistors.
                  ADDRESS_LATCH_OUTPUT_ENABLE();		// uP takes control of low address bus
                  MAKE_PORTA_ZERO();                    // uP takes control of high address bus
                  MAKE_PORTC_ZERO();		            // uP takes control of data bus
                  SET_ADDRESS_LATCH();
                  TOSH_uwait(5);
                  CLEAR_ADDRESS_LATCH();    
                  atomic { state = CPLD_STANDBY; }
                  signal cpld.setCpldModeDone[calling_id](cpldCode);
                  break;
              case CPLD_OPCODE_MCU_ACCESS_SRAM:
                  //mhr::This is the default mode
                  downloadCpld(cpldCode);
                  atomic { state = CPLD_MCU_ACCESS_SRAM; }
                  ADDRESS_LATCH_OUTPUT_ENABLE();  		// uP takes control of low address bus
                  MAKE_PORTC_OUTPUT();                    // uP takes control of high address bus
                  MAKE_PORTA_OUTPUT();            		// uP takes control of data bus
                  SET_RAM_LINES_EXTERNAL_SRAM_MODE();
                  atomic {TOSH_CYCLOPS_RESET_DIRECT_MEMORY_ACCESS();}
                  signal cpld.setCpldModeDone[calling_id](cpldCode); //This assumes that CPLD does it very fast
                  break;
              case CPLD_OPCODE_MCU_ACCESS_FLASH:
                  //mhr:: This is something to think about it
                  downloadCpld(cpldCode);
                  atomic { state = CPLD_MCU_ACCESS_FLASH; }
                  ADDRESS_LATCH_OUTPUT_ENABLE();		// uP takes control of low address bus
                  MAKE_PORTC_OUTPUT();        // uP takes control of high address bus
                  MAKE_PORTA_OUTPUT();		// uP takes control of data bus
                  SET_RAM_LINES_EXTERNAL_SRAM_MODE();
                  signal cpld.setCpldModeDone[calling_id](cpldCode);
                  break;
              case CPLD_OPCODE_CAPTURE_IMAGE:  //returns through INT
                  //mhr:: DMA mode
                  //rlb: Capture should not be attempted from STANDBY mode.
                  INT_ENABLE();   // enable interrupts first, or it doesn't work.                   
                  downloadCpld(cpldCode);  
                  atomic { state = CPLD_CAPTURE_IMAGE; }
                  atomic {TOSH_CYCLOPS_SET_DIRECT_MEMORY_ACCESS();}
                  break;
              case CPLD_OPCODE_CAPTURE_TEST_PATTERN: //returns through INT
                  //mhr:: DMA mode
                INT_ENABLE();
                downloadCpld(cpldCode);
                atomic { state = CPLD_CAPTURE_TEST_PATTERN; }
                atomic {TOSH_CYCLOPS_SET_DIRECT_MEMORY_ACCESS();}
                  break;          
              case CPLD_OPCODE_TRANSFER_SRAM_TO_FLASH: //returns through INT
                  // RLB: 4/29/05
                  // The CPLD must wait for at least 20 milliseconds after each segment write. The uP provides a
                  // 30 msec clock signal on HS1 for this purpose. In the original design, the CPLD was to use an 
                  // RC delay. Unfortunately the time constant is too short with the existing RC values, and the 
                  // slowly slewing signal could cause excessive current consumption when applied to a digital input.  
                  downloadCpld(cpldCode);
                  INT_ENABLE();                
                  //call Timer.start(TIMER_REPEAT, 15);    // 30 millisecond period for Flash segment writes (on HS1)
                  atomic { state = CPLD_TRANSFER_SRAM_TO_FLASH; }
                  break;
              case CPLD_OPCODE_TRANSFER_FLASH_TO_SRAM: //returns through INT
                  //FIX ME!
                  //mhr:: This is something to think about it: TOSH_CYCLOPS_SET_DIRECT_MEMORY_ACCESS();
                  downloadCpld(cpldCode);
                  INT_ENABLE();
                  atomic { state = CPLD_TRANSFER_FLASH_TO_SRAM;}
                  break;
              case CPLD_OPCODE_RUN_CAMERA:
                  // RLB: 4/29/05 
                  // This mode is obsolete in Cyclops2. The camera clock is now controlled independently by HS3,
                  // not by the CPLD. This mode has only been included for backward compatibility.
                  // The uP may access the SRAM in this mode.
                  downloadCpld(cpldCode);
                  atomic { state = CPLD_RUN_CAMERA;}
                  call Timer.start(TIMER_ONE_SHOT, 150);   // Start timer and signal after 150 mSec delay
                  break;
              default:
                  return FAIL;
              }     
          return SUCCESS;
      }
  
  command result_t cpld.stdByCpld[uint8_t id]()
      {
          setCpldStanddBy();
          return SUCCESS;
      }
    
  default event result_t cpld.setCpldModeDone[uint8_t id](cpldCommand_t *cpldCd)
      {
          return SUCCESS;
      }
  

  event result_t Timer.fired() 
      { 

          switch(cpldCode->opcode & 0x0f)	// signal after delay
              {
              case CPLD_OPCODE_RUN_CAMERA:                  
                  signal cpld.setCpldModeDone[calling_id](cpldCode);
                  break;
                  //case CPLD_OPCODE_TRANSFER_SRAM_TO_FLASH:
                  //if (writeDelay)
                  //    SET_CLOCK();
                  //else
                  //    CLEAR_CLOCK();
                  //writeDelay = !writeDelay;
                  //break;
              default:
              }

          return SUCCESS;
      }
  
  
  //**************************************************** 
  //A transaction such as Image Capture or Copy between Flash and SRAM has been
  //done. We post a task so that the result in upper layer does not happen inside
  //an interrupt service routine.
  TOSH_SIGNAL(SIG_INTERRUPT7)
      {
          switch(state)
              {
              case CPLD_TRANSFER_SRAM_TO_FLASH:
                  //                  call Timer.stop();     // stop HS1 delay timer for Flash write
                  CLEAR_CLOCK();
              case CPLD_CAPTURE_IMAGE:
              case CPLD_CAPTURE_TEST_PATTERN:
              case CPLD_TRANSFER_FLASH_TO_SRAM:
                setDirectMemAccess();
                  break;          
              default:
              }
          post processSignal();
          return;
      }
}
