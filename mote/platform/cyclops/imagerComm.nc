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
// Contents: A high level interface to enable communication with camera to
//           write and read data to different block and offset addresses in
//           8 or 16 bit mode.
//          
//
////////////////////////////////////////////////////////////////////////////
//
// $Header: /home/public_repository/root/tenet/mote/platform/cyclops/imagerComm.nc,v 1.1 2007-07-03 00:57:48 jpaek Exp $
//
// Authors : 
//           Mohammad Rahimi mhr@cens.ucla.edu
//
////////////////////////////////////////////////////////////////////////////

interface imagerComm
{
  /**
   * writing to a register inside the camera module
   * @ return SUCCESS if component is idle.
   */
  command result_t writeRegister(uint16_t reg, uint16_t data);
  /**
   * the result of writing.
   * @return SUCCESS
   */
  event result_t writeRegisterDone(uint16_t reg,uint16_t data,result_t status);
  /**
   * reading from a register inside the module
   * @ return SUCCESS if component is idle.
   */
  command result_t readRegister(uint16_t reg);
  /**
   * the result of reading is the data.
   * @return SUCCESS
   */
  event result_t readRegisterDone(uint16_t reg,uint16_t data,result_t status);
  /**
   * writing a block of data.
   * @return SUCCESS
   */  
  command result_t writeBlock(uint16_t startReg, char *data,uint8_t length);
  event result_t writeBlockDone(uint16_t startReg,char *data,uint8_t lenght,result_t status);

  command result_t readBlock(uint16_t startReg,char *data,uint8_t length);
  event result_t readBlockDone(uint16_t startReg,char *data,uint8_t lenght,result_t status);
  
}
