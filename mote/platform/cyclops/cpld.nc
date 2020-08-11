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
// Contents: A high level interface to enable communication with cpld and
//           setting cpld in the proper mode.
//           
//          
//
////////////////////////////////////////////////////////////////////////////
//
// $Header
//
// $Log: not supported by cvs2svn $
// Revision 1.1  2005-04-14 23:03:15  local
// initial check in
//
// Revision 1.3  2005/01/11 00:49:49  mhr
// There is no getBus needed any more with DMA concept.
//
// Revision 1.2  2004/05/28 20:05:48  mhr
// *** empty log message ***
//
// Revision 1.1  2004/05/06 20:26:19  mhr
// initial check in
//
//
// Authors : 
//           Mohammad Rahimi mhr@cens.ucla.edu 
//           Rick Baer       rick_baer@agilent.com 
//
////////////////////////////////////////////////////////////////////////////

includes cpldConst;

interface cpld
{
  /**
   * Set the mode of the cpld.
   *
   * @cpldC is should be filled by the application for proper operation
   *  and passed to this cpldControl component.
   *
   * Note that the event cpldDone will be signaled some time in future
   * if command is successful.
   *
   * @return SUCCESS if cpld is free, FAIL id cpld is already busy
   */
  command result_t setCpldMode(cpldCommand_t *cpldC);

  /**
   * force cpld to go to standby mode
   * NOTE: not recommended except in start time.
   *
   * @return SUCCESS
   */
  command result_t stdByCpld();  

  /**
   * cpld respone to for the setCpldMode operations that have result later.
   *
   * @ cpld is the address of originating command.
   * Application might check the pointer address to make sure it was the
   * result of its calling the component.
   *
   * @return SUCCESS
   */
  event result_t setCpldModeDone(cpldCommand_t *myCpld);

}
