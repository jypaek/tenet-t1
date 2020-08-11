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
//
////////////////////////////////////////////////////////////////////////////
// Authors : 
//           Ning Xu  nxu@cens.ucla.edu
//           Mohammad Rahimi mhr@cens.ucla.edu
//
// Note:  modify the UCB i2c interface to accommodate the master wait state
//        now slave can force master into wait state by pulling the clock low
////////////////////////////////////////////////////////////////////////////

includes I2C;
interface I2CPacketSlave
{
    /**
     * Sets the address of the I2C Slave
     *
     * @param value The 7 lower bits of value are the I2C slave address.
     * @param bcast determines whether slave will respond to general call
     *  address
     *
     * @return SUCCESS always
     */
    command result_t setAddress(uint8_t value, bool bcast);

    /**
     * Gets the address of the I2C Slave
     *
     * @return I2C Slave Address.
     */
    command uint8_t getAddress();

    /**
     * An I2C write has been received
     *
     * @param data Pointer to received data
     * @param length Number of bytes received
     * @return As with the Receive interface, the event handler can either
     *   process data immediately and return it, or hold onto data and
     *   return a free buffer in its place. The returned buffer must be
     *   I2CSLAVE_PACKETSIZE bytes long
     */
    event char *write(char *data, uint8_t length);

    /**
     * An I2C read has been received. The master has been forced into wait state.
     * Once the application is ready for sending the data, it should pass the buffer
     * and length to the HPLI2CSlave by calling readReady(...)
     *
     */
    event result_t readRequest();

    /**
     * pass buffer pointer and length to lower layer and start sending
     * @param data The handler should place its buffer address in 
     *   <code>*data</code>
     * @param length The handler should place the number of bytes it wishes
     *   to return in <code>*length</code>. The master will get 0xff for all
     *   bytes beyond <code>*length</code>.
     * @return Ignored.
     */
    command result_t readBufReady(char *data, uint8_t length);

    /**
     * The I2C read signaled by the previous <code>read</code> event has
     * completed.
     * @param success true if all bytes read by master
     * @return Ignored.
     */
    event result_t readDone(bool success);
}
