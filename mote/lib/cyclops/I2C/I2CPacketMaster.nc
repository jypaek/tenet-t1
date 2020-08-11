// $Id: I2CPacketMaster.nc,v 1.1 2007-07-02 22:51:58 jpaek Exp $

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
 * A higher level interface to send or receive a series of bytes
 * over the I2C hardware bus to/from a specified address.  
 * The underlying implementation uses the
 * <code>I2C</code> byte level command interface
 */
interface I2CPacketMaster
{
  /**
   * Reads a series of bytes from a slave device
   *
   * @param length the number of bytes to be read
   * @param flags bitmask that is defined:<br>
   * <table border=0><tr><td><code>STOP_FLAG</code></td>
   * <td><code>0x01</code></td>
   * <td>The stop/end command is sent at the end of the packet if set</td></tr>
   * <tr><td><code>ACK_FLAG</code></td>
   * <td><code>0x02</code></td>
   * <td>The master acks every byte except for the last received if set</td></tr>
   * <tr><td><code>ACK_END_FLAG</code></td>
   * <td><code>0x04</code></td>
   * <td>The master acks after the last byte read if set</td></tr>
   * <tr><td><code>ADDR_8BITS_FLAG</code></td>
   * <td><code>0x80</code></td>
   * <td>The slave address is a full eight bits, not seven and a read flag.</td></tr>
   * </table>
   *
   * @return SUCCESS if the bus is free and the request is accepted
   */
  command result_t readPacket(char* data);
  /**
   * Writes a series of bytes to a slave device
   *
   * @param length the number of bytes to be written
   * @param data a pointer to the data to be written
   * @param flags bitmask that is defined:<br>
   * <table border=0><tr><td><code>STOP_FLAG</code></td>
   * <td><code>0x01</code></td>
   * <td>The stop/end command is sent at the end of the packet if set</td></tr>
   * <tr><td><code>ADDR_8BITS_FLAG</code></td>
   * <td><code>0x80</code></td>
   * <td>The slave address is a full eight bits, not seven and a read flag.</td></tr>
   * </table>
   *
   * @return SUCCESS if the bus is free and the request is accepted
   */
  command result_t writePacket(char length, char* data); 

  /**
   * Notifies that the bytes have been read from the slave device
   *
   * @param length the length of resulting data.  the application should
   * check if the length is equal to the requested length in the
   * <code>readPacket()</code> command.  If not, the application may assume
   * that the request has failed
   *
   * @param data a pointer to the bytes read from the bus
   *
   * @return SUCCESS to retain control of the bus, FAIL to release it
   */
  event result_t readPacketDone(char length, char* data);
  /**
   * Notifies that the bytes have been written to the slave device
   *
   * @param result SUCCESS if the slave acknowledged all bytes, FAIL otherwise
   *
   * @return SUCCESS to retain control of the bus, FAIL to release it
   */
  event result_t writePacketDone(bool result);
}
