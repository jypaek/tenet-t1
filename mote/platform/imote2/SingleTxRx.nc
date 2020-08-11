/**
 * SingleTxRx interface is intended to provide the generic functionality 
 * of a single sample receive or transmit.  The receive model requres that 
 * a user first issue a request to receive data (startReceive).  Successive 
 * received samples will be indicated by a receiveDone event.  A user may 
 * at any time issue a stopReceive command.   
 *
 * @author Robbie Adler	 
**/ 

interface SingleTxRx {

  /**
   * 
   * Begin a single sample at a time Receive.  a receiveDone event will be
   * generated everytime a sample is received
   *
   **/
  command result_t startReceive() ;
  
  /**
   *  Stops a single sample at a time received.
   *  
   **/
  command result_t stopReceive() ;

  /**
   * This command informs the component to send a sample
   *  
   **/
  command result_t transmit(uint32_t sample) ;

  /**
   *
   * event to indicate the reception a sample
   *
   **/
  event result_t receiveDone(uint32_t data);

  /**
   *
   * event to indcate that a transmit sample operation has been completed
   *
   **/
  event result_t transmitDone();

}
