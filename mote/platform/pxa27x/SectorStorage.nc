// $Id: SectorStorage.nc,v 1.2 2007/03/05 00:06:07 lnachman Exp $

/*									tab:2
 * "Copyright (c) 2000-2005 The Regents of the University  of California.  
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
 */

/*
 * @author: Jonathan Hui <jwhui@cs.berkeley.edu>
 */

includes PXAFlash;

interface SectorStorage 
{
  command result_t read(storage_addr_t addr, void* data, storage_addr_t len);
  command result_t fread(void* data, storage_addr_t len);

  command result_t write(storage_addr_t addr, void* data, storage_addr_t len);
  event void writeDone(storage_result_t result);

  command result_t erase(storage_addr_t addr, storage_addr_t len);
  event void eraseDone(storage_result_t result);
  
  command result_t computeCrc(uint16_t* crcResult, uint16_t crc, 
                              storage_addr_t addr, storage_addr_t len);

  command result_t append(void* data, storage_addr_t len);

  command storage_addr_t getWritePtr ();
  command result_t resetWritePtr ();

  command storage_addr_t getReadPtr ();
  command result_t resetReadPtr ();
  command result_t rseek (storage_addr_t addr);
}
