/**
 *@author Robbie Adler
 **/
includes SSP; //this will need to change to #include SSP in the future

interface SSP{
  
  
  /****************************************
   *master vs slave configuration routines
   ****************************************/
  
  /**
   *configure the port to be Master of SCLK
   *
   *@param enable:  port is master of SCLK if TRUE, slave if FALSE
   *
   *@return FAIL if error, SUCCESS otherwise
   */
  command result_t setMasterSCLK(bool enable);
  

  /**
   *configure the port to be Master of SFRM
   *
   *@param enable:  port is master of SFRM if TRUE, slave if FALSE
   *
   *@return FAIL if error, SUCCESS otherwise
   */
  command result_t setMasterSFRM(bool enable);
  
  /**
   *configure the port to be in ReceiveWithoutTransmit mode
   *
   *@param enable:  port only receives if TRUE, slave if FALSE
   *
   *@return FAIL if error, SUCCESS otherwise
   */
  command result_t setReceiveWithoutTransmit(bool enable);
    
  /**
   *configure the port to be in SPI, SSP, Microwire, or PSP modes
   *
   *@param format:  format to use...see SSP.h for encodings
   *
   *@return FAIL if error, SUCCESS otherwise
   */
  command result_t setSSPFormat(SSPFrameFormat_t format);
    
  /**
   *configure how many bits wide the port should consider 1 sample
   *
   *@param width:  bits to use...see SSP.h for encodings
   *
   *@return FAIL if error, SUCCESS otherwise
   */
  command result_t setDataWidth(SSPDataWidth_t width);
  
  /**
   *configure the port to invert the SFRM signal
   *
   *@param enable:  invert the signal if TRUE, don't invert if FALSE
   *
   *@return FAIL if error, SUCCESS otherwise
   */
  command result_t enableInvertedSFRM(bool enable);

  /**
   *configure the port to set the idle state of the CLK High (only valid in SPI mode)
   *
   *@param enable:  Clk's resting state is HIGH if TRUE, LOW if FALSE
   *
   *@return FAIL if error, SUCCESS otherwise
   */
  command result_t enableSPIClkHigh(bool enable);

  /**
   *configure the port to shift the SPIClk by 1/2 of a clock (only valid in SPI mode)
   *
   *@param enable:  Clk's is shifted if enable if TRUE, not shifted if FALSE
   *
   *@return FAIL if error, SUCCESS otherwise
   */
  command result_t shiftSPIClk(bool enable);

  /**
   *configure the depth of the RX FIFO at which point an interrupt is generated
   *
   *@param level:  fifo level...see SSP.h for encodings
   *
   *@return FAIL if error, SUCCESS otherwise
   */
  command result_t setRxFifoLevel(SSPFifoLevel_t level);
  
  /**
   *configure the depth of the TX FIFO at which point an interrupt is generated
   *
   *@param level:  fifo level...see SSP.h for encodings
   *
   *@return FAIL if error, SUCCESS otherwise
   */
  command result_t setTxFifoLevel(SSPFifoLevel_t level);
    
  /**
   *configure the width of microwire commands
   *
   *@param size:  8 bit or 16 bit commands...see SSP.h for encodings
   *
   *@return FAIL if error, SUCCESS otherwise
   */
  command result_t setMicrowireTxSize(SSPMicrowireTxSize_t size);
  
  
  /************************************
   *clk specific configuration routines
   ************************************/
  
  /**
   *configure the clock divider for the port.
   *
   *@param clkdivider:  divider for the port...clk will be 13M/(clkdivider)
   *
   *@return FAIL if error, SUCCESS otherwise
   */
  command result_t setClkRate(uint16_t clkdivider);
  
  /**
   *configure the Clk Mode of the port. 
   *
   *@param mode:  SSP_normalmode for normal operation, SSP_networkmode for 
   *              network mode
   *
   *@return FAIL if error, SUCCESS otherwise
   */
  command result_t setClkMode(SSPClkMode_t mode);

  command result_t enableManualRxPinCtrl(bool enable);
  command result_t enableManualTxPinCtrl(bool enable);
  command result_t enableManualSFRMPinCtrl(bool enable);
  command result_t enableManualSCLKPinCtrl(bool enable);

  

  
  
}
