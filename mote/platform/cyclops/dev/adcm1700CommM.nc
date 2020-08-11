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
//
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
// Contents: A high level component to enable communication with camera to
//           write and read data to different block and offset addresses.
//           
//          
//
////////////////////////////////////////////////////////////////////////////
//
// $Header: /home/public_repository/root/tenet/mote/platform/cyclops/dev/adcm1700CommM.nc,v 1.1 2007-07-03 00:57:48 jpaek Exp $
//
// Authors : 
//           Mohammad Rahimi mhr@cens.ucla.edu
//
////////////////////////////////////////////////////////////////////////////


module adcm1700CommM
{
  provides interface StdControl as imagerCommControl;
  provides interface imagerComm[uint8_t id];
  uses {
    interface Leds;

    interface StdControl as I2CStdControl;
    interface I2CPacket;
  }
}
implementation
{

#include <adcm1700Const.h>
#include <I2CPacketImager.h>
    
    enum { 
        //Note: state name always infer the action to be done in next step.
        IMAGER_IDLE = 1,
        //writing happens in two states that is two writing
        IMAGER_WRITING_SET_BLOCK = 2,
        IMAGER_WRITING_DATA = 3,
        //reading happens in three states that is two writing and one reading
        IMAGER_READING_SET_BLOCK = 4,
        IMAGER_READING_SET_OFFSET = 5,
        IMAGER_READING_DATA = 6
    };
    
#define INVALID_ADDRESS 0xff  //we know that the lsb of both Block and offset are always zero
#define MAX_PAYLOAD_SIZE 4

    //the state of the camera in terms of block and offset registers, current data register and its content.
    uint8_t currentBlock;
    uint8_t currentOffset;
    uint16_t currentReg;
    uint16_t currentData;
    
    uint8_t cameraPayload[MAX_PAYLOAD_SIZE];
    uint8_t state;
    uint8_t addr;

    struct register_s *cameraRegister;

  //***********************************************************************************
  //****************************Initialization and Termination ************************
  //***********************************************************************************
  command result_t imagerCommControl.init() {
      state = IMAGER_IDLE;
      currentBlock = INVALID_ADDRESS;
      currentOffset = INVALID_ADDRESS;
      call Leds.init();    
      call I2CStdControl.init();
      return SUCCESS;
  }
  
  command result_t imagerCommControl.start() {
      call I2CStdControl.start(); 
      return SUCCESS;
  }
  
  command result_t imagerCommControl.stop() {
      return SUCCESS;
  }
  
  //***********************************************************************************
  //******************Writing & Reading Data to/from Imager via I2C********************
  //***********************************************************************************

  command result_t imagerComm.writeRegister[uint8_t id](uint16_t reg, uint16_t data)
      {
          // *** RLB 4/21/05 ***
          //    When the following code is included, the first I2C transaction after the first
          // capture fails (although the previous transaction completed correctly. This is
          // an interrupt problem. On the previous version of the board it was corrected by
          // placing the CPLD in SRAM_ACCESS mode before the first capture. 
          //    On the first capture, the initial value of the state variable is IMAGER_WRITING_SET_BLOCK.
          // However the previous I2C command completes normally as evidenced by:
          // 1) The I2C pattern of the previous transaction on the scope is correct.
          // 2) Diagnostic LEDS in the lower layers (I2CPacketImagerM.nc and I2CImagerM.nc)
          // do not reveal a fail condition.
          //    If the state variable is set to IMAGER_IDLE without resetting the interface, a failure
          // condition will be triggered on a lower layer.
          //    I believe that the ATOMIC directive can be used to correct the problem in this
          // interface, but I don't know enough about the scheduler to do it.

          /*  
          if(state != IMAGER_IDLE) 
              {
                  // reset interface to prepare for next transaction
                  state = IMAGER_IDLE;
                  call I2CStdControl.init();              // reset I2C interface
                  signal imagerComm.writeRegisterDone[addr](reg,data,FAIL);
                  call Leds.yellowOn();
                  return FAIL;
              }
          */

          // the next two lines replace the block that has been commented out.
          call I2CStdControl.init();
          state = IMAGER_IDLE; 

          addr=id;
          currentReg = reg;
          currentData = data;
          //if register is in a different block we should set the block.
          if( GET_REGISTER_BLOCK(reg) != currentBlock )
              {
                  state = IMAGER_WRITING_SET_BLOCK;
                  cameraPayload[0]=(((BLOCK_SWITCH_CODE) << 1) & 0xfe )+ 0x00; 
                  cameraPayload[1]=GET_REGISTER_BLOCK(reg);
                  call I2CPacket.writePacket(2,(char*) cameraPayload,STOP_FLAG|ACK_FLAG|ACK_END_FLAG);
              }
          //now that blocks are already set we can only write the actual data
          else 
              {
                  state = IMAGER_WRITING_DATA;
                  cameraPayload[0]=(((GET_REGISTER_OFFSET(reg)) << 1) & 0xfe )+ 0x0; 
                  if(GET_REGISTER_LENGHT(reg)==TWO_BYTE_REGISTER)          //if it is a two byte register 
                      {
                          cameraPayload[1]=(uint8_t) ( data     & 0x00ff);  //lsb of data
                          cameraPayload[2]=(uint8_t) ((data>>8) & 0x00ff);  //msb of data
                          call I2CPacket.writePacket(3,(char*) cameraPayload,STOP_FLAG|ACK_FLAG|ACK_END_FLAG);
                      }
                  else if(GET_REGISTER_LENGHT(reg)==ONE_BYTE_REGISTER)     //if it is a one byte register 
                      {
  			  cameraPayload[1]=(uint8_t) (  data    & 0x00ff);  //1 byte data
                          call I2CPacket.writePacket(2,(char*) cameraPayload,STOP_FLAG|ACK_FLAG|ACK_END_FLAG);
                      }
                  else return FAIL;  //we never should reach here.
              }
          return SUCCESS;
      }
  
  event result_t I2CPacket.writePacketDone(bool r) {
      if(r == SUCCESS)
           {
             switch(state)
                  {
                      //now that we have written new block we should write actual data.
                  case IMAGER_WRITING_SET_BLOCK:
                      currentBlock = GET_REGISTER_BLOCK(currentReg);
                      atomic{state = IMAGER_WRITING_DATA;}
                      cameraPayload[0]=(((GET_REGISTER_OFFSET(currentReg)) << 1) & 0xfe )+ 0x0; 
                      if(GET_REGISTER_LENGHT(currentReg)==TWO_BYTE_REGISTER)
                          {
                              cameraPayload[1]=(uint8_t) ( currentData     & 0x00ff);  //lsb of data
                              cameraPayload[2]=(uint8_t) ((currentData>>8) & 0x00ff);  //msb of data
                              call I2CPacket.writePacket(3,(char*) cameraPayload,STOP_FLAG|ACK_FLAG|ACK_END_FLAG);
                          }
                      else if(GET_REGISTER_LENGHT(currentReg)==ONE_BYTE_REGISTER)
                          {
                              // TYPO!!! DISCOVERED 3/24/05 ==> cameraPayload[1]=(uint8_t) ( currentReg & 0x00ff);  //1 byte data
                              cameraPayload[1]=(uint8_t) ( currentData & 0x00ff);  //1 byte data
                              call I2CPacket.writePacket(2,(char*) cameraPayload,STOP_FLAG|ACK_FLAG|ACK_END_FLAG);
                          }
                      //now that data is also written, do not wait, give signal to user
                      break;
                  case IMAGER_WRITING_DATA:
                      //currentReg++;
                      atomic{state = IMAGER_IDLE;}
                      signal imagerComm.writeRegisterDone[addr](currentReg,currentData,SUCCESS);
                      break;
                  case IMAGER_READING_SET_BLOCK:
                      currentBlock = GET_REGISTER_BLOCK(currentReg);
                      state = IMAGER_READING_SET_OFFSET;
                      cameraPayload[0]=(((GET_REGISTER_OFFSET(currentReg)) << 1) & 0xfe )+ 0x1; 
                      call I2CPacket.writePacket(1,(char*) cameraPayload,ACK_FLAG|ACK_END_FLAG); //no stop flag
                      break;
                  case IMAGER_READING_SET_OFFSET:
                      state = IMAGER_READING_DATA;                      
                      if(GET_REGISTER_LENGHT(currentReg)==TWO_BYTE_REGISTER)
                          {
                              call I2CPacket.readPacket(2,STOP_FLAG|ACK_FLAG);  //FIXME
                          }
                      else if(GET_REGISTER_LENGHT(currentReg)==ONE_BYTE_REGISTER)
                          {
                              call I2CPacket.readPacket(1,STOP_FLAG|ACK_FLAG);  //FIXME
                          }
                      break;
                  default:
                      return FAIL;  //never should reach here.
                  }	// state switch
              
	  }   
      else   //unsuccessful writing!
          {
              switch(state)
                  {
                  case IMAGER_WRITING_SET_BLOCK:
                  case IMAGER_WRITING_DATA:
                      state = IMAGER_IDLE;
                      call I2CStdControl.init();              // reset I2C interface                      
                      signal imagerComm.writeRegisterDone[addr](currentReg,currentData,FAIL);
                      break;
                  case IMAGER_READING_SET_BLOCK:
                  case IMAGER_READING_SET_OFFSET:
                      state = IMAGER_IDLE;
                      call I2CStdControl.init();              // reset I2C interface
                      signal imagerComm.readRegisterDone[addr](currentReg,currentData,FAIL);
                      break;
                  default:
                      return FAIL;  //never should reach here.
                  }
             return FAIL; //shouldn't get here either!
          }

      return SUCCESS;    // program will never reach this point
  }
  
  command result_t imagerComm.readRegister[uint8_t id](uint16_t reg)
  {
      if(state != IMAGER_IDLE) 
          {
              // reset interface to prepare for next transaction
              state = IMAGER_IDLE;
              call I2CStdControl.init();              // reset I2C interface
              signal imagerComm.readRegisterDone[addr](reg,0,FAIL);
              return FAIL;
          } 
      addr=id;
      currentReg = reg;
      //if register is in a different block we should set the block.
      if( GET_REGISTER_BLOCK(reg) != currentBlock )
          {
              state = IMAGER_READING_SET_BLOCK;
              cameraPayload[0]=(((BLOCK_SWITCH_CODE) << 1) & 0xfe )+ 0x00; 
              cameraPayload[1]=GET_REGISTER_BLOCK(reg); 
              call I2CPacket.writePacket(2,(char*) cameraPayload,STOP_FLAG|ACK_FLAG|ACK_END_FLAG);
          }
      //now that blocks are already set we can only read the actual data
      else
          {
              state = IMAGER_READING_SET_OFFSET;
              cameraPayload[0]=(((GET_REGISTER_OFFSET(currentReg)) << 1) & 0xfe) + 0x1;
              call I2CPacket.writePacket(1,(char*) cameraPayload,ACK_FLAG|ACK_END_FLAG); //no stop flag
          }
      return SUCCESS;
  }
  
  event result_t I2CPacket.readPacketDone(char len,char *data) {    
      char msb,lsb;
      if(GET_REGISTER_LENGHT(currentReg)==TWO_BYTE_REGISTER)
          {
              lsb = *data;
              msb = *(data+1);
              currentData =  ( ( ((uint16_t) msb) << 8) & 0xff00)+ ( ((uint16_t) lsb) & 0x00ff);
              state = IMAGER_IDLE;   // *** Change state BEFORE signal!
              signal imagerComm.readRegisterDone[addr](currentReg,currentData,SUCCESS);
          }
      else if(GET_REGISTER_LENGHT(currentReg)==ONE_BYTE_REGISTER)
          {
              currentData = (uint16_t) (*data & 0x00ff);
              state = IMAGER_IDLE;
              signal imagerComm.readRegisterDone[addr](currentReg,currentData,SUCCESS);
          }
      return SUCCESS;
  }
  
  command result_t imagerComm.writeBlock[uint8_t id](uint16_t startReg, char *data,uint8_t length)
      {
          signal imagerComm.writeBlockDone[id](startReg, data, length, SUCCESS);
          return SUCCESS;
      }
  
  command result_t imagerComm.readBlock[uint8_t id](uint16_t startReg,char *data,uint8_t length)
      {
          signal imagerComm.readBlockDone[id](startReg, data, length, SUCCESS);
          return SUCCESS;
      }
  
  default event result_t imagerComm.writeBlockDone[uint8_t id](uint16_t startReg,char *data,uint8_t lenght,result_t status)
      {
          return SUCCESS;
      }
  
  default event result_t imagerComm.readBlockDone[uint8_t id](uint16_t startReg,char *data,uint8_t lenght,result_t status) 
      {
          return SUCCESS;
      }
  
  default event result_t imagerComm.readRegisterDone[uint8_t id](uint16_t reg,uint16_t data,result_t status)
      {
          return SUCCESS;
      }
  
  default event result_t imagerComm.writeRegisterDone[uint8_t id](uint16_t reg,uint16_t data,result_t status)
      {
          return SUCCESS;
      }
}
