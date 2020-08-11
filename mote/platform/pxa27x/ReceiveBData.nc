/**
 * Interface for receiving binary data.
 *
 * Author:		Josh Herbach
 * Revision:	1.0
 * Date:		09/02/2005
 */

interface ReceiveBData{ 
  event result_t receive(uint8_t* buffer, uint8_t numBytesRead,
			       uint32_t i, uint32_t n, uint8_t type);
}
