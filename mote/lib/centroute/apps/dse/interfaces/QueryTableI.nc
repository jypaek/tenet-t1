////////////////////////////////////////////////////////////////////////////
//
// CENS
//
// Copyright (c) 2003 The Regents of the University of California.  All 
// rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions
// are met:
//
// - Redistributions of source code must retain the above copyright
//   notice, this list of conditions and the following disclaimer.
//
// - Neither the name of the University nor the names of its
//   contributors may be used to endorse or promote products derived
//   from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS''
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
// THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
// PARTICULAR  PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE REGENTS OR
// CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
// EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
// PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
// PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
// OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// Contents: This file contains Query Table Interface.
//
//
////////////////////////////////////////////////////////////////////////////
//
// $Id: QueryTableI.nc,v 1.1 2007-09-10 21:45:23 karenyc Exp $
//
// $Log: not supported by cvs2svn $
// Revision 1.1  2004-07-19 22:02:26  ben
// no more dsp
//
// Revision 1.3  2004/02/09 00:42:15  tschoell
// *** empty log message ***
//
// Revision 1.2  2004/01/07 20:06:16  tschoell
// *** empty log message ***
//
// Revision 1.1  2003/12/20 02:27:49  tschoell
// Initial Entry
//
// Revision 1.1  2003/11/18 15:00:16  mhr
// inital
//
// Revision 1.1  2003/11/14  mhr,tom
// Initial.
//
////////////////////////////////////////////////////////////////////////////


interface QueryTableI {
  /**
   * Initial insertion Of the Query.
   *
   * @return SUCCESS if there is enough memory space
   */
  command uint8_t* insert(uint8_t* query, uint8_t queryLength, uint8_t extraSpace);
  /**
   * Remove Query from Query Table and based on Primary key.It should not usualy be used
. 
   *
   * @return SUCCESS if the Primary Key is found.otherwise inconsistancy
   */
  command result_t deleteQueryID(uint8_t QueryID);
  /**
   * Retreival Of the Query by sampling ID.
   *
   * @return SUCCESS if the Primary Key is found.otherwise inconsistancy
   */
  command uint8_t* request(uint8_t Samplingid);
  /**
   * Retreival Of the Query by sampling ID.
   *
   * @return SUCCESS if the Primary Key is found.otherwise inconsistancy
   */
  command uint8_t* requestByID(uint8_t qID);
  /**
   * Return the value of the memory location loc.
   *
   * @return Value of the memory location loc.
   */
  command uint8_t memread( uint8_t loc );
}
