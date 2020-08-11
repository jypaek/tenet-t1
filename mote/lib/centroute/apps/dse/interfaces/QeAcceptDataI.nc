interface QeAcceptDataI { 
  /** 
   * Pass a buffer and its length.
   * 
   * @return SUCCESS
   */ 
  command result_t passData(uint16_t sample, uint8_t samplingID);


}
 
