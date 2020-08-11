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

/*
 *
 * Authors:		Joe Polastre, Rob Szewczyk
 * Date last modified:  7/18/02
 * Modified on : 08/14/2003 by Mohammad Rahimi for some minor 
 * synchronization problems.
 */

/**
 * Provides functionality for writing and reading packets on the I2C bus
 */

module I2CPacketImagerM
{
  provides {
    interface StdControl;
    interface I2CPacket[uint8_t id];
  }
  uses {
    interface I2C;
    interface StdControl as I2CStdControl;
    interface Leds;
  }
}

implementation
{

#include <I2CPacketImager.h>

  /* state of the i2c request  */
  enum {IDLE=99,
        I2C_START_COMMAND=1,
        I2C_STOP_COMMAND=2,
        I2C_STOP_COMMAND_SENT=3,
        I2C_WRITE_ADDRESS=10,
        I2C_WRITE_DATA=11,
        I2C_READ_ADDRESS=20,
        I2C_READ_DATA=21,
	I2C_READ_DONE=22};

  /**
   *  bytes to write to the i2c bus 
   */
  char* data;    

  /**
   * length in bytes of the request 
   */
  char length;   

  /**
   * current index of read/write byte 
   */
  char index;    

  /** 
   * current state of the i2c request 
   */
  char state;    

  /**
   * destination address 
   */
  char addr;     
  
  /**
   * store flags 
   */
  char flags;    

  /**
   * cache incoming bytes : 10 is a random number
   */
  char temp[10]; 

  /**
   * initialize the I2C bus and set initial state
   */

command result_t StdControl.init() {
    
    call I2CStdControl.init();
    atomic {
        state = IDLE;
        index = 0;
    }
    return SUCCESS;
  }
 
/**
   * start the component 
   **/
command result_t StdControl.start() {
     return SUCCESS;
 }
 
 /**
   * stop the component
   **/
command result_t StdControl.stop() {
     return SUCCESS;
  }
 
  /**
   * writes a series of bytes out to the I2C bus 
   *
   * @param in_length number of bytes to be written to the bus
   * @param in_data pointer to the data
   * @param in_flags bitmask of flags (see I2CPacket.ti interface)
   *
   * @return returns SUCCESS if the bus is free and the request is accepted.
   */
  command result_t I2CPacket.writePacket[uint8_t id](char in_length,char* in_data, char in_flags) {      
      
      uint8_t status;
      atomic {
      status = FALSE;
      if (state == IDLE)
          {
              /*  reset variables  */
              addr = id;
              data = in_data;
              index = 0;
              length = in_length;
              flags = in_flags;
              state = I2C_WRITE_ADDRESS;
              status = TRUE;
          }
      }
      if(status == FALSE ) {
          signal I2CPacket.writePacketDone[id](FAIL);
          return FAIL;
      }
      
      
      if (call I2C.sendStart())
          {
              return SUCCESS;
          }
      else
          {
              atomic { state = IDLE; }
              signal I2CPacket.writePacketDone[id](FAIL);
              return FAIL;
          }
  }
  
  /**
   * reads a series of bytes out to the I2C bus 
   *
   * @param in_length number of bytes to be read from the bus
   * @param in_flags bitmask of flags (see I2CPacket.ti interface)
   *
   * @return returns SUCCESS if the bus is free and the request is accepted.
   */
 command result_t I2CPacket.readPacket[uint8_t id](char in_length, 
                                                    char in_flags) {
      uint8_t status;
      atomic {
          status = FALSE;
          if (state == IDLE)
              {
                  addr = id;
                  index = 0;
                  length = in_length;
                  flags = in_flags;
                  state = I2C_READ_ADDRESS;
                  status = TRUE;
              }
      }
      if(status == FALSE ) {
          return FAIL;                    // need to signal done with FAIL !!!!
      }
      
      if (call I2C.sendStart())
          {
              return SUCCESS;
          }
      else
          {
              atomic { state = IDLE; }   
              return FAIL;                // need to signal done with FAIL !!!!
          }
  }
  
  /**
   * notification that the start symbol was sent 
   **/
event result_t I2C.sendStartDone() {
        if(state == I2C_WRITE_ADDRESS){
            state = I2C_WRITE_DATA;
            call I2C.write( (flags & ADDR_8BITS_FLAG) ? addr : ((addr << 1) + 0) );
        }
        else if (state == I2C_READ_ADDRESS){
            state = I2C_READ_DATA;
            call I2C.write( (flags & ADDR_8BITS_FLAG) ? addr : ((addr << 1) + 1) );
            index++;
        }
    return 1;
}
 
  /**
   * notification that the stop symbol was sent 
   **/
event result_t I2C.sendEndDone() 
{
      if (state == I2C_STOP_COMMAND_SENT) 
      {
	// success!
	state = IDLE;
    TOSH_uwait(20);    // additional inter-command delay
	signal I2CPacket.writePacketDone[addr](SUCCESS);
      }
      else if (state == I2C_READ_DONE) 
      {
	state = IDLE;
    TOSH_uwait(20);    // additional inter-command delay
	signal I2CPacket.readPacketDone[addr](length, data);
      }

      return SUCCESS;
}
 
  /**
   * notification of a byte sucessfully written to the bus 
   **/
event result_t I2C.writeDone(bool result) {
      if(result == FAIL) 
         {
     	     state = IDLE;
             signal I2CPacket.writePacketDone[addr](FAIL);
             return FAIL;
        }
    else if ((state == I2C_WRITE_DATA) && (index < length))
        {
            index++;
            if (index == length) {
                state = I2C_STOP_COMMAND;
            }
            return call I2C.write(data[index-1]);
        }
    else if (state == I2C_STOP_COMMAND)
        {
            state = I2C_STOP_COMMAND_SENT;
            if (flags & STOP_FLAG)
                {
                    return call I2C.sendEnd();
                }
            else {
                state = IDLE;
                //TOSH_uwait(200);    // additional inter-packet delay
                return signal I2CPacket.writePacketDone[addr](SUCCESS);
            }
        }
    else if (state == I2C_READ_DATA)
        {
            if (index == length)
                {
                    return call I2C.read((flags & ACK_END_FLAG) == ACK_END_FLAG);
                }
            else if (index < length)
                return call I2C.read((flags & ACK_FLAG) == ACK_FLAG);
        }
    
    return SUCCESS;
}


  /**
   * read a byte off the bus and add it to the packet 
   **/
event result_t I2C.readDone(char in_data) {
    temp[index-1] = in_data;
    index++;
    if (index == length)
        call I2C.read((flags & ACK_END_FLAG) == ACK_END_FLAG);
    else if (index < length)
        call I2C.read((flags & ACK_FLAG) == ACK_FLAG);
    else if (index > length)
          {
              state = I2C_READ_DONE;
              data = (char*)(&temp);
              if (flags & STOP_FLAG)
                  call I2C.sendEnd();
              else
                  {
                      state = IDLE;
                      //TOSH_uwait(200);    // additional inter-packet delay
                      signal I2CPacket.readPacketDone[addr](length, data);
                  }
          }
      return SUCCESS;
  }
  
  default event result_t I2CPacket.readPacketDone[uint8_t id](char in_length, char* in_data) {
    return SUCCESS;
  }

  default event result_t I2CPacket.writePacketDone[uint8_t id](bool result) {
    return SUCCESS;
  }

}

