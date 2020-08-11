/*
 *
 * Copyright (c) 2003 The Regents of the University of California.  All 
 * rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 *
 * - Neither the name of the University nor the names of its
 *   contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS''
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
 * PARTICULAR  PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE REGENTS OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 *
 * Authors:   Mohammad Rahimi mhr@cens.ucla.edu
 * History:   created 11/14/2003
 *
 * This is a copy of ADC interface to have conversion interface t
 * for cases that seat on top of raw conversion and we do not want
 * to be callable from Interrupt so async has been removed
 */


interface Convert {
  /**
   * Set parameters for the given channel.  Null operation on devices with no
   * parameters to set.
   *
   * @param channel Channel for which to set the parameter
   *        param Paramter to set
   *
   * @return SUCCESS If parameter was successfully set, FAIL if the channel
   * does not exist.  Always returns SUCCESS if setting the param is meaningless
   * for the device.
   * 
   */
  command result_t setParam(uint8_t channel, uint8_t param);

  /**
   * Initiates a conversion on a given channel.
   *
   * @return SUCCESS if the device is able to accept the request and the channel
   * exists.
   */
  command result_t getData(uint8_t channel);

  /**
   * Indicates a sample has been recorded by the device as the result
   * of a <code>getData()</code> command.
   *
   * @param data a 4 byte int of the data returned by the DAQ
   *        port the port from which the data arrived
   *
   * @return SUCCESS if ready for the next conversion in continuous mode.
   * if not in continuous mode, the return code is ignored.
   */
  event result_t dataReady(int32_t data, uint8_t channel);
}
