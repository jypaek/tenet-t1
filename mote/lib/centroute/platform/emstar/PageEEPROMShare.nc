// $Id: PageEEPROMShare.nc,v 1.1 2007-11-17 00:55:24 karenyc Exp $

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
/**
 * Provide simple multi-client access to a PageEEPROM interface
 * (just request-response matching)
 */
module PageEEPROMShare {
  provides interface PageEEPROM[uint8_t id];
  uses interface PageEEPROM as ActualEEPROM;
}
implementation {
  enum {
    NCLIENTS = uniqueCount("PageEEPROM")
  };
  uint8_t lastClient;

  // Read & write the client id. We special case the 1-client case to
  // eliminate the overhead (still costs 1 byte of ram, though)
  int setClient(uint8_t client) {
    if (NCLIENTS != 1)
      {
	if (lastClient)
	  return FALSE;
	lastClient = client + 1;
      }
    return TRUE;
  }

  uint8_t getClient() {
    uint8_t id = 0;

    if (NCLIENTS != 1)
      {
	id = lastClient - 1;
	lastClient = 0;
      }

    return id;
  }

  // Simply use the setClient, getClient functions to match requests &
  // responses. The inline reduces the overhead of this layer.
  inline command result_t PageEEPROM.write[uint8_t client](eeprompage_t page, eeprompageoffset_t offset,
						    void *data, eeprompageoffset_t n) {
    if (!setClient(client))
      return FAIL;
    return call ActualEEPROM.write(page, offset, data, n);
  }

  inline event result_t ActualEEPROM.writeDone(result_t result) {
    return signal PageEEPROM.writeDone[getClient()](result);
  }

  inline command result_t PageEEPROM.erase[uint8_t client](eeprompage_t page, uint8_t eraseKind) {
    if (!setClient(client))
      return FAIL;
    return call ActualEEPROM.erase(page, eraseKind);
  }

  inline event result_t ActualEEPROM.eraseDone(result_t result) {
    return signal PageEEPROM.eraseDone[getClient()](result);
  }

  inline command result_t PageEEPROM.sync[uint8_t client](eeprompage_t page) {
    if (!setClient(client))
      return FAIL;
    return call ActualEEPROM.sync(page);
  }

  inline command result_t PageEEPROM.syncAll[uint8_t client]() {
    if (!setClient(client))
      return FAIL;
    return call ActualEEPROM.syncAll();
  }

  inline event result_t ActualEEPROM.syncDone(result_t result) {
    return signal PageEEPROM.syncDone[getClient()](result);
  }

  inline command result_t PageEEPROM.flush[uint8_t client](eeprompage_t page) {
    if (!setClient(client))
      return FAIL;
    return call ActualEEPROM.flush(page);
  }

  inline command result_t PageEEPROM.flushAll[uint8_t client]() {
    if (!setClient(client))
      return FAIL;
    return call ActualEEPROM.flushAll();
  }

  inline event result_t ActualEEPROM.flushDone(result_t result) {
    return signal PageEEPROM.flushDone[getClient()](result);
  }

  inline command result_t PageEEPROM.read[uint8_t client](eeprompage_t page, eeprompageoffset_t offset,
						   void *data, eeprompageoffset_t n) {
    if (!setClient(client))
      return FAIL;
    return call ActualEEPROM.read(page, offset, data, n);
  }

  inline event result_t ActualEEPROM.readDone(result_t result) {
    return signal PageEEPROM.readDone[getClient()](result);
  }

  inline command result_t PageEEPROM.computeCrc[uint8_t client](eeprompage_t page, eeprompageoffset_t offset,
							 eeprompageoffset_t n) {
    if (!setClient(client))
      return FAIL;
    return call ActualEEPROM.computeCrc(page, offset, n);
  }

  inline event result_t ActualEEPROM.computeCrcDone(result_t result, uint16_t crc) {
    return signal PageEEPROM.computeCrcDone[getClient()](result, crc);
  }
  
  default event result_t PageEEPROM.writeDone[uint8_t client](result_t result) {
    return FAIL;
  }

  default event result_t PageEEPROM.eraseDone[uint8_t client](result_t result) {
    return FAIL;
  }

  default event result_t PageEEPROM.syncDone[uint8_t client](result_t result) {
    return FAIL;
  }

  default event result_t PageEEPROM.flushDone[uint8_t client](result_t result) {
    return FAIL;
  }

  default event result_t PageEEPROM.readDone[uint8_t client](result_t result) {
    return FAIL;
  }

  default event result_t PageEEPROM.computeCrcDone[uint8_t client](result_t result, uint16_t crc) {
    return FAIL;
  }
}
