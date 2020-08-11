/*									tab:4
 *  IMPORTANT: READ BEFORE DOWNLOADING, COPYING, INSTALLING OR USING.  By
 *  downloading, copying, installing or using the software you agree to
 *  this license.  If you do not agree to this license, do not download,
 *  install, copy or use the software.
 *
 *  Intel Open Source License
 *
 *  Copyright (c) 2002 Intel Corporation
 *  All rights reserved.
 *  Redistribution and use in source and binary forms, with or without
 *  modification, are permitted provided that the following conditions are
 *  met:
 *
 *	Redistributions of source code must retain the above copyright
 *  notice, this list of conditions and the following disclaimer.
 *	Redistributions in binary form must reproduce the above copyright
 *  notice, this list of conditions and the following disclaimer in the
 *  documentation and/or other materials provided with the distribution.
 *      Neither the name of the Intel Corporation nor the names of its
 *  contributors may be used to endorse or promote products derived from
 *  this software without specific prior written permission.
 *
 *  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 *  ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 *  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
 *  PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE INTEL OR ITS
 *  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 *  EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 *  PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 *  PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 *  LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 *  NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 *  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 *
 */

/*
 * This module maintains a buffer of characters to put on the UART.
 * It copies incoming characters into the buffer and streams them out the
 * UART as each previous character finishes.
 */

module UARTBufferM {
  provides {
    interface StdControl as Control;
    interface SendVarLenPacket;
    interface ReceiveData;

  }
  uses {
    interface ByteComm;
    interface StdControl as ByteControl;
  }
}

implementation
{

  uint32_t Head;               // Next entry in the buffer to fill
  uint32_t Tail;               // Oldest entry in the buffer
  // Head == Tail -> buffer is empty

  #define NEXT_BUFFER(ent, max) (((ent) >= ((max) - 1)) ? 0 : ((ent) + 1))
  #define BUFFER_SIZE 1000    // maximum characters buffered in the queue
  char Buffer[BUFFER_SIZE];  // circular buffer of characters

  bool BytePending;          // whether there is a byte sent w/o a
                             // corresponding sendDone


/*
 * Start of StdControl interface
 */

  command result_t Control.init() {
    atomic {
      Head = 0;
      Tail = 0;
      BytePending = FALSE;
    }

    return call ByteControl.init();
  }

  command result_t Control.start() {
    return call ByteControl.start();
  }

  command result_t Control.stop() {
    return call ByteControl.stop();
  }

/*
 * End of StdControl interface
 */



   result_t SendNextByte() {
     bool busy;
     uint32_t queueEmpty;
     char nextChar; 
     atomic {
        busy = (BytePending == TRUE);
	queueEmpty = (Head ==Tail);
     }
     if (busy) {
        return FAIL;
     }
     
     if (queueEmpty) return SUCCESS; // buffer is empty

     atomic {
        BytePending = TRUE;
	nextChar = Buffer[Tail];
     }

     call ByteComm.txByte(nextChar);
//     if (call ByteComm.txByte(Buffer[Tail]) == FAIL) {
//       // UART not enabled
//       Tail = Head;
//       BytePending = FALSE;
//     }

     return SUCCESS;
   }

/*
 * Start of SendVarLenPacket interface
 */

  command result_t SendVarLenPacket.send(uint8_t* data, uint8_t length) {
    int     i, size;
    bool    not_busy;

    // see if there's enough room for this packet
    atomic{
      size = (Head < Tail) ? Head + BUFFER_SIZE - Tail : Head - Tail;
    }
    if (size + length >= BUFFER_SIZE) return FAIL; // not enough room

    // copy incoming bytes to the buffer
    atomic{
      for (i = 0; i < length; i++) {
	Buffer[Head] = data[i];
	Head = NEXT_BUFFER(Head, BUFFER_SIZE);
      }
      not_busy = (BytePending == FALSE);
    }

    if (not_busy) SendNextByte();

    return SUCCESS;
  }

  default event result_t SendVarLenPacket.sendDone(uint8_t* data, result_t suc) {
    return suc;
  }

/*
 * End of SendVarLenPacket interface
 */



/*
 * Start of ByteComm interface
 */

  async event result_t ByteComm.txByteReady(bool success) {

    uint32_t queueEmpty;
    atomic {
       BytePending = FALSE;
       queueEmpty = (Head == Tail);
    }
    if (queueEmpty) return SUCCESS;
    atomic {
      Tail = NEXT_BUFFER(Tail, BUFFER_SIZE);
    }
    SendNextByte();

    return SUCCESS;
  }

  // this appears to be redundant in the interface with txByteReady
  async event result_t ByteComm.txDone() { return SUCCESS; }

  async event result_t ByteComm.rxByteReady(uint8_t data, bool error, uint16_t str) {
    //arguably need to add receive fifo here, however what should its behavior be?
    signal ReceiveData.receive(&data, 1);
    return SUCCESS;
  }

/*
 * End of ByteComm interface
 */



/*
 * Start of ReceiveData interface
 */

  default event result_t ReceiveData.receive(uint8_t* Data, uint32_t Length) {
    return SUCCESS;
  }

/*
 * End of ReceiveData interface
 */

}

