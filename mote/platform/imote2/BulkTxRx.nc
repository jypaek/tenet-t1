/**
 * The BulkTxRx interface is intended to provide the functionality required for
 * both the send and the receive sides of a half-duplex or full-duplex
 * communication transaction. In order to provide this functionality, 
 * the interface provide 2 commands and 2 events.  Because this interface is
 * intended to be generic, there are no explicit configuration or 
 * initialization * commands.  Instead, it is expected that the port that 
 * exposes this interface expose a port-specific set of configuration commands.
 *  Additionally, there are no explicit start or stop commands.  Instead, 
 * "starting" is done implicitly by calling one of the commands.  If the 
 * command returns SUCCESS, the transaction has been started.  Once a 
 * transaction has been started, it may be stopped by returning NULL in the
 * corresponding *Done events or by calling the Abort command.
 *
 * @author Robbie Adler	 
**/ 

includes BulkTxRx;
interface BulkTxRx {

  /**
   * Begin a BulkReceive.  The parameters should be the initial buffer
   * to place data into and the inital number of bytes.  Receive chaining
   * may be accomplished by returning a new buffer in the associated BulkReceiveDone
   * event.  Return NULL to complete the transaction.
   **/
  command result_t BulkReceive(uint8_t *RxBuffer, uint16_t NumBytes);
  
  /**
   * This command informs the component to send NumBytes 
   * using the TxBuffer parameter as the source.  Transmit chaining 
   * may be accomplished by returned a new buffer in the associated BulkTransmitDone
   * event.  Return NULL to complete the transaction
   **/
  command result_t BulkTransmit(uint8_t *TxBuffer, uint16_t NumBytes);

  /**
   * This command informs the component to send NumBytes 
   *  using the TxBuffer parameter as the source while receiving NumBytes
   * simultaneously into the RxBuffer.  The intention of this command is 
   * to allow the interface to be exposed by FULL-DUPLEX protocals such as 
   * SSP and SPI.  TxRx chaining may be accomplished by returning 2 NON-NULL
   * buffers in the associated BulkTxRxDone event
   **/
  command result_t BulkTxRx(BulkTxRxBuffer_t *TxRxBuffer, uint16_t NumBytes);
    
  
  /**
   * This event is signaled to inform the application that NumBytes
   * have been received.  No assumptions can be made about the
   * contents of the RxBuffer once this event returns.  If the caller
   * wants to hold onto these bytes, it should save a copy of it.  To
   * chain receives OF THE SAME LENGTH together, return a new buffer from this 
   * event. If a new transaction of a different length is required or if
   * the application is done receiving data, return NULL and trigger the new
   * transaction from outside this event.  If for some reason
   * the hardware was unable to capture NumBytes of contiguous data without
   * an overrun condition occuring, the event will be signaled with NumBytes 0.
   * In this case, the data pointer will be valid so as to allow the 
   * application to free the memory associated with the original get request.
   * 
   **/
  async event uint8_t *BulkReceiveDone(uint8_t *RxBuffer, uint16_t NumBytes);
  
  /**
   * This event is signaled by the component to indicate
   * that the bytes have been sent out.  Return NULL to stop the 
   * transaction and return to the IDLE state.  Return a valid buffer
   * to continue the transaction.
   **/
  async event uint8_t *BulkTransmitDone(uint8_t *TxBuffer, uint16_t NumBytes);
  
  /**
   * This event is signaled by the component to indicate
   * that the FULL-DUPLEX operation has been completed.  Return NULL
   * to stop the transaction and return to the IDLE state.  Return
   * a valid BulkTxRx_t stucture with both fields pointing to valid
   * buffer to continue the transaction.  It is a checked run-time
   * error to return a structure with one of it's fields set to NULL.
   **/
 
  async event BulkTxRxBuffer_t *BulkTxRxDone(BulkTxRxBuffer_t *TxRxBuffer, uint16_t NumBytes);
  
}
