// $Id: I2CSlave.nc,v 1.1 2007-07-02 22:51:58 jpaek Exp $

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
 * Byte and Command interface for using the I2C hardware bus
 */
includes I2C;
interface I2CSlave
{
  /**
   * Sets the address of the I2C Slave
   *
   * @param value The 7 lower bits of value are the I2C slave address. The 
   *  most significant bit is always ignored.
   * 
   * @param bcast specifies whether or not to respond to address 0x00 as 
   * well as to the I2C slave address. True = respond, False = ignore.
   *
   * @return SUCCESS always
   */
  async command result_t setAddress(uint8_t value, bool bcast);

  /**
   * Gets the address of the I2C Slave
   *
   * @return I2C Slave Address.
   */
  async command uint8_t getAddress();

  /**
   * The device has received a write request
   * @return Ignored
   */
  async event result_t masterWriteStart();

  /**
   * Call this after a masterWriteStart event to signal that you're
   * ready to receive data. 
   * @parm ack TRUE to ack the byte, FALSE to nack it
   * @return SUCCESS
   */
  async command result_t masterWriteReady(bool ack);

  /**
   * Notifies the application that the master has written
   * a byte to the slave
   *
   * @return SUCCESS to ack the next byte, FAIL to nack it
   *   If FAIL is returned, you will get:
   *     at most one masterWrite() event
   *     followed by one masterWriteDone() event
   */
  async event result_t masterWrite(uint8_t value);

  /**
   * Notifies the application that the current data transfer
   * from the master has been completed
   *
   * @param moreData informs whether there is more data to be stored
   * @param value is the data if there is more to be stored, ignored otherwise
   *
   * @return Ignored
   */
  async event result_t masterWriteDone(bool moreData, uint8_t value);

  /**
   * The device has received a read request
   * @return Ignored.
   */
  async event result_t masterReadStart();

  /**
   * Call this after a masterReadStart event to signal that you're
   * ready to send data. 
   * @return SUCCESS
   */
  async command result_t masterReadReady();

  /**
   * Notifies the application that the master is requesting
   * a byte from the slave.  The slave must *immediately* return
   * the next byte to be sent and tell the I2C protocol if this is the
   * last byte.
   *
   * Note: if you return a byte with its high bit clear when the master was
   * not expecting any more bytes, you will prevent the master from
   * signaling the stop condition and hence lock the bus.
   *
   * @return byte to be sent to the master, ored with I2CSLAVE_LAST if this
   *   is the last byte (in this case, the data line will be released by the
   *   slave at the end of this byte and masterReadDone 
   *   will be signaled - the lastByteAcked parameter will tell you if the
   *   master acked this last byte)
   */
  async event uint16_t masterRead();

  /**
   * Notifies the application that the master is done reading
   * from the slave
   *
   * @return Ignored
   */
  async event result_t masterReadDone();
}
