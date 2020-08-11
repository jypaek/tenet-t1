/**
 * Interface for sending arbitrary streams of bytes using the JTrans protocol.
 *
 * Author:		Josh Herbach
 * Revision:	1.0
 * Date:		09/02/2005
 */

interface SendJTPacket
{
  /**
   * Send numBytes bytes of the buffer data. Data type is specified by type as 
   * described by the JTrans protocol (b00 General, b01 Binary, b10 Radio
   * Packet, b11 BluSH). If device cannot send the data for any obvious
   * reason (eg when using USB, the device is not enumerated), returns FAIL,
   * otherwise, returns SUCCESS.
   *
   * @returns SUCCESS or FAIL.
   */
  command result_t send(uint8_t* data, uint32_t numBytes, uint8_t type);
  
  /**
   * Send request completed. The buffer sent, the type requested and success
   * (success is always SUCCESS).
   *
   * @return SUCCESS always.
   */
  event result_t sendDone(uint8_t* packet, uint8_t type, result_t success);
}



