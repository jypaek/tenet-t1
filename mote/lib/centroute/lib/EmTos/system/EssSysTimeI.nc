interface EssSysTimeI {
  // Getter and setter for the 64 bit mote time
  async command int64_t getTime();
  async command int64_t getTimeMilliSeconds();
  async command int64_t setTime(int64_t newtime);
  // Find time resolution
  async command uint32_t getTimeResolution();
}













