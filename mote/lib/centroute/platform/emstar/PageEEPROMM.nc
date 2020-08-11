// $Id: PageEEPROMM.nc,v 1.1 2007-11-17 00:55:24 karenyc Exp $

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
includes crc;
includes PageEEPROM;
includes tos_emstar;
module PageEEPROMM {
  provides {
    interface StdControl;
    interface PageEEPROM;
  }
  uses {
    interface Leds;
  }
}
implementation
{

  enum { // requests
    IDLE,
    R_READ,
    R_READCRC,
    R_WRITE,
    R_ERASE,
    R_SYNC,
    R_SYNCALL,
    R_FLUSH,
    R_FLUSHALL
  };
  uint8_t request;
  uint8_t *reqBuf;
  eeprompageoffset_t reqOffset, reqBytes;
  eeprompage_t reqPage;
  uint16_t computedCrc;


  struct {
    eeprompage_t page;
    bool busy : 1;
    bool clean : 1;
    bool erased : 1;
    uint8_t unchecked : 2;
    uint8_t data[TOS_EEPROM_PAGE_SIZE];
  } buffer[2];

  uint8_t selected; // buffer used by the current op


  uint16_t calcrc(uint8_t *ptr, uint16_t count) {
    uint16_t crc;
    crc = 0;
    while (count-- > 0)
      crc = crcByte(crc, *ptr++);

    return crc;
  }

  command result_t StdControl.init() {
    fp_list_t *list=get_fplist();

    request = IDLE;

    // pretend we're on an invalid non-existent page
    buffer[0].page = buffer[1].page = TOS_EEPROM_MAX_PAGES;
    buffer[0].busy = buffer[1].busy = FALSE;
    buffer[0].clean = buffer[1].clean = TRUE;
    buffer[0].unchecked = buffer[1].unchecked = 0;
    buffer[0].erased = buffer[1].erased = FALSE;

    if (list==NULL) {
      printf("NULL fplist!\n");
      exit(0);
    }
    emtos_pageeeprom_init(list);
    return SUCCESS;
  }

  command result_t StdControl.start() {
    return SUCCESS;
  }

  command result_t StdControl.stop() {
    return SUCCESS;
  }



  void requestDone(result_t result) {
    uint8_t orequest = request;

    request = IDLE;
    switch (orequest)
      {
      case R_READ: signal PageEEPROM.readDone(result); break;
      case R_READCRC: signal PageEEPROM.computeCrcDone(result, computedCrc); break;
      case R_WRITE: signal PageEEPROM.writeDone(result); break;
      case R_SYNC: case R_SYNCALL: signal PageEEPROM.syncDone(result); break;
      case R_FLUSH: case R_FLUSHALL: signal PageEEPROM.flushDone(result); break;
      case R_ERASE: signal PageEEPROM.eraseDone(result); break;
      }
  }

  void requestDone(result_t result);

  task void taskSuccess() {
    requestDone(SUCCESS);
  }

  task void taskFail() {
    requestDone(FAIL);
  }


  result_t newRequest(uint8_t req, eeprompage_t page,eeprompageoffset_t offset,void *reqdata, eeprompageoffset_t n) {
    if (page >= TOS_EEPROM_MAX_PAGES || offset >= TOS_EEPROM_PAGE_SIZE || n > TOS_EEPROM_PAGE_SIZE || offset + n > TOS_EEPROM_PAGE_SIZE){
      return FAIL;
    }

    if (request != IDLE){
      return FAIL;
    }

    request = req;

    reqBuf = reqdata;
    reqBytes = n;
    reqPage = page;
    reqOffset = offset;

    if (page == buffer[0].page){
      selected = 0;
    }else if (page == buffer[1].page){
      selected = 1;
    }else{
      selected = !selected; // LRU with 2 buffers...
    }

    if(reqPage == buffer[selected].page){
      dbg(DBG_USR2,"Page %i found buffer. Request is %i\n",reqPage,request);
      switch(request){
	case IDLE:
	  break;
	case R_READ:
	  memcpy(reqBuf,&buffer[selected].data[reqOffset],reqBytes);
	  post taskSuccess();
	  break;
	case R_READCRC:
	  computedCrc = calcrc((uint8_t*)&(buffer[selected].data[reqOffset]),reqBytes);
	  post taskSuccess();
	  break;
	case R_WRITE:
	  memcpy((uint8_t*)&(buffer[selected].data[reqOffset]),reqBuf,reqBytes);
	  buffer[selected].clean = FALSE;
	  post taskSuccess();
	  break;
	case R_ERASE:
	  memset((uint8_t*)&(buffer[selected].data[0]),0,TOS_EEPROM_PAGE_SIZE);
	  buffer[selected].clean = TRUE;
	  emtos_pageeeprom_write(reqPage,(uint8_t*)(buffer[selected].data));
	  post taskSuccess();
	  break;
	case R_SYNC:
	  break;
	case R_SYNCALL:
	  break;
	case R_FLUSH:
	  break;
	case R_FLUSHALL:
	  break;
      }
    }else{
      dbg(DBG_USR2,"Page %i NOT found in buffer. Request is %i\n",reqPage,request);
      switch(request){
	case IDLE:
	  break;
	case R_READ:
	  //write the page if its dirty
	  if(buffer[selected].clean == FALSE){
	    emtos_pageeeprom_write(buffer[selected].page,(uint8_t*)(buffer[selected].data));
	  }
	  emtos_pageeeprom_read(reqPage,buffer[selected].data);
	  buffer[selected].clean = TRUE;
	  buffer[selected].page = reqPage;
	  
	  memcpy(reqBuf,(uint8_t*)&(buffer[selected].data[reqOffset]),reqBytes);
	  post taskSuccess();
	  
	  break;
	case R_READCRC:
	  //write the page if its dirty
	  if(buffer[selected].clean == FALSE){
	    emtos_pageeeprom_write(buffer[selected].page,buffer[selected].data);
	  }
	  emtos_pageeeprom_read(reqPage,buffer[selected].data);
	  buffer[selected].clean = TRUE;
	  buffer[selected].page = reqPage;
	  
	  computedCrc = calcrc((uint8_t*)&(buffer[selected].data[reqOffset]),reqBytes);
	  post taskSuccess();
	  
	  break;
	case R_WRITE:
	  //write the page if its dirty
	  if(buffer[selected].clean == FALSE){
	    emtos_pageeeprom_write(buffer[selected].page,buffer[selected].data);
	  }
	  emtos_pageeeprom_read(reqPage,buffer[selected].data);
	  buffer[selected].clean = TRUE;
	  buffer[selected].page = reqPage;
	  
	  memcpy((uint8_t*)&(buffer[selected].data[reqOffset]),reqBuf,reqBytes);
	  buffer[selected].clean = FALSE;
	  
	  post taskSuccess();

	  break;
	case R_ERASE:
	  
	  //write the page if its dirty
	  if(buffer[selected].clean == FALSE){
	    emtos_pageeeprom_write(buffer[selected].page,buffer[selected].data);
	  }
	  emtos_pageeeprom_read(reqPage,buffer[selected].data);
	  buffer[selected].clean = TRUE;
	  buffer[selected].page = reqPage;
	  
	  memset((uint8_t*)&(buffer[selected].data[0]),0,TOS_EEPROM_PAGE_SIZE);
	  buffer[selected].clean = TRUE;
	  emtos_pageeeprom_write(reqPage,buffer[selected].data);

	  post taskSuccess();

	  break;
	case R_SYNC:
	  break;
	case R_SYNCALL:
	  break;
	case R_FLUSH:
	  break;
	case R_FLUSHALL:
	  break;
      }

    }

    return SUCCESS;
  }

  command result_t PageEEPROM.read(eeprompage_t page, eeprompageoffset_t offset, void *reqdata, eeprompageoffset_t n) {
    return newRequest(R_READ, page, offset, reqdata, n);
  }

  command result_t PageEEPROM.computeCrc(eeprompage_t page,eeprompageoffset_t offset, eeprompageoffset_t n) {
    if (n == 0){
		request = R_READCRC;
		computedCrc = 0;
		post taskSuccess();
		return SUCCESS;
    }else{
      return newRequest(R_READCRC, page, offset, NULL, n);
  	}
  }

  command result_t PageEEPROM.write(eeprompage_t page, eeprompageoffset_t offset,void *reqdata, eeprompageoffset_t n) {
    return newRequest(R_WRITE, page, offset, reqdata, n);
  }


  command result_t PageEEPROM.erase(eeprompage_t page, uint8_t eraseKind) {
    return newRequest(R_ERASE, page, eraseKind, NULL, 0);
  }

  result_t syncOrFlush(eeprompage_t page, uint8_t newReq) {
    if (page >= TOS_EEPROM_MAX_PAGES){
      return FAIL;
    }

    if (request != IDLE)
      return FAIL;

    request = newReq;

    if (buffer[0].page == page){
      selected = 0;
    }else if(buffer[1].page == page){
      selected = 1;
    }else{
		post taskSuccess();
		return SUCCESS;
    }

	//only write it dirty
	if(buffer[selected].clean == FALSE){
		emtos_pageeeprom_write(page,buffer[selected].data);
		buffer[selected].clean = TRUE;
	}

	post taskSuccess();
    return SUCCESS;
  }

  command result_t PageEEPROM.sync(eeprompage_t page) {
    return syncOrFlush(page, R_SYNC);
  }

  command result_t PageEEPROM.flush(eeprompage_t page) {
    return syncOrFlush(page, R_FLUSH);
  }

  result_t syncOrFlushAll(uint8_t newReq) {
    if (request != IDLE)
      return FAIL;

    request = newReq;


    if (!buffer[0].clean){
      	selected = 0;
	emtos_pageeeprom_write(buffer[selected].page,buffer[selected].data);
	buffer[selected].clean = TRUE;
    }
    if (!buffer[1].clean){
      selected = 1;
      emtos_pageeeprom_write(buffer[selected].page,buffer[selected].data);
      buffer[selected].clean = TRUE;
    }
    post taskSuccess();
    return SUCCESS;
  }

  command result_t PageEEPROM.syncAll() {
    return syncOrFlushAll(R_SYNCALL);
  }

  command result_t PageEEPROM.flushAll() {
    return syncOrFlushAll(R_FLUSHALL);
  }
}
