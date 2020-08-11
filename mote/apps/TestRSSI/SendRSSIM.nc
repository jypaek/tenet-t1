includes CountMsg;

module SendRSSIM {
  provides {
    interface StdControl;
  }
  uses {
    interface SendMsg;
    interface Timer;
    interface Leds;
  }
}
implementation {
  uint16_t m_count;
  TOS_Msg m_msg;
  bool m_is_sending;
  enum {
    RSSI_TIME = 100
  };
  
  command result_t StdControl.init() {
    m_count = 0;
    m_is_sending = FALSE;
    return SUCCESS;
  }
  
  command result_t StdControl.start() {
    return call Timer.start(TIMER_REPEAT, RSSI_TIME);
  }
  
  command result_t StdControl.stop() {
    return call Timer.stop();
  }
  
  event result_t Timer.fired() {
    if (!m_is_sending) {
      CountMsg_t *body = (CountMsg_t *)m_msg.data;
      body->n = m_count;
      body->src = 0;
      call SendMsg.send(TOS_BCAST_ADDR, sizeof(CountMsg_t), &m_msg);
      call Leds.set(m_count);
      m_is_sending = TRUE;
      m_count++;
    }
    return SUCCESS;
  }
  
  event result_t SendMsg.sendDone(TOS_MsgPtr msg, result_t result) {
    m_is_sending = FALSE;
    return SUCCESS;
  }
}
