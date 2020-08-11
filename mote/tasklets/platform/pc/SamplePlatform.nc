/*
 * Platform dependant part of sampling.
 *
 * @author August Joki
*/

module SamplePlatform {
  uses {
    interface Timer;
  }
  provides {
    interface SampleADC as ADC;
  }
}
implementation {
  
  uint16_t *m_data;
  uint8_t chans;
  
  command void ADC.setup(uint8_t numChannels, uint8_t * channel) {
    return;
  }
  
  command result_t ADC.getData(uint16_t *buf, uint8_t numChannels, uint32_t rate) {
    m_data = buf;
    chans = numChannels;
    return call Timer.start(TIMER_ONE_SHOT, 1);
  }
  
  event result_t Timer.fired() {
    int ii;
    for(ii = 0; ii < chans; ii++) {
      m_data[ii] = 27;
    }
    signal ADC.dataReady(m_data[0]);
//    signal ADC.dataReady(m_data, chans);
    return SUCCESS;
  }
  
  command void ADC.init() {
    return;
  }
  
  command void ADC.start() {
    return;
  }
  
  command void ADC.stop() {
    return;
  }
}
