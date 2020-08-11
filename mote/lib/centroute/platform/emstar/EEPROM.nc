// $Id: EEPROM.nc,v 1.1 2007-11-17 00:55:24 karenyc Exp $

/*									tab:4
 * "Copyright (c) 2000-2003 The Regents of the University  of California.  
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
 * Copyright (c) 2002-2003 Intel Corporation
 * All rights reserved.
 *
 * This file is distributed under the terms in the attached INTEL-LICENSE     
 * file. If you do not find these files, copies can be found by writing to
 * Intel Research Berkeley, 2150 Shattuck Avenue, Suite 1300, Berkeley, CA, 
 * 94704.  Attention:  Intel License Inquiry.
 */
/*
 *
 * Authors:		Jason Hill, David Gay, Philip Levis
 * Date last modified:  6/25/02
 *
 */

/**
 * @author Jason Hill
 * @author David Gay
 * @author Philip Levis
 */

/* EmTOS mods by Thanos Stathopoulos */

includes tos_emstar;

module EEPROM
{
  provides {
    interface StdControl;
    interface EEPROMRead;
    interface EEPROMWrite[uint8_t writerId];
  }
}
implementation
{
enum {
    PHASE = 1,
    IDLE = 0,
    SEND_CMD = 1,
    READ_DATA = 2,
    WIDLE = 3,
    WRITE_DATA = 4,

    LOGGER_DELAY = 40000,   // 10 milliseconds (40,000 cycles)
    APPEND_ADDR_START = 16
};

char state;
char *data_buf;
char data_len;
int last_line;
int read_line;
uint8_t currentWriter;
   
char *readBuf;
char *writeBuf;
result_t readResult;

command result_t EEPROMRead.read(uint16_t line, uint8_t *buffer) 
{
    if (state == IDLE) {
      data_buf = buffer;
      state = READ_DATA;
      data_len = TOS_EEPROM_LINE_SIZE;
      read_line = line;

	  emtos_eeprom_read(line, buffer);

      return SUCCESS;
    }
    else {
      return FAIL;
    }
}


command result_t EEPROMWrite.startWrite[uint8_t id]() 
{
    if (state != IDLE) {
		printf("state != IDLE\n");
		fflush(stdout);
      return FAIL;
	}
    state = WIDLE;
    currentWriter = id;

    return SUCCESS;
}


command result_t EEPROMWrite.write[uint8_t id](uint16_t line, uint8_t *buffer)
{
    if (state != WIDLE || id != currentWriter)
      return FAIL;
  
    data_buf = buffer;
    data_len = TOS_EEPROM_LINE_SIZE;
    last_line = line;
    state = WRITE_DATA;

	emtos_eeprom_write(line, buffer);
    return SUCCESS;
}


command result_t EEPROMWrite.endWrite[uint8_t id]() 
{
    if (state != WIDLE || id != currentWriter) {
		printf("endWrite returns FAIL (state=%d, id=%d)\n",state, id);
		fflush(stdout);
      return FAIL;
	}
    
    state = IDLE;
    signal EEPROMWrite.endWriteDone[currentWriter](SUCCESS);
    return SUCCESS;
}


default event result_t EEPROMWrite.writeDone[uint8_t id](uint8_t *buffer) {
    return FAIL;
}


default event result_t EEPROMWrite.endWriteDone[uint8_t id](result_t result) {
    return FAIL;
}

task void readDone()
{

	state = IDLE;
	signal EEPROMRead.readDone(readBuf, readResult);
}


task void writeDone()
{
	state = WIDLE;
	signal EEPROMWrite.writeDone[currentWriter](writeBuf);
}


void eeprom_read_done(uint8_t *buffer, int8_t retcode)
{
	result_t result;
	if (retcode==1) {
		result=SUCCESS;
	} else {
		result=FAIL;
	}

	if (buffer==NULL) {
		printf("NULL buffer pointer\n");
		exit(0);
	}

	readBuf=buffer;
	readResult=retcode;
	post readDone();

}



void eeprom_write_done(uint8_t *buffer)
{
	if (buffer==NULL) {
		printf("NULL buffer pointer\n");
		exit(0);
	}

	writeBuf=buffer;
	post writeDone();


}

command result_t StdControl.init() 
{
	fp_list_t *list=get_fplist();

  	if (list==NULL) {
		printf("NULL fplist!\n");
		exit(0);
	}
	

	list->Eeprom_readDone=eeprom_read_done;
	list->Eeprom_writeDone=eeprom_write_done;

		
    state = IDLE;
    last_line = APPEND_ADDR_START;
   
	emtos_eeprom_init(list);
	
    dbg(DBG_BOOT, "Logger initialized.\n");
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
