module SampleRSSI {
  uses {
    //interface MSP430ADC12MultipleChannel as MSP430ADC12;
    //interface StdControl as ADCControl;
    interface ReceiveMsg;
    interface Leds;
  }
  provides {
    interface SampleADC as ADC;
  }
}
implementation {
  
  enum {
    RSSI_TIMEOUT = 150,
  }
  
  uint16_t *m_data;
  uint8_t m_len;
  uint16_t m_rssi;
  
  task void processRSSI();
  void set_leds();
  
  void set_leds() {
    uint16_t leds = 1;
    if( m_rssi >= 20 ) leds |= 2; //prev 15
    if( m_rssi >= 40 ) leds |= 4; //prev 35
    call Leds.set( leds );
  }
  
  command void ADC.setup(uint8_t numChannels, uint8_t *channel) {
    return;
  }
  
  command result_t ADC.getData(uint16_t *buf, uint8_t numChannels, uint32_t rate) {
    m_data = buf;
    m_len = numChannels;
    post processRSSI();
    return SUCCESS;
  }
  
  
  command void ADC.init() { 
    m_rssi = 0;
    return;
  }
  
  command void ADC.start() { return; }
  
  command void ADC.stop() { return; }
  
  task void processRSSI()
  {
    set_leds();
    m_data[0] = m_rssi;
    signal ADC.dataReady(m_data, m_len);
  }
  
  event TOS_MsgPtr ReceiveMsg.receive(TOS_MsgPtr msg){
    if (msg == NULL){
      return msg;
    }
    m_rssi  = (msg->strength + 60) & 255;
    call Timer.stop();
    call Timer.start(TIMER_ONE_SHOT, TIMEOUT);
    set_leds();
    return msg;
  }
  
  event result_t Timer.fired() {
    m_rssi = 0;
    return SUCCESS;
  }
}
