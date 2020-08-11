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
    interface ADCError;
  }
}
implementation {
  norace bool m_adc_busy; 

  uint16_t *m_data;
  uint8_t chans;
  
  command result_t ADC.getData(uint8_t channel) {
    result_t result;

    if(m_adc_busy) return FAIL;

    //result=call something;

    if(result==SUCCESS){
      m_adc_busy = TRUE;
      call Timer.start(TIMER_ONE_SHOT,50);
    }

    if(m_adc_busy) return FAIL;

    return result;
  }
  
  command result_t ADC.validChannel(uint8_t channel) {
    return TRUE;
  }

  task void stopTimer() {
    call Timer.stop();
  }

  event result_t Timer.fired() {
    if( m_adc_busy)
		signal ADCError.error(0);
    m_adc_busy = FALSE;
    post stopTimer();
    return SUCCESS;
  }

  command void ADC.init() {
    m_adc_busy = FALSE;
    return;
  }
  
  command void ADC.start() {
    return;
  }
  
  command void ADC.stop() {
    return;
  }

  command result_t ADCError.enable() { return SUCCESS; }
  command result_t ADCError.disable() { return SUCCESS; }

}
