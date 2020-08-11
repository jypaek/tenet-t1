/**
 *@author Robbie Adler
 **/

includes I2S; //this will need to change to #include SSP in the future

interface I2S{
  
  
  /****************************************
   *I2S Configuration routines
   ****************************************/
  
  /**
   *init the port
   *
   *
   *
   **/
  command result_t initI2S();
  event void initI2SDone();
  
  /**
   *enable the port
   *
   *@param enable:  port is enabled if TRUE, disabled if FALSE
   *
   *@return FAIL if error, SUCCESS otherwise
   **/
  command result_t enableI2S(bool enable);

  /**
   *enable the port
   *
   *@param enable:  port is enabled for playback if TRUE, disabled if FALSE
   *
   *@return FAIL if error, SUCCESS otherwise
   **/
  command result_t enablePlayback(bool enable);

  /**
   *enable the port
   *
   *@param enable:  port is enabled for recording if TRUE, disabled if FALSE
   *
   *@return FAIL if error, SUCCESS otherwise
   **/
  command result_t enableRecord(bool enable);


  /**
   *inform the port of the direciton of the I2S_BITCLK signal.
   *
   *@param enable:  signal is input if TRUE, output if FALSE
   *
   *@return FAIL if error, SUCCESS otherwise
   **/
  command result_t setBitClkDir(bool input);

  
  /**
   *enable MSB-justified mode
   *
   *@param enable:  MSB-justified mode is used if TRUE, normal I2S mode is used of FALSE
   *
   *@return FAIL if error, SUCCESS otherwise
   **/
  command result_t enableMSBJustifiedMode(bool enable);


  /**
   *configure the depth of the RX FIFO at which point an interrupt is generated
   *
   *@param level:  fifo level...see I2S.h for encodings
   *
   *@return FAIL if error, SUCCESS otherwise
   */
  command result_t setRxFifoLevel(I2SFifoLevel_t level);
  
  /**
   *configure the depth of the TX FIFO at which point an interrupt is generated
   *
   *@param level:  fifo level...see I2S.h for encodings
   *
   *@return FAIL if error, SUCCESS otherwise
   */
  command result_t setTxFifoLevel(I2SFifoLevel_t level);

  /**
   *configure the audio clock divider for the I2S hardware
   *
   *@param level:  clk divider...see I2S.h for encodings
   *
   *@return FAIL if error, SUCCESS otherwise
   */
  command result_t setAudioClkDivider(I2SAudioDivider_t divider);

}
