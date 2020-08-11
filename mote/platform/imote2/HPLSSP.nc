/**
 *@author Robbie Adler
 **/
//#include "SSP.H"

interface HPLSSP{
  
  //configuration routines
#if 0
  async command result_t init();  //generic command to configure things the way we defintiely need.
   async command result_t setSSPFormat(SSPFrameFormat_t format);
  async command result_t setDataWidth(SSPDataWidth_t width);
  async command result_t enableInvertedSFRM(bool enable);
  async command result_t setRxFifoLevel(SSPFifoLevel_t level);
  async command result_t setTxFifoLevel(SSPFifoLevel_t level);
  async command result_t setMicrowireTxSize(SSPMicrowireTxSize_t size);
  //clk specific configuration routines
  async command result_t setClkRate(uint16_t clkdivider);
  async command result_t setClkMode(SSPClkMode_t);
 

  //interrupt manipulation routines
  //DMA driven
  async command result_t enableTxDMAInterrupt();
  async command result_t disableTxDMAInterrupt();
  async command result_t enableRxDMAInterrupt();
  async command result_t disableRxDMAInterrupt();
  //Processor driven
  async command result_t enableTxInterrupt();
  async command result_t disableTxInterrupt();
  async command result_t enableRxInterrupt();
  async command result_t disableRxInterrupt();
  //generic
  async command result_t enableRxTimeOutInterrupt();
  async command result_t disableRxTimeOutInterrupt();
  async command result_t enableTrailingByteInterrupt();
  async command result_t disableTrailingByteInterrupt();
  
  //port behavior routines
  async command result_t enablePort(bool enable);
  async command result_t enableTxTristate(bool enable);
  async command result_t enableClkMaster(bool enable);
  async command result_t enableSFRMMaster(bool enable);
  async command result_t enableRxWithoutTx(bool enable);
  async command result_t enableFreeRunningSlaveClk(bool enable);
  async command result_t enableTrailingBytes(bool processorhandles);
  async command result_t setSCLKPhase(SSPSCLKPhase_t clkphase);
  async command result_t setSCLKPolarity(SSPSCLKPolarity_t clkpolarity);
  
   
  //test routines
  async command result_t enableTestFIFOMode(bool enable);
  async command result_t setTestModeFIFO(SSPTestModeFIFO_t whichFifo);
  async command result_t enableLoopBack(bool enable);

#endif
  async command result_t setSSCR0(uint32_t newVal);
  async command uint32_t getSSCR0();
  
  async command result_t setSSCR1(uint32_t newVal);
  async command uint32_t getSSCR1();
  
  async command result_t setSSPSP(uint32_t newVal);
  async command uint32_t getSSPSP();
  
  async command result_t setSSTO(uint32_t newVal);
  async command uint32_t getSSTO();

  async command result_t setSSITR(uint32_t newVal);
  async command uint32_t getSSITR();
  
  async command result_t setSSSR(uint32_t newVal);
  async command uint32_t getSSSR();
  
  async command result_t setSSDR(uint32_t newVal);
  async command uint32_t getSSDR();
}
