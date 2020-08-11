// $Id: HALPXA27X.nc,v 1.2 2007/03/05 00:06:07 lnachman Exp $

/*									tab:4
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

interface HALPXA27X 
{
  command result_t read(stm25p_addr_t addr, void* data, stm25p_addr_t len);
  command result_t pageProgram(stm25p_addr_t addr, void* data, stm25p_addr_t len);
  event void pageProgramDone();

  command result_t blockErase(stm25p_addr_t addr);
  event void blockEraseDone();

  command result_t bulkErase(stm25p_addr_t addr);
  event void bulkEraseDone(result_t res, uint32_t addr);

  command result_t readSR(void* value);

  command result_t writeSR(uint8_t value);
  event void writeSRDone();

  command bool isErasing ();

  command result_t computeCrc(uint16_t* crcResult, uint16_t crc, 
                              stm25p_addr_t addr, stm25p_addr_t len);

  command stm25p_sig_t getSignature();

  command result_t clearBlock (uint16_t block);
  command result_t wordProgram (stm25p_addr_t addr, uint16_t word);
}
